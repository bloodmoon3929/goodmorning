-- ingest — 관리자 페이지에서 시작하는 수집 실행 (큐 · 단계별 기록 · 수집기 상태)
--
-- 관리자 페이지 → collect_run(queued) → 수집기 워커(python -m worker)가 꺼내서 실제 크롤링 · 쇼핑 API 실행
--   → 단계마다 collect_event 한 줄 (robots.txt 확인, 페이지 요청 · 응답, 파싱, 서명, API 응답, DB 저장 …)
--   → 몰마다 collect_job, 수집 결과는 raw_listing(job_id)

CREATE TABLE ingest.collect_run (
    id            BIGSERIAL PRIMARY KEY,
    kind          TEXT        NOT NULL CHECK (kind IN ('api', 'crawl')),
    params        JSONB       NOT NULL DEFAULT '{}'::jsonb,    -- mall · keyword · max_queries
    status        TEXT        NOT NULL DEFAULT 'queued' CHECK (status IN ('queued', 'running', 'success', 'failed')),
    requested_by  BIGINT      REFERENCES account.app_user (id),
    item_count    INTEGER     NOT NULL DEFAULT 0,
    error         TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    started_at    TIMESTAMPTZ,
    finished_at   TIMESTAMPTZ
);
CREATE INDEX collect_run_queue_idx ON ingest.collect_run (status, id);

CREATE TABLE ingest.collect_event (
    id       BIGSERIAL PRIMARY KEY,
    run_id   BIGINT      NOT NULL REFERENCES ingest.collect_run (id) ON DELETE CASCADE,
    at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- start · target · robots · request · response · parse · sign · api_request · api_response · save · done · error
    step     TEXT        NOT NULL,
    level    TEXT        NOT NULL DEFAULT 'info' CHECK (level IN ('info', 'warn', 'error')),
    message  TEXT        NOT NULL,
    data     JSONB
);
CREATE INDEX collect_event_run_idx ON ingest.collect_event (run_id, id);

-- 수집기 워커가 몇 초마다 남기는 생존 신호 (관리자 페이지의 "수집기 연결됨")
CREATE TABLE ingest.collect_worker (
    name     TEXT        PRIMARY KEY,
    pid      INTEGER     NOT NULL,
    seen_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE ingest.collect_job ADD COLUMN run_id BIGINT REFERENCES ingest.collect_run (id);
ALTER TABLE ingest.raw_listing ADD COLUMN job_id BIGINT REFERENCES ingest.collect_job (id);
CREATE INDEX raw_listing_job_idx ON ingest.raw_listing (job_id);
