//! 마이 (모두 로그인 필요)

use axum::{
    Json,
    extract::{Path, Query, State},
    http::StatusCode,
};
use chrono::NaiveDate;
use serde::Deserialize;
use serde_json::Value;

use super::LocationQuery;
use crate::{
    AppState,
    error::AppResult,
    middleware::AuthUser,
    services::{
        self,
        me::{IssueInput, NewAlert, PurchaseInput},
    },
    views::{
        Done, List,
        me::{AlertView, IssueView, NotificationView, PurchaseView, VisitView, WishView},
        store::StoreView,
    },
};

#[derive(Deserialize, serde::Serialize)]
pub struct MyIpsBody {
    ip_ids: Vec<i64>,
}

/// PUT /me/ips — IP 목록 조정 (보일 IP와 순서)
pub async fn set_my_ips(State(s): State<AppState>, user: AuthUser, Json(b): Json<MyIpsBody>) -> AppResult<Json<MyIpsBody>> {
    let ip_ids = services::me::set_my_ips(&s.pool, user, &b.ip_ids).await?;
    Ok(Json(MyIpsBody { ip_ids }))
}

#[derive(Deserialize)]
pub struct IpRequestBody {
    name: String,
}

/// POST /me/ip-requests — 없는 IP 추가 요청
pub async fn request_ip(State(s): State<AppState>, user: AuthUser, Json(b): Json<IpRequestBody>) -> AppResult<(StatusCode, Json<Done>)> {
    Ok((StatusCode::CREATED, Json(Done::id(services::me::request_ip(&s.pool, user, &b.name).await?))))
}

/// GET /me/wishlist
pub async fn wishlist(State(s): State<AppState>, user: AuthUser, Query(loc): Query<LocationQuery>) -> AppResult<Json<List<WishView>>> {
    let list = services::me::wishlist(&s.pool, user, loc.point()?).await?;
    Ok(Json(List::of(list.into_iter().map(Into::into).collect())))
}

/// PUT /me/wishlist/{variant_id} — 찜 (버전 단위)
pub async fn add_wish(State(s): State<AppState>, user: AuthUser, Path(variant_id): Path<i64>) -> AppResult<Json<Done>> {
    services::me::set_wish(&s.pool, user, variant_id, true).await?;
    Ok(Json(Done::ok()))
}

/// DELETE /me/wishlist/{variant_id}
pub async fn remove_wish(State(s): State<AppState>, user: AuthUser, Path(variant_id): Path<i64>) -> AppResult<Json<Done>> {
    services::me::set_wish(&s.pool, user, variant_id, false).await?;
    Ok(Json(Done::ok()))
}

/// GET /me/saved-stores
pub async fn saved_stores(State(s): State<AppState>, user: AuthUser, Query(loc): Query<LocationQuery>) -> AppResult<Json<List<StoreView>>> {
    let list = services::me::saved_stores(&s.pool, user, loc.point()?).await?;
    Ok(Json(List::of(list.into_iter().map(Into::into).collect())))
}

/// PUT /me/saved-stores/{store_id} — ⭐ 매장 저장
pub async fn save_store(State(s): State<AppState>, user: AuthUser, Path(store_id): Path<i64>) -> AppResult<Json<Done>> {
    services::me::set_saved_store(&s.pool, user, store_id, true).await?;
    Ok(Json(Done::ok()))
}

/// DELETE /me/saved-stores/{store_id}
pub async fn unsave_store(State(s): State<AppState>, user: AuthUser, Path(store_id): Path<i64>) -> AppResult<Json<Done>> {
    services::me::set_saved_store(&s.pool, user, store_id, false).await?;
    Ok(Json(Done::ok()))
}

/// GET /me/alerts
pub async fn alerts(State(s): State<AppState>, user: AuthUser) -> AppResult<Json<List<AlertView>>> {
    let list = services::me::alerts(&s.pool, user).await?;
    Ok(Json(List::of(list.into_iter().map(Into::into).collect())))
}

#[derive(Deserialize)]
pub struct AlertBody {
    #[serde(rename = "type")]
    kind: String,
    variant_id: Option<i64>,
    store_id: Option<i64>,
    target_price: Option<i32>,
}

/// POST /me/alerts — 🔔 알림 받기 (목표가 이하 / 재입고 / 근처 매장 입고)
pub async fn create_alert(State(s): State<AppState>, user: AuthUser, Json(b): Json<AlertBody>) -> AppResult<(StatusCode, Json<AlertView>)> {
    let alert = services::me::create_alert(
        &s.pool,
        user,
        NewAlert { variant_id: b.variant_id, store_id: b.store_id, kind: b.kind, target_price: b.target_price },
    )
    .await?;
    Ok((StatusCode::CREATED, Json(alert.into())))
}

/// DELETE /me/alerts/{id}
pub async fn delete_alert(State(s): State<AppState>, user: AuthUser, Path(id): Path<i64>) -> AppResult<Json<Done>> {
    services::me::delete_alert(&s.pool, user, id).await?;
    Ok(Json(Done::ok()))
}

/// GET /me/notifications — 알림 목록
pub async fn notifications(State(s): State<AppState>, user: AuthUser) -> AppResult<Json<List<NotificationView>>> {
    let list = services::me::notifications(&s.pool, user).await?;
    Ok(Json(List::of(list.into_iter().map(Into::into).collect())))
}

/// POST /me/notifications/{id}/read
pub async fn read_notification(State(s): State<AppState>, user: AuthUser, Path(id): Path<i64>) -> AppResult<Json<Done>> {
    Ok(Json(Done::count(services::me::mark_read(&s.pool, user, Some(id)).await?)))
}

/// POST /me/notifications/read-all
pub async fn read_all_notifications(State(s): State<AppState>, user: AuthUser) -> AppResult<Json<Done>> {
    Ok(Json(Done::count(services::me::mark_read(&s.pool, user, None).await?)))
}

/// GET /me/visits — 이동 기록
pub async fn visits(State(s): State<AppState>, user: AuthUser) -> AppResult<Json<List<VisitView>>> {
    let list = services::me::visits(&s.pool, user).await?;
    Ok(Json(List::of(list.into_iter().map(Into::into).collect())))
}

#[derive(Deserialize)]
pub struct PurchaseBody {
    click_id: Option<i64>,
    variant_id: Option<i64>,
    store_id: Option<i64>,
    price: Option<i32>,
    purchased_on: Option<NaiveDate>,
}

/// POST /me/purchases — [구매했어요] (click_id) 또는 오프라인 구매 (variant_id + store_id)
pub async fn create_purchase(State(s): State<AppState>, user: AuthUser, Json(b): Json<PurchaseBody>) -> AppResult<(StatusCode, Json<PurchaseView>)> {
    let input = PurchaseInput { click_id: b.click_id, variant_id: b.variant_id, store_id: b.store_id, price: b.price, purchased_on: b.purchased_on };
    Ok((StatusCode::CREATED, Json(services::me::create_purchase(&s.pool, user, input).await?.into())))
}

/// GET /me/purchases
pub async fn purchases(State(s): State<AppState>, user: AuthUser) -> AppResult<Json<List<PurchaseView>>> {
    let list = services::me::purchases(&s.pool, user).await?;
    Ok(Json(List::of(list.into_iter().map(Into::into).collect())))
}

#[derive(Deserialize)]
pub struct IssueBody {
    click_id: Option<i64>,
    purchase_id: Option<i64>,
    #[serde(rename = "type")]
    kind: String,
    content: String,
    attachments: Option<Value>,
}

/// POST /me/issues — 문제 제기
pub async fn create_issue(State(s): State<AppState>, user: AuthUser, Json(b): Json<IssueBody>) -> AppResult<(StatusCode, Json<IssueView>)> {
    let input = IssueInput { click_id: b.click_id, purchase_id: b.purchase_id, kind: b.kind, content: b.content, attachments: b.attachments };
    Ok((StatusCode::CREATED, Json(services::me::create_issue(&s.pool, user, input).await?.into())))
}

/// GET /me/issues — 문의 내역
pub async fn issues(State(s): State<AppState>, user: AuthUser) -> AppResult<Json<List<IssueView>>> {
    let list = services::me::issues(&s.pool, user).await?;
    Ok(Json(List::of(list.into_iter().map(Into::into).collect())))
}
