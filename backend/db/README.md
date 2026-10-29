# backend/db — PostgreSQL 스키마

`migrations/`에 스키마 변경을 순서대로 SQL 파일로 남긴다 (예: `0001_create_schemas.sql`). API 서버 · AI 서버 · 수집기가 함께 쓴다.

테이블 정의: [../db.md](../db.md) · 확장: pgvector (임베딩), PostGIS (매장 좌표)
