//! 운영 (운영자 계정만): 수집 원본 검토, 수집 실행 기록, 상태 확인

use axum::{
    Json,
    extract::{Path, Query, State},
};
use serde::Deserialize;
use serde_json::{Value, json};

use crate::{
    AppState,
    error::AppResult,
    middleware::AdminUser,
    services,
    views::{
        Done, List,
        admin::{CollectJobView, RawListingView},
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
    limit: Option<i64>,
}

/// GET /admin/raw-listings?state=pending — 매칭 대기 목록
pub async fn raw_listings(State(s): State<AppState>, _admin: AdminUser, Query(q): Query<RawQuery>) -> AppResult<Json<List<RawListingView>>> {
    let list = services::admin::raw_listings(&s.pool, q.state.as_deref().unwrap_or("pending"), q.limit.unwrap_or(50)).await?;
    Ok(Json(List::of(list.into_iter().map(Into::into).collect())))
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
