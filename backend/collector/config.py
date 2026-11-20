"""환경 변수. 키는 .env(저장소에 올리지 않음)나 실행 환경에 둔다 — .env.example 참고."""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def _load_dotenv(path: Path = ROOT / ".env") -> None:
    """간단한 .env 읽기 (KEY=VALUE, 이미 있는 환경 변수는 덮어쓰지 않음)"""
    if not path.exists():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


_load_dotenv()


def database_url() -> str:
    url = os.environ.get("DATABASE_URL")
    if not url:
        raise RuntimeError("DATABASE_URL이 없습니다 (예: postgres://goodmorning:goodmorning@localhost:5432/goodmorning)")
    return url


@dataclass(frozen=True)
class CoupangConfig:
    access_key: str
    secret_key: str
    sub_id: str | None
    domain: str
    search_path: str
    # 한 번 실행할 때 부를 최대 횟수 · 호출 사이 간격(초). 쿠팡 파트너스 호출 한도를 넘으면 키가 정지될 수 있다.
    max_calls: int
    min_interval_sec: float

    @staticmethod
    def from_env() -> CoupangConfig:
        access = os.environ.get("COUPANG_ACCESS_KEY", "")
        secret = os.environ.get("COUPANG_SECRET_KEY", "")
        if not access or not secret:
            raise RuntimeError("COUPANG_ACCESS_KEY · COUPANG_SECRET_KEY가 없습니다 (쿠팡 파트너스 최종 승인 후 발급)")
        return CoupangConfig(
            access_key=access,
            secret_key=secret,
            sub_id=os.environ.get("COUPANG_SUB_ID") or None,
            domain=os.environ.get("COUPANG_API_DOMAIN", "https://api-gateway.coupang.com"),
            search_path=os.environ.get("COUPANG_SEARCH_PATH", "/v2/providers/affiliate_open_api/apis/openapi/products/search"),
            max_calls=int(os.environ.get("COUPANG_MAX_CALLS", "10")),
            min_interval_sec=float(os.environ.get("COUPANG_MIN_INTERVAL_SEC", "5")),
        )
