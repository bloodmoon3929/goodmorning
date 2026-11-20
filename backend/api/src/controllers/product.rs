//! 홈 신상품 · 상품 카드 묶음 · 상품 상세

use axum::{
    Json,
    extract::{Path, Query, State},
};
use serde::Deserialize;

use super::{LocationQuery, id_list};
use crate::{
    AppState,
    error::{AppError, AppResult},
    middleware::MaybeUser,
    services::{
        self,
        rules::{Channel, GeoPoint},
    },
    views::{
        List,
        product::{ProductCard, ProductDetailView},
    },
};

#[derive(Deserialize)]
pub struct NewQuery {
    ip_ids: Option<String>,
    lat: Option<f64>,
    lng: Option<f64>,
    channel: Option<String>,
    limit: Option<usize>,
}

/// GET /products/new — 홈의 내 IP 신상품 (ip_ids가 없으면 로그인한 회원의 내 IP, 둘 다 없으면 전체)
pub async fn new_products(State(s): State<AppState>, MaybeUser(user): MaybeUser, Query(q): Query<NewQuery>) -> AppResult<Json<List<ProductCard>>> {
    let point = GeoPoint::from_query(q.lat, q.lng)?;
    let ip_ids = services::store::resolve_ip_ids(&s.pool, id_list(q.ip_ids.as_deref())?, user).await?;
    let limit = q.limit.unwrap_or(8).clamp(1, 50);
    let list = services::product::new_products(&s.pool, &ip_ids, point, Channel::parse(q.channel.as_deref())?, limit).await?;
    Ok(Json(List::of(list.into_iter().map(Into::into).collect())))
}

#[derive(Deserialize)]
pub struct IdsQuery {
    ids: Option<String>,
    lat: Option<f64>,
    lng: Option<f64>,
}

/// GET /products?ids=1,2 — 찜 · 최근 본 상품처럼 번호로 카드 묶음
pub async fn products(State(s): State<AppState>, Query(q): Query<IdsQuery>) -> AppResult<Json<List<ProductCard>>> {
    let ids = id_list(q.ids.as_deref())?.ok_or_else(|| AppError::bad("ids가 필요합니다"))?;
    let list = services::product::summaries(&s.pool, &ids, GeoPoint::from_query(q.lat, q.lng)?).await?;
    Ok(Json(List::of(list.into_iter().map(Into::into).collect())))
}

/// GET /products/{id} — 상품 상세 (온라인 가격 · 오프라인 매장 · 비슷한 상품)
pub async fn product_detail(
    State(s): State<AppState>,
    MaybeUser(user): MaybeUser,
    Path(id): Path<i64>,
    Query(loc): Query<LocationQuery>,
) -> AppResult<Json<ProductDetailView>> {
    let detail = services::product::detail(&s.pool, id, loc.point()?, user).await?;
    Ok(Json(detail.into()))
}
