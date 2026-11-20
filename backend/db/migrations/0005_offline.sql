-- offline — 오프라인 판매 정보

CREATE TABLE offline.store (
    id           BIGSERIAL PRIMARY KEY,
    name         TEXT                   NOT NULL,
    kind         TEXT,                                   -- 캐릭터샵 / 피규어샵 / 가챠 / 팝업 …
    address      TEXT                   NOT NULL,
    location     GEOGRAPHY(Point, 4326) NOT NULL,
    phone        TEXT,
    hours        JSONB,                                  -- {"mon": {"open": "10:30", "close": "20:30"}, "tue": null, …}
    popup_until  DATE,
    info_source  TEXT                   NOT NULL CHECK (info_source IN ('owner', 'report', 'crawl')),
    is_closed    BOOLEAN                NOT NULL DEFAULT false,
    updated_at   TIMESTAMPTZ            NOT NULL DEFAULT now()
);
CREATE INDEX store_location_idx ON offline.store USING gist (location);

CREATE TABLE offline.stock (
    id            BIGSERIAL PRIMARY KEY,
    store_id      BIGINT      NOT NULL REFERENCES offline.store (id) ON DELETE CASCADE,
    variant_id    BIGINT      NOT NULL REFERENCES catalog.variant (id),
    status        TEXT        NOT NULL CHECK (status IN ('many', 'few', 'none', 'unknown')),
    price         INTEGER,
    source        TEXT        NOT NULL CHECK (source IN ('owner', 'report', 'crawl')),
    confirmed_at  TIMESTAMPTZ NOT NULL,                  -- 48시간 지나면 확인 필요
    UNIQUE (store_id, variant_id)
);
CREATE INDEX stock_variant_id_idx ON offline.stock (variant_id);

CREATE TABLE offline.stock_report (
    id           BIGSERIAL PRIMARY KEY,
    store_id     BIGINT      NOT NULL REFERENCES offline.store (id) ON DELETE CASCADE,
    variant_id   BIGINT      NOT NULL REFERENCES catalog.variant (id),
    user_id      BIGINT      NOT NULL REFERENCES account.app_user (id),
    status       TEXT        NOT NULL CHECK (status IN ('many', 'few', 'none')),
    photo_url    TEXT,
    state        TEXT        NOT NULL DEFAULT 'pending' CHECK (state IN ('pending', 'approved', 'rejected')),
    resolved_by  BIGINT      REFERENCES account.app_user (id),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX stock_report_pending_idx ON offline.stock_report (store_id, variant_id) WHERE state = 'pending';

CREATE TABLE offline.store_suggestion (
    id          BIGSERIAL PRIMARY KEY,
    store_id    BIGINT      REFERENCES offline.store (id) ON DELETE CASCADE,   -- 새 매장이면 NULL
    user_id     BIGINT      NOT NULL REFERENCES account.app_user (id),
    type        TEXT        NOT NULL CHECK (type IN ('new', 'edit', 'closed')),
    content     JSONB       NOT NULL,
    state       TEXT        NOT NULL DEFAULT 'pending' CHECK (state IN ('pending', 'approved', 'rejected')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK ((type = 'new') = (store_id IS NULL))
);
