-- account — 사용자 · 판매자 (app_user는 0003)

CREATE TABLE account.user_ip (
    user_id     BIGINT      NOT NULL REFERENCES account.app_user (id) ON DELETE CASCADE,
    ip_id       BIGINT      NOT NULL REFERENCES catalog.ip (id) ON DELETE CASCADE,
    sort_order  SMALLINT    NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, ip_id)
);

CREATE TABLE account.ip_request (
    id             BIGSERIAL PRIMARY KEY,
    user_id        BIGINT      NOT NULL REFERENCES account.app_user (id) ON DELETE CASCADE,
    name           TEXT        NOT NULL,
    state          TEXT        NOT NULL DEFAULT 'pending' CHECK (state IN ('pending', 'added', 'rejected')),
    created_ip_id  BIGINT      REFERENCES catalog.ip (id),
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 판매자 계정 ↔ 매장 · 몰 (본인 매장 · 몰만 수정)
CREATE TABLE account.seller_member (
    id           BIGSERIAL PRIMARY KEY,
    user_id      BIGINT NOT NULL REFERENCES account.app_user (id) ON DELETE CASCADE,
    store_id     BIGINT REFERENCES offline.store (id) ON DELETE CASCADE,
    mall_id      BIGINT REFERENCES online.mall (id) ON DELETE CASCADE,
    role         TEXT   NOT NULL DEFAULT 'owner' CHECK (role IN ('owner', 'staff')),
    verified_at  TIMESTAMPTZ,
    CHECK (store_id IS NOT NULL OR mall_id IS NOT NULL)
);
CREATE INDEX seller_member_store_id_idx ON account.seller_member (store_id);
CREATE INDEX seller_member_user_id_idx ON account.seller_member (user_id);

CREATE TABLE account.wishlist (
    user_id     BIGINT      NOT NULL REFERENCES account.app_user (id) ON DELETE CASCADE,
    variant_id  BIGINT      NOT NULL REFERENCES catalog.variant (id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, variant_id)
);

CREATE TABLE account.saved_store (
    user_id     BIGINT      NOT NULL REFERENCES account.app_user (id) ON DELETE CASCADE,
    store_id    BIGINT      NOT NULL REFERENCES offline.store (id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, store_id)
);

CREATE TABLE account.alert (
    id            BIGSERIAL PRIMARY KEY,
    user_id       BIGINT  NOT NULL REFERENCES account.app_user (id) ON DELETE CASCADE,
    variant_id    BIGINT  REFERENCES catalog.variant (id) ON DELETE CASCADE,
    store_id      BIGINT  REFERENCES offline.store (id) ON DELETE CASCADE,   -- 매장 입고 알림
    type          TEXT    NOT NULL CHECK (type IN ('price', 'restock', 'stock_in')),
    target_price  INTEGER,
    is_active     BOOLEAN NOT NULL DEFAULT true,
    CHECK (type <> 'price' OR target_price IS NOT NULL)
);
CREATE INDEX alert_user_id_idx ON account.alert (user_id);

CREATE TABLE account.notification (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT      NOT NULL REFERENCES account.app_user (id) ON DELETE CASCADE,
    type        TEXT        NOT NULL,   -- price 가격 · restock 재입고 · stock_in 입고 · report 제보 · issue 문의 · new_goods 새 굿즈
    title       TEXT        NOT NULL,
    body        TEXT,
    link        TEXT,                   -- 누르면 갈 화면 (/products/1, /stores/2 …)
    image_url   TEXT,
    read_at     TIMESTAMPTZ,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX notification_user_id_idx ON account.notification (user_id, created_at DESC);

-- 구매하러 가기를 누른 시점의 몰 · 가격 (구매 추적 · 문의 확인의 기준)
CREATE TABLE account.outbound_click (
    id                 BIGSERIAL PRIMARY KEY,
    user_id            BIGINT      REFERENCES account.app_user (id) ON DELETE SET NULL,   -- 비로그인이면 NULL
    offer_id           BIGINT      NOT NULL REFERENCES online.offer (id),
    variant_id         BIGINT      NOT NULL REFERENCES catalog.variant (id),
    price_snapshot     INTEGER     NOT NULL,
    shipping_snapshot  INTEGER,                -- NULL: 그때 배송비를 알 수 없었음
    clicked_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX outbound_click_user_id_idx ON account.outbound_click (user_id, clicked_at DESC);

CREATE TABLE account.purchase (
    id            BIGSERIAL PRIMARY KEY,
    user_id       BIGINT      NOT NULL REFERENCES account.app_user (id) ON DELETE CASCADE,
    variant_id    BIGINT      NOT NULL REFERENCES catalog.variant (id),
    click_id      BIGINT      REFERENCES account.outbound_click (id),   -- 온라인 구매
    store_id      BIGINT      REFERENCES offline.store (id),            -- 오프라인 구매
    price         INTEGER,
    purchased_on  DATE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX purchase_click_id_idx ON account.purchase (click_id) WHERE click_id IS NOT NULL;

CREATE TABLE account.issue (
    id           BIGSERIAL PRIMARY KEY,
    user_id      BIGINT      NOT NULL REFERENCES account.app_user (id) ON DELETE CASCADE,
    click_id     BIGINT      REFERENCES account.outbound_click (id),
    purchase_id  BIGINT      REFERENCES account.purchase (id),
    type         TEXT        NOT NULL CHECK (type IN ('price', 'stock', 'fake', 'etc')),
    content      TEXT        NOT NULL,
    attachments  JSONB,
    price_now    INTEGER,                -- 문의 시점 가격 (스냅샷과 비교)
    state        TEXT        NOT NULL DEFAULT 'open' CHECK (state IN ('open', 'answered', 'closed')),
    answer       TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (click_id IS NOT NULL OR purchase_id IS NOT NULL)
);
CREATE INDEX issue_user_id_idx ON account.issue (user_id, created_at DESC);
