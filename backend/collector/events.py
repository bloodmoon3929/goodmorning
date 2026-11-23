"""수집 실행의 단계별 기록 (ingest.collect_event). 관리자 페이지가 이 기록을 읽어 진행 상황을 보여 준다.

관리자 페이지에서 시작한 실행(ingest.collect_run)에만 남긴다. cron처럼 run 없이 돌면 아무것도 하지 않는다.
"""

from __future__ import annotations

from typing import Any

import psycopg
from psycopg.types.json import Jsonb


class RunLog:
    def __init__(self, conn: psycopg.Connection | None, run_id: int | None):
        self.conn = conn
        self.run_id = run_id

    @property
    def enabled(self) -> bool:
        return self.conn is not None and self.run_id is not None

    def emit(self, step: str, message: str, level: str = "info", **data: Any) -> None:
        if not self.enabled:
            return
        self.conn.execute(
            "INSERT INTO ingest.collect_event (run_id, step, level, message, data) VALUES (%s, %s, %s, %s, %s)",
            (self.run_id, step, level, message, Jsonb(data) if data else None),
        )


def won(v: int | None) -> str:
    return "알 수 없음" if v is None else f"{v:,}원"
