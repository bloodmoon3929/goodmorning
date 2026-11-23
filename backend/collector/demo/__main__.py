"""데모: 수집 대상(데모 몰 A · B, 쿠팡 형식 테스트 서버)을 띄우고, 그 대상을 보도록 설정한 수집기 워커를 함께 돌린다.

  uv run python -m demo             # 대상 서버 3개 + 워커 → 관리자 페이지(http://localhost:8080/console/)에서 [수집 시작]
  uv run python -m demo --no-worker # 대상 서버만 (워커는 따로)

실제 키 · 몰로 바꿀 때는 데모 없이 .env(쿠팡 키)와 sites.toml(몰 선택자)을 채우고 `uv run python -m worker`.
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
import time
from pathlib import Path

from demo.servers import DEMO_ACCESS_KEY, DEMO_SECRET_KEY, CoupangHandler, MallAHandler, MallBHandler, serve

ROOT = Path(__file__).resolve().parents[1]


def demo_env(coupang_port: int) -> dict[str, str]:
    """워커 · 수집 프로세스가 데모 대상을 보게 하는 환경 변수 (실제 키 · 몰 설정은 건드리지 않는다)"""
    base = f"http://127.0.0.1:{coupang_port}"
    return {
        "SITES_FILE": str(ROOT / "sites.demo.toml"),
        "COUPANG_ACCESS_KEY": DEMO_ACCESS_KEY,
        "COUPANG_SECRET_KEY": DEMO_SECRET_KEY,
        "COUPANG_API_DOMAIN": base,
        "COUPANG_MALL_NAME": "쿠팡 (테스트 서버)",
        "COUPANG_PRODUCT_BASE": base,
        "COUPANG_MIN_INTERVAL_SEC": "1",
        "COUPANG_MAX_CALLS": "10",
    }


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="python -m demo")
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--ports", type=int, nargs=3, default=(8091, 8092, 8093), metavar=("MALL_A", "MALL_B", "COUPANG"))
    ap.add_argument("--no-worker", action="store_true")
    ap.add_argument("--verbose", action="store_true", help="대상 서버가 받은 요청을 출력")
    args = ap.parse_args(argv)

    a, b, c = args.ports
    for h in (MallAHandler, MallBHandler, CoupangHandler):
        h.quiet = not args.verbose
    servers = [serve(MallAHandler, args.host, a), serve(MallBHandler, args.host, b), serve(CoupangHandler, args.host, c)]
    print(f"데모 몰 A (정적 HTML)     http://{args.host}:{a}/search?q=쿠로미")
    print(f"데모 몰 B (자바스크립트)  http://{args.host}:{b}/search?keyword=쿠로미")
    print(f"쿠팡 형식 테스트 서버     http://{args.host}:{c}  (access-key {DEMO_ACCESS_KEY}, HMAC 서명이 틀리면 401)")

    worker = None
    if not args.no_worker:
        env = {**os.environ, **demo_env(c)}
        worker = subprocess.Popen([sys.executable, "-m", "worker"], cwd=ROOT, env=env)
        print("수집기 워커 실행 중 — 관리자 페이지에서 [수집 시작]을 누르면 이 대상들을 실제로 수집합니다 (Ctrl+C로 종료)")
    try:
        while True:
            if worker and worker.poll() is not None:
                print(f"워커가 종료되었습니다 (코드 {worker.returncode})", file=sys.stderr)
                return worker.returncode or 1
            time.sleep(1)
    except KeyboardInterrupt:
        return 0
    finally:
        if worker and worker.poll() is None:
            worker.terminate()
        for s in servers:
            s.shutdown()


if __name__ == "__main__":
    sys.exit(main())
