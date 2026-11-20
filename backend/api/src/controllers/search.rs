//! 검색 결과 · 품목으로 보기

use axum::{
    Json,
    extract::{Query, State},
};
use serde::Deserialize;

use super::catalog::parse_kind;
use crate::{
    AppState,
    error::{AppError, AppResult},
    services::{
        self,
        rules::{self, Channel, GeoPoint},
        search::{SearchParams, Sort},
    },
    views::search::SearchView,
};

#[derive(Deserialize)]
pub struct SearchQuery {
    q: Option<String>,
    #[serde(rename = "type")]
    kind: Option<String>,
    /// 배송비 포함 최저 총액 상한 (1만 원 이하 → 10000)
    max_price: Option<i32>,
    sort: Option<String>,
    channel: Option<String>,
    lat: Option<f64>,
    lng: Option<f64>,
    limit: Option<i64>,
    offset: Option<i64>,
}

/// GET /search?q=먼작귀 키링&type=keyring&max_price=10000&sort=lowest
pub async fn search(State(s): State<AppState>, Query(q): Query<SearchQuery>) -> AppResult<Json<SearchView>> {
    let text = q.q.unwrap_or_default();
    if text.chars().count() > 100 {
        return Err(AppError::bad("검색어는 100자까지입니다"));
    }
    if q.max_price.is_some_and(|p| p <= 0) {
        return Err(AppError::bad("max_price는 1 이상입니다"));
    }
    let (limit, offset) = rules::page(q.limit, q.offset);
    let params = SearchParams {
        text,
        kind: parse_kind(q.kind)?,
        max_price: q.max_price,
        sort: Sort::parse(q.sort.as_deref(), Sort::Lowest)?,
        channel: Channel::parse(q.channel.as_deref())?,
        point: GeoPoint::from_query(q.lat, q.lng)?,
        limit,
        offset,
    };
    Ok(Json(services::search::search(&s.pool, params).await?.into()))
}
