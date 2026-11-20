"""Scrapy 설정. 지킬 것: robots.txt 준수, 요청 사이 간격, 사이트당 동시 요청 1개 (docs/03-tech-spec.md 27번)"""

BOT_NAME = "goodmorning"
SPIDER_MODULES = ["spiders"]
NEWSPIDER_MODULE = "spiders"

# 누가 수집하는지 밝힌다
USER_AGENT = "goodmorning-collector/0.1 (+https://github.com/bloodmoon3929/goodmorning)"
ROBOTSTXT_OBEY = True

# 요청 사이 3초 안팎, 사이트당 한 번에 하나. 응답이 느리면 더 늦춘다.
DOWNLOAD_DELAY = 3
RANDOMIZE_DOWNLOAD_DELAY = True
CONCURRENT_REQUESTS = 4
CONCURRENT_REQUESTS_PER_DOMAIN = 1
AUTOTHROTTLE_ENABLED = True
AUTOTHROTTLE_START_DELAY = 3
AUTOTHROTTLE_MAX_DELAY = 30
RETRY_TIMES = 2
DOWNLOAD_TIMEOUT = 30
COOKIES_ENABLED = False

# 수집 결과 → ingest.raw_listing (DATABASE_URL 필요)
ITEM_PIPELINES = {"pipelines.raw_listing.RawListingPipeline": 300}

# 자바스크립트로 그려지는 페이지만 Playwright(Chromium)로 연다: Request(meta={"playwright": True})
# 나머지 요청은 일반 Scrapy 다운로더가 처리한다.
DOWNLOAD_HANDLERS = {
    "http": "scrapy_playwright.handler.ScrapyPlaywrightDownloadHandler",
    "https": "scrapy_playwright.handler.ScrapyPlaywrightDownloadHandler",
}
TWISTED_REACTOR = "twisted.internet.asyncioreactor.AsyncioSelectorReactor"
PLAYWRIGHT_BROWSER_TYPE = "chromium"
PLAYWRIGHT_LAUNCH_OPTIONS = {"headless": True}
PLAYWRIGHT_DEFAULT_NAVIGATION_TIMEOUT = 30_000

# 수집 대상 몰 설정 (선택자). 실제 몰은 robots.txt · 약관을 확인한 뒤 sites.toml에 넣는다.
SITES_FILE = "sites.toml"
# online.mall.crawl_allowed = true 인 몰만 수집한다. (False는 tests/의 로컬 고정 페이지 테스트용)
CRAWL_ALLOWED_CHECK = True

FEED_EXPORT_ENCODING = "utf-8"
LOG_LEVEL = "INFO"
