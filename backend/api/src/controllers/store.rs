//! 매장 찾기 (리스트 · 지도) · 홈의 내 주변 재고 · 매장 상세

use axum::{
    Json,
    extract::{Path, Query, State},
};
use serde::Deserialize;

use super::id_list;
use crate::{
    AppState,
    error::AppResult,
    middleware::MaybeUser,
    services::{self, rules::GeoPoint, store::StoreQuery},
    views::{
        List,
        store::{StoreDetailView, StoreView},
    },
};

#[derive(Deserialize)]
pub struct StoresQuery {
    lat: Option<f64>,
    lng: Option<f64>,
    /// 내 IP (없으면 로그인한 회원의 내 IP)
    ip_ids: Option<String>,
    radius_km: Option<f64>,
    /// 재고 있는 매장만
    in_stock_only: Option<bool>,
    limit: Option<usize>,
}

/// GET /stores — 거리순. 홈의 내 주변 재고는 limit=3
pub async fn stores(State(s): State<AppState>, MaybeUser(user): MaybeUser, Query(q): Query<StoresQuery>) -> AppResult<Json<List<StoreView>>> {
    let ip_ids = services::store::resolve_ip_ids(&s.pool, id_list(q.ip_ids.as_deref())?, user).await?;
    let list = services::store::stores(
        &s.pool,
        StoreQuery {
            point: GeoPoint::from_query(q.lat, q.lng)?,
            ip_ids,
            radius_km: q.radius_km,
            in_stock_only: q.in_stock_only.unwrap_or(false),
            limit: q.limit.map(|l| l.clamp(1, 200)),
        },
    )
    .await?;
    Ok(Json(List::of(list.into_iter().map(Into::into).collect())))
}

#[derive(Deserialize)]
pub struct DetailQuery {
    lat: Option<f64>,
    lng: Option<f64>,
    ip_ids: Option<String>,
}

/// GET /stores/{id} — 매장 상세 (재고마다 상태 · 출처 · 확인 시각)
pub async fn store_detail(
    State(s): State<AppState>,
    MaybeUser(user): MaybeUser,
    Path(id): Path<i64>,
    Query(q): Query<DetailQuery>,
) -> AppResult<Json<StoreDetailView>> {
    let ip_ids = services::store::resolve_ip_ids(&s.pool, id_list(q.ip_ids.as_deref())?, user).await?;
    let detail = services::store::detail(&s.pool, id, GeoPoint::from_query(q.lat, q.lng)?, &ip_ids, user).await?;
    Ok(Json(detail.into()))
}
