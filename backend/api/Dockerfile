# 빌드 컨텍스트는 backend/ (마이그레이션 · 개발용 데이터 SQL을 바이너리에 함께 넣는다)
#   docker build -f api/Dockerfile -t goodmorning-api .
FROM rust:1.100-bookworm AS build
WORKDIR /src
COPY db ./db
COPY api ./api
WORKDIR /src/api
RUN cargo build --release --locked

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=build /src/api/target/release/goodmorning-api /usr/local/bin/goodmorning-api
ENV BIND_ADDR=0.0.0.0:8080
EXPOSE 8080
USER nobody
CMD ["goodmorning-api"]
