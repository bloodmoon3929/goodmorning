-- ingest — 수집 원본 · 요청

CREATE TABLE ingest.collect_job (
    id           BIGSERIAL PRIMARY KEY,
    mall_id      BIGINT      REFERENCES online.mall (id),
    kind         TEXT        NOT NULL CHECK (kind IN ('api', 'crawl')),
    status       TEXT        NOT NULL DEFAULT 'running' CHECK (status IN ('running', 'success', 'failed')),
    item_count   INTEGER     NOT NULL DEFAULT 0,
    error        TEXT,
    started_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    finished_at  TIMESTAMPTZ
);

-- 수집한 그대로. 앱에는 catalog.variant와 매칭된 것만 online.offer로 보인다.
CREATE TABLE ingest.raw_listing (
    id                  BIGSERIAL PRIMARY KEY,
    mall_id             BIGINT      REFERENCES online.mall (id),
    source              TEXT        NOT NULL CHECK (source IN ('api', 'crawl')),
    source_url          TEXT        NOT NULL,
    title               TEXT,
    price               INTEGER,
    shipping_fee        INTEGER,                 -- NULL: 배송비를 알 수 없음
    image_url           TEXT,
    payload             JSONB,
    match_state         TEXT        NOT NULL DEFAULT 'pending' CHECK (match_state IN ('pending', 'matched', 'review', 'rejected')),
    matched_variant_id  BIGINT      REFERENCES catalog.variant (id),
    match_score         REAL,
    collected_at        TIMESTAMPTZ NOT NULL,
    CHECK ((match_state = 'matched') = (matched_variant_id IS NOT NULL))
);
CREATE INDEX raw_listing_state_idx ON ingest.raw_listing (match_state, collected_at DESC);
CREATE INDEX raw_listing_url_idx ON ingest.raw_listing (mall_id, source_url);

CREATE TABLE ingest.product_request (
    id                  BIGSERIAL PRIMARY KEY,
    requested_by        BIGINT      NOT NULL REFERENCES account.app_user (id),
    store_id            BIGINT      REFERENCES offline.store (id),
    name                TEXT        NOT NULL,
    image_url           TEXT,
    state               TEXT        NOT NULL DEFAULT 'pending' CHECK (state IN ('pending', 'approved', 'rejected')),
    created_variant_id  BIGINT      REFERENCES catalog.variant (id),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
