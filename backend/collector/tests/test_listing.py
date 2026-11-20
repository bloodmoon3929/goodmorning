import pytest

from listing import parse_price, parse_shipping


@pytest.mark.parametrize(
    ("text", "expected"),
    [("12,900원", 12900), ("₩ 24,900", 24900), ("12,900 원~", 12900), ("가격 문의", None), ("", None), (None, None)],
)
def test_parse_price(text, expected):
    assert parse_price(text) == expected


@pytest.mark.parametrize(
    ("text", "expected"),
    [("무료배송", 0), ("배송비 무료", 0), ("배송비 3,000원", 3000), ("  ", None), (None, None)],
)
def test_parse_shipping(text, expected):
    assert parse_shipping(text) == expected
