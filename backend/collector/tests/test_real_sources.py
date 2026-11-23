"""실제 수집 대상 설정 · 공식몰 공개 API 클라이언트. 외부 사이트에는 요청하지 않는다 (httpx.MockTransport).
실제 사이트로 돌린 확인은 README의 '실제 대상'에 적었다."""

import os
from pathlib import Path

import httpx
import pytest

import db
import worker
from api_clients.shopify import SHOPS, ShopifyClient, ShopifyError, matches
from sites import SiteConfig, load_sites

ROOT = Path(__file__).resolve().parents[1]


def test_real_sites_file_is_valid_and_reviewed():
    sites = load_sites(ROOT / "sites.real.toml")
    assert {s.mall for s in sites} == {"반다이남코코리아몰", "포켓몬스토어", "대원샵", "텐바이텐"}
    assert all(s.reviewed and s.site_url and s.search_url.startswith("https://") for s in sites)


def test_several_site_files_and_missing_ones(tmp_path):
    sites = load_sites(f"{ROOT / 'sites.real.toml'},{ROOT / 'sites.demo.toml'},{tmp_path / 'none.toml'}")
    assert len(sites) == 6


def test_link_pattern_builds_product_url_from_image_name():
    s = SiteConfig(
        mall="텐바이텐",
        search_url="https://x/?q={query}",
        item="li",
        title="h3::text",
        price=".p::text",
        link="img::attr(src)",
        link_pattern=r"B0*(\d+)\.jpg",
        link_format="https://www.10x10.co.kr/shopping/category_prd.asp?itemid={0}",
    )
    assert s.product_link("https://webimage.10x10.co.kr/image/basic/785/B007857505.jpg") == (
        "https://www.10x10.co.kr/shopping/category_prd.asp?itemid=7857505"
    )
    assert s.product_link("https://x/no-match.png") is None
    assert SiteConfig("m", "u{query}", "i", "t", "p", "a::attr(href)").product_link("/goods/1") == "/goods/1"


def test_link_pattern_needs_format(tmp_path):
    f = tmp_path / "s.toml"
    f.write_text('[[site]]\nmall="m"\nsearch_url="https://x/{query}"\nitem="i"\ntitle="t"\nprice="p"\nlink="l"\nlink_pattern="(\\\\d+)"\n')
    with pytest.raises(ValueError, match="link_format"):
        load_sites(f)


PRODUCTS = [
    {
        "id": 1,
        "title": "ちいかわ マスコット（ハチワレ）",
        "handle": "4580000000001",
        "product_type": "マスコット",
        "tags": ["ハチワレ"],
        "vendor": "ちいかわ",
        "variants": [{"price": "1650.00", "available": True}],
        "images": [{"src": "https://cdn.shopify.com/a.jpg"}],
    },
    {
        "id": 2,
        "title": "ちいかわ マグカップ",
        "handle": "4580000000002",
        "product_type": "食器",
        "tags": [],
        "vendor": "ちいかわ",
        "variants": [{"price": "1980.00", "available": False}],
        "images": [],
    },
]


def fake_shop(products=PRODUCTS, fx=8.5):
    seen = []

    def handler(req: httpx.Request) -> httpx.Response:
        seen.append(str(req.url))
        if req.url.path == "/meta.json":
            return httpx.Response(200, json={"currency": "JPY"})
        if req.url.path == "/products.json":
            page = int(req.url.params["page"])
            return httpx.Response(200, json={"products": products if page == 1 else []})
        if req.url.host == "api.frankfurter.app":
            return httpx.Response(200, json={"base": "JPY", "date": "2026-11-20", "rates": {"KRW": fx}})
        return httpx.Response(404)

    return httpx.Client(transport=httpx.MockTransport(handler)), seen


def test_matches_all_words_in_title_tags_type():
    assert matches(PRODUCTS[0], ["ハチワレ", "マスコット"])
    assert not matches(PRODUCTS[1], ["ハチワレ"])


def test_shopify_search_converts_yen_and_keeps_original():
    http, seen = fake_shop()
    events = []
    client = ShopifyClient(SHOPS["chiikawa_market"], http=http, on_event=lambda s, m, **d: events.append(s), min_interval_sec=0)
    items = client.search("ハチワレ マスコット")
    assert len(items) == 1
    it = items[0]
    assert it.mall_name == "치이카와 마켓" and it.source == "api"
    assert it.source_url == "https://chiikawamarket.jp/products/4580000000001"
    assert it.price == round(1650 * 8.5) and it.shipping_fee is None and not it.sold_out
    assert it.extra["original_price"] == 1650 and it.extra["currency"] == "JPY" and it.extra["fx_date"] == "2026-11-20"
    assert events == ["fx", "api_request", "api_response", "parse"]
    assert any("products.json" in u for u in seen)


def test_shopify_marks_sold_out_and_needs_keyword():
    http, _ = fake_shop()
    client = ShopifyClient(SHOPS["chiikawa_market"], http=http, min_interval_sec=0)
    assert client.search("マグカップ")[0].sold_out
    with pytest.raises(ShopifyError):
        client.search("  ")


def test_worker_runs_shopify_for_official_mall_provider():
    cmd = worker.command("api", 9, {"provider": "chiikawa_market", "keyword": "ハチワレ"})
    assert cmd[2:4] == ["api_clients", "shopify"] and cmd[cmd.index("--shop") + 1] == "chiikawa_market"
    assert cmd[cmd.index("--keyword") + 1] == "ハチワレ"
    assert worker.command("api", 9, {})[3] == "coupang"


@pytest.mark.skipif(not os.environ.get("DATABASE_URL"), reason="DATABASE_URL 없음")
def test_sync_sites_registers_reviewed_malls_once():
    conn = db.connect(os.environ["DATABASE_URL"])
    try:
        name = f"동기화 테스트몰 {os.getpid()}"
        sites = [SiteConfig(name, "https://x/{query}", "i", "t", "p", "l", site_url="https://x", reviewed="확인함")]
        assert db.sync_sites(conn, sites) == 1
        row = conn.execute("SELECT source, crawl_allowed, site_url FROM online.mall WHERE name = %s", (name,)).fetchone()
        assert row == {"source": "crawl", "crawl_allowed": True, "site_url": "https://x"}
        # 이미 있는 몰은 건드리지 않는다 (관리자가 끈 것을 되돌리지 않음)
        conn.execute("UPDATE online.mall SET crawl_allowed = false WHERE name = %s", (name,))
        assert db.sync_sites(conn, sites) == 0
        assert conn.execute("SELECT crawl_allowed FROM online.mall WHERE name = %s", (name,)).fetchone()["crawl_allowed"] is False
        conn.execute("DELETE FROM online.mall WHERE name = %s", (name,))
    finally:
        conn.close()
