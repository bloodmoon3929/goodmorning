"""관리자 페이지에서 누른 [수집 시작]과 같은 경로를 끝까지: collect_run(queued) → 워커 → 실제 크롤링 · API 호출 → 단계별 기록 · 결과.
대상은 이 테스트가 띄우는 데모 서버뿐이다. DATABASE_URL이 없으면 건너뛴다 (마이그레이션 + 개발용 데이터가 들어간 DB)."""

import os

import pytest
from psycopg.types.json import Jsonb

import db
import worker
from demo.servers import DEMO_ACCESS_KEY, DEMO_SECRET_KEY, CoupangHandler, MallAHandler, serve

pytestmark = pytest.mark.skipif(not os.environ.get("DATABASE_URL"), reason="DATABASE_URL 없음")

MALL_A = "데모 몰 A (정적 HTML)"


@pytest.fixture
def conn():
    c = db.connect(os.environ["DATABASE_URL"])
    yield c
    c.close()


@pytest.fixture
def demo(tmp_path, monkeypatch):
    """데모 몰 A · 쿠팡 형식 테스트 서버를 빈 포트에 띄우고, 워커가 그쪽을 보게 환경 변수를 바꾼다"""
    a = serve(MallAHandler, "127.0.0.1", 0)
    c = serve(CoupangHandler, "127.0.0.1", 0)
    base_a = f"http://127.0.0.1:{a.server_address[1]}"
    base_c = f"http://127.0.0.1:{c.server_address[1]}"
    sites = tmp_path / "sites.toml"
    sites.write_text(
        f"""[[site]]
mall = "{MALL_A}"
search_url = "{base_a}/search?q={{query}}"
item = "li.product"
title = ".name::text"
price = ".price::text"
shipping = ".shipping::text"
image = "img::attr(src)"
link = "a::attr(href)"
sold_out = ".soldout"
""",
        encoding="utf-8",
    )
    env = {
        "SITES_FILE": str(sites),
        "COUPANG_ACCESS_KEY": DEMO_ACCESS_KEY,
        "COUPANG_SECRET_KEY": DEMO_SECRET_KEY,
        "COUPANG_API_DOMAIN": base_c,
        "COUPANG_MALL_NAME": "쿠팡 (테스트 서버)",
        "COUPANG_PRODUCT_BASE": base_c,
        "COUPANG_MIN_INTERVAL_SEC": "0",
    }
    for k, v in env.items():
        monkeypatch.setenv(k, v)
    yield {"a": base_a, "c": base_c}
    a.shutdown()
    c.shutdown()


def queue(conn, kind: str, **params) -> int:
    return conn.execute(
        "INSERT INTO ingest.collect_run (kind, params) VALUES (%s, %s) RETURNING id", (kind, Jsonb({"max_queries": 1, **params}))
    ).fetchone()["id"]


def run_once(conn, run_id: int) -> dict:
    # 다른 테스트가 남긴 대기 실행이 먼저 잡히지 않게, 이 실행만 남긴다
    conn.execute("UPDATE ingest.collect_run SET status = 'failed', error = '테스트 정리' WHERE status = 'queued' AND id <> %s", (run_id,))
    assert worker.main(["--once"]) == 0
    return conn.execute("SELECT status, item_count, error FROM ingest.collect_run WHERE id = %s", (run_id,)).fetchone()


def steps(conn, run_id: int) -> list[str]:
    return [r["step"] for r in conn.execute("SELECT step FROM ingest.collect_event WHERE run_id = %s ORDER BY id", (run_id,)).fetchall()]


def test_crawl_run_fetches_robots_then_pages_and_logs_each_step(conn, demo, monkeypatch):
    monkeypatch.setattr(worker, "command", _fast(worker.command))
    conn.execute("UPDATE online.mall SET crawl_allowed = true WHERE name = %s", (MALL_A,))
    run_id = queue(conn, "crawl", mall=MALL_A, keyword="쿠로미 마스코트 인형")
    row = run_once(conn, run_id)
    assert row["status"] == "success", row
    assert row["item_count"] >= 2
    s = steps(conn, run_id)
    # 워커 시작 → 대상 확인 → robots.txt → 페이지 요청 · 응답 → 파싱 → 저장 → 몰별 끝 → 실행 끝
    for expected in ["start", "target", "robots", "request", "response", "parse", "save", "done"]:
        assert expected in s, s
    assert s.index("robots") < s.index("request")
    titles = [
        r["title"]
        for r in conn.execute(
            "SELECT r.title FROM ingest.raw_listing r JOIN ingest.collect_job j ON j.id = r.job_id WHERE j.run_id = %s", (run_id,)
        ).fetchall()
    ]
    assert "[산리오 정품] 쿠로미 마스코트 인형 10cm" in titles


def test_crawl_run_skips_mall_when_not_allowed(conn, demo, monkeypatch):
    monkeypatch.setattr(worker, "command", _fast(worker.command))
    conn.execute("UPDATE online.mall SET crawl_allowed = false WHERE name = %s", (MALL_A,))
    try:
        run_id = queue(conn, "crawl", mall=MALL_A, keyword="쿠로미")
        row = run_once(conn, run_id)
        assert row["status"] == "success" and row["item_count"] == 0
        msgs = [r["message"] for r in conn.execute("SELECT message FROM ingest.collect_event WHERE run_id = %s", (run_id,)).fetchall()]
        assert any("건너뜀" in m and "crawl_allowed" in m for m in msgs), msgs
        assert "request" not in steps(conn, run_id)
    finally:
        conn.execute("UPDATE online.mall SET crawl_allowed = true WHERE name = %s", (MALL_A,))


def test_api_run_signs_calls_and_saves(conn, demo):
    run_id = queue(conn, "api", keyword="치이카와 마스코트 인형")
    row = run_once(conn, run_id)
    assert row["status"] == "success", row
    assert row["item_count"] >= 1
    s = steps(conn, run_id)
    assert s.index("sign") < s.index("api_request") < s.index("api_response") < s.index("save")
    auth = conn.execute(
        "SELECT data->>'authorization' AS a FROM ingest.collect_event WHERE run_id = %s AND step = 'sign'", (run_id,)
    ).fetchone()["a"]
    assert auth.startswith("CEA algorithm=HmacSHA256, access-key=demo-access-key, signed-date=")
    mall = conn.execute(
        "SELECT m.name FROM ingest.collect_job j JOIN online.mall m ON m.id = j.mall_id WHERE j.run_id = %s", (run_id,)
    ).fetchone()["name"]
    assert mall == "쿠팡 (테스트 서버)"


def test_failed_api_run_is_marked_failed(conn, demo, monkeypatch):
    monkeypatch.setenv("COUPANG_SECRET_KEY", "wrong-secret")
    run_id = queue(conn, "api", keyword="쿠로미")
    row = run_once(conn, run_id)
    assert row["status"] == "failed"
    assert "401" in (row["error"] or "") or any(
        "401" in r["message"]
        for r in conn.execute("SELECT message FROM ingest.collect_event WHERE run_id = %s AND level = 'error'", (run_id,)).fetchall()
    )


def test_heartbeat_marks_worker_alive(conn):
    db.heartbeat(conn, "pytest-worker", os.getpid())
    row = conn.execute(
        "SELECT seen_at > now() - interval '5 seconds' AS fresh FROM ingest.collect_worker WHERE name = 'pytest-worker'"
    ).fetchone()
    assert row["fresh"]
    conn.execute("DELETE FROM ingest.collect_worker WHERE name = 'pytest-worker'")


def _fast(command):
    """테스트에서는 요청 간격을 두지 않는다 (실제 실행은 settings.py의 3초)"""

    def wrapped(kind, run_id, params):
        cmd = command(kind, run_id, params)
        if kind == "crawl":
            cmd += ["-s", "DOWNLOAD_DELAY=0", "-s", "AUTOTHROTTLE_ENABLED=False"]
        return cmd

    return wrapped


def test_command_lines(monkeypatch):
    monkeypatch.delenv("SITES_FILE", raising=False)
    crawl = worker.command("crawl", 7, {"mall": "몰", "keyword": "쿠로미", "max_queries": 2})
    assert crawl[1:5] == ["-m", "scrapy", "crawl", "mall"]
    assert crawl[5:] == ["-a", "run_id=7", "-a", "max_queries=2", "-a", "mall=몰", "-a", "query=쿠로미"]
    api = worker.command("api", 7, {"max_queries": 4})
    assert api[api.index("--run-id") + 1] == "7" and "--catalog" in api and api[api.index("--max-queries") + 1] == "4"
    with pytest.raises(ValueError):
        worker.command("ftp", 7, {})
