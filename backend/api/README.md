# backend/api — Rust API 서버 (MVC)

앱(Flutter)의 요청을 받아 DB를 읽고 쓰는 서버. 웹 프레임워크는 Axum 0.8, DB 접근은 sqlx 0.8 (PostgreSQL), 비밀번호는 Argon2id, 로그인 토큰은 JWT.
요청 하나는 항상 아래 순서로 흐른다.

```mermaid
flowchart LR
    app["Flutter 앱"] --> route["routes<br/>URL 연결"]
    route --> mw["middleware<br/>로그인 · 권한"]
    mw --> ctrl["controllers (C)<br/>요청 검사 · 응답"]
    ctrl --> svc["services<br/>규칙 · 계산"]
    svc --> repo["repositories<br/>SQL"]
    repo --> db[("PostgreSQL")]
    repo --> model["models (M)<br/>DB 행 구조체"]
    ctrl --> view["views (V)<br/>응답 JSON 모양"]
    view --> app
```

```text
api/
├── src/
│   ├── routes/         # URL ↔ 컨트롤러 연결. 화면 명세의 버튼 하나 = API 하나 = route 한 줄
│   ├── middleware/     # 로그인 확인, 판매자 권한(본인 매장만), 요청 로그
│   ├── controllers/    # C: 입력 검사 → 서비스 호출 → view로 응답. SQL을 직접 쓰지 않는다
│   ├── services/       # 업무 규칙: 48시간 지난 재고는 확인 필요, 같은 제보 2건이면 반영, 배송비 포함 총액 정렬 …
│   ├── repositories/   # DB 접근만. sqlx 쿼리, 값은 매개변수로 넘긴다 (SQL 인젝션 방지)
│   ├── models/         # M: DB 테이블과 같은 구조체 (backend/db.md)
│   ├── views/          # V: 앱에 내려줄 JSON 모양 (화면에 필요한 필드만)
│   ├── config/         # 환경 변수, DB 연결 설정
│   ├── error.rs        # 에러 → HTTP 상태 · {"error", "message"}
│   ├── seed.rs         # 개발용 가상 데이터 넣기 (db/seed/dev_seed.sql)
│   └── main.rs         # 시작: 설정 → DB 연결 → 마이그레이션 → 서버
└── tests/api.rs        # 실제 DB에 붙는 통합 테스트
```

기능별 파일: `catalog`(IP · 캐릭터) · `product` · `search` · `store` · `auth` · `me`(마이) · `offer`(구매하러 가기) · `report`(재고 · 매장 제보) · `seller`(판매자 센터) · `admin`(수집 원본 매칭 · 상태 확인).
업무 규칙 상수(48시간 · 근처 7km · 기준 위치 서울시청 · 가격 정렬)는 `services/rules.rs`에 모았다.

## 규칙

- 폴더는 기능별로 같은 이름의 파일을 둔다. 예: 재고 제보 → `routes/report.rs`, `controllers/report.rs`, `services/report.rs`, `repositories/report.rs`, `views/report.rs`
- controllers는 services만, services는 repositories만 부른다. 거꾸로 부르거나 건너뛰지 않는다.
- models(DB 모양)와 views(응답 모양)를 섞지 않는다. 비밀번호 해시 같은 DB 컬럼이 응답에 실수로 나가지 않게 하기 위해서다.
- DB 스키마 변경은 `backend/db/migrations/`에 SQL 파일로 남긴다.

> MVVM은 화면 쪽 패턴이라 Flutter의 화면별 view model에서 쓰고 (frontend/lib/README.md), 서버는 화면이 없으므로 응답 JSON을 View로 보는 MVC로 나눴다.

## 실행 · 테스트

```bash
cp .env.example .env            # DATABASE_URL, JWT_SECRET …
cargo run                       # RUN_MIGRATIONS=true면 ../db/migrations 적용, SEED_DEV_DATA=true면 가상 데이터
cargo test                      # DATABASE_URL이 있으면 통합 테스트까지
cargo fmt --check && cargo clippy --all-targets -- -D warnings
docker build -f Dockerfile -t goodmorning-api ..       # 이미지 (빌드 컨텍스트는 backend/)
```

|환경 변수|기본값|설명|
|--|--|--|
|`DATABASE_URL`|(필수)|`postgres://goodmorning:goodmorning@localhost:5432/goodmorning`|
|`JWT_SECRET`|(필수, 16자 이상)|로그인 토큰 서명 키. 운영에서는 길고 무작위로|
|`JWT_TTL_HOURS`|168|토큰 유효 시간|
|`BIND_ADDR`|127.0.0.1:8080||
|`RUN_MIGRATIONS`|false|시작할 때 마이그레이션 적용|
|`SEED_DEV_DATA`|false|DB가 비었으면 개발용 가상 데이터|
|`CORS_ORIGINS`|(비움 = 모두 허용)|쉼표로 구분, 예: `https://bloodmoon3929.github.io`|
|`DB_MAX_CONNECTIONS`|10||
|`RUST_LOG`|info||

API 목록 · 화면 대응은 [../README.md](../README.md)의 API 명세 표.
