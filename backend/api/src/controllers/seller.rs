//! 판매자 센터. /seller/stores/{store_id}/… 는 middleware::seller가 본인 매장인지 먼저 확인한다.

use axum::{
    Json,
    extract::{Path, Query, State},
    http::StatusCode,
};
use serde::Deserialize;

use crate::{
    AppState,
    error::AppResult,
    middleware::AuthUser,
    services::{self, seller::StockChange},
    views::{Done, List, report::StockReportView, seller::SellerStoreView, store::StoreView},
};

/// GET /seller/stores — 내가 관리하는 매장
pub async fn my_stores(State(s): State<AppState>, user: AuthUser) -> AppResult<Json<List<StoreView>>> {
    let list = services::seller::my_stores(&s.pool, user).await?;
    Ok(Json(List::of(list.into_iter().map(Into::into).collect())))
}

/// GET /seller/stores/{store_id} — 재고 관리 화면
pub async fn store(State(s): State<AppState>, Path(store_id): Path<i64>) -> AppResult<Json<SellerStoreView>> {
    Ok(Json(services::seller::store(&s.pool, store_id).await?.into()))
}

#[derive(Deserialize)]
pub struct StockItem {
    variant_id: i64,
    status: String,
    price: Option<i32>,
}

#[derive(Deserialize)]
pub struct StockBody {
    items: Vec<StockItem>,
}

/// PUT /seller/stores/{store_id}/stock — 바꾼 재고를 한 번에 저장 (처음 보는 버전은 취급 상품으로 추가)
pub async fn save_stock(State(s): State<AppState>, Path(store_id): Path<i64>, Json(b): Json<StockBody>) -> AppResult<Json<Done>> {
    let changes: Vec<StockChange> = b.items.into_iter().map(|i| StockChange { variant_id: i.variant_id, status: i.status, price: i.price }).collect();
    let n = services::seller::save_stock(&s.pool, store_id, &changes).await?;
    Ok(Json(Done::count(n as u64)))
}

/// POST /seller/stores/{store_id}/stock/confirm — [오늘 재고 그대로예요]
pub async fn confirm_all(State(s): State<AppState>, Path(store_id): Path<i64>) -> AppResult<Json<Done>> {
    Ok(Json(Done::count(services::seller::confirm_all(&s.pool, store_id).await?)))
}

#[derive(Deserialize)]
pub struct ReportsQuery {
    state: Option<String>,
}

/// GET /seller/stores/{store_id}/reports?state=pending — 제보 확인
pub async fn reports(State(s): State<AppState>, Path(store_id): Path<i64>, Query(q): Query<ReportsQuery>) -> AppResult<Json<List<StockReportView>>> {
    let list = services::seller::reports(&s.pool, store_id, q.state.as_deref()).await?;
    Ok(Json(List::of(list.into_iter().map(Into::into).collect())))
}

/// POST /seller/stores/{store_id}/reports/{report_id}/approve
pub async fn approve_report(
    State(s): State<AppState>,
    user: AuthUser,
    Path((store_id, report_id)): Path<(i64, i64)>,
) -> AppResult<Json<StockReportView>> {
    Ok(Json(services::seller::resolve_report(&s.pool, user, store_id, report_id, true).await?.into()))
}

/// POST /seller/stores/{store_id}/reports/{report_id}/reject
pub async fn reject_report(
    State(s): State<AppState>,
    user: AuthUser,
    Path((store_id, report_id)): Path<(i64, i64)>,
) -> AppResult<Json<StockReportView>> {
    Ok(Json(services::seller::resolve_report(&s.pool, user, store_id, report_id, false).await?.into()))
}

#[derive(Deserialize)]
pub struct ProductRequestBody {
    name: String,
    image_url: Option<String>,
}

/// POST /seller/stores/{store_id}/product-requests — 후보에 없는 새 굿즈 요청
pub async fn request_product(
    State(s): State<AppState>,
    user: AuthUser,
    Path(store_id): Path<i64>,
    Json(b): Json<ProductRequestBody>,
) -> AppResult<(StatusCode, Json<Done>)> {
    let id = services::seller::request_product(&s.pool, user, store_id, &b.name, b.image_url.as_deref()).await?;
    Ok((StatusCode::CREATED, Json(Done::id(id))))
}
