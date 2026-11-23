"""DB까지: 수집 결과 저장, 이미 매칭된 판매처 가격 갱신, crawl_allowed 확인, 수집 실행 기록.
DATABASE_URL이 없으면 건너뛴다 (마이그레이션이 적용된 DB — backend/README.md)."""

import os
import time

import pytest

import db
from listing import Listing
from tests.conftest import run_crawl
from tests.test_crawl_local import site_toml

pytestmark = pytest.mark.skipif(not os.environ.get("DATABASE_URL"), reason="DATABASE_URL 없음")


@pytest.fixture
def conn():
    c = db.connect(os.environ["DATABASE_URL"])
    yield c
    c.close()


@pytest.fixture
def mall(conn):
    """이 테스트만 쓰는 몰과, 이미 매칭된 판매처 한 줄"""
    name = f"수집 테스트몰 {time.time_ns()}"
    mall_id = db.get_or_create_mall(conn, name, "http://127.0.0.1", "crawl")
    variant_id = conn.execute("SELECT id FROM catalog.variant ORDER BY id LIMIT 1").fetchone()["id"]
    url = f"http://127.0.0.1/goods/{time.time_ns()}"
    offer_id = conn.execute(
        "INSERT INTO online.offer (variant_id, mall_id, url, price, shipping_fee, source, observed_at) "
        "VALUES (%s, %s, %s, 10000, 0, 'crawl', now() - interval '1 day') RETURNING id",
        (variant_id, mall_id, url),
    ).fetchone()["id"]
    yield {"name": name, "id": mall_id, "variant_id": variant_id, "url": url, "offer_id": offer_id}
    # 개발용 DB를 같이 쓰는 API 테스트(최저가 순서)에 끼어들지 않게 치운다
    conn.execute("DELETE FROM online.offer_history WHERE offer_id IN (SELECT id FROM online.offer WHERE mall_id = %s)", (mall_id,))
    conn.execute("DELETE FROM online.offer WHERE mall_id = %s", (mall_id,))
    conn.execute("DELETE FROM ingest.raw_listing WHERE mall_id = %s", (mall_id,))
    conn.execute("DELETE FROM ingest.collect_job WHERE mall_id = %s", (mall_id,))
    conn.execute("DELETE FROM online.mall WHERE id = %s", (mall_id,))


def listing(mall: dict, url: str, price, shipping=0, sold_out=False) -> Listing:
    return Listing(
        mall_name=mall["name"], source="crawl", source_url=url, title="테스트 굿즈", price=price, shipping_fee=shipping, sold_out=sold_out
    )


def offer_row(conn, offer_id):
    return conn.execute("SELECT price, shipping_fee, sold_out, observed_at FROM online.offer WHERE id = %s", (offer_id,)).fetchone()


def history_count(conn, offer_id):
    return conn.execute("SELECT count(*) AS n FROM online.offer_history WHERE offer_id = %s", (offer_id,)).fetchone()["n"]


def test_new_url_waits_for_matching(conn, mall):
    r = db.save_listing(conn, mall["id"], listing(mall, mall["url"] + "-new", 9000))
    assert r.offer_id is None
    row = conn.execute("SELECT match_state, price FROM ingest.raw_listing WHERE id = %s", (r.raw_id,)).fetchone()
    assert row == {"match_state": "pending", "price": 9000}


def test_matched_url_refreshes_offer_and_records_price_change(conn, mall):
    before = offer_row(conn, mall["offer_id"])
    r = db.save_listing(conn, mall["id"], listing(mall, mall["url"], 8500, shipping=2500))
    assert r.offer_id == mall["offer_id"] and r.price_changed
    after = offer_row(conn, mall["offer_id"])
    assert (after["price"], after["shipping_fee"]) == (8500, 2500)
    assert after["observed_at"] > before["observed_at"]
    assert history_count(conn, mall["offer_id"]) == 1
    raw = conn.execute("SELECT match_state, matched_variant_id FROM ingest.raw_listing WHERE id = %s", (r.raw_id,)).fetchone()
    assert raw == {"match_state": "matched", "matched_variant_id": mall["variant_id"]}

    # 같은 가격이면 기록을 늘리지 않는다
    r2 = db.save_listing(conn, mall["id"], listing(mall, mall["url"], 8500, shipping=2500))
    assert not r2.price_changed and history_count(conn, mall["offer_id"]) == 1


def test_failed_price_keeps_previous_values(conn, mall):
    before = offer_row(conn, mall["offer_id"])
    r = db.save_listing(conn, mall["id"], listing(mall, mall["url"], None))
    assert r.offer_id is None
    assert offer_row(conn, mall["offer_id"]) == before


def test_sold_out_without_price_keeps_price(conn, mall):
    r = db.save_listing(conn, mall["id"], listing(mall, mall["url"], None, shipping=None, sold_out=True))
    assert r.offer_id == mall["offer_id"]
    row = offer_row(conn, mall["offer_id"])
    assert (row["price"], row["shipping_fee"], row["sold_out"]) == (10000, 0, True)


def test_catalog_queries_use_variant_names_only_when_needed(conn):
    queries = db.catalog_queries(conn)
    keywords = {q.keyword for q in queries}
    assert "쿠로미 마스코트 인형 빅 20cm" in keywords
    assert "치이카와 마스코트 인형" in keywords  # 버전 이름이 '일반'


def test_crawl_saves_only_crawl_allowed_malls_and_logs_job(conn, fixture_server, tmp_path):
    name = f"고정몰 {time.time_ns()}"
    mall_id = db.get_or_create_mall(conn, name, fixture_server, "crawl")
    toml = site_toml(fixture_server, "search.html").replace('mall = "고정몰"', f'mall = "{name}"')

    # 아직 crawl_allowed가 아니면 요청하지 않는다
    proc, _ = run_crawl(tmp_path, toml, "-a", "query=쿠로미")
    assert proc.returncode == 0, proc.stderr[-2000:]
    assert conn.execute("SELECT count(*) AS n FROM ingest.raw_listing WHERE mall_id = %s", (mall_id,)).fetchone()["n"] == 0

    conn.execute("UPDATE online.mall SET crawl_allowed = true WHERE id = %s", (mall_id,))
    proc, _ = run_crawl(tmp_path, toml, "-a", "query=쿠로미")
    assert proc.returncode == 0, proc.stderr[-2000:]
    rows = conn.execute("SELECT title, price, match_state FROM ingest.raw_listing WHERE mall_id = %s ORDER BY id", (mall_id,)).fetchall()
    assert [r["title"] for r in rows] == ["쿠로미 마스코트 인형 10cm", "쿠로미 마스코트 인형 20cm", "쿠로미 쿠션"]
    assert all(r["match_state"] == "pending" for r in rows)
    job = conn.execute("SELECT kind, status, item_count, finished_at FROM ingest.collect_job WHERE mall_id = %s", (mall_id,)).fetchone()
    assert (job["kind"], job["status"], job["item_count"]) == ("crawl", "success", 3)
    assert job["finished_at"] is not None
