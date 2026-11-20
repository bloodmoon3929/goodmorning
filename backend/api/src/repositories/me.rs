//! 마이: 찜, 저장한 매장, 알림 조건, 받은 알림, 이동 기록, 구매 기록, 문의, IP 추가 요청

use chrono::NaiveDate;
use serde_json::Value;
use sqlx::{PgPool, types::Json};

use crate::models::account::{Alert, Issue, Notification, Purchase, SavedStore, Visit, Wish};

// ------------------------------------------------------------ 찜
pub async fn wishes(pool: &PgPool, user_id: i64) -> sqlx::Result<Vec<Wish>> {
    sqlx::query_as(
        "SELECT v.product_id, w.variant_id, v.name AS variant_name, w.created_at
         FROM account.wishlist w JOIN catalog.variant v ON v.id = w.variant_id
         WHERE w.user_id = $1 ORDER BY w.created_at DESC",
    )
    .bind(user_id)
    .fetch_all(pool)
    .await
}

pub async fn add_wish(pool: &PgPool, user_id: i64, variant_id: i64) -> sqlx::Result<()> {
    sqlx::query("INSERT INTO account.wishlist (user_id, variant_id) VALUES ($1, $2) ON CONFLICT DO NOTHING")
        .bind(user_id)
        .bind(variant_id)
        .execute(pool)
        .await?;
    Ok(())
}

pub async fn remove_wish(pool: &PgPool, user_id: i64, variant_id: i64) -> sqlx::Result<()> {
    sqlx::query("DELETE FROM account.wishlist WHERE user_id = $1 AND variant_id = $2").bind(user_id).bind(variant_id).execute(pool).await?;
    Ok(())
}

// ------------------------------------------------------------ 저장한 매장
pub async fn saved_stores(pool: &PgPool, user_id: i64) -> sqlx::Result<Vec<SavedStore>> {
    sqlx::query_as("SELECT store_id, created_at FROM account.saved_store WHERE user_id = $1 ORDER BY created_at DESC")
        .bind(user_id)
        .fetch_all(pool)
        .await
}

pub async fn save_store(pool: &PgPool, user_id: i64, store_id: i64) -> sqlx::Result<()> {
    sqlx::query("INSERT INTO account.saved_store (user_id, store_id) VALUES ($1, $2) ON CONFLICT DO NOTHING")
        .bind(user_id)
        .bind(store_id)
        .execute(pool)
        .await?;
    Ok(())
}

pub async fn unsave_store(pool: &PgPool, user_id: i64, store_id: i64) -> sqlx::Result<()> {
    sqlx::query("DELETE FROM account.saved_store WHERE user_id = $1 AND store_id = $2").bind(user_id).bind(store_id).execute(pool).await?;
    Ok(())
}

// ------------------------------------------------------------ 알림 조건
const ALERT_SELECT: &str = "
    SELECT a.id, a.variant_id, v.name AS variant_name, p.id AS product_id, p.name AS product_name,
           a.store_id, s.name AS store_name, a.type, a.target_price, a.is_active
    FROM account.alert a
    LEFT JOIN catalog.variant v ON v.id = a.variant_id
    LEFT JOIN catalog.product p ON p.id = v.product_id
    LEFT JOIN offline.store s ON s.id = a.store_id";

pub async fn alerts(pool: &PgPool, user_id: i64) -> sqlx::Result<Vec<Alert>> {
    sqlx::query_as(&format!("{ALERT_SELECT} WHERE a.user_id = $1 ORDER BY a.id DESC")).bind(user_id).fetch_all(pool).await
}

pub async fn insert_alert(
    pool: &PgPool,
    user_id: i64,
    variant_id: Option<i64>,
    store_id: Option<i64>,
    kind: &str,
    target_price: Option<i32>,
) -> sqlx::Result<i64> {
    sqlx::query_scalar("INSERT INTO account.alert (user_id, variant_id, store_id, type, target_price) VALUES ($1, $2, $3, $4, $5) RETURNING id")
        .bind(user_id)
        .bind(variant_id)
        .bind(store_id)
        .bind(kind)
        .bind(target_price)
        .fetch_one(pool)
        .await
}

pub async fn alert(pool: &PgPool, user_id: i64, id: i64) -> sqlx::Result<Option<Alert>> {
    sqlx::query_as(&format!("{ALERT_SELECT} WHERE a.user_id = $1 AND a.id = $2")).bind(user_id).bind(id).fetch_optional(pool).await
}

pub async fn delete_alert(pool: &PgPool, user_id: i64, id: i64) -> sqlx::Result<u64> {
    Ok(sqlx::query("DELETE FROM account.alert WHERE user_id = $1 AND id = $2").bind(user_id).bind(id).execute(pool).await?.rows_affected())
}

// ------------------------------------------------------------ 받은 알림
pub async fn notifications(pool: &PgPool, user_id: i64, limit: i64) -> sqlx::Result<Vec<Notification>> {
    sqlx::query_as(
        "SELECT id, type, title, body, link, image_url, read_at, created_at
         FROM account.notification WHERE user_id = $1 ORDER BY created_at DESC LIMIT $2",
    )
    .bind(user_id)
    .bind(limit)
    .fetch_all(pool)
    .await
}

pub async fn mark_read(pool: &PgPool, user_id: i64, id: Option<i64>) -> sqlx::Result<u64> {
    Ok(sqlx::query(
        "UPDATE account.notification SET read_at = now()
         WHERE user_id = $1 AND read_at IS NULL AND ($2::bigint IS NULL OR id = $2)",
    )
    .bind(user_id)
    .bind(id)
    .execute(pool)
    .await?
    .rows_affected())
}

// ------------------------------------------------------------ 이동 기록
const VISIT_SELECT: &str = "
    SELECT c.id, c.clicked_at, c.offer_id, m.name AS mall_name, p.id AS product_id, p.name AS product_name,
           c.variant_id, v.name AS variant_name, c.price_snapshot, c.shipping_snapshot,
           (SELECT pu.id FROM account.purchase pu WHERE pu.click_id = c.id) AS purchase_id
    FROM account.outbound_click c
    JOIN online.offer o ON o.id = c.offer_id
    JOIN online.mall m ON m.id = o.mall_id
    JOIN catalog.variant v ON v.id = c.variant_id
    JOIN catalog.product p ON p.id = v.product_id";

pub async fn visits(pool: &PgPool, user_id: i64, limit: i64) -> sqlx::Result<Vec<Visit>> {
    sqlx::query_as(&format!("{VISIT_SELECT} WHERE c.user_id = $1 ORDER BY c.clicked_at DESC LIMIT $2"))
        .bind(user_id)
        .bind(limit)
        .fetch_all(pool)
        .await
}

pub async fn visit(pool: &PgPool, user_id: i64, click_id: i64) -> sqlx::Result<Option<Visit>> {
    sqlx::query_as(&format!("{VISIT_SELECT} WHERE c.user_id = $1 AND c.id = $2")).bind(user_id).bind(click_id).fetch_optional(pool).await
}

// ------------------------------------------------------------ 구매 기록
const PURCHASE_SELECT: &str = "
    SELECT pu.id, p.id AS product_id, p.name AS product_name, pu.variant_id, v.name AS variant_name,
           pu.click_id, m.name AS mall_name, pu.store_id, s.name AS store_name, pu.price, pu.purchased_on, pu.created_at
    FROM account.purchase pu
    JOIN catalog.variant v ON v.id = pu.variant_id
    JOIN catalog.product p ON p.id = v.product_id
    LEFT JOIN account.outbound_click c ON c.id = pu.click_id
    LEFT JOIN online.offer o ON o.id = c.offer_id
    LEFT JOIN online.mall m ON m.id = o.mall_id
    LEFT JOIN offline.store s ON s.id = pu.store_id";

pub async fn purchases(pool: &PgPool, user_id: i64) -> sqlx::Result<Vec<Purchase>> {
    sqlx::query_as(&format!("{PURCHASE_SELECT} WHERE pu.user_id = $1 ORDER BY COALESCE(pu.purchased_on, pu.created_at::date) DESC, pu.id DESC"))
        .bind(user_id)
        .fetch_all(pool)
        .await
}

pub async fn purchase(pool: &PgPool, user_id: i64, id: i64) -> sqlx::Result<Option<Purchase>> {
    sqlx::query_as(&format!("{PURCHASE_SELECT} WHERE pu.user_id = $1 AND pu.id = $2")).bind(user_id).bind(id).fetch_optional(pool).await
}

pub struct NewPurchase {
    pub variant_id: i64,
    pub click_id: Option<i64>,
    pub store_id: Option<i64>,
    pub price: Option<i32>,
    pub purchased_on: Option<NaiveDate>,
}

pub async fn insert_purchase(pool: &PgPool, user_id: i64, p: NewPurchase) -> sqlx::Result<i64> {
    sqlx::query_scalar(
        "INSERT INTO account.purchase (user_id, variant_id, click_id, store_id, price, purchased_on)
         VALUES ($1, $2, $3, $4, $5, $6) RETURNING id",
    )
    .bind(user_id)
    .bind(p.variant_id)
    .bind(p.click_id)
    .bind(p.store_id)
    .bind(p.price)
    .bind(p.purchased_on)
    .fetch_one(pool)
    .await
}

// ------------------------------------------------------------ 문의
const ISSUE_SELECT: &str = "
    SELECT i.id, i.click_id, i.purchase_id, i.type, i.content, i.price_now,
           c.price_snapshot, c.shipping_snapshot, m.name AS mall_name, p.name AS product_name,
           i.state, i.answer, i.created_at
    FROM account.issue i
    LEFT JOIN account.purchase pu ON pu.id = i.purchase_id
    LEFT JOIN account.outbound_click c ON c.id = COALESCE(i.click_id, pu.click_id)
    LEFT JOIN online.offer o ON o.id = c.offer_id
    LEFT JOIN online.mall m ON m.id = o.mall_id
    LEFT JOIN catalog.variant v ON v.id = COALESCE(c.variant_id, pu.variant_id)
    LEFT JOIN catalog.product p ON p.id = v.product_id";

pub async fn issues(pool: &PgPool, user_id: i64) -> sqlx::Result<Vec<Issue>> {
    sqlx::query_as(&format!("{ISSUE_SELECT} WHERE i.user_id = $1 ORDER BY i.created_at DESC")).bind(user_id).fetch_all(pool).await
}

pub async fn issue(pool: &PgPool, user_id: i64, id: i64) -> sqlx::Result<Option<Issue>> {
    sqlx::query_as(&format!("{ISSUE_SELECT} WHERE i.user_id = $1 AND i.id = $2")).bind(user_id).bind(id).fetch_optional(pool).await
}

/// 문의 시점의 현재 가격 (이동 기록의 몰 판매, 배송비 포함)
pub async fn current_total_of_click(pool: &PgPool, click_id: i64) -> sqlx::Result<Option<i32>> {
    sqlx::query_scalar(
        "SELECT COALESCE(o.total_price, o.price) FROM account.outbound_click c JOIN online.offer o ON o.id = c.offer_id WHERE c.id = $1",
    )
    .bind(click_id)
    .fetch_optional(pool)
    .await
}

pub struct NewIssue<'a> {
    pub click_id: Option<i64>,
    pub purchase_id: Option<i64>,
    pub kind: &'a str,
    pub content: &'a str,
    pub attachments: Option<Value>,
    pub price_now: Option<i32>,
}

pub async fn insert_issue(pool: &PgPool, user_id: i64, i: NewIssue<'_>) -> sqlx::Result<i64> {
    sqlx::query_scalar(
        "INSERT INTO account.issue (user_id, click_id, purchase_id, type, content, attachments, price_now)
         VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id",
    )
    .bind(user_id)
    .bind(i.click_id)
    .bind(i.purchase_id)
    .bind(i.kind)
    .bind(i.content)
    .bind(i.attachments.map(Json))
    .bind(i.price_now)
    .fetch_one(pool)
    .await
}

// ------------------------------------------------------------ IP 추가 요청
pub async fn insert_ip_request(pool: &PgPool, user_id: i64, name: &str) -> sqlx::Result<i64> {
    sqlx::query_scalar("INSERT INTO account.ip_request (user_id, name) VALUES ($1, $2) RETURNING id").bind(user_id).bind(name).fetch_one(pool).await
}
