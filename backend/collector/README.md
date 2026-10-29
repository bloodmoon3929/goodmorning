# backend/collector — Python 수집기

쇼핑 API와 크롤링으로 몰 · 매장 정보를 모아 `ingest.raw_listing`에 저장한다. 앱에 보이는 것은 AI 매칭을 거친 뒤다.

```text
collector/
├── api_clients/   # 네이버 쇼핑 검색 API, 쿠팡 파트너스 Open API (API가 있으면 API 먼저)
├── spiders/       # Scrapy + Playwright 크롤러 (online.mall.crawl_allowed = true 인 사이트만)
├── pipelines/     # 파싱 결과 → ingest.raw_listing 저장, ingest.collect_job 기록
└── tests/
```

지킬 것: robots.txt · 이용약관 확인, 하루 1~2회, 요청 사이 간격 두기 (docs/03-tech-spec.md 27–28번)
