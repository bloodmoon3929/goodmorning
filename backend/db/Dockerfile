# PostgreSQL 17 + PostGIS 3 (매장 좌표) + pgvector (임베딩)
# 공식 postgres 이미지에는 PostgreSQL apt 저장소(PGDG)가 설정되어 있어 두 확장을 패키지로 바로 받는다.
FROM postgres:17-bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends postgresql-17-postgis-3 postgresql-17-pgvector \
    && rm -rf /var/lib/apt/lists/*
