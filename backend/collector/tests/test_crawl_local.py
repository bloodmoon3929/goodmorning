"""scrapy crawl mall 을 실제로 돌린다. 대상은 conftest의 로컬 고정 페이지 서버뿐이다.
- robots.txt가 막은 주소는 요청하지 않는지
- 자바스크립트로 그려지는 페이지를 Playwright로 읽는지 (Chromium이 없으면 건너뜀)
DB 없이 돌리기 위해 crawl_allowed 확인과 DB 파이프라인을 끈다 (DB까지 가는 경로는 test_db.py)."""

import pytest

from tests.conftest import chromium_installed, run_crawl

NO_DB = ("-s", "CRAWL_ALLOWED_CHECK=False", "-s", "ITEM_PIPELINES={}")


def site_toml(base: str, path: str, js: bool = False) -> str:
    if js:
        return f"""[[site]]
mall = "고정몰 JS"
search_url = "{base}/{path}?q={{query}}"
js = true
item = "div.goods-card"
title = ".goods-name::text"
price = ".goods-price::text"
link = "a::attr(href)"
"""
    return f"""[[site]]
mall = "고정몰"
search_url = "{base}/{path}?q={{query}}"
item = "li.product"
title = ".name::text"
price = ".price::text"
shipping = ".shipping::text"
image = "img::attr(src)"
link = "a::attr(href)"
sold_out = ".soldout"
"""


def test_crawls_static_page(fixture_server, tmp_path):
    fixture_server.paths.clear()
    proc, items = run_crawl(tmp_path, site_toml(fixture_server, "search.html"), "-a", "query=쿠로미 인형", *NO_DB)
    assert proc.returncode == 0, proc.stderr[-2000:]
    assert [i["title"] for i in items] == ["쿠로미 마스코트 인형 10cm", "쿠로미 마스코트 인형 20cm", "쿠로미 쿠션"]
    assert items[0]["price"] == 12900 and items[0]["source_url"] == f"{fixture_server}/goods/101"
    assert items[0]["query"] == "쿠로미 인형"
    # robots.txt를 먼저 받는다
    assert fixture_server.paths[:2] == ["/robots.txt", "/search.html"]


def test_does_not_fetch_paths_disallowed_by_robots(fixture_server, tmp_path):
    fixture_server.paths.clear()
    proc, items = run_crawl(tmp_path, site_toml(fixture_server, "private/search.html"), "-a", "query=쿠로미", *NO_DB)
    assert proc.returncode == 0, proc.stderr[-2000:]
    assert items == []
    assert "/private/search.html" not in fixture_server.paths
    assert "robots.txt" in proc.stderr


@pytest.mark.skipif(not chromium_installed(), reason="Playwright Chromium 없음: uv run playwright install chromium")
def test_crawls_javascript_page_with_playwright(fixture_server, tmp_path):
    proc, items = run_crawl(tmp_path, site_toml(fixture_server, "search_js.html", js=True), "-a", "query=치이카와", *NO_DB)
    assert proc.returncode == 0, proc.stderr[-2000:]
    assert [(i["title"], i["price"]) for i in items] == [("치이카와 마스코트 키링", 9900), ("하치와레 랜덤 키링", 9000)]
