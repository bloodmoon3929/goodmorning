//! 운영: 수집 원본 검토(매칭 확정 · 제외), 수집 실행 기록, 관리자 페이지에서 시작하는 수집 (큐 · 단계별 기록)

use serde_json::Value;
use sqlx::{PgPool, Postgres, Transaction, types::Json};

use crate::models::{
    ingest::{CollectEvent, CollectJob, CollectRun, CollectWorker, RawListing, VariantCandidate},
    online::MallStat,
};

const RAW_SELECT: &str = "
    SELECT r.id, r.mall_id, m.name AS mall_name, r.source, r.source_url, r.title, r.price, r.shipping_fee, r.image_url,
           r.payload, r.match_state, r.matched_variant_id, r.match_score, r.collected_at
    FROM ingest.raw_listing r LEFT JOIN online.mall m ON m.id = r.mall_id";

pub async fn ping(pool: &PgPool) -> sqlx::Result<()> {
    sqlx::query("SELECT 1").execute(pool).await?;
    Ok(())
}

/// state가 None이면 모든 상태, run_id가 있으면 그 실행에서 모은 것만
pub async fn raw_listings(pool: &PgPool, state: Option<&str>, run_id: Option<i64>, limit: i64) -> sqlx::Result<Vec<RawListing>> {
    sqlx::query_as(&format!(
        "{RAW_SELECT}
         WHERE ($1::text IS NULL OR r.match_state = $1)
           AND ($2::bigint IS NULL OR r.job_id IN (SELECT id FROM ingest.collect_job WHERE run_id = $2))
         ORDER BY r.collected_at DESC, r.id DESC LIMIT $3"
    ))
    .bind(state)
    .bind(run_id)
    .bind(limit)
    .fetch_all(pool)
    .await
}

pub async fn raw_listing(pool: &PgPool, id: i64) -> sqlx::Result<Option<RawListing>> {
    sqlx::query_as(&format!("{RAW_SELECT} WHERE r.id = $1")).bind(id).fetch_optional(pool).await
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

const JOB_SELECT: &str = "
    SELECT j.id, j.mall_id, m.name AS mall_name, j.kind, j.status, j.item_count, j.error, j.started_at, j.finished_at
    FROM ingest.collect_job j LEFT JOIN online.mall m ON m.id = j.mall_id";

pub async fn collect_jobs(pool: &PgPool, limit: i64) -> sqlx::Result<Vec<CollectJob>> {
    sqlx::query_as(&format!("{JOB_SELECT} ORDER BY j.started_at DESC, j.id DESC LIMIT $1")).bind(limit).fetch_all(pool).await
}

// ------------------------------------------------------------ 관리자 페이지: 몰 · 수집 실행

pub async fn malls(pool: &PgPool) -> sqlx::Result<Vec<MallStat>> {
    sqlx::query_as(
        "SELECT m.id, m.name, m.site_url, m.source, m.api_name, m.crawl_allowed, m.is_active,
                (SELECT count(*) FROM online.offer o WHERE o.mall_id = m.id) AS offer_count,
                (SELECT count(*) FROM ingest.raw_listing r WHERE r.mall_id = m.id) AS raw_count
         FROM online.mall m ORDER BY m.source DESC, m.id",
    )
    .fetch_all(pool)
    .await
}

/// 바꾼 행 수 (0이면 없는 몰)
pub async fn update_mall(pool: &PgPool, id: i64, crawl_allowed: Option<bool>, is_active: Option<bool>) -> sqlx::Result<u64> {
    let r = sqlx::query("UPDATE online.mall SET crawl_allowed = COALESCE($2, crawl_allowed), is_active = COALESCE($3, is_active) WHERE id = $1")
        .bind(id)
        .bind(crawl_allowed)
        .bind(is_active)
        .execute(pool)
        .await?;
    Ok(r.rows_affected())
}

pub async fn mall_exists(pool: &PgPool, name: &str) -> sqlx::Result<bool> {
    sqlx::query_scalar("SELECT EXISTS (SELECT 1 FROM online.mall WHERE name = $1)").bind(name).fetch_one(pool).await
}

const RUN_SELECT: &str =
    "SELECT id, kind, params, status, requested_by, item_count, error, created_at, started_at, finished_at FROM ingest.collect_run";

pub async fn insert_run(pool: &PgPool, kind: &str, params: Value, requested_by: i64) -> sqlx::Result<i64> {
    sqlx::query_scalar("INSERT INTO ingest.collect_run (kind, params, requested_by) VALUES ($1, $2, $3) RETURNING id")
        .bind(kind)
        .bind(Json(params))
        .bind(requested_by)
        .fetch_one(pool)
        .await
}

pub async fn runs(pool: &PgPool, limit: i64) -> sqlx::Result<Vec<CollectRun>> {
    sqlx::query_as(&format!("{RUN_SELECT} ORDER BY id DESC LIMIT $1")).bind(limit).fetch_all(pool).await
}

pub async fn run(pool: &PgPool, id: i64) -> sqlx::Result<Option<CollectRun>> {
    sqlx::query_as(&format!("{RUN_SELECT} WHERE id = $1")).bind(id).fetch_optional(pool).await
}

/// after 번호 뒤의 기록만 (관리자 페이지가 1초마다 새로 생긴 것만 받아 간다)
pub async fn events(pool: &PgPool, run_id: i64, after: i64, limit: i64) -> sqlx::Result<Vec<CollectEvent>> {
    sqlx::query_as(
        "SELECT id, run_id, at, step, level, message, data FROM ingest.collect_event
         WHERE run_id = $1 AND id > $2 ORDER BY id LIMIT $3",
    )
    .bind(run_id)
    .bind(after)
    .bind(limit)
    .fetch_all(pool)
    .await
}

pub async fn run_jobs(pool: &PgPool, run_id: i64) -> sqlx::Result<Vec<CollectJob>> {
    sqlx::query_as(&format!("{JOB_SELECT} WHERE j.run_id = $1 ORDER BY j.id")).bind(run_id).fetch_all(pool).await
}

pub async fn workers(pool: &PgPool) -> sqlx::Result<Vec<CollectWorker>> {
    sqlx::query_as("SELECT name, pid, seen_at FROM ingest.collect_worker ORDER BY seen_at DESC LIMIT 5").fetch_all(pool).await
}

/// (대기, 실행 중) 개수
pub async fn queue_counts(pool: &PgPool) -> sqlx::Result<(i64, i64)> {
    sqlx::query_as("SELECT count(*) FILTER (WHERE status = 'queued'), count(*) FILTER (WHERE status = 'running') FROM ingest.collect_run")
        .fetch_one(pool)
        .await
}

/// 제목 낱말이 많이 겹치는 카탈로그 버전. hint(수집할 때 쓴 검색어의 버전)가 있으면 맨 앞.
/// 띄어쓰기가 없는 일본어 제목도 잡히게, 제목 안에 IP 이름 · 별칭(ちいかわ …)이 들어 있으면 1점씩 더한다
pub async fn variant_candidates(pool: &PgPool, words: &[String], title: &str, hint: Option<i64>, limit: i64) -> sqlx::Result<Vec<VariantCandidate>> {
    sqlx::query_as(
        "SELECT v.id AS variant_id, v.name AS variant_name, p.id AS product_id, p.name AS product_name, ip.name AS ip_name,
                ((SELECT count(*) FROM unnest($1::text[]) w
                  WHERE strpos(lower(p.name || ' ' || v.name || ' ' || ip.name || ' '
                                    || COALESCE((SELECT string_agg(a.alias, ' ') FROM catalog.ip_alias a WHERE a.ip_id = ip.id), '')), w) > 0)
                 + (SELECT count(*) FROM catalog.ip_alias a WHERE a.ip_id = ip.id AND strpos($4, lower(a.alias)) > 0)
                 + (CASE WHEN strpos($4, lower(ip.name)) > 0 THEN 1 ELSE 0 END))::int AS hits
         FROM catalog.variant v
         JOIN catalog.product p ON p.id = v.product_id
         JOIN catalog.ip ip ON ip.id = p.ip_id
         ORDER BY (v.id = $2) DESC NULLS LAST, hits DESC, v.is_default DESC, v.id
         LIMIT $3",
    )
    .bind(words)
    .bind(hint)
    .bind(limit)
    .bind(title.to_lowercase())
    .fetch_all(pool)
    .await
}
