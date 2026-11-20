//! IP 목록 · IP 화면 · 캐릭터 화면 · 굿즈 탐색의 내 IP 타일

use axum::{
    Json,
    extract::{Path, Query, State},
};
use serde::Deserialize;

use super::id_list;
use crate::{
    AppState,
    error::{AppError, AppResult},
    services::{
        self,
        catalog::ListFilter,
        rules::{Channel, GeoPoint, PRODUCT_TYPES},
        search::Sort,
    },
    views::{
        List,
        catalog::{CharacterDetailView, IpDetailView, IpStatView, IpView},
    },
};

/// GET /ips — 회원가입 IP 고르기 · IP 목록 조정
pub async fn list_ips(State(s): State<AppState>) -> AppResult<Json<List<IpView>>> {
    let ips = services::catalog::ips(&s.pool).await?;
    Ok(Json(List::of(ips.into_iter().map(Into::into).collect())))
}

#[derive(Deserialize)]
pub struct StatsQuery {
    ids: Option<String>,
}

/// GET /ips/stats?ids=1,2 — 굿즈 탐색의 내 IP 타일 (캐릭터 수 · 굿즈 수)
pub async fn ip_stats(State(s): State<AppState>, Query(q): Query<StatsQuery>) -> AppResult<Json<List<IpStatView>>> {
    let ids = id_list(q.ids.as_deref())?.ok_or_else(|| AppError::bad("ids가 필요합니다"))?;
    let stats = services::catalog::ip_stats(&s.pool, &ids).await?;
    Ok(Json(List::of(stats.into_iter().map(Into::into).collect())))
}

#[derive(Deserialize)]
pub struct ListQuery {
    lat: Option<f64>,
    lng: Option<f64>,
    channel: Option<String>,
    #[serde(rename = "type")]
    kind: Option<String>,
    sort: Option<String>,
}

pub fn parse_kind(kind: Option<String>) -> AppResult<Option<String>> {
    match kind.as_deref() {
        None | Some("") => Ok(None),
        Some(k) if PRODUCT_TYPES.contains(&k) => Ok(Some(k.to_string())),
        Some(_) => Err(AppError::bad("type은 figure · doll · keyring · acrylic · plamodel · random 중 하나입니다")),
    }
}

/// GET /ips/{id} — IP 화면 (캐릭터, 인기순 상품, 품목 · 판매 경로 필터)
pub async fn ip_detail(State(s): State<AppState>, Path(id): Path<i64>, Query(q): Query<ListQuery>) -> AppResult<Json<IpDetailView>> {
    let point = GeoPoint::from_query(q.lat, q.lng)?;
    let filter = ListFilter {
        channel: Channel::parse(q.channel.as_deref())?,
        kind: parse_kind(q.kind)?,
        sort: Sort::parse(q.sort.as_deref(), Sort::Popular)?,
    };
    let detail = services::catalog::ip_detail(&s.pool, id, point, filter).await?;
    Ok(Json(detail.into()))
}

/// GET /characters/{id} — 캐릭터 화면 (품목별 묶음)
pub async fn character_detail(State(s): State<AppState>, Path(id): Path<i64>, Query(q): Query<ListQuery>) -> AppResult<Json<CharacterDetailView>> {
    let point = GeoPoint::from_query(q.lat, q.lng)?;
    let detail = services::catalog::character_detail(&s.pool, id, point, Channel::parse(q.channel.as_deref())?).await?;
    Ok(Json(detail.into()))
}
