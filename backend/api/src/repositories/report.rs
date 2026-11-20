//! 재고 제보 · 매장 제보, 그리고 제보를 반영할 때의 재고 갱신 · 알림

use serde_json::Value;
use sqlx::{PgPool, Postgres, Transaction, types::Json};

use crate::models::offline::StockReport;

const REPORT_SELECT: &str = "
    SELECT r.id, r.store_id, s.name AS store_name, r.variant_id, v.name AS variant_name,
           p.id AS product_id, p.name AS product_name, r.user_id, r.status, r.photo_url, r.state, r.created_at
    FROM offline.stock_report r
    JOIN offline.store s ON s.id = r.store_id
    JOIN catalog.variant v ON v.id = r.variant_id
    JOIN catalog.product p ON p.id = v.product_id";

pub async fn insert_report(
    tx: &mut Transaction<'_, Postgres>,
    store_id: i64,
    variant_id: i64,
    user_id: i64,
    status: &str,
    photo_url: Option<&str>,
) -> sqlx::Result<i64> {
    sqlx::query_scalar(
        "INSERT INTO offline.stock_report (store_id, variant_id, user_id, status, photo_url)
         VALUES ($1, $2, $3, $4, $5) RETURNING id",
    )
    .bind(store_id)
    .bind(variant_id)
    .bind(user_id)
    .bind(status)
    .bind(photo_url)
    .fetch_one(&mut **tx)
    .await
}

/// 같은 매장 · 버전 · 상태로 들어온 다른 회원의 검토 대기 제보 (잠가서 함께 처리)
pub async fn pending_same_reports(
    tx: &mut Transaction<'_, Postgres>,
    store_id: i64,
    variant_id: i64,
    status: &str,
    except_user: i64,
) -> sqlx::Result<Vec<(i64, i64)>> {
    sqlx::query_as(
        "SELECT id, user_id FROM offline.stock_report
         WHERE store_id = $1 AND variant_id = $2 AND status = $3 AND state = 'pending' AND user_id <> $4
         ORDER BY id FOR UPDATE",
    )
    .bind(store_id)
    .bind(variant_id)
    .bind(status)
    .bind(except_user)
    .fetch_all(&mut **tx)
    .await
}

pub async fn store_has_owner(tx: &mut Transaction<'_, Postgres>, store_id: i64) -> sqlx::Result<bool> {
    sqlx::query_scalar("SELECT EXISTS (SELECT 1 FROM account.seller_member WHERE store_id = $1)").bind(store_id).fetch_one(&mut **tx).await
}

pub async fn store_name(tx: &mut Transaction<'_, Postgres>, store_id: i64) -> sqlx::Result<Option<String>> {
    sqlx::query_scalar("SELECT name FROM offline.store WHERE id = $1 AND NOT is_closed").bind(store_id).fetch_optional(&mut **tx).await
}

/// 제보 처리: 상태를 바꾸고 처리한 사람을 남긴다
pub async fn resolve_reports(tx: &mut Transaction<'_, Postgres>, ids: &[i64], state: &str, resolved_by: Option<i64>) -> sqlx::Result<()> {
    sqlx::query("UPDATE offline.stock_report SET state = $2, resolved_by = $3 WHERE id = ANY($1)")
        .bind(ids)
        .bind(state)
        .bind(resolved_by)
        .execute(&mut **tx)
        .await?;
    Ok(())
}

/// 재고 반영 (매장 · 버전마다 한 줄)
pub async fn upsert_stock(
    tx: &mut Transaction<'_, Postgres>,
    store_id: i64,
    variant_id: i64,
    status: &str,
    price: Option<i32>,
    source: &str,
) -> sqlx::Result<()> {
    sqlx::query(
        "INSERT INTO offline.stock (store_id, variant_id, status, price, source, confirmed_at)
         VALUES ($1, $2, $3, $4, $5, now())
         ON CONFLICT (store_id, variant_id) DO UPDATE
         SET status = EXCLUDED.status, price = COALESCE(EXCLUDED.price, offline.stock.price),
             source = EXCLUDED.source, confirmed_at = EXCLUDED.confirmed_at",
    )
    .bind(store_id)
    .bind(variant_id)
    .bind(status)
    .bind(price)
    .bind(source)
    .execute(&mut **tx)
    .await?;
    Ok(())
}

pub async fn insert_notification(
    tx: &mut Transaction<'_, Postgres>,
    user_id: i64,
    kind: &str,
    title: &str,
    body: &str,
    link: &str,
) -> sqlx::Result<()> {
    sqlx::query("INSERT INTO account.notification (user_id, type, title, body, link) VALUES ($1, $2, $3, $4, $5)")
        .bind(user_id)
        .bind(kind)
        .bind(title)
        .bind(body)
        .bind(link)
        .execute(&mut **tx)
        .await?;
    Ok(())
}

pub async fn report(pool: &PgPool, id: i64) -> sqlx::Result<Option<StockReport>> {
    sqlx::query_as(&format!("{REPORT_SELECT} WHERE r.id = $1")).bind(id).fetch_optional(pool).await
}

pub async fn reports_of_user(pool: &PgPool, user_id: i64) -> sqlx::Result<Vec<StockReport>> {
    sqlx::query_as(&format!("{REPORT_SELECT} WHERE r.user_id = $1 ORDER BY r.created_at DESC")).bind(user_id).fetch_all(pool).await
}

pub async fn reports_of_store(pool: &PgPool, store_id: i64, state: Option<&str>) -> sqlx::Result<Vec<StockReport>> {
    sqlx::query_as(&format!("{REPORT_SELECT} WHERE r.store_id = $1 AND ($2::text IS NULL OR r.state = $2) ORDER BY r.created_at DESC"))
        .bind(store_id)
        .bind(state)
        .fetch_all(pool)
        .await
}

/// 판매자가 처리할 제보 하나를 잠가서 가져온다 (그 매장의 검토 대기 제보만)
pub async fn lock_pending_report(tx: &mut Transaction<'_, Postgres>, store_id: i64, report_id: i64) -> sqlx::Result<Option<(i64, i64, String)>> {
    sqlx::query_as(
        "SELECT user_id, variant_id, status FROM offline.stock_report
         WHERE id = $1 AND store_id = $2 AND state = 'pending' FOR UPDATE",
    )
    .bind(report_id)
    .bind(store_id)
    .fetch_optional(&mut **tx)
    .await
}

pub async fn insert_store_suggestion(pool: &PgPool, user_id: i64, store_id: Option<i64>, kind: &str, content: Value) -> sqlx::Result<i64> {
    sqlx::query_scalar("INSERT INTO offline.store_suggestion (store_id, user_id, type, content) VALUES ($1, $2, $3, $4) RETURNING id")
        .bind(store_id)
        .bind(user_id)
        .bind(kind)
        .bind(Json(content))
        .fetch_one(pool)
        .await
}
