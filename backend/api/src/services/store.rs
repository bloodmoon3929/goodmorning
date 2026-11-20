//! 매장 찾기 · 매장 상세

use chrono::Utc;
use sqlx::PgPool;

use super::rules::{self, GeoPoint, STALE_HOURS};
use crate::{
    error::{AppError, AppResult},
    middleware::AuthUser,
    models::offline::{Store, StoreItem},
    repositories,
};

/// 지도 마커 · 목록 배지 색: 내 IP 굿즈 재고 기준
pub fn marker_status(s: &Store) -> &'static str {
    if s.my_ip_total == 0 || s.my_ip_unknown == s.my_ip_total {
        "unknown"
    } else if s.my_ip_in_stock >= 2 {
        "many"
    } else if s.my_ip_in_stock == 1 {
        "few"
    } else {
        "none"
    }
}

/// 내 IP: 앱이 보낸 값 → 로그인했으면 회원의 내 IP → 없으면 전체
pub async fn resolve_ip_ids(pool: &PgPool, given: Option<Vec<i64>>, user: Option<AuthUser>) -> AppResult<Vec<i64>> {
    match (given, user) {
        (Some(ids), _) => Ok(ids),
        (None, Some(u)) => Ok(repositories::auth::user_ip_ids(pool, u.id).await?),
        (None, None) => Ok(vec![]),
    }
}

pub struct StoreQuery {
    pub point: GeoPoint,
    pub ip_ids: Vec<i64>,
    pub radius_km: Option<f64>,
    pub in_stock_only: bool,
    pub limit: Option<usize>,
}

/// 거리순. 리스트 뷰와 지도 뷰는 같은 결과를 쓴다.
pub async fn stores(pool: &PgPool, q: StoreQuery) -> AppResult<Vec<Store>> {
    if q.radius_km.is_some_and(|r| !(0.0..=100.0).contains(&r)) {
        return Err(AppError::bad("radius_km는 0~100 사이입니다"));
    }
    let list = repositories::store::stores(pool, &q.ip_ids, q.point.lng, q.point.lat, STALE_HOURS, q.radius_km.map(|r| r * 1000.0)).await?;
    Ok(list.into_iter().filter(|s| !q.in_stock_only || s.my_ip_in_stock > 0).take(q.limit.unwrap_or(usize::MAX)).collect())
}

pub struct StoreDetail {
    pub store: Store,
    /// status는 48시간 규칙을 적용한 값
    pub items: Vec<StoreItem>,
    pub saved: bool,
}

pub async fn detail(pool: &PgPool, id: i64, point: GeoPoint, ip_ids: &[i64], user: Option<AuthUser>) -> AppResult<StoreDetail> {
    let store = repositories::store::store(pool, id, ip_ids, point.lng, point.lat, STALE_HOURS).await?.ok_or(AppError::NotFound("매장"))?;
    let now = Utc::now();
    let mut items = repositories::store::items(pool, id).await?;
    for it in &mut items {
        it.status = rules::effective_status(&it.status, it.confirmed_at, now).to_string();
    }
    let saved = match user {
        Some(u) => repositories::store::is_saved(pool, u.id, id).await?,
        None => false,
    };
    Ok(StoreDetail { store, items, saved })
}
