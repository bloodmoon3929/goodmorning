"""쿠팡 파트너스 클라이언트. 실제 API는 부르지 않는다 (httpx.MockTransport).
fixtures/coupang_search.json은 공개된 응답 필드 이름으로 만든 예시 응답이다 (실제 응답을 저장한 것이 아님)."""

import hashlib
import hmac
import json
from datetime import UTC, datetime
from pathlib import Path
from urllib.parse import unquote

import httpx
import pytest

from api_clients.coupang import CoupangClient, CoupangError, authorization, parse_search, signed_date
from config import CoupangConfig

FIXTURE = json.loads((Path(__file__).parent / "fixtures" / "coupang_search.json").read_text(encoding="utf-8"))
SEARCH_PATH = "/v2/providers/affiliate_open_api/apis/openapi/products/search"


def make_config(**kw) -> CoupangConfig:
    base = {
        "access_key": "test-access",
        "secret_key": "test-secret",
        "sub_id": None,
        "domain": "https://api-gateway.coupang.com",
        "search_path": SEARCH_PATH,
        "max_calls": 3,
        "min_interval_sec": 0,
    }
    base.update(kw)
    return CoupangConfig(**base)


def test_signed_date_is_gmt_yymmdd_t_hhmmss_z():
    kst = datetime(2026, 11, 20, 18, 5, 9).astimezone(UTC)
    assert signed_date(datetime(2026, 11, 20, 9, 5, 9, tzinfo=UTC)) == "261120T090509Z"
    assert signed_date(kst).endswith("Z")


def test_authorization_signs_date_method_path_query():
    now = datetime(2026, 11, 20, 9, 5, 9, tzinfo=UTC)
    header = authorization("GET", f"{SEARCH_PATH}?keyword=%EC%BF%A0%EB%A1%9C%EB%AF%B8&limit=10", "AK", "SK", now)
    expected = hmac.new(
        b"SK", f"261120T090509ZGET{SEARCH_PATH}keyword=%EC%BF%A0%EB%A1%9C%EB%AF%B8&limit=10".encode(), hashlib.sha256
    ).hexdigest()
    assert header == f"CEA algorithm=HmacSHA256, access-key=AK, signed-date=261120T090509Z, signature={expected}"


def test_parse_search_maps_fields():
    items = parse_search(FIXTURE, query="쿠로미 마스코트 인형", query_variant_id=7)
    assert len(items) == 2
    first, second = items
    assert first.mall_name == "쿠팡" and first.source == "api"
    assert first.source_url == "https://www.coupang.com/vp/products/1000000001"
    assert first.price == 12500 and first.shipping_fee == 0
    # 무료배송이 아니면 배송비를 모른다 (0으로 넣지 않는다)
    assert second.shipping_fee is None
    assert first.extra["partner_url"].startswith("https://link.coupang.com/")
    assert first.query_variant_id == 7


def test_parse_search_raises_on_error_code():
    with pytest.raises(CoupangError):
        parse_search({"rCode": "400", "rMessage": "Invalid keyword"})


def test_client_sends_signed_request_and_respects_call_limit():
    seen = []

    def handler(request: httpx.Request) -> httpx.Response:
        seen.append(request)
        return httpx.Response(200, json=FIXTURE)

    client = CoupangClient(make_config(max_calls=1, sub_id="goodmorning"), http=httpx.Client(transport=httpx.MockTransport(handler)))
    items = client.search("쿠로미 마스코트 인형", limit=5)
    assert len(items) == 2

    req = seen[0]
    raw_path = req.url.raw_path.decode()
    assert raw_path.startswith(SEARCH_PATH + "?")
    # 공백은 %20 으로 (서명한 쿼리와 같은 글자)
    assert "keyword=%EC%BF%A0%EB%A1%9C%EB%AF%B8%20" in raw_path
    assert unquote(req.url.params["keyword"]) == "쿠로미 마스코트 인형"
    assert req.url.params["limit"] == "5" and req.url.params["subId"] == "goodmorning"

    auth = req.headers["Authorization"]
    date = auth.split("signed-date=")[1].split(",")[0]
    path, _, query = raw_path.partition("?")
    expected = hmac.new(b"test-secret", f"{date}GET{path}{query}".encode(), hashlib.sha256).hexdigest()
    assert auth.endswith(f"signature={expected}")

    with pytest.raises(CoupangError, match="호출 한도"):
        client.search("치이카와")


def test_client_raises_on_http_error():
    client = CoupangClient(
        make_config(), http=httpx.Client(transport=httpx.MockTransport(lambda r: httpx.Response(401, text="unauthorized")))
    )
    with pytest.raises(CoupangError, match="401"):
        client.search("쿠로미")
