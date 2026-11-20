//! 운영: 수집 원본 검토(매칭 확정 · 제외), 수집 실행 기록

use sqlx::{PgPool, Postgres, Transaction};

use crate::models::ingest::{CollectJob, RawListing};

const RAW_SELECT: &str = "
    SELECT r.id, r.mall_id, m.name AS mall_name, r.source, r.source_url, r.title, r.price, r.shipping_fee, r.image_url,
           r.payload, r.match_state, r.matched_variant_id, r.match_score, r.collected_at
    FROM ingest.raw_listing r LEFT JOIN online.mall m ON m.id = r.mall_id";

pub async fn ping(pool: &PgPool) -> sqlx::Result<()> {
    sqlx::query("SELECT 1").execute(pool).await?;
    Ok(())
}

pub async fn raw_listings(pool: &PgPool, state: &str, limit: i64) -> sqlx::Result<Vec<RawListing>> {
    sqlx::query_as(&format!("{RAW_SELECT} WHERE r.match_state = $1 ORDER BY r.collected_at DESC, r.id DESC LIMIT $2"))
        .bind(state)
        .bind(limit)
        .fetch_all(pool)
        .await
}

pub async fn lock_raw_listing(tx: &mut Transaction<'_, Postgres>, id: i64) -> sqlx::Result<Option<RawListing>> {
    sqlx::query_as(&format!("{RAW_SELECT} WHERE r.id = $1 FOR UPDATE OF r")).bind(id).fetch_optional(&mut **tx).await
}

/// 매칭된 수집 결과를 online.offer에 반영하고 가격 기록을 남긴다 (같은 몰 같은 주소는 한 줄)
pub async fn upsert_offer_from_raw(tx: &mut Transaction<'_, Postgres>, raw: &RawListing, variant_id: i64) -> sqlx::Result<i64> {
    let offer_id: i64 = sqlx::query_scalar(
        "INSERT INTO online.offer (variant_id, mall_id, title, url, price, shipping_fee, sold_out, source, observed_at)
         SELECT $1, r.mall_id, r.title, r.source_url, r.price, r.shipping_fee,
                COALESCE((r.payload ->> 'sold_out')::boolean, false), r.source, r.collected_at
         FROM ingest.raw_listing r WHERE r.id = $2
         ON CONFLICT (mall_id, url) DO UPDATE
         SET variant_id = EXCLUDED.variant_id, title = EXCLUDED.title, price = EXCLUDED.price,
             shipping_fee = EXCLUDED.shipping_fee, sold_out = EXCLUDED.sold_out,
             source = EXCLUDED.source, observed_at = EXCLUDED.observed_at
         RETURNING id",
    )
    .bind(variant_id)
    .bind(raw.id)
    .fetch_one(&mut **tx)
    .await?;
    sqlx::query(
        "INSERT INTO online.offer_history (offer_id, price, shipping_fee, sold_out, observed_at)
         SELECT id, price, shipping_fee, sold_out, observed_at FROM online.offer WHERE id = $1",
    )
    .bind(offer_id)
    .execute(&mut **tx)
    .await?;
    Ok(offer_id)
}

pub async fn set_match_state(tx: &mut Transaction<'_, Postgres>, id: i64, state: &str, variant_id: Option<i64>) -> sqlx::Result<()> {
    sqlx::query("UPDATE ingest.raw_listing SET match_state = $2, matched_variant_id = $3 WHERE id = $1")
        .bind(id)
        .bind(state)
        .bind(variant_id)
        .execute(&mut **tx)
        .await?;
    Ok(())
}

pub async fn collect_jobs(pool: &PgPool, limit: i64) -> sqlx::Result<Vec<CollectJob>> {
    sqlx::query_as(
        "SELECT j.id, j.mall_id, m.name AS mall_name, j.kind, j.status, j.item_count, j.error, j.started_at, j.finished_at
         FROM ingest.collect_job j LEFT JOIN online.mall m ON m.id = j.mall_id
         ORDER BY j.started_at DESC, j.id DESC LIMIT $1",
    )
    .bind(limit)
    .fetch_all(pool)
    .await
}
