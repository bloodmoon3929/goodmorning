-- 확장과 스키마
-- PostGIS: 매장 좌표 · 거리 계산 / pgvector: EmbeddingGemma 2 임베딩

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS vector;

CREATE SCHEMA IF NOT EXISTS catalog;  -- 공통 상품 정보
CREATE SCHEMA IF NOT EXISTS online;   -- 온라인 판매 정보
CREATE SCHEMA IF NOT EXISTS offline;  -- 오프라인 판매 정보
CREATE SCHEMA IF NOT EXISTS account;  -- 사용자 · 판매자
CREATE SCHEMA IF NOT EXISTS ingest;   -- 수집 원본 · 요청
