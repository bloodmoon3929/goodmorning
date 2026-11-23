"""API가 없는 몰의 검색 결과 페이지를 읽는 크롤러

  uv run scrapy crawl mall                              # sites.toml의 몰 × 카탈로그 검색어
  uv run scrapy crawl mall -a mall="공식 온라인몰" -a query="쿠로미 마스코트 인형"
  uv run scrapy crawl mall -a max_queries=3
  uv run scrapy crawl mall -a run_id=12                 # 관리자 페이지에서 시작한 실행 (단계별 기록을 남김)

수집 대상: sites.toml에 선택자가 있고, DB의 online.mall.crawl_allowed = true 인 몰만.
robots.txt가 막은 주소는 Scrapy가 요청하지 않는다 (ROBOTSTXT_OBEY).
"""

from __future__ import annotations

from collections.abc import Iterator
from typing import Any
from urllib.parse import quote

import scrapy
from scrapy import signals
from scrapy.exceptions import IgnoreRequest
from scrapy.http import Request, Response
from scrapy_playwright.page import PageMethod

import config
import db
from events import RunLog, won
from listing import Listing, parse_price, parse_shipping
from sites import SiteConfig, load_sites


class MallSpider(scrapy.Spider):
    name = "mall"

    def __init__(
        self,
        mall: str | None = None,
        query: str | None = None,
        max_queries: str = "5",
        sites: str | None = None,
        run_id: str | None = None,
        **kwargs: Any,
    ):
        super().__init__(**kwargs)
        self.only_mall = mall
        self.query = query
        self.max_queries = int(max_queries)
        self.sites_file = sites
        self.run_id = int(run_id) if run_id else None
        # 몰별 실패 이유 (파이프라인이 ingest.collect_job에 남긴다)
        self.errors: dict[str, list[str]] = {}
        self.targets: list[SiteConfig] = []
        self.log_conn = db.connect(config.database_url()) if self.run_id else None
        self.run_log = RunLog(self.log_conn, self.run_id)

    @classmethod
    def from_crawler(cls, crawler: Any, *args: Any, **kwargs: Any) -> MallSpider:
        spider = super().from_crawler(crawler, *args, **kwargs)
        crawler.signals.connect(spider._on_request, signal=signals.request_reached_downloader)
        crawler.signals.connect(spider._on_response, signal=signals.response_received)
        crawler.signals.connect(spider._on_closed, signal=signals.spider_closed)
        return spider

    # ---- 단계별 기록 (관리자 페이지에서 시작한 실행만)

    @staticmethod
    def _is_robots(url: str) -> bool:
        return url.split("?")[0].endswith("/robots.txt")

    def _on_request(self, request: Request, spider: Any) -> None:
        if spider is not self:
            return
        robots = self._is_robots(request.url)
        via = "Playwright(Chromium)" if request.meta.get("playwright") else "HTTP"
        self.run_log.emit(
            "robots" if robots else "request",
            f"robots.txt 받기 {request.url}" if robots else f"GET {request.url} ({via})",
            url=request.url,
            playwright=bool(request.meta.get("playwright")),
            mall=request.meta["site"].mall if "site" in request.meta else None,
        )

    def _on_response(self, response: Response, request: Request, spider: Any) -> None:
        if spider is not self:
            return
        robots = self._is_robots(response.url)
        size = len(response.body)
        latency = request.meta.get("download_latency")
        msg = f"{response.status} · {size / 1024:.1f}KB" + (f" · {latency:.2f}초" if latency else "")
        data: dict[str, Any] = {"url": response.url, "status": response.status, "bytes": size}
        if robots:
            data["body"] = response.text[:600]
        self.run_log.emit("robots" if robots else "response", ("robots.txt " if robots else "응답 ") + msg, **data)

    def _on_closed(self, spider: Any, reason: str) -> None:
        if self.log_conn is not None:
            self.log_conn.close()

    def _targets(self) -> list[SiteConfig]:
        sites = load_sites(self.sites_file or self.settings.get("SITES_FILE"))
        if self.only_mall:
            sites = [s for s in sites if s.mall == self.only_mall]
        if self.settings.getbool("CRAWL_ALLOWED_CHECK", True):
            with db.connect(config.database_url()) as conn:
                # 설정 파일에만 있는 몰은 DB에 만든다 (확인 기록 reviewed가 있으면 수집 허용으로)
                db.sync_sites(conn, sites)
                allowed = db.crawl_allowed_malls(conn)
            skipped = [s.mall for s in sites if s.mall not in allowed]
            if skipped:
                self.logger.warning("crawl_allowed가 아닌 몰은 건너뜁니다: %s", ", ".join(skipped))
            for name in skipped:
                self.run_log.emit("target", f"건너뜀: {name} (수집 허용 꺼짐 · crawl_allowed = false)", level="warn", mall=name)
            sites = [s for s in sites if s.mall in allowed]
        for s in sites:
            self.run_log.emit(
                "target",
                f"대상 몰: {s.mall} ({'자바스크립트 → Playwright' if s.js else '정적 HTML → 일반 요청'})",
                mall=s.mall,
                search_url=s.search_url,
                js=s.js,
                selectors={"item": s.item, "title": s.title, "price": s.price, "link": s.link},
            )
        return sites

    def _queries(self) -> list[tuple[str, int | None]]:
        if self.query:
            return [(self.query, None)]
        with db.connect(config.database_url()) as conn:
            return [(q.keyword, q.variant_id) for q in db.catalog_queries(conn, limit=self.max_queries)]

    async def start(self) -> Any:
        for req in self.start_requests():
            yield req

    def start_requests(self) -> Iterator[scrapy.Request]:
        self.targets = self._targets()
        if not self.targets:
            self.logger.warning("수집할 몰이 없습니다 (sites.toml · crawl_allowed 확인)")
            self.run_log.emit("target", "수집할 몰이 없습니다 (sites.toml · crawl_allowed 확인)", level="warn")
            return
        queries = self._queries()
        self.run_log.emit("start", f"크롤링 시작: 몰 {len(self.targets)}곳 × 검색어 {len(queries)}개", queries=[q for q, _ in queries])
        for site in self.targets:
            for keyword, variant_id in queries:
                # 요청 간격은 몰마다 따로 지킨다 (같은 컴퓨터에 뜬 데모 몰 두 개도 각각)
                meta: dict[str, Any] = {"site": site, "query": keyword, "variant_id": variant_id, "download_slot": site.mall}
                if site.js:
                    meta["playwright"] = True
                    meta["playwright_page_methods"] = [PageMethod("wait_for_selector", site.item, timeout=15_000)]
                yield scrapy.Request(site.search_url.format(query=quote(keyword)), meta=meta, callback=self.parse, errback=self.on_error)

    def parse(self, response: Response, **kwargs: Any) -> Iterator[Listing]:
        site: SiteConfig = response.meta["site"]
        nodes = response.css(site.item)
        parsed: list[Listing] = []
        for node in nodes:
            link = site.product_link(node.css(site.link).get())
            if not link:
                continue
            title = " ".join(t.strip() for t in node.css(site.title).getall() if t.strip()) or None
            sold_out = bool(site.sold_out and node.css(site.sold_out))
            item = Listing(
                mall_name=site.mall,
                source="crawl",
                source_url=response.urljoin(link),
                title=title,
                price=parse_price(node.css(site.price).get()),
                shipping_fee=parse_shipping(node.css(site.shipping).get()) if site.shipping else None,
                image_url=response.urljoin(img) if site.image and (img := node.css(site.image).get()) else None,
                sold_out=sold_out,
                query=response.meta.get("query"),
                query_variant_id=response.meta.get("variant_id"),
                extra={"page_url": response.url},
            )
            parsed.append(item)
        self.run_log.emit(
            "parse",
            f'{site.mall} · "{response.meta.get("query")}" → 상품 {len(parsed)}개 읽음 (선택자 {site.item})',
            mall=site.mall,
            url=response.url,
            items=[
                {
                    "title": i.title,
                    "price": i.price,
                    "shipping": won(i.shipping_fee) if i.shipping_fee is not None else None,
                    "sold_out": i.sold_out,
                }
                for i in parsed[:10]
            ],
        )
        yield from parsed

    def on_error(self, failure: Any) -> None:
        site: SiteConfig = failure.request.meta["site"]
        if failure.check(IgnoreRequest):
            # robots.txt가 막은 주소: 요청하지 않았다
            self.run_log.emit(
                "robots", f"robots.txt가 막은 주소라 요청하지 않음: {failure.request.url}", level="warn", url=failure.request.url
            )
        else:
            self.run_log.emit("error", f"요청 실패 {failure.request.url}: {failure.value!r}"[:300], level="error", url=failure.request.url)
        self.errors.setdefault(site.mall, []).append(f"{failure.request.url}: {failure.value!r}"[:300])
        self.logger.error("수집 실패 %s: %r", failure.request.url, failure.value)
