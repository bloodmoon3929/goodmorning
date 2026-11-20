//! 판매자 센터: 본인 매장 확인, 재고 관리, 새 굿즈 요청

use chrono::{DateTime, Utc};
use sqlx::{PgPool, Postgres, Transaction};

pub async fn is_store_member(pool: &PgPool, user_id: i64, store_id: i64) -> sqlx::Result<bool> {
    sqlx::query_scalar("SELECT EXISTS (SELECT 1 FROM account.seller_member WHERE user_id = $1 AND store_id = $2)")
        .bind(user_id)
        .bind(store_id)
        .fetch_one(pool)
        .await
}

/// 재고 요약: 전체 품목 수, 마지막 확인 시각, 검토 대기 제보 수
pub async fn stock_overview(pool: &PgPool, store_id: i64) -> sqlx::Result<(i64, Option<DateTime<Utc>>, i64)> {
    sqlx::query_as(
        "SELECT (SELECT count(*) FROM offline.stock WHERE store_id = $1),
                (SELECT max(confirmed_at) FROM offline.stock WHERE store_id = $1 AND source = 'owner'),
                (SELECT count(*) FROM offline.stock_report WHERE store_id = $1 AND state = 'pending')",
    )
    .bind(store_id)
    .fetch_one(pool)
    .await
}

/// [오늘 재고 그대로예요]: 상태는 그대로 두고 확인 시각만 지금으로. 확인한 사람은 사장님.
pub async fn confirm_all(tx: &mut Transaction<'_, Postgres>, store_id: i64) -> sqlx::Result<u64> {
    Ok(sqlx::query("UPDATE offline.stock SET confirmed_at = now(), source = 'owner' WHERE store_id = $1")
        .bind(store_id)
        .execute(&mut **tx)
        .await?
        .rows_affected())
}

pub async fn insert_product_request(pool: &PgPool, user_id: i64, store_id: i64, name: &str, image_url: Option<&str>) -> sqlx::Result<i64> {
    sqlx::query_scalar("INSERT INTO ingest.product_request (requested_by, store_id, name, image_url) VALUES ($1, $2, $3, $4) RETURNING id")
        .bind(user_id)
        .bind(store_id)
        .bind(name)
        .bind(image_url)
        .fetch_one(pool)
        .await
}

pub async fn existing_variant_ids(pool: &PgPool, ids: &[i64]) -> sqlx::Result<Vec<i64>> {
    sqlx::query_scalar("SELECT id FROM catalog.variant WHERE id = ANY($1)").bind(ids).fetch_all(pool).await
}
