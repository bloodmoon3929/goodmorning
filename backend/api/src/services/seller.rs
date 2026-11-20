//! 판매자 센터: 본인 매장만 수정, 재고 관리, 제보 확인, 새 굿즈 요청

use chrono::{DateTime, Utc};
use sqlx::PgPool;

use super::rules::{self, DEFAULT_POINT, STALE_HOURS};
use crate::{
    error::{AppError, AppResult},
    middleware::{AuthUser, Role},
    models::offline::{StockReport, Store, StoreItem},
    repositories,
};

pub async fn ensure_store_member(pool: &PgPool, user: AuthUser, store_id: i64) -> AppResult<()> {
    if user.role == Role::Admin || repositories::seller::is_store_member(pool, user.id, store_id).await? {
        Ok(())
    } else {
        Err(AppError::Forbidden("본인 매장만 관리할 수 있습니다"))
    }
}

pub async fn my_stores(pool: &PgPool, user: AuthUser) -> AppResult<Vec<Store>> {
    let ids = repositories::auth::seller_store_ids(pool, user.id).await?;
    let mut list = Vec::new();
    for id in ids {
        if let Some(s) = repositories::store::store(pool, id, &[], DEFAULT_POINT.lng, DEFAULT_POINT.lat, STALE_HOURS).await? {
            list.push(s);
        }
    }
    Ok(list)
}

pub struct SellerStore {
    pub store: Store,
    /// 저장된 상태 그대로 (사장님이 고칠 값)
    pub items: Vec<StoreItem>,
    pub total_items: i64,
    pub last_confirmed_at: Option<DateTime<Utc>>,
    pub pending_reports: i64,
}

pub async fn store(pool: &PgPool, store_id: i64) -> AppResult<SellerStore> {
    let store = repositories::store::store(pool, store_id, &[], DEFAULT_POINT.lng, DEFAULT_POINT.lat, STALE_HOURS)
        .await?
        .ok_or(AppError::NotFound("매장"))?;
    let items = repositories::store::items(pool, store_id).await?;
    let (total_items, last_confirmed_at, pending_reports) = repositories::seller::stock_overview(pool, store_id).await?;
    Ok(SellerStore { store, items, total_items, last_confirmed_at, pending_reports })
}

pub struct StockChange {
    pub variant_id: i64,
    pub status: String,
    pub price: Option<i32>,
}

/// 재고 상태를 한 번에 저장. 처음 보는 버전이면 취급 상품으로 추가된다.
pub async fn save_stock(pool: &PgPool, store_id: i64, changes: &[StockChange]) -> AppResult<usize> {
    if changes.is_empty() || changes.len() > 500 {
        return Err(AppError::bad("바꿀 재고는 1~500개입니다"));
    }
    if let Some(c) = changes.iter().find(|c| !rules::is_stock_status(&c.status)) {
        return Err(AppError::bad(format!("variant {}: status는 many · few · none 중 하나입니다", c.variant_id)));
    }
    if changes.iter().any(|c| c.price.is_some_and(|p| p < 0)) {
        return Err(AppError::bad("가격이 올바르지 않습니다"));
    }
    let mut ids: Vec<i64> = changes.iter().map(|c| c.variant_id).collect();
    ids.sort_unstable();
    ids.dedup();
    if ids.len() != changes.len() {
        return Err(AppError::bad("같은 버전이 두 번 들어 있습니다"));
    }
    if repositories::seller::existing_variant_ids(pool, &ids).await?.len() != ids.len() {
        return Err(AppError::NotFound("버전"));
    }
    let mut tx = pool.begin().await?;
    for c in changes {
        repositories::report::upsert_stock(&mut tx, store_id, c.variant_id, &c.status, c.price, "owner").await?;
    }
    tx.commit().await?;
    Ok(changes.len())
}

/// [오늘 재고 그대로예요]
pub async fn confirm_all(pool: &PgPool, store_id: i64) -> AppResult<u64> {
    let mut tx = pool.begin().await?;
    let n = repositories::seller::confirm_all(&mut tx, store_id).await?;
    tx.commit().await?;
    Ok(n)
}

pub async fn reports(pool: &PgPool, store_id: i64, state: Option<&str>) -> AppResult<Vec<StockReport>> {
    if state.is_some_and(|s| !matches!(s, "pending" | "approved" | "rejected")) {
        return Err(AppError::bad("state는 pending · approved · rejected 중 하나입니다"));
    }
    Ok(repositories::report::reports_of_store(pool, store_id, state).await?)
}

/// 제보 승인(재고 반영) 또는 반려. 결과는 제보자에게 알린다.
pub async fn resolve_report(pool: &PgPool, user: AuthUser, store_id: i64, report_id: i64, approve: bool) -> AppResult<StockReport> {
    let mut tx = pool.begin().await?;
    let (reporter, variant_id, status) =
        repositories::report::lock_pending_report(&mut tx, store_id, report_id).await?.ok_or(AppError::NotFound("검토 대기 제보"))?;
    let store_name = repositories::report::store_name(&mut tx, store_id).await?.unwrap_or_default();
    let link = format!("/stores/{store_id}");
    if approve {
        repositories::report::upsert_stock(&mut tx, store_id, variant_id, &status, None, "report").await?;
        repositories::report::resolve_reports(&mut tx, &[report_id], "approved", Some(user.id)).await?;
        let body = format!("{store_name} · {}", rules::status_label(&status));
        repositories::report::insert_notification(&mut tx, reporter, "report", "재고 제보가 반영됐어요", &body, &link).await?;
    } else {
        repositories::report::resolve_reports(&mut tx, &[report_id], "rejected", Some(user.id)).await?;
        let body = format!("{store_name} · 사장님이 확인한 재고와 달라 반영하지 않았어요");
        repositories::report::insert_notification(&mut tx, reporter, "report", "재고 제보를 확인했어요", &body, &link).await?;
    }
    tx.commit().await?;
    repositories::report::report(pool, report_id).await?.ok_or(AppError::NotFound("제보"))
}

/// 상품 등록에서 후보에 없을 때: 새 굿즈 요청 (관리자 검토 후 카탈로그에 추가)
pub async fn request_product(pool: &PgPool, user: AuthUser, store_id: i64, name: &str, image_url: Option<&str>) -> AppResult<i64> {
    let name = name.trim();
    if name.is_empty() || name.chars().count() > 100 {
        return Err(AppError::bad("굿즈 이름은 1~100자입니다"));
    }
    Ok(repositories::seller::insert_product_request(pool, user.id, store_id, name, image_url).await?)
}
