import functools
import http.server
import os
import shutil
import subprocess
import sys
import threading
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
SITE_DIR = Path(__file__).parent / "fixtures" / "site"


class FixtureServer(str):
    """주소 문자열 + 받은 요청 경로 목록"""

    paths: list[str]


@pytest.fixture(scope="session")
def fixture_server():
    """fixtures/site를 내 컴퓨터(127.0.0.1)에서 띄운다. 외부 사이트에는 요청하지 않는다."""
    paths: list[str] = []

    class Handler(http.server.SimpleHTTPRequestHandler):
        def log_message(self, *args):
            paths.append(self.path.split("?")[0])

    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(Handler, directory=str(SITE_DIR)))
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    base = FixtureServer(f"http://127.0.0.1:{server.server_address[1]}")
    base.paths = paths
    yield base
    server.shutdown()


def run_crawl(tmp_path: Path, sites_toml: str, *args: str, env: dict | None = None) -> tuple[subprocess.CompletedProcess, list[dict]]:
    """scrapy crawl mall 을 따로 실행하고 (Twisted 리액터를 테스트 프로세스와 섞지 않기 위해) 결과 JSON Lines를 읽는다"""
    import json

    sites = tmp_path / "sites.toml"
    sites.write_text(sites_toml, encoding="utf-8")
    out = tmp_path / "out.jsonl"
    cmd = [
        sys.executable, "-m", "scrapy", "crawl", "mall",
        "-a", f"sites={sites}",
        "-s", "DOWNLOAD_DELAY=0", "-s", "AUTOTHROTTLE_ENABLED=False", "-s", "LOG_LEVEL=INFO",
        "-O", f"{out}:jsonlines",
        *args,
    ]  # fmt: skip
    proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, timeout=120, env={**os.environ, **(env or {})}, check=False)
    items = [json.loads(line) for line in out.read_text(encoding="utf-8").splitlines()] if out.exists() else []
    return proc, items


def chromium_installed() -> bool:
    cache = Path(os.environ.get("PLAYWRIGHT_BROWSERS_PATH", Path.home() / ".cache" / "ms-playwright"))
    return cache.exists() and any(p.name.startswith("chromium") for p in cache.iterdir()) or shutil.which("chromium") is not None
