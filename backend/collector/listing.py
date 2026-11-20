"""수집 결과 한 줄 (쇼핑 API · 크롤링 공통) → ingest.raw_listing 한 줄"""

from __future__ import annotations

import re
from dataclasses import asdict, dataclass, field
from datetime import UTC, datetime
from typing import Any


@dataclass
class Listing:
    mall_name: str
    source: str  # api · crawl
    source_url: str
    title: str | None
    price: int | None
    shipping_fee: int | None  # None: 배송비를 알 수 없음
    image_url: str | None = None
    sold_out: bool = False
    # 어떤 검색어 · 카탈로그 버전을 찾다가 나온 것인지 (매칭할 때 참고)
    query: str | None = None
    query_variant_id: int | None = None
    extra: dict[str, Any] = field(default_factory=dict)
    collected_at: datetime = field(default_factory=lambda: datetime.now(UTC))

    def payload(self) -> dict[str, Any]:
        """원본 응답 · 파싱 결과를 JSONB로 남긴다"""
        d = asdict(self)
        d.pop("collected_at")
        return d


_DIGITS = re.compile(r"\d[\d,]*")


def parse_price(text: str | None) -> int | None:
    """'12,900원' · '₩ 12900' · '12,900 원~' → 12900. 숫자가 없으면 None"""
    if not text:
        return None
    m = _DIGITS.search(text.replace(" ", ""))
    if not m:
        return None
    return int(m.group(0).replace(",", ""))


def parse_shipping(text: str | None) -> int | None:
    """'무료배송' · '배송비 무료' → 0, '배송비 3,000원' → 3000, 비었거나 알 수 없으면 None"""
    if text is None:
        return None
    t = text.strip()
    if not t:
        return None
    if "무료" in t or t.lower() in {"free", "free shipping"}:
        return 0
    return parse_price(t)
