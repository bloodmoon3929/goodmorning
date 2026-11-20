-- catalog — 공통 상품 정보 (backend/db.md)

CREATE TABLE catalog.ip (
    id          BIGSERIAL PRIMARY KEY,
    name        TEXT        NOT NULL UNIQUE,
    category    TEXT        NOT NULL CHECK (category IN ('character', 'anime', 'game', 'plamodel')),
    image_url   TEXT,
    is_active   BOOLEAN     NOT NULL DEFAULT true,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON COLUMN catalog.ip.category IS 'character 캐릭터 / anime 애니 / game 게임 / plamodel 프라모델';

CREATE TABLE catalog.ip_alias (
    id     BIGSERIAL PRIMARY KEY,
    ip_id  BIGINT NOT NULL REFERENCES catalog.ip (id) ON DELETE CASCADE,
    alias  TEXT   NOT NULL UNIQUE
);
CREATE INDEX ip_alias_ip_id_idx ON catalog.ip_alias (ip_id);

CREATE TABLE catalog.character (
    id         BIGSERIAL PRIMARY KEY,
    ip_id      BIGINT NOT NULL REFERENCES catalog.ip (id) ON DELETE CASCADE,
    name       TEXT   NOT NULL,
    image_url  TEXT,
    UNIQUE (ip_id, name)
);

CREATE TABLE catalog.product (
    id            BIGSERIAL PRIMARY KEY,
    ip_id         BIGINT      NOT NULL REFERENCES catalog.ip (id),
    name          TEXT        NOT NULL,
    type          TEXT        NOT NULL CHECK (type IN ('figure', 'doll', 'keyring', 'acrylic', 'plamodel', 'random')),
    maker         TEXT,
    description   TEXT,
    release_date  DATE,
    image_url     TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON COLUMN catalog.product.type IS 'figure 피규어 / doll 인형 / keyring 키링 / acrylic 아크릴 / plamodel 프라모델 / random 랜덤';
CREATE INDEX product_ip_id_idx ON catalog.product (ip_id);
CREATE INDEX product_release_date_idx ON catalog.product (release_date DESC);

CREATE TABLE catalog.product_character (
    product_id    BIGINT NOT NULL REFERENCES catalog.product (id) ON DELETE CASCADE,
    character_id  BIGINT NOT NULL REFERENCES catalog.character (id) ON DELETE CASCADE,
    PRIMARY KEY (product_id, character_id)
);
CREATE INDEX product_character_character_id_idx ON catalog.product_character (character_id);

-- 가격 · 재고의 단위
CREATE TABLE catalog.variant (
    id          BIGSERIAL PRIMARY KEY,
    product_id  BIGINT  NOT NULL REFERENCES catalog.product (id) ON DELETE CASCADE,
    name        TEXT    NOT NULL,
    attrs       JSONB,
    barcode     TEXT UNIQUE,
    is_default  BOOLEAN NOT NULL DEFAULT false,
    UNIQUE (product_id, name)
);
-- 상품마다 처음 보일 버전은 하나
CREATE UNIQUE INDEX variant_one_default_idx ON catalog.variant (product_id) WHERE is_default;

CREATE TABLE catalog.embedding (
    id          BIGSERIAL PRIMARY KEY,
    variant_id  BIGINT      NOT NULL REFERENCES catalog.variant (id) ON DELETE CASCADE,
    kind        TEXT        NOT NULL CHECK (kind IN ('image', 'text')),
    vector      VECTOR(768) NOT NULL,
    model       TEXT        NOT NULL,
    source_url  TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX embedding_variant_id_idx ON catalog.embedding (variant_id);
-- 코사인 거리(<=>)로 가장 가까운 상품 찾기
CREATE INDEX embedding_vector_hnsw_idx ON catalog.embedding USING hnsw (vector vector_cosine_ops);
