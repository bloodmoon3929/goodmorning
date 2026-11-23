//! 운영: 수집 원본을 카탈로그 버전에 연결(매칭 확정)하거나 제외한다.
//! AI 매칭(EmbeddingGemma 2)이 생기기 전까지는 운영자가 이 화면으로 확정한다.
//! 한 번 매칭된 몰 · 주소는 수집기가 다음 수집부터 online.offer 가격을 바로 갱신한다 (collector/pipelines).
//!
//! 관리자 페이지(/console/)의 [수집 시작]은 ingest.collect_run에 한 줄(queued)을 넣기만 한다.
//! 실제 크롤링 · 쇼핑 API 호출은 수집기 워커(collector: python -m worker)가 꺼내서 하고, 단계마다 ingest.collect_event를 남긴다.

use chrono::{DateTime, Utc};
use serde_json::{Value, json};
use sqlx::PgPool;

use crate::{
    error::{AppError, AppResult},
    models::{
        ingest::{CollectEvent, CollectJob, CollectRun, CollectWorker, RawListing, VariantCandidate},
        online::MallStat,
    },
    repositories,
};

/// 워커가 이 시간 안에 신호를 남겼으면 "연결됨"
pub const WORKER_ALIVE_SECS: i64 = 10;

const STATES: [&str; 4] = ["pending", "review", "matched", "rejected"];

pub async fn health(pool: &PgPool) -> AppResult<()> {
    repositories::admin::ping(pool).await?;
    Ok(())
}

/// state가 없으면: 실행 번호(run_id)를 준 경우 모든 상태, 아니면 매칭 대기(pending)
pub async fn raw_listings(pool: &PgPool, state: Option<&str>, run_id: Option<i64>, limit: i64) -> AppResult<Vec<RawListing>> {
    let state = match (state, run_id) {
        (Some(s), _) => Some(s),
        (None, Some(_)) => None,
        (None, None) => Some("pending"),
    };
    if let Some(s) = state
        && !STATES.contains(&s)
    {
        return Err(AppError::bad("state는 pending · review · matched · rejected 중 하나입니다"));
    }
    Ok(repositories::admin::raw_listings(pool, state, run_id, limit.clamp(1, 200)).await?)
}

/// 매칭 확정 → online.offer 반영 (+ 가격 기록). 반영된 offer 번호를 돌려준다.
pub async fn match_raw(pool: &PgPool, id: i64, variant_id: i64) -> AppResult<i64> {
    if !repositories::product::variant_exists(pool, variant_id).await? {
        return Err(AppError::NotFound("버전"));
    }
    let mut tx = pool.begin().await?;
    let raw = repositories::admin::lock_raw_listing(&mut tx, id).await?.ok_or(AppError::NotFound("수집 원본"))?;
    if !matches!(raw.match_state.as_str(), "pending" | "review") {
        return Err(AppError::Conflict(format!("이미 처리한 수집 원본입니다 ({})", raw.match_state)));
    }
    if raw.mall_id.is_none() || raw.price.is_none() {
        return Err(AppError::bad("몰 또는 가격이 없는 수집 원본은 반영할 수 없습니다"));
    }
    let offer_id = repositories::admin::upsert_offer_from_raw(&mut tx, &raw, variant_id).await?;
    repositories::admin::set_match_state(&mut tx, id, "matched", Some(variant_id)).await?;
    tx.commit().await?;
    Ok(offer_id)
}

pub async fn reject_raw(pool: &PgPool, id: i64) -> AppResult<()> {
    let mut tx = pool.begin().await?;
    let raw = repositories::admin::lock_raw_listing(&mut tx, id).await?.ok_or(AppError::NotFound("수집 원본"))?;
    if !matches!(raw.match_state.as_str(), "pending" | "review") {
        return Err(AppError::Conflict(format!("이미 처리한 수집 원본입니다 ({})", raw.match_state)));
    }
    repositories::admin::set_match_state(&mut tx, id, "rejected", None).await?;
    tx.commit().await?;
    Ok(())
}

pub async fn collect_jobs(pool: &PgPool, limit: i64) -> AppResult<Vec<CollectJob>> {
    Ok(repositories::admin::collect_jobs(pool, limit.clamp(1, 200)).await?)
}

// ------------------------------------------------------------ 관리자 페이지

pub async fn malls(pool: &PgPool) -> AppResult<Vec<MallStat>> {
    Ok(repositories::admin::malls(pool).await?)
}

/// 몰 수집 허용(crawl_allowed) · 사용 여부 바꾸기 — robots.txt · 약관을 확인한 운영자가 켠다
pub async fn update_mall(pool: &PgPool, id: i64, crawl_allowed: Option<bool>, is_active: Option<bool>) -> AppResult<()> {
    if crawl_allowed.is_none() && is_active.is_none() {
        return Err(AppError::bad("crawl_allowed 또는 is_active가 필요합니다"));
    }
    if repositories::admin::update_mall(pool, id, crawl_allowed, is_active).await? == 0 {
        return Err(AppError::NotFound("몰"));
    }
    Ok(())
}

/// 쇼핑 API 종류: 쿠팡 파트너스(키 필요) · 치이카와 마켓 공개 상품 JSON(키 없음, collector/api_clients/shopify.py)
pub const API_PROVIDERS: [&str; 2] = ["coupang", "chiikawa_market"];

/// 수집 실행 요청 값
#[derive(Debug, Default)]
pub struct RunRequest {
    pub kind: String,
    pub provider: Option<String>,
    pub mall: Option<String>,
    pub keyword: Option<String>,
    pub max_queries: Option<i64>,
}

/// [수집 시작] → 대기열에 넣고 실행 번호를 돌려준다
pub async fn start_run(pool: &PgPool, admin_id: i64, req: RunRequest) -> AppResult<i64> {
    if !matches!(req.kind.as_str(), "crawl" | "api") {
        return Err(AppError::bad("kind는 crawl(크롤링) 또는 api(쇼핑 API)입니다"));
    }
    let keyword = req.keyword.map(|k| k.trim().to_string()).filter(|k| !k.is_empty());
    if keyword.as_ref().is_some_and(|k| k.chars().count() > 60) {
        return Err(AppError::bad("검색어는 60자까지입니다"));
    }
    let mall = req.mall.map(|m| m.trim().to_string()).filter(|m| !m.is_empty());
    if req.kind == "api" && mall.is_some() {
        return Err(AppError::bad("쇼핑 API는 몰을 고르지 않습니다 (API가 정한 몰)"));
    }
    let provider = match req.kind.as_str() {
        "api" => {
            let p = req.provider.unwrap_or_else(|| "coupang".into());
            if !API_PROVIDERS.contains(&p.as_str()) {
                return Err(AppError::bad("provider는 coupang 또는 chiikawa_market입니다"));
            }
            if p != "coupang" && keyword.is_none() {
                return Err(AppError::bad("공식몰 공개 API는 검색어가 필요합니다 (상품 이름 언어로, 예: マスコット)"));
            }
            Some(p)
        }
        _ if req.provider.is_some() => return Err(AppError::bad("크롤링은 provider를 고르지 않습니다")),
        _ => None,
    };
    if let Some(m) = &mall
        && !repositories::admin::mall_exists(pool, m).await?
    {
        return Err(AppError::NotFound("몰"));
    }
    // 검색어 수는 작게: 데모 · 실제 몰 모두 요청 간격을 지켜야 해서 오래 걸린다
    let max_queries = req.max_queries.unwrap_or(3).clamp(1, 10);
    let params = json!({ "mall": mall, "keyword": keyword, "max_queries": max_queries, "provider": provider });
    Ok(repositories::admin::insert_run(pool, &req.kind, params, admin_id).await?)
}

pub async fn runs(pool: &PgPool, limit: i64) -> AppResult<Vec<CollectRun>> {
    Ok(repositories::admin::runs(pool, limit.clamp(1, 100)).await?)
}

pub struct RunDetail {
    pub run: CollectRun,
    pub events: Vec<CollectEvent>,
    pub jobs: Vec<CollectJob>,
}

pub async fn run_detail(pool: &PgPool, id: i64, after: i64) -> AppResult<RunDetail> {
    let run = repositories::admin::run(pool, id).await?.ok_or(AppError::NotFound("수집 실행"))?;
    let events = repositories::admin::events(pool, id, after.max(0), 500).await?;
    let jobs = repositories::admin::run_jobs(pool, id).await?;
    Ok(RunDetail { run, events, jobs })
}

pub struct CollectorStatus {
    pub worker: Option<CollectWorker>,
    pub alive: bool,
    pub queued: i64,
    pub running: i64,
}

pub async fn collector_status(pool: &PgPool, now: DateTime<Utc>) -> AppResult<CollectorStatus> {
    let worker = repositories::admin::workers(pool).await?.into_iter().next();
    let alive = worker.as_ref().is_some_and(|w| (now - w.seen_at).num_seconds() <= WORKER_ALIVE_SECS);
    let (queued, running) = repositories::admin::queue_counts(pool).await?;
    Ok(CollectorStatus { worker, alive, queued, running })
}

/// 상품 제목 → 비교할 낱말 (기호로 나누고 두 글자 이상만)
pub fn title_words(title: &str) -> Vec<String> {
    title.split(|c: char| !c.is_alphanumeric()).filter(|w| w.chars().count() >= 2).take(12).map(str::to_lowercase).collect()
}

/// 매칭 후보: 수집할 때 쓴 검색어의 버전(payload.query_variant_id)을 맨 앞에, 나머지는 제목 낱말이 많이 겹치는 순
pub async fn candidates(pool: &PgPool, raw_id: i64) -> AppResult<(RawListing, Vec<VariantCandidate>, Option<i64>)> {
    let raw = repositories::admin::raw_listing(pool, raw_id).await?.ok_or(AppError::NotFound("수집 원본"))?;
    let hint = raw.payload.as_ref().and_then(|p| p.0.get("query_variant_id")).and_then(Value::as_i64);
    let title = raw.title.as_deref().unwrap_or("");
    let list = repositories::admin::variant_candidates(pool, &title_words(title), title, hint, 5).await?;
    Ok((raw, list, hint))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn title_words_split_on_symbols() {
        assert_eq!(title_words("[산리오 정품] 쿠로미 마스코트 인형 10cm"), vec!["산리오", "정품", "쿠로미", "마스코트", "인형", "10cm"]);
        assert_eq!(title_words("마이멜로디&쿠로미 아크릴 스탠드 L"), vec!["마이멜로디", "쿠로미", "아크릴", "스탠드"]);
    }
}
