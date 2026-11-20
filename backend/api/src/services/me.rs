//! 마이: 내 IP, 찜, 저장한 매장, 알림, 이동 기록, 구매, 문의

use std::collections::HashMap;

use chrono::NaiveDate;
use serde_json::Value;
use sqlx::PgPool;

use super::{
    auth::dedup,
    product,
    rules::{GeoPoint, STALE_HOURS},
};
use crate::{
    error::{AppError, AppResult},
    middleware::AuthUser,
    models::{
        account::{Alert, Issue, Notification, Purchase, Visit, Wish},
        catalog::ProductSummary,
        offline::Store,
    },
    repositories::{
        self,
        me::{NewIssue, NewPurchase},
    },
};

// ------------------------------------------------------------ 내 IP
pub async fn set_my_ips(pool: &PgPool, user: AuthUser, ip_ids: &[i64]) -> AppResult<Vec<i64>> {
    let ids = dedup(ip_ids);
    if repositories::catalog::existing_ip_ids(pool, &ids).await?.len() != ids.len() {
        return Err(AppError::bad("없는 IP가 들어 있습니다"));
    }
    let mut tx = pool.begin().await?;
    repositories::auth::replace_user_ips(&mut tx, user.id, &ids).await?;
    tx.commit().await?;
    Ok(ids)
}

pub async fn request_ip(pool: &PgPool, user: AuthUser, name: &str) -> AppResult<i64> {
    let name = name.trim();
    if name.is_empty() || name.chars().count() > 50 {
        return Err(AppError::bad("IP 이름은 1~50자입니다"));
    }
    Ok(repositories::me::insert_ip_request(pool, user.id, name).await?)
}

// ------------------------------------------------------------ 찜
pub async fn wishlist(pool: &PgPool, user: AuthUser, point: GeoPoint) -> AppResult<Vec<(Wish, ProductSummary)>> {
    let wishes = repositories::me::wishes(pool, user.id).await?;
    let ids = dedup(&wishes.iter().map(|w| w.product_id).collect::<Vec<_>>());
    let by_id: HashMap<i64, ProductSummary> = product::summaries(pool, &ids, point).await?.into_iter().map(|s| (s.id, s)).collect();
    Ok(wishes.into_iter().filter_map(|w| by_id.get(&w.product_id).cloned().map(|s| (w, s))).collect())
}

pub async fn set_wish(pool: &PgPool, user: AuthUser, variant_id: i64, on: bool) -> AppResult<()> {
    if on {
        if !repositories::product::variant_exists(pool, variant_id).await? {
            return Err(AppError::NotFound("버전"));
        }
        repositories::me::add_wish(pool, user.id, variant_id).await?;
    } else {
        repositories::me::remove_wish(pool, user.id, variant_id).await?;
    }
    Ok(())
}

// ------------------------------------------------------------ 저장한 매장
pub async fn saved_stores(pool: &PgPool, user: AuthUser, point: GeoPoint) -> AppResult<Vec<Store>> {
    let saved = repositories::me::saved_stores(pool, user.id).await?;
    let ip_ids = repositories::auth::user_ip_ids(pool, user.id).await?;
    let mut by_id: HashMap<i64, Store> =
        repositories::store::stores(pool, &ip_ids, point.lng, point.lat, STALE_HOURS, None).await?.into_iter().map(|s| (s.id, s)).collect();
    Ok(saved.iter().filter_map(|s| by_id.remove(&s.store_id)).collect())
}

pub async fn set_saved_store(pool: &PgPool, user: AuthUser, store_id: i64, on: bool) -> AppResult<()> {
    if on {
        if !repositories::store::exists(pool, store_id).await? {
            return Err(AppError::NotFound("매장"));
        }
        repositories::me::save_store(pool, user.id, store_id).await?;
    } else {
        repositories::me::unsave_store(pool, user.id, store_id).await?;
    }
    Ok(())
}

// ------------------------------------------------------------ 알림 조건 · 받은 알림
pub struct NewAlert {
    pub variant_id: Option<i64>,
    pub store_id: Option<i64>,
    pub kind: String,
    pub target_price: Option<i32>,
}

/// 목표가 이하(price) · 재입고(restock) · 매장 입고(stock_in) 중 하나
pub async fn create_alert(pool: &PgPool, user: AuthUser, a: NewAlert) -> AppResult<Alert> {
    match a.kind.as_str() {
        "price" if a.variant_id.is_none() || !a.target_price.is_some_and(|p| p > 0) => {
            return Err(AppError::bad("목표가 알림에는 variant_id와 target_price(1원 이상)가 필요합니다"));
        }
        "restock" if a.variant_id.is_none() => return Err(AppError::bad("재입고 알림에는 variant_id가 필요합니다")),
        "stock_in" if a.store_id.is_none() => return Err(AppError::bad("매장 입고 알림에는 store_id가 필요합니다")),
        "price" | "restock" | "stock_in" => {}
        _ => return Err(AppError::bad("type은 price · restock · stock_in 중 하나입니다")),
    }
    let target = if a.kind == "price" { a.target_price } else { None };
    let id = repositories::me::insert_alert(pool, user.id, a.variant_id, a.store_id, &a.kind, target).await?;
    repositories::me::alert(pool, user.id, id).await?.ok_or(AppError::NotFound("알림"))
}

pub async fn alerts(pool: &PgPool, user: AuthUser) -> AppResult<Vec<Alert>> {
    Ok(repositories::me::alerts(pool, user.id).await?)
}

pub async fn delete_alert(pool: &PgPool, user: AuthUser, id: i64) -> AppResult<()> {
    match repositories::me::delete_alert(pool, user.id, id).await? {
        0 => Err(AppError::NotFound("알림")),
        _ => Ok(()),
    }
}

pub async fn notifications(pool: &PgPool, user: AuthUser) -> AppResult<Vec<Notification>> {
    Ok(repositories::me::notifications(pool, user.id, 100).await?)
}

/// id가 없으면 모두 읽음
pub async fn mark_read(pool: &PgPool, user: AuthUser, id: Option<i64>) -> AppResult<u64> {
    Ok(repositories::me::mark_read(pool, user.id, id).await?)
}

// ------------------------------------------------------------ 이동 기록 · 구매
pub async fn visits(pool: &PgPool, user: AuthUser) -> AppResult<Vec<Visit>> {
    Ok(repositories::me::visits(pool, user.id, 100).await?)
}

pub struct PurchaseInput {
    pub click_id: Option<i64>,
    pub variant_id: Option<i64>,
    pub store_id: Option<i64>,
    pub price: Option<i32>,
    pub purchased_on: Option<NaiveDate>,
}

/// 이동 기록에서 [구매했어요] (click_id) 또는 오프라인 구매 직접 입력 (variant_id + store_id)
pub async fn create_purchase(pool: &PgPool, user: AuthUser, p: PurchaseInput) -> AppResult<Purchase> {
    if p.price.is_some_and(|v| v < 0) {
        return Err(AppError::bad("가격이 올바르지 않습니다"));
    }
    let new = match (p.click_id, p.variant_id, p.store_id) {
        (Some(click_id), None, None) => {
            let visit = repositories::me::visit(pool, user.id, click_id).await?.ok_or(AppError::NotFound("이동 기록"))?;
            if visit.purchase_id.is_some() {
                return Err(AppError::Conflict("이미 구매로 등록한 이동 기록입니다".into()));
            }
            NewPurchase {
                variant_id: visit.variant_id,
                click_id: Some(click_id),
                store_id: None,
                price: p.price.or(Some(visit.price_snapshot + visit.shipping_snapshot.unwrap_or(0))),
                purchased_on: p.purchased_on.or(Some(visit.clicked_at.with_timezone(&super::rules::kst()).date_naive())),
            }
        }
        (None, Some(variant_id), Some(store_id)) => {
            NewPurchase { variant_id, click_id: None, store_id: Some(store_id), price: p.price, purchased_on: p.purchased_on }
        }
        _ => return Err(AppError::bad("click_id 하나, 또는 variant_id와 store_id를 함께 보내야 합니다")),
    };
    let id = repositories::me::insert_purchase(pool, user.id, new).await?;
    repositories::me::purchase(pool, user.id, id).await?.ok_or(AppError::NotFound("구매 기록"))
}

pub async fn purchases(pool: &PgPool, user: AuthUser) -> AppResult<Vec<Purchase>> {
    Ok(repositories::me::purchases(pool, user.id).await?)
}

// ------------------------------------------------------------ 문의
pub struct IssueInput {
    pub click_id: Option<i64>,
    pub purchase_id: Option<i64>,
    pub kind: String,
    pub content: String,
    pub attachments: Option<Value>,
}

/// 가격이 달랐어요(price) · 재고가 없었어요(stock) · 가품 의심(fake) · 기타(etc).
/// 운영자가 비교할 수 있게 문의 시점의 현재 가격을 함께 저장한다.
pub async fn create_issue(pool: &PgPool, user: AuthUser, i: IssueInput) -> AppResult<Issue> {
    if !matches!(i.kind.as_str(), "price" | "stock" | "fake" | "etc") {
        return Err(AppError::bad("type은 price · stock · fake · etc 중 하나입니다"));
    }
    let content = i.content.trim();
    if content.is_empty() || content.chars().count() > 2000 {
        return Err(AppError::bad("내용은 1~2000자입니다"));
    }
    let mut click_id = i.click_id;
    if let Some(cid) = click_id {
        repositories::me::visit(pool, user.id, cid).await?.ok_or(AppError::NotFound("이동 기록"))?;
    }
    if let Some(pid) = i.purchase_id {
        let purchase = repositories::me::purchase(pool, user.id, pid).await?.ok_or(AppError::NotFound("구매 기록"))?;
        click_id = click_id.or(purchase.click_id);
    }
    if click_id.is_none() && i.purchase_id.is_none() {
        return Err(AppError::bad("click_id 또는 purchase_id가 필요합니다"));
    }
    let price_now = match click_id {
        Some(cid) => repositories::me::current_total_of_click(pool, cid).await?,
        None => None,
    };
    let id = repositories::me::insert_issue(
        pool,
        user.id,
        NewIssue { click_id: i.click_id, purchase_id: i.purchase_id, kind: &i.kind, content, attachments: i.attachments, price_now },
    )
    .await?;
    repositories::me::issue(pool, user.id, id).await?.ok_or(AppError::NotFound("문의"))
}

pub async fn issues(pool: &PgPool, user: AuthUser) -> AppResult<Vec<Issue>> {
    Ok(repositories::me::issues(pool, user.id).await?)
}
