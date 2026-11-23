# backend/collector — Python 수집기

쇼핑 API와 크롤링으로 몰 정보를 모아 `ingest.raw_listing`에 저장한다. 앱에 보이는 것은 카탈로그 버전과 매칭된 뒤다.

```text
collector/
├── api_clients/        # 쇼핑 API: coupang.py (쿠팡 파트너스, 키 필요) · shopify.py (공식몰 공개 상품 JSON, 키 없음)
├── spiders/mall.py     # Scrapy + Playwright 크롤러 (online.mall.crawl_allowed = true 인 몰만)
├── pipelines/          # 크롤링 결과 → ingest.raw_listing, 몰마다 ingest.collect_job
├── worker.py           # 관리자 페이지에서 누른 [수집 시작]을 실제로 실행 (python -m worker)
├── events.py           # 실행 단계별 기록 → ingest.collect_event (관리자 페이지가 읽음)
├── demo/               # 데모 수집 대상: 데모 몰 A(정적) · B(자바스크립트) + 쿠팡 형식 테스트 서버 (python -m demo)
├── sites.real.toml     # 실제 몰 4곳 선택자 (robots.txt · 약관 확인 기록 포함)
├── sites.demo.toml     # 데모 몰 선택자 (이 PC 안 시험용)
├── db.py               # DB 접근 · 저장 규칙 (매칭된 판매처 가격 갱신, 실행 대기열)
├── listing.py          # 수집 결과 한 줄 (API · 크롤링 공통), 가격 · 배송비 읽기
├── sites.py            # 크롤링 대상 몰 설정 읽기 (sites.real.toml · sites.toml)
├── settings.py         # Scrapy 설정: robots.txt 준수, 요청 간격
├── sites.example.toml  # 몰 설정 예시 → sites.toml 로 복사 (저장소에 올리지 않음)
├── .env.example        # DATABASE_URL, 쿠팡 키 → .env 로 복사 (저장소에 올리지 않음)
└── tests/              # 로컬 고정 페이지 · 가짜 API 응답으로만 테스트 (외부 사이트에 요청하지 않음)
```

## 설치

```bash
cd backend/collector
uv sync
uv run playwright install chromium   # 자바스크립트로 그려지는 몰을 수집할 때만
cp .env.example .env                 # DATABASE_URL, 쿠팡 키
```

## 수집 흐름

```mermaid
flowchart LR
    api["쿠팡 파트너스 API"] --> raw["ingest.raw_listing"]
    crawl["크롤링 (crawl_allowed 몰)"] --> raw
    raw -->|이미 연결된 몰 · 주소| offer["online.offer 가격 갱신<br/>+ offer_history"]
    raw -->|새 주소: pending| match["매칭: 운영자 /admin/raw-listings<br/>(나중에 AI 서버)"]
    match --> offer
```

- 수집한 원본은 바로 노출하지 않는다. 같은 몰 · 같은 주소가 이미 `online.offer`로 연결되어 있으면 그 가격 · 품절을 바로 갱신하고, 바뀌었으면 `offer_history`에 남긴다.
- 가격을 못 읽은 경우(수집 실패)에는 이전 값을 유지하고 수집 시각도 바꾸지 않는다. 품절이라 가격이 안 보이면 품절만 반영한다.
- 실행마다 `ingest.collect_job`에 몰별 개수 · 성공 여부 · 실패 이유를 남긴다 (`/admin/collect-jobs`).

## 실제 수집 대상 (2026-11-23 확인)

관리자 페이지의 [수집 시작]은 아래 실제 대상을 실제로 요청한다. 워커를 켜면 `sites.real.toml`의 몰이 DB에 등록되고(확인 기록이 있으면 수집 허용으로), 관리자 페이지에서 언제든 끌 수 있다.

|대상|방식|주소|확인한 것|"키링" · "ハチワレ マスコット"으로 돌린 결과|
|--|--|--|--|--|
|반다이남코코리아몰|크롤링 (정적 HTML)|모바일 검색 `m.bnkrmall.co.kr/mw/goods/search.do?sword=`|robots.txt: /nmanager · /cscenter · /member만 막음. 일반 브라우저가 아니면 모바일로 보냄|"키링" 0건 (몰 자체에 결과 없음), "건담" 39건|
|포켓몬스토어|크롤링 (자바스크립트 → Playwright)|`pokemonstore.co.kr/pages/product/product-list.html?keywords=`|robots.txt 전체 허용|20건|
|대원샵|크롤링 (자바스크립트 → Playwright)|`daewonshop.com/search?searchKeyword=`|robots.txt 전체 허용|20건|
|텐바이텐|크롤링 (자바스크립트 → Playwright)|`10x10.co.kr/search/renewal/index.asp?rect=`|robots.txt: 회원 · 결제 폴더만 막음. 상품 링크가 자바스크립트라 이미지 파일명(B00+번호)으로 상품 주소를 만듦|56건 (무료배송 배지 → 배송비 0)|
|치이카와 마켓 (일본 공식몰)|공개 API (Shopify 상품 JSON, 키 없음)|`chiikawamarket.jp/products.json?limit=250&page=N`|robots.txt가 막지 않음. 검색 JSON은 막혀 있어(417) 목록을 받아 거름. 엔화 → 원화는 ECB 기준 환율(Frankfurter, 키 없음)|40쪽(1만 개) 81초, 20건|

- 이용약관: 네 몰 모두 공정위 표준약관 형태로, 자동 수집을 따로 금지하는 조항은 없고 "게시된 정보의 변경 · 업무 방해 · 저작권 침해"를 금지한다 → 사이트당 한 번에 요청 하나, 3초 안팎 간격, 이름 · 가격 · 주소만 저장 (이미지는 주소만)
- 사이트 구조가 바뀌면 "상품 0개 읽음"으로 보인다. 관리자 페이지의 파싱 기록(선택자 · 읽은 상품 표)으로 확인하고 `sites.real.toml`의 선택자를 고친다
- 쿠팡 파트너스는 키가 생기면 `.env`에 넣고 관리자 페이지 API 종류에서 고른다. 키가 없으면 그 실행은 "키 없음"으로 실패한다

```bash
DATABASE_URL=postgres://goodmorning:goodmorning@localhost:5432/goodmorning uv run python -m worker   # 실제 대상
uv run python -m api_clients shopify --keyword "ハチワレ マスコット" --dry-run                        # DB 없이 공개 API만
```

## 관리자 페이지에서 실행 — 워커

관리자 페이지(`http://localhost:8080/console/`)의 [수집 시작]은 `ingest.collect_run`에 한 줄을 넣기만 한다. 워커가 그 줄을 꺼내 아래 명령을 따로 실행하고(Scrapy 리액터는 한 프로세스에서 다시 시작할 수 없어서), 각 프로세스가 단계마다 `ingest.collect_event`를 남긴다.

```bash
uv run python -m worker          # 2초마다 대기열 확인 (3초마다 생존 신호 → 페이지의 "수집기 연결됨")
uv run python -m worker --once   # 하나만 처리
```

|종류|워커가 실행하는 것|남기는 단계|
|--|--|--|
|크롤링|`scrapy crawl mall -a run_id=… [-a mall=…] [-a query=…] -a max_queries=…`|대상 확인(crawl_allowed · 건너뜀) → robots.txt 받기 · 본문 → 페이지 요청(HTTP / Playwright) → 응답(상태 · 크기 · 시간) → 파싱(선택자, 읽은 상품) → 저장(새 주소 매칭 대기 / 이미 연결된 판매처 가격 갱신) → 몰별 끝. robots.txt가 막은 주소는 "요청하지 않음"|
|쇼핑 API|`python -m api_clients coupang --run-id … (--keyword … \| --catalog --max-queries …)`|시작(호출 한도 · 간격) → 서명(서명한 문자열 · Authorization 헤더, 시크릿은 남기지 않음) → 요청 → 응답(상태 · 시간 · JSON) → 저장 → 끝|

cron으로 돌 때처럼 `run_id` 없이 실행하면 기록을 남기지 않는다 (이전과 같음).

## 이 PC 안 시험 대상 — `python -m demo`

인터넷 없이, 또는 실제 몰에 요청을 보내지 않고 시험할 때 쓰는 가상 대상 (테스트에서도 쓴다). 크롤러 · API 클라이언트 코드는 실제 대상과 같다. 평소 관리자 페이지 시연은 위의 실제 대상으로 한다.

```bash
DATABASE_URL=postgres://goodmorning:goodmorning@localhost:5432/goodmorning uv run python -m demo
```

|대상|주소|확인되는 것|
|--|--|--|
|데모 몰 A (정적 HTML)|`http://127.0.0.1:8091/search?q=`|서버가 그린 HTML → 일반 요청 · CSS 선택자. robots.txt에 `Disallow: /cart`. 품절 상품 1개|
|데모 몰 B (자바스크립트)|`http://127.0.0.1:8092/search?keyword=`|HTML에는 상품이 없고 0.5초 뒤 자바스크립트가 그림 → Playwright(Chromium)로만 읽힘|
|쿠팡 형식 테스트 서버|`http://127.0.0.1:8093/v2/providers/affiliate_open_api/apis/openapi/products/search`|쿠팡 파트너스와 같은 경로 · 응답 모양. `Authorization`의 HMAC 서명 · 날짜(±10분) · access-key가 틀리면 401|

- 상품은 `demo/data.py`의 가상 상품 (이름은 개발용 카탈로그와 겹치게). `sale` 상품은 10분마다 1,000원 할인이 켜졌다 꺼져서, 연결(매칭)한 뒤 다시 수집하면 가격 변동이 실제로 잡힌다.
- 워커는 데모용 환경 변수로 돈다: `SITES_FILE=sites.demo.toml`, `COUPANG_API_DOMAIN=http://127.0.0.1:8093`, `COUPANG_MALL_NAME=쿠팡 (테스트 서버)`, 데모 키. `.env`의 실제 키 · `sites.toml`은 건드리지 않는다.
- 데모 몰 두 곳은 `dev_seed.sql`에 `crawl_allowed = true`로 들어 있다 (직접 만든 사이트). 관리자 페이지에서 끄면 다음 크롤링에서 "건너뜀"이 보인다.

## 쇼핑 API — 쿠팡 파트너스

```bash
uv run python -m api_clients coupang --keyword "쿠로미 마스코트 인형" --dry-run   # DB에 넣지 않고 출력
uv run python -m api_clients coupang --keyword "쿠로미 마스코트 인형"
uv run python -m api_clients coupang --catalog --max-queries 5                     # 카탈로그 버전마다 검색어
```

- 키: 쿠팡 파트너스 가입 → 최종 승인 → Access Key · Secret Key (`.env`의 `COUPANG_ACCESS_KEY` · `COUPANG_SECRET_KEY`). 키에 유효기간이 있다.
- 요청마다 HMAC-SHA256 서명 (`signed-date + GET + 경로 + 쿼리`, GMT `yyMMddTHHmmssZ`).
- 호출 한도를 넘으면 키가 정지될 수 있어, 한 번 실행에 `COUPANG_MAX_CALLS`(기본 10)회까지, 호출 사이 `COUPANG_MIN_INTERVAL_SEC`(기본 5)초를 둔다. 실제 한도는 파트너스 공식 문서로 확인한다.
- 같은 상품을 한 줄로 묶기 위해 `source_url`은 `https://www.coupang.com/vp/products/{productId}`로 저장하고, 파트너스 링크(수수료 추적)는 `payload.partner_url`에 둔다.
- 응답에 배송비 금액이 없어 무료배송이면 0, 아니면 '알 수 없음'(NULL)으로 저장한다.
- 아직 실제 키로 호출해 보지 않았다. 경로 · 응답 필드는 docs/03-tech-spec.md 28번과 공개된 개발자 자료 기준이고, 키를 받으면 `--dry-run`으로 먼저 확인한다. 경로가 다르면 `COUPANG_SEARCH_PATH`로 바꾼다.

네이버 쇼핑 검색 API(`/v1/search/shop`)는 2026-07-31에 종료되었고 NAVER API HUB로도 옮겨지지 않아 연동하지 않았다 (기존 키도 호출 불가, 쇼핑인사이트 API는 상품 · 가격을 주지 않음).

## 크롤링

```bash
cp sites.example.toml sites.toml          # 몰마다 검색 주소 · CSS 선택자
uv run scrapy crawl mall                  # sites.real.toml · sites.toml의 몰 × 카탈로그 검색어 (기본 5개)
uv run scrapy crawl mall -a mall="공식 온라인몰" -a query="쿠로미 마스코트 인형"
```

몰을 추가하기 전에 확인할 것

1. robots.txt에서 검색 결과 페이지를 막지 않았는지 (Scrapy도 `ROBOTSTXT_OBEY`로 매번 확인하고, 막힌 주소는 요청하지 않는다)
2. 이용약관에 자동 수집 금지 조항이 없는지
3. 확인했으면 관리자 페이지 몰 목록에서 수집 허용을 켠다 (또는 `reviewed`에 확인 기록을 적어 두면 처음 등록할 때 켜진다) — `crawl_allowed`가 아닌 몰은 설정 파일에 있어도 건너뛴다

지킬 것 (settings.py): 사이트당 동시 요청 1개, 요청 사이 3초 안팎 + 응답이 느리면 더 늦춤(AutoThrottle), 수집기임을 밝히는 User-Agent, 하루 1~2회.
자바스크립트로 목록을 그리는 몰은 `js = true` → 그 요청만 Playwright(Chromium)로 연다.

확인한 실제 몰은 `sites.real.toml`(저장소에 있음)에, 이 PC에서만 더할 몰은 `sites.toml`(저장소 제외)에 적는다. 둘 다 읽는다 (`settings.py`의 `SITES_FILE`). 개발용 가상 몰(오픈마켓 A · 공식 온라인몰 …)은 `crawl_allowed = false`다.

## 주기 실행 예시 (cron, 하루 2회)

```cron
0 6,18 * * *  cd /srv/goodmorning/backend/collector && uv run python -m api_clients coupang --catalog --max-queries 10 >> logs/api.log 2>&1
30 6,18 * * * cd /srv/goodmorning/backend/collector && uv run scrapy crawl mall >> logs/crawl.log 2>&1
```

## 테스트

```bash
uv run pytest                                   # DB · Chromium이 없으면 그 테스트는 건너뜀
DATABASE_URL=postgres://… uv run pytest         # DB까지 (마이그레이션된 개발용 DB)
```

- 크롤링 테스트는 `tests/fixtures/site/`를 127.0.0.1에 띄워서 `scrapy crawl mall`을 실제로 돌린다: robots.txt를 먼저 받는지, 막힌 경로를 요청하지 않는지, 자바스크립트 페이지를 Playwright로 읽는지, crawl_allowed가 아닌 몰을 건너뛰는지.
- 쿠팡 테스트는 가짜 응답(`tests/fixtures/coupang_search.json`, 공개된 필드 이름으로 만든 예시)과 httpx MockTransport로 서명 · 요청 모양을 확인한다.
- `test_demo.py`: 데모 대상 서버를 빈 포트에 띄워 실제 HTTP로 확인 (쿠팡 형식 테스트 서버가 서명을 검사하는지, 틀린 시크릿이면 401).
- `test_worker.py`(DB): 대기열 → 워커 → 실제 크롤링 · API 호출 → 단계 기록 순서 · 결과 · 실패 처리 · crawl_allowed가 꺼진 몰 건너뛰기.
- `test_real_sources.py`: 실제 몰 설정 파일 검사, 텐바이텐식 링크 만들기, 공식몰 공개 API(가짜 응답으로 엔화 → 원화 · 품절 · 검색어), 몰 자동 등록. 테스트는 외부 사이트에 요청하지 않는다 (실제 요청 결과는 위 표)
