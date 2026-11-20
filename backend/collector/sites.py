"""크롤링 대상 몰 설정 (sites.toml). 몰마다 검색 주소와 CSS 선택자를 적는다.

[[site]]
mall = "공식 온라인몰"                         # online.mall.name 과 같아야 한다
search_url = "https://…/search?q={query}"      # {query} 자리에 검색어(URL 인코딩)
js = false                                     # true: 자바스크립트로 그려지는 페이지 → Playwright
item = "li.product"                            # 상품 하나를 감싸는 요소
title = ".name::text"
price = ".price::text"
shipping = ".shipping::text"                   # 선택. 없거나 비면 배송비를 알 수 없음
image = "img::attr(src)"                       # 선택
link = "a::attr(href)"
sold_out = ".soldout"                          # 선택. 이 요소가 있으면 품절
"""

from __future__ import annotations

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


REQUIRED = ("mall", "search_url", "item", "title", "price", "link")


def load_sites(path: str | Path) -> list[SiteConfig]:
    path = Path(path)
    if not path.exists():
        return []
    data = tomllib.loads(path.read_text(encoding="utf-8"))
    sites = []
    for i, raw in enumerate(data.get("site", [])):
        missing = [k for k in REQUIRED if not raw.get(k)]
        if missing:
            raise ValueError(f"{path} {i + 1}번째 site에 {', '.join(missing)}이(가) 없습니다")
        if "{query}" not in raw["search_url"]:
            raise ValueError(f"{path} {raw['mall']}: search_url에 {{query}}가 없습니다")
        sites.append(SiteConfig(**{k: raw.get(k) for k in SiteConfig.__dataclass_fields__ if k in raw}))
    return sites
