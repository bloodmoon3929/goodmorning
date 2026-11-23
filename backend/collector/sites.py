"""크롤링 대상 몰 설정 (sites.real.toml · sites.demo.toml · sites.toml). 몰마다 검색 주소와 CSS 선택자를 적는다.

[[site]]
mall = "공식 온라인몰"                         # online.mall.name 과 같다 (없으면 수집기가 만든다)
site_url = "https://…"                         # 선택. 몰 첫 화면 (online.mall.site_url)
reviewed = "2026-11-23 robots.txt · 약관 확인"  # 선택. 확인한 기록이 있으면 처음 만들 때 수집 허용(crawl_allowed)으로
search_url = "https://…/search?q={query}"      # {query} 자리에 검색어(URL 인코딩)
js = false                                     # true: 자바스크립트로 그려지는 페이지 → Playwright
item = "li.product"                            # 상품 하나를 감싸는 요소
title = ".name::text"
price = ".price::text"
shipping = ".shipping::text"                   # 선택. 없거나 비면 배송비를 알 수 없음
image = "img::attr(src)"                       # 선택
link = "a::attr(href)"                         # 상품 주소. 요소 자신이면 "::attr(href)"
link_pattern = 'B0*(\\d+)\\.jpg'               # 선택. 링크가 자바스크립트라 다른 값(예: 이미지 파일명)에서 번호를 뽑을 때
link_format = "https://…?itemid={0}"           # 선택. link_pattern으로 뽑은 값을 넣을 주소
sold_out = ".soldout"                          # 선택. 이 요소가 있으면 품절

SITES_FILE에 여러 파일을 쉼표로 적으면 모두 읽는다 (예: "sites.real.toml,sites.toml").
"""

from __future__ import annotations

import re
import tomllib
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class SiteConfig:
    mall: str
    search_url: str
    item: str
    title: str
    price: str
    link: str
    js: bool = False
    shipping: str | None = None
    image: str | None = None
    sold_out: str | None = None
    link_pattern: str | None = None
    link_format: str | None = None
    site_url: str | None = None
    reviewed: str | None = None

    def product_link(self, raw: str | None) -> str | None:
        """선택자로 읽은 값 → 상품 주소. link_pattern이 있으면 뽑은 값을 link_format에 넣는다"""
        if not raw or not self.link_pattern:
            return raw
        m = re.search(self.link_pattern, raw)
        if not m:
            return None
        return (self.link_format or "{0}").format(*m.groups())


REQUIRED = ("mall", "search_url", "item", "title", "price", "link")


def load_sites(paths: str | Path) -> list[SiteConfig]:
    sites: list[SiteConfig] = []
    for one in str(paths).split(","):
        path = Path(one.strip())
        if not one.strip() or not path.exists():
            continue
        data = tomllib.loads(path.read_text(encoding="utf-8"))
        for i, raw in enumerate(data.get("site", [])):
            missing = [k for k in REQUIRED if not raw.get(k)]
            if missing:
                raise ValueError(f"{path} {i + 1}번째 site에 {', '.join(missing)}이(가) 없습니다")
            if "{query}" not in raw["search_url"]:
                raise ValueError(f"{path} {raw['mall']}: search_url에 {{query}}가 없습니다")
            if raw.get("link_pattern") and not raw.get("link_format"):
                raise ValueError(f"{path} {raw['mall']}: link_pattern에는 link_format이 필요합니다")
            sites.append(SiteConfig(**{k: raw.get(k) for k in SiteConfig.__dataclass_fields__ if k in raw}))
    return sites
