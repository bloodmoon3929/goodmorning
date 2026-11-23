"""DB 접근 (psycopg 3). 모든 값은 매개변수로 넘긴다.

수집 결과는 ingest.raw_listing에 그대로 쌓는다. 앱에는 바로 보이지 않는다.
단, 같은 몰 · 같은 주소가 이미 online.offer로 매칭되어 있으면(운영자 확정 또는 AI 매칭) 그 가격을 바로 갱신하고
가격이 바뀌었으면 online.offer_history에 남긴다. 새 주소는 매칭 대기(pending)로 남는다.
수집에 실패해서 가격을 못 읽은 경우에는 이전 값을 그대로 두고 수집 시각도 바꾸지 않는다 (루트 README 예외 상황).
"""

from __future__ import annotations

from dataclasses import dataclass

import psycopg
from psycopg.rows import dict_row
from psycopg.types.json import Jsonb

from listing import Listing


def connect(url: str) -> psycopg.Connection:
    # autocommit: 문장 하나는 바로 반영, 여러 문장은 conn.transaction()으로 묶는다
    return psycopg.connect(url, row_factory=dict_row, autocommit=True)


def get_or_create_mall(conn: psycopg.Connection, name: str, site_url: str, source: str, api_name: str | None = None) -> int:
    row = conn.execute("SELECT id FROM online.mall WHERE name = %s", (name,)).fetchone()
    if row:
        return row["id"]
    row = conn.execute(
        "INSERT INTO online.mall (name, site_url, source, api_name) VALUES (%s, %s, %s, %s) "
        "ON CONFLICT (name) DO UPDATE SET name = EXCLUDED.name RETURNING id",
        (name, site_url, source, api_name),
    ).fetchone()
    return row["id"]


def sync_sites(conn: psycopg.Connection, sites: list) -> int:
    """크롤링 설정의 몰이 DB에 없으면 만든다. robots.txt · 약관 확인 기록(reviewed)이 있으면 수집 허용으로.
    이미 있는 몰은 건드리지 않는다 (관리자 페이지에서 끈 것을 되돌리지 않게). 새로 만든 수를 돌려준다."""
    made = 0
    for s in sites:
        row = conn.execute(
            "INSERT INTO online.mall (name, site_url, source, crawl_allowed) VALUES (%s, %s, 'crawl', %s) ON CONFLICT (name) DO NOTHING RETURNING id",
            (s.mall, s.site_url, bool(s.reviewed)),
        ).fetchone()
        made += row is not None
    return made


def mall_id_by_name(conn: psycopg.Connection, name: str) -> int | None:
    row = conn.execute("SELECT id FROM online.mall WHERE name = %s", (name,)).fetchone()
    return row["id"] if row else None


def crawl_allowed_malls(conn: psycopg.Connection) -> set[str]:
    """robots.txt · 약관을 확인해 crawl_allowed = true 로 표시한 활성 몰"""
    rows = conn.execute("SELECT name FROM online.mall WHERE crawl_allowed AND is_active").fetchall()
    return {r["name"] for r in rows}


@dataclass(frozen=True)
class CatalogQuery:
    variant_id: int
    keyword: str


GENERIC_VARIANTS = {"단품", "일반"}


def catalog_queries(conn: psycopg.Connection, limit: int | None = None) -> list[CatalogQuery]:
    """카탈로그 버전마다 검색어 하나: 상품명 (+ 버전명이 구분에 필요하면 함께)"""
    rows = conn.execute(
        "SELECT v.id, p.name AS product, v.name AS variant "
        "FROM catalog.variant v JOIN catalog.product p ON p.id = v.product_id "
        "JOIN catalog.ip ip ON ip.id = p.ip_id AND ip.is_active "
        "ORDER BY p.release_date DESC NULLS LAST, v.id"
    ).fetchall()
    out = [CatalogQuery(r["id"], r["product"] if r["variant"] in GENERIC_VARIANTS else f"{r['product']} {r['variant']}") for r in rows]
    return out[:limit] if limit else out


def start_job(conn: psycopg.Connection, mall_id: int | None, kind: str, run_id: int | None = None) -> int:
    row = conn.execute(
        "INSERT INTO ingest.collect_job (mall_id, kind, run_id) VALUES (%s, %s, %s) RETURNING id", (mall_id, kind, run_id)
    ).fetchone()
    return row["id"]


def finish_job(conn: psycopg.Connection, job_id: int, item_count: int, error: str | None = None) -> None:
    conn.execute(
        "UPDATE ingest.collect_job SET status = %s, item_count = %s, error = %s, finished_at = now() WHERE id = %s",
        ("failed" if error else "success", item_count, error, job_id),
    )


@dataclass(frozen=True)
class SaveResult:
    raw_id: int
    # 이미 매칭된 판매처라 online.offer를 갱신했는지
    offer_id: int | None
    price_changed: bool
    # 갱신 전 가격 (관리자 페이지 기록용)
    old_price: int | None = None


def save_listing(conn: psycopg.Connection, mall_id: int, item: Listing, job_id: int | None = None) -> SaveResult:
    with conn.transaction():
        raw_id = conn.execute(
            "INSERT INTO ingest.raw_listing (mall_id, source, source_url, title, price, shipping_fee, image_url, payload, collected_at, job_id) "
            "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s) RETURNING id",
            (
                mall_id,
                item.source,
                item.source_url,
                item.title,
                item.price,
                item.shipping_fee,
                item.image_url,
                Jsonb(item.payload()),
                item.collected_at,
                job_id,
            ),
        ).fetchone()["id"]

        offer = conn.execute(
            "SELECT id, variant_id, price, shipping_fee, sold_out FROM online.offer WHERE mall_id = %s AND url = %s FOR UPDATE",
            (mall_id, item.source_url),
        ).fetchone()
        # 가격을 못 읽었으면(품절 표시도 없으면) 수집 실패로 보고 이전 값을 그대로 둔다
        if offer is None or (item.price is None and not item.sold_out):
            return SaveResult(raw_id, None, False)

        # 품절이라 가격이 안 보이면 가격 · 배송비는 이전 값을 유지하고 품절만 반영
        price = item.price if item.price is not None else offer["price"]
        shipping = item.shipping_fee if item.price is not None else offer["shipping_fee"]
        changed = (offer["price"], offer["shipping_fee"], offer["sold_out"]) != (price, shipping, item.sold_out)
        conn.execute(
            "UPDATE online.offer SET title = COALESCE(%s, title), price = %s, shipping_fee = %s, sold_out = %s, source = %s, observed_at = %s "
            "WHERE id = %s",
            (item.title, price, shipping, item.sold_out, item.source, item.collected_at, offer["id"]),
        )
        if changed:
            conn.execute(
                "INSERT INTO online.offer_history (offer_id, price, shipping_fee, sold_out, observed_at) VALUES (%s, %s, %s, %s, %s)",
                (offer["id"], price, shipping, item.sold_out, item.collected_at),
            )
        conn.execute(
            "UPDATE ingest.raw_listing SET match_state = 'matched', matched_variant_id = %s WHERE id = %s",
            (offer["variant_id"], raw_id),
        )
        return SaveResult(raw_id, offer["id"], changed, offer["price"])


# ------------------------------------------------------------ 관리자 페이지에서 시작한 실행 (워커)


def claim_run(conn: psycopg.Connection) -> dict | None:
    """대기 중인 실행 하나를 가져가며 running으로 바꾼다 (워커가 여럿이어도 한 번만)"""
    return conn.execute(
        "UPDATE ingest.collect_run SET status = 'running', started_at = now() "
        "WHERE id = (SELECT id FROM ingest.collect_run WHERE status = 'queued' ORDER BY id FOR UPDATE SKIP LOCKED LIMIT 1) "
        "RETURNING id, kind, params"
    ).fetchone()


def run_item_count(conn: psycopg.Connection, run_id: int) -> int:
    row = conn.execute(
        "SELECT count(*) AS n FROM ingest.raw_listing r JOIN ingest.collect_job j ON j.id = r.job_id WHERE j.run_id = %s", (run_id,)
    ).fetchone()
    return row["n"]


def finish_run(conn: psycopg.Connection, run_id: int, error: str | None) -> int:
    count = run_item_count(conn, run_id)
    conn.execute(
        "UPDATE ingest.collect_run SET status = %s, item_count = %s, error = %s, finished_at = now() WHERE id = %s",
        ("failed" if error else "success", count, error, run_id),
    )
    return count


def heartbeat(conn: psycopg.Connection, name: str, pid: int) -> None:
    conn.execute(
        "INSERT INTO ingest.collect_worker (name, pid, seen_at) VALUES (%s, %s, now()) "
        "ON CONFLICT (name) DO UPDATE SET pid = EXCLUDED.pid, seen_at = now()",
        (name, pid),
    )
