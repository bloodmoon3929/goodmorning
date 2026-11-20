"""쿠팡 파트너스 Open API — 상품 검색

요청마다 HMAC-SHA256 서명을 Authorization 헤더에 넣는다.
  서명할 문자열 = signed-date(yyMMddTHHmmssZ, GMT) + 메서드 + 경로 + 쿼리(물음표 제외)
  Authorization: CEA algorithm=HmacSHA256, access-key={ACCESS}, signed-date={날짜}, signature={hex}

경로 · 응답 필드는 docs/03-tech-spec.md 28번과 공개된 개발자 자료 기준이다. 키를 받으면 공식 문서
(쿠팡 파트너스 > 도움말 > Open API)와 한 번 맞춰 볼 것 — 다르면 COUPANG_SEARCH_PATH 환경 변수로 바꾼다.
"""

from __future__ import annotations

import hashlib
import hmac
import time
from datetime import UTC, datetime
from typing import Any
from urllib.parse import quote, urlencode

import httpx

from config import CoupangConfig
from listing import Listing

MALL_NAME = "쿠팡"
MALL_SITE = "https://www.coupang.com"
API_NAME = "쿠팡 파트너스"


class CoupangError(RuntimeError):
    pass


def signed_date(now: datetime | None = None) -> str:
    return (now or datetime.now(UTC)).astimezone(UTC).strftime("%y%m%dT%H%M%SZ")


def authorization(method: str, path_with_query: str, access_key: str, secret_key: str, now: datetime | None = None) -> str:
    path, _, query = path_with_query.partition("?")
    date = signed_date(now)
    message = f"{date}{method}{path}{query}"
    signature = hmac.new(secret_key.encode("utf-8"), message.encode("utf-8"), hashlib.sha256).hexdigest()
    return f"CEA algorithm=HmacSHA256, access-key={access_key}, signed-date={date}, signature={signature}"


def product_url(product_id: Any) -> str:
    """같은 상품을 한 줄로 묶는 기준 주소 (파트너스 링크는 호출마다 추적값이 달라질 수 있어 payload에 따로 둔다)"""
    return f"{MALL_SITE}/vp/products/{product_id}"


def parse_search(body: dict[str, Any], query: str | None = None, query_variant_id: int | None = None) -> list[Listing]:
    if str(body.get("rCode", "0")) != "0":
        raise CoupangError(f"쿠팡 API 오류 {body.get('rCode')}: {body.get('rMessage')}")
    data = body.get("data") or {}
    items = data.get("productData") if isinstance(data, dict) else data
    out: list[Listing] = []
    for p in items or []:
        pid = p.get("productId")
        if pid is None:
            continue
        price = p.get("productPrice")
        out.append(
            Listing(
                mall_name=MALL_NAME,
                source="api",
                source_url=product_url(pid),
                title=p.get("productName"),
                price=int(price) if price is not None else None,
                # 무료배송이 아니면 배송비를 응답에서 알 수 없다
                shipping_fee=0 if p.get("isFreeShipping") else None,
                image_url=p.get("productImage"),
                sold_out=False,
                query=query,
                query_variant_id=query_variant_id,
                extra={
                    "partner_url": p.get("productUrl"),
                    "product_id": pid,
                    "is_rocket": p.get("isRocket"),
                    "category": p.get("categoryName"),
                    "rank": p.get("rank"),
                },
            )
        )
    return out


class CoupangClient:
    def __init__(self, config: CoupangConfig, http: httpx.Client | None = None):
        self.config = config
        self.http = http or httpx.Client(timeout=10.0)
        self.calls = 0
        self._last_call = 0.0

    def search(self, keyword: str, limit: int = 10, query_variant_id: int | None = None) -> list[Listing]:
        if self.calls >= self.config.max_calls:
            raise CoupangError(f"이번 실행의 호출 한도({self.config.max_calls}회)를 다 썼습니다")
        wait = self.config.min_interval_sec - (time.monotonic() - self._last_call)
        if self.calls and wait > 0:
            time.sleep(wait)

        params: dict[str, Any] = {"keyword": keyword, "limit": max(1, min(limit, 10))}
        if self.config.sub_id:
            params["subId"] = self.config.sub_id
        # 서명한 쿼리와 보내는 쿼리가 글자까지 같아야 한다 (공백은 %20)
        path_with_query = f"{self.config.search_path}?{urlencode(params, quote_via=quote)}"
        headers = {
            "Authorization": authorization("GET", path_with_query, self.config.access_key, self.config.secret_key),
            "Content-Type": "application/json;charset=UTF-8",
        }
        self.calls += 1
        self._last_call = time.monotonic()
        res = self.http.get(self.config.domain + path_with_query, headers=headers)
        if res.status_code != 200:
            raise CoupangError(f"쿠팡 API HTTP {res.status_code}: {res.text[:200]}")
        return parse_search(res.json(), query=keyword, query_variant_id=query_variant_id)
