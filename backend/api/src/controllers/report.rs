//! 재고 제보 · 매장 제보 (로그인 필요)

use axum::{Json, extract::State, http::StatusCode};
use serde::Deserialize;
use serde_json::Value;

use crate::{
    AppState,
    error::AppResult,
    middleware::AuthUser,
    services,
    views::{
        Done, List,
        report::{ReportOutcomeView, StockReportView},
    },
};

#[derive(Deserialize)]
pub struct StockReportBody {
    store_id: i64,
    variant_id: i64,
    /// many · few · none
    status: String,
    photo_url: Option<String>,
}

/// POST /stock-reports — 매장 상세 [제보하기]
pub async fn create_stock_report(
    State(s): State<AppState>,
    user: AuthUser,
    Json(b): Json<StockReportBody>,
) -> AppResult<(StatusCode, Json<ReportOutcomeView>)> {
    let out = services::report::create_stock_report(&s.pool, user, b.store_id, b.variant_id, &b.status, b.photo_url.as_deref()).await?;
    Ok((StatusCode::CREATED, Json(out.into())))
}

/// GET /me/stock-reports — 내 제보 내역
pub async fn my_reports(State(s): State<AppState>, user: AuthUser) -> AppResult<Json<List<StockReportView>>> {
    let list = services::report::my_reports(&s.pool, user).await?;
    Ok(Json(List::of(list.into_iter().map(Into::into).collect())))
}

#[derive(Deserialize)]
pub struct SuggestionBody {
    store_id: Option<i64>,
    /// new · edit · closed
    #[serde(rename = "type")]
    kind: String,
    content: Value,
}

/// POST /store-suggestions — 새 매장 · 정보 수정 · 폐업 제보
pub async fn create_store_suggestion(
    State(s): State<AppState>,
    user: AuthUser,
    Json(b): Json<SuggestionBody>,
) -> AppResult<(StatusCode, Json<Done>)> {
    let id = services::report::create_store_suggestion(&s.pool, user, b.store_id, &b.kind, b.content).await?;
    Ok((StatusCode::CREATED, Json(Done::id(id))))
}
