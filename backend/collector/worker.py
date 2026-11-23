"""수집기 워커: 관리자 페이지에서 누른 [수집 시작]을 실제로 실행한다.

  uv run python -m worker            # 계속 돌면서 2초마다 대기 중인 실행을 확인
  uv run python -m worker --once     # 대기 중인 실행 하나만 처리하고 끝

관리자 페이지 → API 서버가 ingest.collect_run(queued)에 한 줄 → 워커가 꺼내서
  crawl: scrapy crawl mall -a run_id=…   (Scrapy + Playwright, robots.txt 준수)
  api:   python -m api_clients coupang --run-id …   (HMAC 서명 → 쇼핑 API 호출)
을 따로 실행한다. 단계별 기록(ingest.collect_event)은 그 프로세스가 직접 남긴다.
Scrapy(Twisted 리액터)는 한 프로세스에서 다시 시작할 수 없어서 실행마다 새 프로세스를 띄운다.
"""

from __future__ import annotations

import argparse
import os
import socket
import subprocess
import sys
import threading
import time
from pathlib import Path
from typing import Any

import config
import db
import settings
from api_clients import shopify
from events import RunLog
from sites import load_sites

ROOT = Path(__file__).resolve().parent
WORKER_NAME = f"{socket.gethostname()}:{os.getpid()}"


def command(kind: str, run_id: int, params: dict[str, Any]) -> list[str]:
    max_queries = str(int(params.get("max_queries") or 3))
    if kind == "crawl":
        cmd = [sys.executable, "-m", "scrapy", "crawl", "mall", "-a", f"run_id={run_id}", "-a", f"max_queries={max_queries}"]
        if params.get("mall"):
            cmd += ["-a", f"mall={params['mall']}"]
        if params.get("keyword"):
            cmd += ["-a", f"query={params['keyword']}"]
        if os.environ.get("SITES_FILE"):
            cmd += ["-a", f"sites={os.environ['SITES_FILE']}"]
        return cmd
    if kind == "api":
        provider = params.get("provider") or "coupang"
        if provider in shopify.SHOPS:
            # 키 없는 공식몰 공개 상품 JSON (검색어 필수: 상품 이름 언어로)
            return [
                sys.executable,
                "-m",
                "api_clients",
                "shopify",
                "--shop",
                provider,
                "--run-id",
                str(run_id),
                "--keyword",
                str(params.get("keyword") or ""),
                "--limit",
                "20",
            ]
        cmd = [sys.executable, "-m", "api_clients", "coupang", "--run-id", str(run_id), "--limit", str(int(params.get("limit") or 5))]
        if params.get("keyword"):
            cmd += ["--keyword", str(params["keyword"])]
        else:
            cmd += ["--catalog", "--max-queries", max_queries]
        return cmd
    raise ValueError(f"알 수 없는 수집 종류: {kind}")


def process(conn: Any, run: dict[str, Any], timeout: int = 600) -> str:
    run_id, kind, params = run["id"], run["kind"], run["params"] or {}
    log = RunLog(conn, run_id)
    cmd = command(kind, run_id, params)
    log.emit(
        "start",
        f"수집기가 실행을 받았습니다 ({'크롤링' if kind == 'crawl' else '쇼핑 API'})",
        command=" ".join(cmd[1:]),
        worker=WORKER_NAME,
    )
    error: str | None = None
    try:
        proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, timeout=timeout, check=False)
        if proc.returncode != 0:
            tail = (proc.stderr or proc.stdout).strip().splitlines()[-3:]
            error = f"종료 코드 {proc.returncode}: " + " / ".join(tail)[:500]
    except subprocess.TimeoutExpired:
        error = f"{timeout}초 안에 끝나지 않았습니다"
    count = db.finish_run(conn, run_id, error)
    if error:
        log.emit("error", error, level="error")
    log.emit("done", f"실행 끝: 수집 {count}건" + (" (실패)" if error else ""), level="error" if error else "info", item_count=count)
    return "failed" if error else "success"


def _heartbeat(url: str, stop: threading.Event) -> None:
    """실행이 길어져도 관리자 페이지에 "연결됨"이 보이게 따로 3초마다 신호를 남긴다"""
    conn = db.connect(url)
    try:
        while not stop.is_set():
            db.heartbeat(conn, WORKER_NAME, os.getpid())
            stop.wait(3)
    finally:
        conn.close()


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="python -m worker", description="관리자 페이지에서 시작한 수집 실행을 처리한다")
    ap.add_argument("--once", action="store_true", help="대기 중인 실행 하나만 처리하고 끝")
    ap.add_argument("--interval", type=float, default=2.0)
    args = ap.parse_args(argv)
    try:
        url = config.database_url()
        conn = db.connect(url)
    except RuntimeError as e:
        print(e, file=sys.stderr)
        return 2
    sites_file = os.environ.get("SITES_FILE", settings.SITES_FILE)
    made = db.sync_sites(conn, load_sites(sites_file))  # 설정의 몰을 관리자 페이지에 바로 보이게
    print(f"수집기 워커 {WORKER_NAME} 시작 (크롤링 설정 {sites_file}, 새로 등록한 몰 {made}곳)", flush=True)
    stop = threading.Event()
    db.heartbeat(conn, WORKER_NAME, os.getpid())
    threading.Thread(target=_heartbeat, args=(url, stop), daemon=True).start()
    try:
        while True:
            run = db.claim_run(conn)
            if run:
                print(f"실행 #{run['id']} ({run['kind']}) 시작", flush=True)
                status = process(conn, run)
                print(f"실행 #{run['id']} {status}", flush=True)
            if args.once:
                return 0
            if not run:
                time.sleep(args.interval)
    except KeyboardInterrupt:
        return 0
    finally:
        stop.set()
        conn.close()


if __name__ == "__main__":
    sys.exit(main())
