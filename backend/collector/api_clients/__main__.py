"""쇼핑 API 수집 실행

  uv run python -m api_clients coupang --keyword "쿠로미 마스코트 인형"   # 검색어 직접
  uv run python -m api_clients coupang --catalog --max-queries 5          # 카탈로그 버전마다 검색어를 만들어서
  uv run python -m api_clients coupang --keyword 쿠로미 --dry-run         # DB에 넣지 않고 결과만 출력
  uv run python -m api_clients coupang --catalog --run-id 12               # 관리자 페이지에서 시작한 실행 (단계별 기록)
  uv run python -m api_clients shopify --shop chiikawa_market --keyword マスコット   # 키 없는 공식몰 공개 상품 JSON

결과는 ingest.raw_listing에 쌓이고, 실행 기록은 ingest.collect_job에 남는다.
"""

from __future__ import annotations

import argparse
import json
import sys

import httpx

import config
import db
from api_clients import shopify
from api_clients.coupang import API_NAME, CoupangClient, CoupangError
from events import RunLog, won
from listing import Listing


def save_with_log(conn, log: RunLog, mall_id: int, item: Listing, job_id: int) -> bool:
    """저장하고 기록을 남긴다. 이미 연결된 판매처를 갱신했으면 True"""
    result = db.save_listing(conn, mall_id, item, job_id)
    if result.offer_id is None:
        msg = f"저장 #{result.raw_id} {item.title} · {won(item.price)} → 새 상품이라 매칭 대기"
    elif result.price_changed:
        msg = f"저장 #{result.raw_id} {item.title} → 이미 연결된 판매처 가격 갱신 {won(result.old_price)} → {won(item.price)}"
    else:
        msg = f"저장 #{result.raw_id} {item.title} → 이미 연결된 판매처, 가격 그대로 {won(item.price)}"
    log.emit("save", msg, raw_id=result.raw_id, offer_id=result.offer_id, price_changed=result.price_changed)
    return result.offer_id is not None


def run_coupang(args: argparse.Namespace) -> int:
    cfg = config.CoupangConfig.from_env()
    if args.dry_run:
        client = CoupangClient(cfg)
        for keyword in args.keyword:
            for item in client.search(keyword, limit=args.limit):
                print(json.dumps(item.payload(), ensure_ascii=False))
        return 0

    conn = db.connect(config.database_url())
    log = RunLog(conn, args.run_id)
    client = CoupangClient(cfg, on_event=log.emit)
    queries: list[tuple[str, int | None]] = [(k, None) for k in args.keyword]
    if args.catalog:
        queries += [(q.keyword, q.variant_id) for q in db.catalog_queries(conn, limit=args.max_queries)]
    if not queries:
        print("--keyword 또는 --catalog가 필요합니다", file=sys.stderr)
        log.emit("error", "검색어가 없습니다", level="error")
        conn.close()
        return 2

    mall_id = db.get_or_create_mall(conn, cfg.mall_name, cfg.product_base, "api", API_NAME)
    job_id = db.start_job(conn, mall_id, "api", args.run_id)
    log.emit(
        "start",
        f"쇼핑 API 수집 시작: {cfg.mall_name} · 검색어 {len(queries)}개 (호출 한도 {cfg.max_calls}회, 간격 {cfg.min_interval_sec:g}초)",
        api=API_NAME,
        domain=cfg.domain,
        queries=[q for q, _ in queries],
    )
    saved = refreshed = 0
    error: str | None = None
    try:
        for keyword, variant_id in queries:
            for item in client.search(keyword, limit=args.limit, query_variant_id=variant_id):
                refreshed += save_with_log(conn, log, mall_id, item, job_id)
                saved += 1
    except (CoupangError, httpx.HTTPError) as e:
        error = str(e)
        log.emit("error", error[:300], level="error")
    finally:
        db.finish_job(conn, job_id, saved, error)
        log.emit("done", f"{cfg.mall_name}: 검색 {client.calls}회 · {saved}건 저장", level="error" if error else "info")
        conn.close()
    print(f"쿠팡: 검색 {client.calls}회, 저장 {saved}건 (이미 매칭된 판매처 갱신 {refreshed}건)" + (f", 오류: {error}" if error else ""))
    return 1 if error else 0


def run_shopify(args: argparse.Namespace) -> int:
    shop = shopify.SHOPS.get(args.shop)
    if shop is None:
        print(f"알 수 없는 상점: {args.shop} (가능: {', '.join(shopify.SHOPS)})", file=sys.stderr)
        return 2
    client_kwargs = {"min_interval_sec": args.interval, "max_pages": args.max_pages}
    if args.dry_run:
        for item in shopify.ShopifyClient(shop, **client_kwargs).search(args.keyword, limit=args.limit):
            print(json.dumps(item.payload(), ensure_ascii=False, default=str))
        return 0

    conn = db.connect(config.database_url())
    log = RunLog(conn, args.run_id)
    client = shopify.ShopifyClient(shop, on_event=log.emit, **client_kwargs)
    mall_id = db.get_or_create_mall(conn, shop.mall_name, shop.base, "api", shopify.API_NAME)
    job_id = db.start_job(conn, mall_id, "api", args.run_id)
    log.emit(
        "start",
        f'공개 API 수집 시작: {shop.mall_name} ({shop.base}) · 검색어 "{args.keyword}" · 요청 간격 {args.interval:g}초 · 최대 {args.max_pages}쪽',
        api=shopify.API_NAME,
        domain=shop.base,
    )
    saved = 0
    error: str | None = None
    try:
        for item in client.search(args.keyword, limit=args.limit):
            save_with_log(conn, log, mall_id, item, job_id)
            saved += 1
    except (shopify.ShopifyError, httpx.HTTPError) as e:
        error = str(e)
        log.emit("error", error[:300], level="error")
    finally:
        db.finish_job(conn, job_id, saved, error)
        log.emit("done", f"{shop.mall_name}: 요청 {client.calls}회 · {saved}건 저장", level="error" if error else "info")
        conn.close()
    print(f"{shop.mall_name}: 요청 {client.calls}회, 저장 {saved}건" + (f", 오류: {error}" if error else ""))
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
    cp.add_argument("--run-id", type=int, default=None, help="관리자 페이지에서 시작한 실행 번호 (단계별 기록을 남김)")
    sp = sub.add_parser("shopify", help="키 없는 공식몰 공개 상품 JSON (Shopify)")
    sp.add_argument("--shop", default="chiikawa_market", help=f"상점 ({', '.join(shopify.SHOPS)})")
    sp.add_argument("--keyword", required=True, help="검색어 (상품 이름 언어로: 치이카와 마켓은 일본어)")
    sp.add_argument("--limit", type=int, default=20, help="저장할 최대 상품 수")
    sp.add_argument("--interval", type=float, default=2.0, help="요청 사이 간격(초)")
    sp.add_argument("--max-pages", type=int, default=40, help="상품 목록 최대 쪽 수 (한 쪽 250개)")
    sp.add_argument("--dry-run", action="store_true", help="DB에 넣지 않고 출력만")
    sp.add_argument("--run-id", type=int, default=None, help="관리자 페이지에서 시작한 실행 번호")
    args = parser.parse_args(argv)
    try:
        if args.api == "coupang":
            return run_coupang(args)
        if args.api == "shopify":
            return run_shopify(args)
    except RuntimeError as e:  # 키 · DATABASE_URL 없음
        print(e, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
