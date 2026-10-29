# 굿모닝 DB 설계

> PPT `frontend/design/굿모닝_UI구상.pptx`의 DB 슬라이드와 같은 내용 (같은 정의에서 생성).
> PostgreSQL + pgvector(임베딩) + PostGIS(매장 좌표). 가격 · 재고는 버전(`catalog.variant`) 단위.

## 주요 관계

- catalog.variant ← online.offer · offline.stock · account.wishlist · catalog.embedding   (같은 굿즈를 온라인 · 오프라인이 같은 버전으로 가리킴)
- account.app_user ← account.user_ip → catalog.ip   (회원가입 때 고른 내 IP)
- online.offer ← account.outbound_click ← account.purchase ← account.issue   (구매하러 가기 → 구매 → 문제 제기)
- ingest.raw_listing → catalog.variant   (수집 → AI 매칭 → online.offer 로 반영)     account.seller_member → offline.store · online.mall   (본인 매장 · 몰만 수정)

## catalog — 공통 상품 정보

### catalog.ip — IP (산리오, 치이카와 …)

쓰는 화면: 회원가입 IP 고르기 · 굿즈 탐색

|컬럼|타입|제약|설명|
|--|--|--|--|
|id|BIGSERIAL|PK|IP 번호|
|name|TEXT|NOT NULL, UNIQUE|IP 이름|
|category|TEXT|NOT NULL|캐릭터 / 애니 / 게임 / 프라모델|
|image_url|TEXT||대표 이미지 (투명 PNG)|
|is_active|BOOLEAN|DEFAULT true|목록에 보일지|
|created_at|TIMESTAMPTZ|DEFAULT now()|등록 시각|

### catalog.ip_alias — IP · 캐릭터 별칭

쓰는 화면: 검색 (먼작귀 → 치이카와)

|컬럼|타입|제약|설명|
|--|--|--|--|
|id|BIGSERIAL|PK||
|ip_id|BIGINT|FK → ip, NOT NULL||
|alias|TEXT|NOT NULL, UNIQUE|먼작귀, 포켓몬 …|

### catalog.character — 캐릭터

쓰는 화면: IP 화면 · 캐릭터 화면

|컬럼|타입|제약|설명|
|--|--|--|--|
|id|BIGSERIAL|PK||
|ip_id|BIGINT|FK → ip, NOT NULL|속한 IP|
|name|TEXT|NOT NULL|쿠로미|
|image_url|TEXT||캐릭터 이미지|

### catalog.product_character — 상품 ↔ 캐릭터 (N:M)

쓰는 화면: 콜라보 굿즈

|컬럼|타입|제약|설명|
|--|--|--|--|
|product_id|BIGINT|PK, FK → product||
|character_id|BIGINT|PK, FK → character||

### catalog.product — 상품

쓰는 화면: 모든 상품 카드 · 상품 상세

|컬럼|타입|제약|설명|
|--|--|--|--|
|id|BIGSERIAL|PK||
|ip_id|BIGINT|FK → ip, NOT NULL||
|name|TEXT|NOT NULL|쿠로미 마스코트 인형|
|type|TEXT|NOT NULL, CHECK|피규어 · 인형 · 키링 · 아크릴 · 프라모델 · 랜덤|
|maker|TEXT||제조사|
|description|TEXT|||
|release_date|DATE||발매일 (신상품 정렬)|
|image_url|TEXT||대표 이미지|
|created_at|TIMESTAMPTZ|DEFAULT now()||

### catalog.variant — 버전 (가격 · 재고의 단위)

쓰는 화면: 상품 상세 버전 선택

|컬럼|타입|제약|설명|
|--|--|--|--|
|id|BIGSERIAL|PK||
|product_id|BIGINT|FK → product, NOT NULL||
|name|TEXT|NOT NULL|일반 10cm, 빅 20cm|
|attrs|JSONB||크기 · 차수 등 구분 정보|
|barcode|TEXT|UNIQUE|JAN · EAN 코드|
|is_default|BOOLEAN|DEFAULT false|처음 보일 버전|

### catalog.embedding — AI 임베딩 (pgvector)

쓰는 화면: 사진 검색 · 텍스트 검색 · 상품 매칭

|컬럼|타입|제약|설명|
|--|--|--|--|
|id|BIGSERIAL|PK||
|variant_id|BIGINT|FK → variant, NOT NULL||
|kind|TEXT|CHECK image / text|이미지인지 글인지|
|vector|VECTOR(768)|NOT NULL|EmbeddingGemma 2 (차원은 모델에 맞춤)|
|model|TEXT|NOT NULL|모델 이름 · 버전|
|source_url|TEXT||원본 이미지|
|created_at|TIMESTAMPTZ|DEFAULT now()||

## online — 온라인 판매 정보

### online.mall — 쇼핑몰 (사이트별 관리)

쓰는 화면: 상품 상세 · 온라인 가격

|컬럼|타입|제약|설명|
|--|--|--|--|
|id|BIGSERIAL|PK||
|name|TEXT|NOT NULL|오픈마켓 A|
|site_url|TEXT|||
|source|TEXT|CHECK api / crawl / seller|가격을 가져오는 방법|
|api_name|TEXT||네이버 쇼핑, 쿠팡 파트너스|
|crawl_allowed|BOOLEAN|DEFAULT false|robots.txt · 약관 확인|
|is_active|BOOLEAN|DEFAULT true||
|created_at|TIMESTAMPTZ|DEFAULT now()||

### online.offer_history — 가격 기록

쓰는 화면: 가격 하락 알림 · 문의 확인

|컬럼|타입|제약|설명|
|--|--|--|--|
|id|BIGSERIAL|PK||
|offer_id|BIGINT|FK → offer, NOT NULL||
|price|INTEGER|NOT NULL||
|shipping_fee|INTEGER|NOT NULL||
|sold_out|BOOLEAN|||
|observed_at|TIMESTAMPTZ|NOT NULL||

### online.offer — 몰별 판매 정보

쓰는 화면: 상품 카드 배지 · 온라인 가격 표

|컬럼|타입|제약|설명|
|--|--|--|--|
|id|BIGSERIAL|PK||
|variant_id|BIGINT|FK → catalog.variant, NOT NULL|어떤 버전인지|
|mall_id|BIGINT|FK → mall, NOT NULL||
|title|TEXT||몰에 적힌 상품명|
|url|TEXT|NOT NULL|구매하러 가기 주소|
|price|INTEGER|NOT NULL|상품가 (원)|
|shipping_fee|INTEGER|DEFAULT 0|배송비|
|total_price|INTEGER|GENERATED|price + shipping_fee (정렬 기준)|
|sold_out|BOOLEAN|DEFAULT false|품절|
|source|TEXT|CHECK api / crawl / seller|수집 출처|
|observed_at|TIMESTAMPTZ|NOT NULL|수집 시각|
|(mall_id, url)||UNIQUE|같은 몰 같은 주소는 한 줄|

## offline — 오프라인 판매 정보

### offline.store — 매장 (가게별 관리)

쓰는 화면: 매장 찾기 · 매장 상세

|컬럼|타입|제약|설명|
|--|--|--|--|
|id|BIGSERIAL|PK||
|name|TEXT|NOT NULL|피규어샵 용산점|
|kind|TEXT||캐릭터샵 / 피규어샵 / 가챠 / 팝업|
|address|TEXT|NOT NULL||
|location|GEOGRAPHY|NOT NULL|좌표 Point (PostGIS, 거리 계산)|
|phone|TEXT||전화걸기|
|hours|JSONB||요일별 영업시간 · 휴무|
|popup_until|DATE||팝업 종료일|
|info_source|TEXT|CHECK owner / report / crawl|정보 출처|
|is_closed|BOOLEAN|DEFAULT false|폐업|
|updated_at|TIMESTAMPTZ|DEFAULT now()|정보 갱신 시각|

### offline.stock — 매장별 재고

쓰는 화면: 오프라인 배지 · 매장 상세 재고

|컬럼|타입|제약|설명|
|--|--|--|--|
|id|BIGSERIAL|PK||
|store_id|BIGINT|FK → store, NOT NULL||
|variant_id|BIGINT|FK → catalog.variant, NOT NULL||
|status|TEXT|CHECK many / few / none / unknown|재고 상태|
|price|INTEGER||매장 판매가|
|source|TEXT|CHECK owner / report / crawl|누가 확인했는지|
|confirmed_at|TIMESTAMPTZ|NOT NULL|48시간 지나면 확인 필요|
|(store_id, variant_id)||UNIQUE||

### offline.stock_report — 재고 제보

쓰는 화면: 재고 제보 · 판매자 제보 확인

|컬럼|타입|제약|설명|
|--|--|--|--|
|id|BIGSERIAL|PK||
|store_id|BIGINT|FK → store, NOT NULL||
|variant_id|BIGINT|FK → catalog.variant, NOT NULL||
|user_id|BIGINT|FK → account.app_user, NOT NULL|제보자|
|status|TEXT|CHECK many / few / none|제보한 상태|
|photo_url|TEXT||사진 (선택)|
|state|TEXT|CHECK pending / approved / rejected|처리 상태|
|resolved_by|BIGINT|FK → account.app_user|승인한 사장님 · 관리자|
|created_at|TIMESTAMPTZ|DEFAULT now()||

### offline.store_suggestion — 매장 제보 · 수정 제안

쓰는 화면: 매장 상세 수정 제안

|컬럼|타입|제약|설명|
|--|--|--|--|
|id|BIGSERIAL|PK||
|store_id|BIGINT|FK → store|새 매장이면 NULL|
|user_id|BIGINT|FK → account.app_user, NOT NULL||
|type|TEXT|CHECK new / edit / closed||
|content|JSONB|NOT NULL|바꿀 내용|
|state|TEXT|CHECK pending / approved / rejected||
|created_at|TIMESTAMPTZ|DEFAULT now()||

## account — 사용자 · 판매자

### account.app_user — 회원

쓰는 화면: 로그인 · 회원가입 · 마이

|컬럼|타입|제약|설명|
|--|--|--|--|
|id|BIGSERIAL|PK||
|email|TEXT|UNIQUE||
|password_hash|TEXT||SNS 가입이면 NULL|
|provider|TEXT|CHECK email / kakao / naver / apple|가입 방법|
|provider_id|TEXT||SNS 계정 번호|
|nickname|TEXT|NOT NULL||
|home_area|TEXT||동네 (선택)|
|role|TEXT|CHECK user / seller / admin||
|agree_location|BOOLEAN|DEFAULT false|위치 정보 동의|
|agree_push|BOOLEAN|DEFAULT false|알림 동의|
|created_at|TIMESTAMPTZ|DEFAULT now()||

### account.user_ip — 내 IP

쓰는 화면: 회원가입 IP 고르기 · IP 목록 조정

|컬럼|타입|제약|설명|
|--|--|--|--|
|user_id|BIGINT|PK, FK → app_user||
|ip_id|BIGINT|PK, FK → catalog.ip||
|sort_order|SMALLINT|NOT NULL|보이는 순서|
|created_at|TIMESTAMPTZ|DEFAULT now()||

### account.ip_request — IP 추가 요청

쓰는 화면: IP 목록 조정 · 회원가입

|컬럼|타입|제약|설명|
|--|--|--|--|
|id|BIGSERIAL|PK||
|user_id|BIGINT|FK → app_user, NOT NULL||
|name|TEXT|NOT NULL|요청한 IP 이름|
|state|TEXT|CHECK pending / added / rejected||
|created_ip_id|BIGINT|FK → catalog.ip|추가된 IP|
|created_at|TIMESTAMPTZ|DEFAULT now()||

### account.seller_member — 판매자 계정 ↔ 매장 · 몰

쓰는 화면: 판매자 센터 (본인 매장만 수정)

|컬럼|타입|제약|설명|
|--|--|--|--|
|id|BIGSERIAL|PK||
|user_id|BIGINT|FK → app_user, NOT NULL||
|store_id|BIGINT|FK → offline.store|매장 사장님|
|mall_id|BIGINT|FK → online.mall|몰 판매자|
|role|TEXT|CHECK owner / staff||
|verified_at|TIMESTAMPTZ||사업자 확인 시각|

### account.wishlist — 찜

쓰는 화면: ♡ · 마이 찜한 굿즈

|컬럼|타입|제약|설명|
|--|--|--|--|
|user_id|BIGINT|PK, FK → app_user||
|variant_id|BIGINT|PK, FK → catalog.variant|버전 단위로 찜|
|created_at|TIMESTAMPTZ|DEFAULT now()||

### account.saved_store — 저장한 매장

쓰는 화면: ⭐ 매장 저장

|컬럼|타입|제약|설명|
|--|--|--|--|
|user_id|BIGINT|PK, FK → app_user||
|store_id|BIGINT|PK, FK → offline.store||
|created_at|TIMESTAMPTZ|DEFAULT now()||

### account.alert — 알림 조건

쓰는 화면: 🔔 알림 받기

|컬럼|타입|제약|설명|
|--|--|--|--|
|id|BIGSERIAL|PK||
|user_id|BIGINT|FK → app_user, NOT NULL||
|variant_id|BIGINT|FK → catalog.variant||
|store_id|BIGINT|FK → offline.store|매장 입고 알림|
|type|TEXT|CHECK price / restock / stock_in||
|target_price|INTEGER||목표가|
|is_active|BOOLEAN|DEFAULT true||

### account.notification — 받은 알림

쓰는 화면: 알림 목록

|컬럼|타입|제약|설명|
|--|--|--|--|
|id|BIGSERIAL|PK||
|user_id|BIGINT|FK → app_user, NOT NULL||
|type|TEXT|NOT NULL|가격 · 재입고 · 입고 · 제보 · 문의 · 새 굿즈|
|title|TEXT|NOT NULL||
|body|TEXT|||
|link|TEXT||누르면 갈 화면|
|image_url|TEXT||굿즈 사진|
|read_at|TIMESTAMPTZ||안 읽었으면 NULL|
|created_at|TIMESTAMPTZ|DEFAULT now()||

### account.outbound_click — 이동 기록

쓰는 화면: 구매하러 가기 · 이동 기록

|컬럼|타입|제약|설명|
|--|--|--|--|
|id|BIGSERIAL|PK||
|user_id|BIGINT|FK → app_user|비로그인이면 NULL|
|offer_id|BIGINT|FK → online.offer, NOT NULL||
|variant_id|BIGINT|FK → catalog.variant, NOT NULL||
|price_snapshot|INTEGER|NOT NULL|누른 시점 상품가|
|shipping_snapshot|INTEGER|NOT NULL|누른 시점 배송비|
|clicked_at|TIMESTAMPTZ|DEFAULT now()||

### account.purchase — 구매 기록

쓰는 화면: 구매했어요 · 구매 기록

|컬럼|타입|제약|설명|
|--|--|--|--|
|id|BIGSERIAL|PK||
|user_id|BIGINT|FK → app_user, NOT NULL||
|variant_id|BIGINT|FK → catalog.variant, NOT NULL||
|click_id|BIGINT|FK → outbound_click|온라인 구매|
|store_id|BIGINT|FK → offline.store|오프라인 구매|
|price|INTEGER||산 가격|
|purchased_on|DATE|||
|created_at|TIMESTAMPTZ|DEFAULT now()||

### account.issue — 문의 (문제 제기)

쓰는 화면: 문제 제기 · 문의 내역

|컬럼|타입|제약|설명|
|--|--|--|--|
|id|BIGSERIAL|PK||
|user_id|BIGINT|FK → app_user, NOT NULL||
|click_id|BIGINT|FK → outbound_click|어떤 이동 기록인지|
|purchase_id|BIGINT|FK → purchase|어떤 구매인지|
|type|TEXT|CHECK price / stock / fake / etc|문제 유형|
|content|TEXT|NOT NULL||
|attachments|JSONB||사진 경로|
|price_now|INTEGER||문의 시점 가격 (스냅샷과 비교)|
|state|TEXT|CHECK open / answered / closed||
|answer|TEXT||운영자 답변|
|created_at|TIMESTAMPTZ|DEFAULT now()||

## ingest — 수집 원본 · 요청

### ingest.raw_listing — 수집한 원본 상품

쓰는 화면: 배치: 수집 → 상품 매칭

|컬럼|타입|제약|설명|
|--|--|--|--|
|id|BIGSERIAL|PK||
|mall_id|BIGINT|FK → online.mall||
|source|TEXT|CHECK api / crawl||
|source_url|TEXT|NOT NULL||
|title|TEXT||몰에 적힌 그대로|
|price|INTEGER|||
|shipping_fee|INTEGER|||
|image_url|TEXT|||
|payload|JSONB||원본 응답 전체|
|match_state|TEXT|CHECK pending / matched / review / rejected|매칭 상태|
|matched_variant_id|BIGINT|FK → catalog.variant|매칭된 버전|
|match_score|REAL||AI 유사도|
|collected_at|TIMESTAMPTZ|NOT NULL||

### ingest.collect_job — 수집 실행 기록

쓰는 화면: 배치 모니터링

|컬럼|타입|제약|설명|
|--|--|--|--|
|id|BIGSERIAL|PK||
|mall_id|BIGINT|FK → online.mall||
|kind|TEXT|CHECK api / crawl||
|status|TEXT|CHECK running / success / failed||
|item_count|INTEGER||가져온 개수|
|error|TEXT||실패 이유|
|started_at|TIMESTAMPTZ|NOT NULL||
|finished_at|TIMESTAMPTZ|||

### ingest.product_request — 새 굿즈 요청 (판매자)

쓰는 화면: 판매자 상품 등록 → 후보에 없을 때

|컬럼|타입|제약|설명|
|--|--|--|--|
|id|BIGSERIAL|PK||
|requested_by|BIGINT|FK → account.app_user, NOT NULL||
|store_id|BIGINT|FK → offline.store||
|name|TEXT|NOT NULL||
|image_url|TEXT||올린 사진|
|state|TEXT|CHECK pending / approved / rejected||
|created_variant_id|BIGINT|FK → catalog.variant|추가된 버전|
|created_at|TIMESTAMPTZ|DEFAULT now()||
