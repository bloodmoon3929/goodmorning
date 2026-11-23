"""데모 몰 · 쿠팡 형식 테스트 서버가 파는 상품 (가상). 상품 이름은 개발용 카탈로그(dev_seed.sql)와 겹치게 지었다.

sale=True 인 상품은 10분마다 1,000원 할인이 켜졌다 꺼졌다 한다 → 다시 수집하면 가격 변동이 실제로 잡힌다.
"""

from __future__ import annotations

import re
import time
from dataclasses import dataclass


@dataclass(frozen=True)
class DemoItem:
    id: int
    title: str
    price: int
    shipping: int | None  # None: 표시 안 함(알 수 없음)
    sold_out: bool = False
    sale: bool = False
    rocket: bool = False

    def current_price(self, now: float | None = None) -> int:
        if not self.sale:
            return self.price
        return self.price - 1000 if int((now or time.time()) // 600) % 2 == 0 else self.price


MALL_A = [
    DemoItem(101, "[산리오 정품] 쿠로미 마스코트 인형 10cm", 12500, 3000, sale=True),
    DemoItem(102, "산리오 쿠로미 마스코트 인형 빅 20cm", 24900, 0),
    DemoItem(103, "치이카와 마스코트 인형 (정품)", 15800, 2500),
    DemoItem(104, "마이멜로디&쿠로미 아크릴 스탠드", 9900, 3000),
    DemoItem(105, "시나모롤 미니 피규어", 7500, 3000, sold_out=True),
    DemoItem(106, "쿠로미 방울 키링", 6900, 0),
    DemoItem(107, "RG 1/144 RX-78-2 건담 Ver.2.0", 31000, 0),
    DemoItem(108, "하치와레 랜덤 키링 블라인드", 8000, 3000),
]

MALL_B = [
    DemoItem(201, "쿠로미 마스코트 인형 S(10cm) 산리오", 11900, 2500, sale=True),
    DemoItem(202, "치이카와 마스코트 인형 치이카와", 14900, 0),
    DemoItem(203, "시나모롤 미니 피규어 컬렉션", 8200, 2500),
    DemoItem(204, "피카츄 인형 M 포켓몬", 19800, 0),
    DemoItem(205, "쿠로미 쿠션 인형 L", 32000, 3000),
    DemoItem(206, "HG 1/144 자쿠 II", 17000, 0),
]

COUPANG = [
    DemoItem(9000001, "산리오 쿠로미 마스코트 인형 10cm", 13200, 0, rocket=True, sale=True),
    DemoItem(9000002, "쿠로미 마스코트 봉제인형 20cm 빅사이즈", 23500, None),
    DemoItem(9000003, "치이카와 마스코트 인형 정품", 16500, 0, rocket=True),
    DemoItem(9000004, "마이멜로디 쿠로미 아크릴 스탠드 세트", 10800, 0),
    DemoItem(9000005, "시나모롤 미니 피규어 랜덤", 6900, None),
    DemoItem(9000006, "RG RX-78-2 건담 Ver.2.0 프라모델", 29900, 0, rocket=True),
    DemoItem(9000007, "하치와레 랜덤 키링 블라인드박스", 8500, None),
]

_WORD = re.compile(r"[0-9A-Za-z가-힣]+")


def words(text: str) -> list[str]:
    return [w.lower() for w in _WORD.findall(text)]


def search(items: list[DemoItem], query: str, limit: int = 8) -> list[DemoItem]:
    """검색어 낱말이 절반 이상 들어간 상품 (실제 몰 검색처럼 비슷한 것도 섞여 나온다)"""
    q = words(query)
    if not q:
        return []
    need = max(1, (len(q) + 1) // 2)
    scored = []
    for it in items:
        title = "".join(words(it.title))
        hit = sum(1 for w in q if w in title)
        if hit >= need:
            scored.append((-hit, it.id, it))
    return [it for _, _, it in sorted(scored)][:limit]
