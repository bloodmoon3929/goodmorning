//! 운영 (운영자 계정만): 수집 원본 검토, 수집 실행 기록, 상태 확인, 관리자 페이지의 수집 시작 · 진행 보기

use axum::{
    Json,
    extract::{Path, Query, State},
    http::StatusCode,
};
use chrono::Utc;
use serde::Deserialize;
use serde_json::{Value, json};

use crate::{
    AppState,
    error::AppResult,
    middleware::AdminUser,
    services::{self, admin::RunRequest},
    views::{
        Done, List,
        admin::{CandidatesView, CollectJobView, CollectorStatusView, MallView, RawListingView, RunDetailView, RunView},
    },
};

/// GET /health — 서버 · DB 상태
pub async fn health(State(s): State<AppState>) -> AppResult<Json<Value>> {
    services::admin::health(&s.pool).await?;
    Ok(Json(json!({ "status": "ok" })))
}

#[derive(Deserialize)]
pub struct RawQuery {
    state: Option<String>,
    run_id: Option<i64>,
    limit: Option<i64>,
}

/// GET /admin/raw-listings?state=pending — 매칭 대기 목록 (?run_id= 이면 그 수집 실행에서 모은 것 전부)
pub async fn raw_listings(State(s): State<AppState>, _admin: AdminUser, Query(q): Query<RawQuery>) -> AppResult<Json<List<RawListingView>>> {
    let list = services::admin::raw_listings(&s.pool, q.state.as_deref(), q.run_id, q.limit.unwrap_or(50)).await?;
    Ok(Json(List::of(list.into_iter().map(Into::into).collect())))
}

/// GET /admin/raw-listings/{id}/candidates — 매칭 후보 버전 (수집 검색어의 버전 + 제목이 비슷한 버전)
pub async fn raw_candidates(State(s): State<AppState>, _admin: AdminUser, Path(id): Path<i64>) -> AppResult<Json<CandidatesView>> {
    let (raw, list, hint) = services::admin::candidates(&s.pool, id).await?;
    Ok(Json(CandidatesView::new(raw, list, hint)))
}

#[derive(Deserialize)]
pub struct MatchBody {
    variant_id: i64,
}

/// POST /admin/raw-listings/{id}/match — 카탈로그 버전에 연결 → online.offer 반영 (id = offer 번호)
pub async fn match_raw(State(s): State<AppState>, _admin: AdminUser, Path(id): Path<i64>, Json(b): Json<MatchBody>) -> AppResult<Json<Done>> {
    Ok(Json(Done::id(services::admin::match_raw(&s.pool, id, b.variant_id).await?)))
}

/// POST /admin/raw-listings/{id}/reject — 굿모닝에서 다루지 않는 상품으로 제외
pub async fn reject_raw(State(s): State<AppState>, _admin: AdminUser, Path(id): Path<i64>) -> AppResult<Json<Done>> {
    services::admin::reject_raw(&s.pool, id).await?;
    Ok(Json(Done::ok()))
}

#[derive(Deserialize)]
pub struct JobsQuery {
    limit: Option<i64>,
}

/// GET /admin/collect-jobs — 수집 실행 기록 (배치 모니터링)
pub async fn collect_jobs(State(s): State<AppState>, _admin: AdminUser, Query(q): Query<JobsQuery>) -> AppResult<Json<List<CollectJobView>>> {
    let list = services::admin::collect_jobs(&s.pool, q.limit.unwrap_or(20)).await?;
    Ok(Json(List::of(list.into_iter().map(Into::into).collect())))
}

/// GET /admin/malls — 몰 목록 (수집 허용 여부, 판매처 · 수집 원본 수)
pub async fn malls(State(s): State<AppState>, _admin: AdminUser) -> AppResult<Json<List<MallView>>> {
    let list = services::admin::malls(&s.pool).await?;
    Ok(Json(List::of(list.into_iter().map(Into::into).collect())))
}

#[derive(Deserialize)]
pub struct MallBody {
    crawl_allowed: Option<bool>,
    is_active: Option<bool>,
}

/// PATCH /admin/malls/{id} — 수집 허용(robots.txt · 약관 확인 후) · 사용 여부
pub async fn update_mall(State(s): State<AppState>, _admin: AdminUser, Path(id): Path<i64>, Json(b): Json<MallBody>) -> AppResult<Json<Done>> {
    services::admin::update_mall(&s.pool, id, b.crawl_allowed, b.is_active).await?;
    Ok(Json(Done::ok()))
}

#[derive(Deserialize)]
pub struct RunBody {
    kind: String,
    provider: Option<String>,
    mall: Option<String>,
    keyword: Option<String>,
    max_queries: Option<i64>,
}

/// POST /admin/collect-runs — [수집 시작]: 대기열에 넣는다 (수집기 워커가 실제로 실행)
pub async fn start_run(State(s): State<AppState>, admin: AdminUser, Json(b): Json<RunBody>) -> AppResult<(StatusCode, Json<Done>)> {
    let req = RunRequest { kind: b.kind, provider: b.provider, mall: b.mall, keyword: b.keyword, max_queries: b.max_queries };
    let id = services::admin::start_run(&s.pool, admin.0.id, req).await?;
    Ok((StatusCode::CREATED, Json(Done::id(id))))
}

/// GET /admin/collect-runs — 최근 수집 실행
pub async fn runs(State(s): State<AppState>, _admin: AdminUser, Query(q): Query<JobsQuery>) -> AppResult<Json<List<RunView>>> {
    let list = services::admin::runs(&s.pool, q.limit.unwrap_or(20)).await?;
    Ok(Json(List::of(list.into_iter().map(Into::into).collect())))
}

#[derive(Deserialize)]
pub struct AfterQuery {
    after: Option<i64>,
}

/// GET /admin/collect-runs/{id}?after=0 — 실행 상태 + after 번호 뒤의 단계별 기록 + 몰별 작업
pub async fn run_detail(
    State(s): State<AppState>,
    _admin: AdminUser,
    Path(id): Path<i64>,
    Query(q): Query<AfterQuery>,
) -> AppResult<Json<RunDetailView>> {
    Ok(Json(services::admin::run_detail(&s.pool, id, q.after.unwrap_or(0)).await?.into()))
}

/// GET /admin/collector — 수집기 워커 연결 상태 · 대기열
pub async fn collector(State(s): State<AppState>, _admin: AdminUser) -> AppResult<Json<CollectorStatusView>> {
    Ok(Json(services::admin::collector_status(&s.pool, Utc::now()).await?.into()))
}
