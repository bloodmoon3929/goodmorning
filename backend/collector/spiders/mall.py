"""API가 없는 몰의 검색 결과 페이지를 읽는 크롤러

  uv run scrapy crawl mall                              # sites.toml의 몰 × 카탈로그 검색어
  uv run scrapy crawl mall -a mall="공식 온라인몰" -a query="쿠로미 마스코트 인형"
  uv run scrapy crawl mall -a max_queries=3

수집 대상: sites.toml에 선택자가 있고, DB의 online.mall.crawl_allowed = true 인 몰만.
robots.txt가 막은 주소는 Scrapy가 요청하지 않는다 (ROBOTSTXT_OBEY).
"""

from __future__ import annotations

from collections.abc import Iterator
from typing import Any
from urllib.parse import quote

import scrapy
from scrapy.http import Response
from scrapy_playwright.page import PageMethod

import config
import db
from listing import Listing, parse_price, parse_shipping
from sites import SiteConfig, load_sites


class MallSpider(scrapy.Spider):
    name = "mall"

    def __init__(self, mall: str | None = None, query: str | None = None, max_queries: str = "5", sites: str | None = None, **kwargs: Any):
        super().__init__(**kwargs)
        self.only_mall = mall
        self.query = query
        self.max_queries = int(max_queries)
        self.sites_file = sites
        # 몰별 실패 이유 (파이프라인이 ingest.collect_job에 남긴다)
        self.errors: dict[str, list[str]] = {}
        self.targets: list[SiteConfig] = []

    def _targets(self) -> list[SiteConfig]:
        sites = load_sites(self.sites_file or self.settings.get("SITES_FILE"))
        if self.only_mall:
            sites = [s for s in sites if s.mall == self.only_mall]
        if self.settings.getbool("CRAWL_ALLOWED_CHECK", True):
            with db.connect(config.database_url()) as conn:
                allowed = db.crawl_allowed_malls(conn)
            skipped = [s.mall for s in sites if s.mall not in allowed]
            if skipped:
                self.logger.warning("crawl_allowed가 아닌 몰은 건너뜁니다: %s", ", ".join(skipped))
            sites = [s for s in sites if s.mall in allowed]
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
            return
        for site in self.targets:
            for keyword, variant_id in self._queries():
                meta: dict[str, Any] = {"site": site, "query": keyword, "variant_id": variant_id}
                if site.js:
                    meta["playwright"] = True
                    meta["playwright_page_methods"] = [PageMethod("wait_for_selector", site.item, timeout=15_000)]
                yield scrapy.Request(site.search_url.format(query=quote(keyword)), meta=meta, callback=self.parse, errback=self.on_error)

    def parse(self, response: Response, **kwargs: Any) -> Iterator[Listing]:
        site: SiteConfig = response.meta["site"]
        for node in response.css(site.item):
            link = node.css(site.link).get()
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
            yield item

    def on_error(self, failure: Any) -> None:
        site: SiteConfig = failure.request.meta["site"]
        self.errors.setdefault(site.mall, []).append(f"{failure.request.url}: {failure.value!r}"[:300])
        self.logger.error("수집 실패 %s: %r", failure.request.url, failure.value)
