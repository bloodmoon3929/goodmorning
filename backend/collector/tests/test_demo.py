"""데모 수집 대상 서버 (몰 A · 몰 B · 쿠팡 형식 테스트 서버)를 127.0.0.1의 빈 포트에 띄워 실제 HTTP로 확인한다."""

import httpx
import pytest

from api_clients.coupang import CoupangClient, CoupangError
from config import CoupangConfig
from demo import data
from demo.servers import DEMO_ACCESS_KEY, DEMO_SECRET_KEY, SEARCH_PATH, CoupangHandler, MallAHandler, MallBHandler, serve


@pytest.fixture(scope="module")
def servers():
    started = [serve(h, "127.0.0.1", 0) for h in (MallAHandler, MallBHandler, CoupangHandler)]
    yield [f"http://127.0.0.1:{s.server_address[1]}" for s in started]
    for s in started:
        s.shutdown()


def coupang_config(base: str, **kw) -> CoupangConfig:
    cfg = {
        "access_key": DEMO_ACCESS_KEY,
        "secret_key": DEMO_SECRET_KEY,
        "sub_id": None,
        "domain": base,
        "search_path": SEARCH_PATH,
        "max_calls": 5,
        "min_interval_sec": 0,
        "mall_name": "쿠팡 (테스트 서버)",
        "product_base": base,
    }
    cfg.update(kw)
    return CoupangConfig(**cfg)


def test_search_matches_half_of_words():
    titles = [i.title for i in data.search(data.MALL_A, "쿠로미 마스코트 인형 빅 20cm")]
    assert titles[0] == "산리오 쿠로미 마스코트 인형 빅 20cm"
    assert "[산리오 정품] 쿠로미 마스코트 인형 10cm" in titles
    assert data.search(data.MALL_A, "") == []


def test_sale_price_toggles_every_ten_minutes():
    item = data.MALL_A[0]
    assert item.sale
    assert {item.current_price(0), item.current_price(600)} == {item.price, item.price - 1000}


def test_mall_a_serves_html_and_robots(servers):
    a, _, _ = servers
    robots = httpx.get(f"{a}/robots.txt").text
    assert "Disallow: /cart" in robots
    page = httpx.get(f"{a}/search", params={"q": "쿠로미"}).text
    assert page.count('class="product"') >= 3
    assert "품절" not in httpx.get(f"{a}/search", params={"q": "쿠로미"}).text  # 품절 상품은 시나모롤
    assert 'class="soldout"' in httpx.get(f"{a}/search", params={"q": "시나모롤 미니 피규어"}).text


def test_mall_b_html_has_no_items_until_javascript_runs(servers):
    _, b, _ = servers
    page = httpx.get(f"{b}/search", params={"keyword": "치이카와"}).text
    assert "goods-card" not in page.split("<script>")[0]
    items = httpx.get(f"{b}/api/goods", params={"keyword": "치이카와"}).json()
    assert items and items[0]["title"].startswith("치이카와")


def test_coupang_client_signs_and_test_server_verifies(servers):
    _, _, c = servers
    events = []
    client = CoupangClient(coupang_config(c), on_event=lambda step, msg, **d: events.append((step, d)))
    items = client.search("쿠로미 마스코트 인형", limit=3)
    assert 1 <= len(items) <= 3
    first = items[0]
    assert first.mall_name == "쿠팡 (테스트 서버)"
    assert first.source_url.startswith(f"{c}/vp/products/")
    assert first.extra["partner_url"].endswith("lptag=DEMO")
    steps = [s for s, _ in events]
    assert steps == ["sign", "api_request", "api_response"]
    sign = events[0][1]
    assert sign["signed"].endswith(
        "keyword=%EC%BF%A0%EB%A1%9C%EB%AF%B8%20%EB%A7%88%EC%8A%A4%EC%BD%94%ED%8A%B8%20%EC%9D%B8%ED%98%95&limit=3"
    )
    assert DEMO_SECRET_KEY not in sign["authorization"]


def test_test_server_rejects_wrong_secret(servers):
    _, _, c = servers
    client = CoupangClient(coupang_config(c, secret_key="wrong-secret"))
    with pytest.raises(CoupangError, match="401"):
        client.search("쿠로미")
    res = httpx.get(f"{c}{SEARCH_PATH}?keyword=x")
    assert res.status_code == 401 and res.json()["rCode"] == "401"
