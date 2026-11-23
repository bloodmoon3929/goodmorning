# backend/db — PostgreSQL 스키마

PostgreSQL 17 + PostGIS 3(매장 좌표 · 거리) + pgvector(임베딩). API 서버 · AI 서버 · 수집기가 함께 쓴다.
테이블 정의: [../db.md](../db.md)

```text
db/
├── Dockerfile        # postgres:17-bookworm + postgresql-17-postgis-3 + postgresql-17-pgvector
├── migrations/       # 스키마 변경을 순서대로 (sqlx migrate 형식: 0001_설명.sql)
│   ├── 0001_create_schemas.sql   # 확장 · 스키마 5개
│   ├── 0002_catalog.sql          # ip, ip_alias, character, product, product_character, variant, embedding
│   ├── 0003_account_user.sql     # app_user (다른 스키마가 먼저 가리켜서 따로)
│   ├── 0004_online.sql           # mall, offer, offer_history
│   ├── 0005_offline.sql          # store, stock, stock_report, store_suggestion
│   ├── 0006_account.sql          # user_ip, ip_request, seller_member, wishlist, saved_store, alert, notification, outbound_click, purchase, issue
│   ├── 0007_ingest.sql           # collect_job, raw_listing, product_request
│   └── 0008_collect_run.sql      # 관리자 페이지에서 시작하는 수집: collect_run(대기열) · collect_event(단계별 기록) · collect_worker(생존 신호)
└── seed/dev_seed.sql # 개발용 가상 데이터 (frontend 목업과 같은 값)
```

## 적용

- API 서버를 `RUN_MIGRATIONS=true`로 띄우면 `migrations/`를 순서대로 적용한다 (적용 기록: `_sqlx_migrations`). `SEED_DEV_DATA=true`이고 IP가 하나도 없으면 `seed/dev_seed.sql`도 넣는다.
- 직접 넣을 때: `psql -f migrations/0001_create_schemas.sql …` 순서대로, 그다음 `seed/dev_seed.sql`.
- 한 번 적용한 마이그레이션 파일은 고치지 않는다. 바꿀 때는 다음 번호로 새 파일을 만든다.

## 개발용 가상 데이터

- IP 9 · 캐릭터 13 · 상품 20 · 버전 25 · 몰 7 · 몰별 가격 49 · 매장 5 · 재고 22, 회원 6 (backend/README.md의 개발용 계정)
- 몰 7곳 중 2곳(데모 몰 A · B)은 수집기 데모 사이트(`collector/demo`, 127.0.0.1)다. 직접 만든 사이트라 `crawl_allowed = true`
- 매장 주소 · 전화 · 몰 주소(`.example`) · 가격은 가상이다. 매장 좌표는 동네의 대략적인 위치다.
- 이미지는 캐릭터 사진 대신 앱에 들어 있는 이모지 그림 키를 `emoji:<키>`로 넣었다 (공개 저장소).
- 시각은 넣는 순간(now) 기준이다. 48시간이 지나면 재고가 '확인 필요'로 바뀌므로, 화면 예시 그대로 보려면 DB를 새로 만든다 (`docker compose down -v`).

## db.md와 다른 점

설계(db.md)를 SQL로 옮기면서 정한 것들. db.md는 PPT와 같은 정의라 그대로 두었다.

|테이블 · 컬럼|db.md|SQL|이유|
|--|--|--|--|
|`ip.category`, `product.type`|한글 값 (캐릭터 · 피규어 …)|영문 코드 (`character` · `figure` …)|앱의 enum 이름과 맞춤. 한글 이름은 API가 `type_label`로 준다|
|DEFAULT가 있는 컬럼|NULL 허용|`NOT NULL DEFAULT`|빈 값과 기본값이 섞이지 않게|
|`online.mall.name`|—|`UNIQUE`|수집기가 몰 이름으로 찾음|
|`online.offer.shipping_fee`, `account.outbound_click.shipping_snapshot`|`DEFAULT 0` / `NOT NULL`|NULL 허용 = 배송비를 알 수 없음|쿠팡 API는 무료배송 여부만 알려 준다. 모르는 배송비를 0원으로 보이지 않게|
|`catalog.variant`|—|상품마다 `is_default` 하나, `(product_id, name)` UNIQUE||
|`catalog.character`|—|`(ip_id, name)` UNIQUE||
|`offline.store.location`|`GEOGRAPHY`|`GEOGRAPHY(Point, 4326)` + GiST 인덱스|거리 계산|
|`catalog.embedding.vector`|`VECTOR(768)`|+ HNSW 인덱스 (코사인)|사진 · 텍스트 검색|
|`ingest.collect_run` · `collect_event` · `collect_worker`|—|새 테이블 (0008)|관리자 페이지에서 수집을 실제로 시작하고 진행을 보기 위해. db.md · PPT에는 아직 없음|
|`ingest.collect_job.run_id`, `ingest.raw_listing.job_id`|—|새 컬럼 (0008)|어느 실행에서 모은 원본인지|
|CHECK 추가|—|가격 0 이상, 목표가 알림은 `target_price` 필수, 문의는 이동 기록이나 구매 중 하나, 새 매장 제보만 `store_id` NULL, 매칭된 원본만 `matched_variant_id`||
