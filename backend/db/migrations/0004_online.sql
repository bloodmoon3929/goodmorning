-- online — 온라인 판매 정보

CREATE TABLE online.mall (
    id             BIGSERIAL PRIMARY KEY,
    name           TEXT        NOT NULL UNIQUE,
    site_url       TEXT,
    source         TEXT        NOT NULL CHECK (source IN ('api', 'crawl', 'seller')),
    api_name       TEXT,                                 -- 쿠팡 파트너스 …
    crawl_allowed  BOOLEAN     NOT NULL DEFAULT false,   -- robots.txt · 약관 확인 후 true
    is_active      BOOLEAN     NOT NULL DEFAULT true,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE online.offer (
    id            BIGSERIAL PRIMARY KEY,
    variant_id    BIGINT      NOT NULL REFERENCES catalog.variant (id),
    mall_id       BIGINT      NOT NULL REFERENCES online.mall (id),
    title         TEXT,
    url           TEXT        NOT NULL,
    price         INTEGER     NOT NULL CHECK (price >= 0),
    shipping_fee  INTEGER     DEFAULT 0 CHECK (shipping_fee >= 0),   -- NULL: 배송비를 알 수 없음
    total_price   INTEGER     GENERATED ALWAYS AS (price + shipping_fee) STORED,
    sold_out      BOOLEAN     NOT NULL DEFAULT false,
    source        TEXT        NOT NULL CHECK (source IN ('api', 'crawl', 'seller')),
    observed_at   TIMESTAMPTZ NOT NULL,
    UNIQUE (mall_id, url)
);
CREATE INDEX offer_variant_id_idx ON online.offer (variant_id);

CREATE TABLE online.offer_history (
    id            BIGSERIAL PRIMARY KEY,
    offer_id      BIGINT      NOT NULL REFERENCES online.offer (id) ON DELETE CASCADE,
    price         INTEGER     NOT NULL,
    shipping_fee  INTEGER,
    sold_out      BOOLEAN,
    observed_at   TIMESTAMPTZ NOT NULL
);
CREATE INDEX offer_history_offer_id_idx ON online.offer_history (offer_id, observed_at DESC);
