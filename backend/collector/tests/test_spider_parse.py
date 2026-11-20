"""크롤러 파싱: 고정 HTML(fixtures/site/search.html)을 응답으로 넣어 본다 (네트워크 없음)"""

from pathlib import Path

import pytest
from scrapy.http import HtmlResponse, Request

from sites import SiteConfig, load_sites
from spiders.mall import MallSpider

SITE = SiteConfig(
    mall="테스트몰",
    search_url="http://shop.test/search?q={query}",
    item="li.product",
    title=".name::text",
    price=".price::text",
    link="a::attr(href)",
    shipping=".shipping::text",
    image="img::attr(src)",
    sold_out=".soldout",
)


def response_for(path: str) -> HtmlResponse:
    body = (Path(__file__).parent / "fixtures" / "site" / path).read_bytes()
    req = Request("http://shop.test/search?q=x", meta={"site": SITE, "query": "쿠로미", "variant_id": 3})
    return HtmlResponse(url=req.url, body=body, encoding="utf-8", request=req)


def test_parse_reads_products_and_skips_items_without_link():
    items = list(MallSpider().parse(response_for("search.html")))
    assert [i.title for i in items] == ["쿠로미 마스코트 인형 10cm", "쿠로미 마스코트 인형 20cm", "쿠로미 쿠션"]

    a, b, c = items
    assert (a.price, a.shipping_fee, a.sold_out) == (12900, 0, False)
    assert a.source_url == "http://shop.test/goods/101"
    assert a.image_url == "http://shop.test/img/101.png"
    assert (b.price, b.shipping_fee) == (24900, 3000)
    # 가격을 못 읽은 품절 상품
    assert (c.price, c.sold_out) == (None, True)
    assert c.source_url == "https://other.example/goods/103"
    assert all(i.source == "crawl" and i.query == "쿠로미" and i.query_variant_id == 3 for i in items)


def test_load_sites_validates(tmp_path):
    ok = tmp_path / "ok.toml"
    ok.write_text(
        '[[site]]\nmall="A"\nsearch_url="http://a/?q={query}"\nitem="li"\ntitle="b::text"\nprice="i::text"\nlink="a::attr(href)"\n',
        encoding="utf-8",
    )
    assert load_sites(ok)[0].mall == "A"
    assert load_sites(tmp_path / "missing.toml") == []

    bad = tmp_path / "bad.toml"
    bad.write_text('[[site]]\nmall="A"\nsearch_url="http://a/"\nitem="li"\ntitle="b"\nprice="i"\nlink="a"\n', encoding="utf-8")
    with pytest.raises(ValueError, match="query"):
        load_sites(bad)


def test_example_sites_file_is_valid():
    assert load_sites(Path(__file__).parents[1] / "sites.example.toml")
