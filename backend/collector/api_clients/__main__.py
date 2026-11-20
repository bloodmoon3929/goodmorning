"""쇼핑 API 수집 실행

  uv run python -m api_clients coupang --keyword "쿠로미 마스코트 인형"   # 검색어 직접
  uv run python -m api_clients coupang --catalog --max-queries 5          # 카탈로그 버전마다 검색어를 만들어서
  uv run python -m api_clients coupang --keyword 쿠로미 --dry-run         # DB에 넣지 않고 결과만 출력

결과는 ingest.raw_listing에 쌓이고, 실행 기록은 ingest.collect_job에 남는다.
"""

from __future__ import annotations

import argparse
import json
import sys

import httpx

import config
import db
from api_clients.coupang import API_NAME, MALL_NAME, MALL_SITE, CoupangClient, CoupangError


def run_coupang(args: argparse.Namespace) -> int:
    client = CoupangClient(config.CoupangConfig.from_env())
    if args.dry_run:
        for keyword in args.keyword:
            for item in client.search(keyword, limit=args.limit):
                print(json.dumps(item.payload(), ensure_ascii=False))
        return 0

    conn = db.connect(config.database_url())
    queries: list[tuple[str, int | None]] = [(k, None) for k in args.keyword]
    if args.catalog:
        queries += [(q.keyword, q.variant_id) for q in db.catalog_queries(conn, limit=args.max_queries)]
    if not queries:
        print("--keyword 또는 --catalog가 필요합니다", file=sys.stderr)
        return 2

    mall_id = db.get_or_create_mall(conn, MALL_NAME, MALL_SITE, "api", API_NAME)
    job_id = db.start_job(conn, mall_id, "api")
    saved = refreshed = 0
    error: str | None = None
    try:
        for keyword, variant_id in queries:
            for item in client.search(keyword, limit=args.limit, query_variant_id=variant_id):
                result = db.save_listing(conn, mall_id, item)
                saved += 1
                refreshed += result.offer_id is not None
    except (CoupangError, httpx.HTTPError) as e:
        error = str(e)
    finally:
        db.finish_job(conn, job_id, saved, error)
        conn.close()
    print(f"쿠팡: 검색 {client.calls}회, 저장 {saved}건 (이미 매칭된 판매처 갱신 {refreshed}건)" + (f", 오류: {error}" if error else ""))
    return 1 if error else 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="python -m api_clients", description="쇼핑 API 수집")
    sub = parser.add_subparsers(dest="api", required=True)
    cp = sub.add_parser("coupang", help="쿠팡 파트너스 상품 검색")
    cp.add_argument("--keyword", action="append", default=[], help="검색어 (여러 번 쓸 수 있음)")
    cp.add_argument("--catalog", action="store_true", help="카탈로그 버전마다 검색어를 만들어 검색")
    cp.add_argument("--max-queries", type=int, default=5, help="--catalog일 때 최대 검색어 수")
    cp.add_argument("--limit", type=int, default=10, help="검색어 하나당 결과 수 (최대 10)")
    cp.add_argument("--dry-run", action="store_true", help="DB에 넣지 않고 출력만")
    args = parser.parse_args(argv)
    try:
        if args.api == "coupang":
            return run_coupang(args)
    except RuntimeError as e:  # 키 · DATABASE_URL 없음
        print(e, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
