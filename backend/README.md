# 굿모닝 Backend — API · 배치 · DB 명세

> 단계 3. `frontend/README.md`의 화면별 버튼 표를 기준으로 작성한다.

```text
backend/
├── docker-compose.yml   # DB + API 로컬 실행
├── db/                  # PostgreSQL 17 + PostGIS + pgvector 이미지, 마이그레이션, 개발용 가상 데이터 — db/README.md
├── api/                 # Rust API 서버 (Axum + sqlx, MVC) — api/README.md
├── collector/           # Python 수집기 (쿠팡 파트너스 API, Scrapy + Playwright 크롤링) — collector/README.md
└── ai/                  # Python AI 서버 (EmbeddingGemma 2) — 아직 폴더만
```

## 실행

```bash
cd backend
docker compose up --build        # DB(5432) + API(8080). API가 시작할 때 마이그레이션과 개발용 가상 데이터를 넣는다
curl localhost:8080/health
```

Docker Compose 없이 따로 띄울 때:

```bash
docker build -t goodmorning-db:17 db
docker run -d --name goodmorning-db -p 5432:5432 \
  -e POSTGRES_USER=goodmorning -e POSTGRES_PASSWORD=goodmorning -e POSTGRES_DB=goodmorning goodmorning-db:17
cd api && cp .env.example .env && cargo run      # Rust 1.88 이상
```

개발용 계정 (비밀번호는 모두 `goodmorning1234`, 가상 데이터):

|이메일|역할|
|--|--|
|`goods@example.com`|회원 (굿즈러버, 내 IP 6개 · 찜 · 이동 기록 · 알림이 들어 있음)|
|`owner.yongsan@example.com`|판매자 — 피규어샵 용산점|
|`owner.hongdae@example.com`|판매자 — 굿즈샵 홍대점|
|`admin@example.com`|운영자 (수집 원본 매칭)|
|`reporter1@example.com`, `reporter2@example.com`|회원 (용산점에 검토 대기 제보)|

## 테스트

테스트는 DB에 테스트용 회원 · 제보 등을 새로 만든다. 개발용 DB에서 돌린다.

```bash
export DATABASE_URL=postgres://goodmorning:goodmorning@localhost:5432/goodmorning
cd api && cargo test                                    # 단위 11개 + API 통합 10개 (DATABASE_URL이 없으면 통합은 건너뜀)
cd collector && uv sync && uv run pytest                # 29개 (DB · Playwright가 없으면 그 테스트는 건너뜀)
```

## 응답 규칙

- 로그인이 필요한 API는 `Authorization: Bearer <token>` (`/auth/login` · `/auth/signup`이 준다)
- 에러: `{"error": "not_found", "message": "상품을(를) 찾을 수 없습니다"}` — 400 `bad_request` · 401 `unauthorized` · 403 `forbidden` · 404 `not_found` · 409 `conflict`
- 목록: `{"items": [...]}`. 시각은 RFC 3339(UTC), 거리는 km, 가격은 원
- 위치: `lat` · `lng`를 함께 보낸다. 없으면 서울시청 기준 (루트 README 예외 상황: 위치 권한 거부)
- 판매 경로 필터: 목록 API의 `channel=all | online | offline`
- 품목 코드: `figure` 피규어 · `doll` 인형 · `keyring` 키링 · `acrylic` 아크릴 · `plamodel` 프라모델 · `random` 랜덤
- 재고 상태: `many` · `few` · `none` · `unknown`(확인 필요). 확인한 지 48시간이 지나면 저장된 값과 상관없이 `unknown`으로 내려간다

## API 명세

> 백엔드를 거치지 않는 동작(길찾기, 전화걸기, 필터 전환 등)도 표에 남기고 Method를 `—`로 적는다.
> 테이블 이름은 스키마를 줄여 적었다 (`catalog.` 생략: ip · product · variant …).

|화면|버튼·동작|Method|Path|동작|읽기·쓰기 테이블|
|--|--|--|--|--|--|
|로그인|로그인|POST|`/auth/login`|이메일 · 비밀번호 확인 → 토큰|R app_user, user_ip, seller_member|
|로그인|SNS 로그인|—|—|아직 없음 (이메일 가입만)|—|
|회원가입 · 계정 정보|이메일 중복 확인|GET|`/auth/email-taken?email=`||R app_user|
|회원가입 · IP 고르기|IP 목록|GET|`/ips`|IP · 분류 · 별칭|R ip, ip_alias|
|회원가입 · IP 고르기|가입 완료|POST|`/auth/signup`|회원 + 고른 순서대로 내 IP 저장 → 토큰|W app_user, user_ip|
|홈 · 마이|내 정보|GET|`/me`|내 IP 순서, 판매자면 관리 매장|R app_user, user_ip, seller_member|
|홈|① 알림 🔔|GET|`/me/notifications`|최근 100개, 읽음 여부|R notification|
|알림 목록|알림 누름 · 모두 읽음|POST|`/me/notifications/{id}/read` · `/me/notifications/read-all`||W notification|
|홈|② 검색|GET|`/search?q=`|검색 결과 화면과 같다|아래 검색 결과|
|홈|③ 사진 📷|—|—|AI 서버(EmbeddingGemma 2)가 생기면 연결|embedding|
|홈|④ 판매 경로 필터|—|목록 API에 `channel=`|필터 전환 자체는 앱 안에서|—|
|홈|⑤ 내 IP 타일|GET|`/ips/{id}`|IP 화면과 같다|아래 IP 화면|
|홈|⑥ 내 주변 재고|GET|`/stores?lat=&lng=&limit=3`|가까운 매장, 내 IP 굿즈 재고 수|R store, stock, variant, product, seller_member|
|홈|⑦ 내 IP 신상품|GET|`/products/new?channel=&lat=&lng=`|발매일 최근순 8개 (ip_ids가 없으면 로그인 회원의 내 IP)|R product, variant, character, offer, mall, stock, store, wishlist, outbound_click|
|홈 · 상품 상세|⑦ 찜 ♡|PUT · DELETE|`/me/wishlist/{variant_id}`|버전 단위|W wishlist|
|굿즈 탐색|① 검색창|GET|`/search?q=`|IP · 캐릭터 이름과 별칭 (먼작귀 → 치이카와)|R ip, ip_alias, character|
|굿즈 탐색|③ 품목으로 보기|GET|`/search?type=figure`|검색어 없이 품목만|아래 검색 결과|
|굿즈 탐색|④ 내 IP 타일|GET|`/ips/stats?ids=1,2`|캐릭터 수 · 굿즈 수|R ip, character, product|
|IP 목록 조정|보일 IP · 순서 저장|PUT|`/me/ips`|`{"ip_ids": [2, 1]}`|W user_ip|
|IP 목록 조정|없는 IP 추가 요청|POST|`/me/ip-requests`||W ip_request|
|검색 결과|검색 · 조건 · 정렬|GET|`/search?q=&type=&max_price=&sort=&channel=&limit=&offset=`|낱말이 모두 들어간 상품 (상품명 · IP · 별칭 · 캐릭터 · 품목 · 버전명), 별칭 안내, 맞은 IP. 정렬 `lowest`(배송비 포함 최저가) · `nearest` · `newest` · `popular`. 20개씩|R product, ip, ip_alias, character, variant, offer, stock, store|
|사진 검색 결과|사진 검색 · [조건 추가]|—|—|AI 서버가 생기면 연결|embedding|
|IP 화면|캐릭터 · 품목 필터 · 정렬|GET|`/ips/{id}?type=&sort=&channel=`|기본 인기순 (찜 수 + 구매하러 가기 수)|R ip, character, product …|
|캐릭터 화면|품목별 묶음|GET|`/characters/{id}?channel=`|피규어 · 인형 · 키링 … 순서|R character, product_character, product …|
|상품 상세|상세|GET|`/products/{id}?lat=&lng=`|버전, 몰별 가격(품절 맨 아래 · 총액 오름차순), 매장 재고(가까운 순), 비슷한 상품(IP당 2개 · 4개), 내가 찜한 버전, 판매처 없음 여부|R product, variant, character, offer, mall, stock, store, wishlist|
|상품 상세|🔔 알림 받기|POST|`/me/alerts`|`price`(목표가 이하, target_price 필수) · `restock` · `stock_in`(store_id)|W alert|
|상품 상세 · 온라인 가격|구매하러 가기|POST|`/offers/{id}/click`|누른 시점 가격 · 배송비를 이동 기록으로 저장 → 외부 몰 주소. 품절이면 409|R offer · W outbound_click|
|(공유 링크)|구매하러 가기|GET|`/offers/{id}/go`|같은 기록 후 302로 외부 몰 이동|R offer · W outbound_click|
|매장 찾기 · 리스트 / 지도|목록 · 마커|GET|`/stores?lat=&lng=&radius_km=&in_stock_only=`|두 뷰가 같은 결과. 거리순, 오늘 영업시간 · 영업 중, 팝업 종료일, 마커 색(`marker_status`)|R store, stock, seller_member|
|매장 상세|상세|GET|`/stores/{id}?lat=&lng=`|재고마다 상태 · 출처(사장님 / 제보 / 수집) · 확인 시각, 요일별 영업시간, 저장 여부|R store, stock, variant, product, saved_store|
|매장 상세|⭐ 매장 저장|PUT · DELETE|`/me/saved-stores/{store_id}`||W saved_store|
|매장 상세|길찾기 · 전화|—|—|지도 앱 딥링크 · `tel:` (백엔드를 거치지 않음)|—|
|매장 상세|정보 수정 · 폐업 · 새 매장 제보|POST|`/store-suggestions`|`type`: new · edit · closed, 관리자 검토 대기|W store_suggestion|
|재고 제보|제보하기|POST|`/stock-reports`|사장님 있는 매장: 검토 대기. 없는 매장: 다른 회원 2명이 같은 상태를 제보하면 바로 반영하고 두 사람에게 알림|W stock_report, stock, notification|
|마이|찜한 굿즈|GET|`/me/wishlist`||R wishlist + 상품 카드|
|마이|저장한 매장|GET|`/me/saved-stores`||R saved_store, store|
|마이|알림 설정 · 삭제|GET · DELETE|`/me/alerts` · `/me/alerts/{id}`||R/W alert|
|마이|내 제보|GET|`/me/stock-reports`|반영 대기 · 반영됨 · 반려|R stock_report|
|이동 기록|목록|GET|`/me/visits`|당시 가격 · 배송비, 구매 여부|R outbound_click, offer, mall, purchase|
|이동 기록|구매했어요|POST|`/me/purchases`|`click_id` 또는 오프라인 구매(`variant_id` + `store_id`). 같은 이동 기록은 한 번만|W purchase|
|마이|구매 기록|GET|`/me/purchases`||R purchase|
|문제 제기|보내기|POST|`/me/issues`|`type`: price · stock · fake · etc. 문의 시점 가격(`price_now`)을 함께 저장해 운영자가 스냅샷과 비교|W issue|
|마이|문의 내역|GET|`/me/issues`|답변 포함|R issue|
|판매자 센터|내 매장|GET|`/seller/stores`||R seller_member, store|
|판매자 센터 · 재고 관리|화면|GET|`/seller/stores/{store_id}`|저장된 상태 그대로, 전체 품목 수, 마지막 확인, 검토 대기 제보 수|R stock, stock_report|
|판매자 센터 · 재고 관리|변경 저장|PUT|`/seller/stores/{store_id}/stock`|`{"items": [{"variant_id", "status", "price"}]}` 한 번에 저장|W stock|
|판매자 센터 · 재고 관리|[오늘 재고 그대로예요]|POST|`/seller/stores/{store_id}/stock/confirm`|상태는 그대로, 전 품목 확인 시각만 지금으로|W stock|
|판매자 센터|제보 확인|GET|`/seller/stores/{store_id}/reports?state=pending`||R stock_report|
|판매자 센터|승인 · 반려|POST|`/seller/stores/{store_id}/reports/{report_id}/approve` · `/reject`|승인하면 재고 반영. 결과를 제보자에게 알림|W stock_report, stock, notification|
|판매자 센터 · 상품 등록|사진 → AI 후보 3개|—|—|AI 서버가 생기면 연결|embedding|
|판매자 센터 · 상품 등록|후보 선택 → 취급 상품 추가|PUT|`/seller/stores/{store_id}/stock`|처음 보는 버전도 같은 API로 추가|W stock|
|판매자 센터 · 상품 등록|후보에 없음 → 새 굿즈 요청|POST|`/seller/stores/{store_id}/product-requests`|관리자 검토 대기|W product_request|
|운영|매칭 대기 목록|GET|`/admin/raw-listings?state=pending`|수집기가 넣은 원본|R raw_listing|
|운영|매칭 확정|POST|`/admin/raw-listings/{id}/match`|`{"variant_id"}` → online.offer 반영 + 가격 기록|W offer, offer_history, raw_listing|
|운영|제외|POST|`/admin/raw-listings/{id}/reject`||W raw_listing|
|운영|수집 실행 기록|GET|`/admin/collect-jobs`|배치 모니터링|R collect_job|
|—|상태 확인|GET|`/health`|DB 연결 확인|—|

`/seller/stores/{store_id}/…`는 그 매장에 연결된 판매자(`account.seller_member`)나 운영자만 부를 수 있다 (`api/src/middleware/seller.rs`). `/admin/…`은 운영자만.

## 배치 작업

버튼과 상관없이 주기적으로 도는 작업 (수집, 임베딩 생성, 상품 매칭, 재고 신선도 감쇠, 알림 확인).

|작업|주기|담당|동작|상태|
|--|--|--|--|--|
|쇼핑 API 수집|하루 1~2회|collector `python -m api_clients coupang --catalog`|카탈로그 버전마다 검색어 → 쿠팡 파트너스 검색 → raw_listing, 실행마다 collect_job|구현함|
|크롤링|하루 1~2회|collector `scrapy crawl mall`|`crawl_allowed` 몰의 검색 결과 페이지 → raw_listing, 몰마다 collect_job|구현함|
|매칭된 판매처 가격 갱신|수집할 때마다|collector `db.save_listing`|이미 offer로 연결된 몰 · 주소면 가격 · 품절을 바로 갱신, 바뀌면 offer_history. 가격을 못 읽으면 이전 값 유지|구현함|
|상품 매칭 (새 주소)|수집 후|운영자 `/admin/raw-listings` (지금) → AI 서버 (나중)|raw_listing → catalog.variant 연결 → offer|운영자 확정만 구현함|
|재고 신선도 감쇠|조회할 때|API `services/rules.rs`|확인한 지 48시간 지난 재고는 `unknown`(확인 필요)으로 내려줌. 배치 없이 조회 시 판단|구현함|
|임베딩 생성|상품 추가 시|AI 서버|EmbeddingGemma 2 → catalog.embedding|아직|
|알림 확인|수집 후|—|alert 조건(목표가 · 재입고 · 입고) → notification|아직|

수집 주기는 cron 등으로 건다 (예시: collector/README.md). 서버에 등록하는 것은 아직 하지 않았다.

## DB 설계

스키마 구분은 루트 `README.md`의 데이터 구분(`catalog` / `online` / `offline` / `account` / `ingest`)을 따른다.

테이블 정의 (컬럼 · 타입 · 제약 · 설명 · 쓰는 화면): [db.md](db.md) · 실제 SQL과 db.md와 다른 점: [db/README.md](db/README.md)
