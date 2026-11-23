"""키 없는 공식몰 공개 API — Shopify로 만든 공식몰의 공개 상품 목록 JSON

  GET {상점}/meta.json                        상점 이름 · 통화
  GET {상점}/products.json?limit=250&page=N   상품 목록 (로그인 · 키 없이 공개, robots.txt가 막지 않음)

치이카와 마켓(chiikawamarket.jp, 공식)은 검색 JSON(/search/suggest.json)을 막아 두어서(417) 목록을 쪽마다 받아 검색어로 거른다.
가격은 엔화라 ECB 기준 환율(Frankfurter API, 키 없음)로 원화로 바꿔 price에 넣고, 원래 가격 · 통화 · 환율 · 기준일은 payload에 남긴다.
해외 배송비는 응답에 없어서 알 수 없음(NULL).
"""

from __future__ import annotations

import json
import time
from collections.abc import Callable
from dataclasses import dataclass
from typing import Any

import httpx

from listing import Listing

API_NAME = "Shopify 공개 상품 JSON"
FX_URL = "https://api.frankfurter.app/latest"
USER_AGENT = "goodmorning-collector/0.1 (+https://github.com/bloodmoon3929/goodmorning)"


@dataclass(frozen=True)
class Shop:
    mall_name: str
    base: str


# 관리자 페이지의 "쇼핑 API" 선택지 (provider 값 → 상점)
SHOPS = {"chiikawa_market": Shop("치이카와 마켓", "https://chiikawamarket.jp")}


class ShopifyError(RuntimeError):
    pass


def matches(product: dict[str, Any], words: list[str]) -> bool:
    """검색어 낱말이 상품명 · 태그 · 종류에 모두 들어 있으면"""
    tags = product.get("tags") or []
    hay = " ".join(
        [product.get("title", ""), product.get("product_type", ""), " ".join(tags if isinstance(tags, list) else [tags])]
    ).lower()
    return all(w in hay for w in words)


def to_listing(shop: Shop, p: dict[str, Any], rate: float, currency: str, fx_date: str | None, query: str) -> Listing:
    variants = p.get("variants") or []
    prices = [float(v["price"]) for v in variants if v.get("price") is not None]
    original = min(prices) if prices else None
    images = p.get("images") or []
    return Listing(
        mall_name=shop.mall_name,
        source="api",
        source_url=f"{shop.base}/products/{p['handle']}",
        title=p.get("title"),
        price=round(original * rate) if original is not None else None,
        shipping_fee=None,
        image_url=images[0]["src"] if images else None,
        sold_out=bool(variants) and not any(v.get("available") for v in variants),
        query=query,
        extra={
            "api": API_NAME,
            "product_id": p.get("id"),
            "original_price": original,
            "currency": currency,
            "fx_rate": rate,
            "fx_date": fx_date,
            "vendor": p.get("vendor"),
        },
    )


class ShopifyClient:
    def __init__(
        self,
        shop: Shop,
        http: httpx.Client | None = None,
        on_event: Callable[..., None] | None = None,
        min_interval_sec: float = 2.0,
        max_pages: int = 40,
    ):
        self.shop = shop
        self.http = http or httpx.Client(timeout=20.0, follow_redirects=True, headers={"User-Agent": USER_AGENT})
        self.on_event = on_event or (lambda *a, **k: None)
        self.min_interval_sec = min_interval_sec
        self.max_pages = max_pages
        self.calls = 0
        self._last = 0.0

    def _get(self, url: str, **params: Any) -> httpx.Response:
        wait = self.min_interval_sec - (time.monotonic() - self._last)
        if self.calls and wait > 0:
            time.sleep(wait)
        self.calls += 1
        self._last = time.monotonic()
        return self.http.get(url, params=params or None)

    def currency(self) -> str:
        res = self._get(f"{self.shop.base}/meta.json")
        if res.status_code != 200:
            raise ShopifyError(f"meta.json HTTP {res.status_code}")
        return res.json().get("currency") or "KRW"

    def fx(self, currency: str) -> tuple[float, str | None]:
        """통화 → 원화 환율 (ECB 기준, Frankfurter). 원화면 1"""
        if currency == "KRW":
            return 1.0, None
        res = self.http.get(FX_URL, params={"from": currency, "to": "KRW"})
        if res.status_code != 200:
            raise ShopifyError(f"환율 API HTTP {res.status_code}")
        body = res.json()
        rate = float(body["rates"]["KRW"])
        self.on_event("fx", f"환율 {currency}→KRW {rate} (ECB 기준일 {body.get('date')})", url=str(res.url), body=json.dumps(body))
        return rate, body.get("date")

    def all_products(self) -> list[dict[str, Any]]:
        products: list[dict[str, Any]] = []
        for page in range(1, self.max_pages + 1):
            url = f"{self.shop.base}/products.json"
            self.on_event("api_request", f"GET {url}?limit=250&page={page}", url=url, page=page)
            started = time.monotonic()
            res = self._get(url, limit=250, page=page)
            ms = round((time.monotonic() - started) * 1000)
            if res.status_code != 200:
                self.on_event(
                    "api_response", f"HTTP {res.status_code} · {ms}ms", level="error", status=res.status_code, body=res.text[:400]
                )
                raise ShopifyError(f"products.json HTTP {res.status_code}")
            batch = res.json().get("products") or []
            sample = json.dumps(batch[:1], ensure_ascii=False, indent=1)[:1200]
            self.on_event("api_response", f"HTTP 200 · {ms}ms · {page}쪽 상품 {len(batch)}개", status=200, ms=ms, body=sample)
            products += batch
            if len(batch) < 250:
                break
        return products

    def search(self, keyword: str, limit: int = 20) -> list[Listing]:
        words = [w.lower() for w in keyword.split() if w]
        if not words:
            raise ShopifyError("검색어가 필요합니다 (상품 이름은 일본어: 예 マスコット, ハチワレ)")
        currency = self.currency()
        rate, fx_date = self.fx(currency)
        products = self.all_products()
        hits = [p for p in products if matches(p, words)][:limit]
        items = [to_listing(self.shop, p, rate, currency, fx_date, keyword) for p in hits]
        self.on_event(
            "parse",
            f'상품 {len(products)}개 중 "{keyword}" {len(hits)}개 (가격은 {currency}×{rate:g} → 원)',
            items=[
                {
                    "title": i.title,
                    "price": i.price,
                    "shipping": None,
                    "sold_out": i.sold_out,
                    "original": f"{i.extra['original_price']:g} {currency}",
                }
                for i in items[:10]
            ],
        )
        return items
