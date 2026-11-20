-- account.app_user — 회원
-- offline.stock_report 등이 회원을 가리키므로 다른 account 테이블보다 먼저 만든다.

CREATE TABLE account.app_user (
    id              BIGSERIAL PRIMARY KEY,
    email           TEXT UNIQUE,
    password_hash   TEXT,                                -- SNS 가입이면 NULL
    provider        TEXT        NOT NULL DEFAULT 'email' CHECK (provider IN ('email', 'kakao', 'naver', 'apple')),
    provider_id     TEXT,
    nickname        TEXT        NOT NULL,
    home_area       TEXT,
    role            TEXT        NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'seller', 'admin')),
    agree_location  BOOLEAN     NOT NULL DEFAULT false,
    agree_push      BOOLEAN     NOT NULL DEFAULT false,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
