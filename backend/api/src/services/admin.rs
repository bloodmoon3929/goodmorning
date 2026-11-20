//! 운영: 수집 원본을 카탈로그 버전에 연결(매칭 확정)하거나 제외한다.
//! AI 매칭(EmbeddingGemma 2)이 생기기 전까지는 운영자가 이 화면으로 확정한다.
//! 한 번 매칭된 몰 · 주소는 수집기가 다음 수집부터 online.offer 가격을 바로 갱신한다 (collector/pipelines).

use sqlx::PgPool;

use crate::{
    error::{AppError, AppResult},
    models::ingest::{CollectJob, RawListing},
    repositories,
};

const STATES: [&str; 4] = ["pending", "review", "matched", "rejected"];

pub async fn health(pool: &PgPool) -> AppResult<()> {
    repositories::admin::ping(pool).await?;
    Ok(())
}

pub async fn raw_listings(pool: &PgPool, state: &str, limit: i64) -> AppResult<Vec<RawListing>> {
    if !STATES.contains(&state) {
        return Err(AppError::bad("state는 pending · review · matched · rejected 중 하나입니다"));
    }
    Ok(repositories::admin::raw_listings(pool, state, limit.clamp(1, 200)).await?)
}

/// 매칭 확정 → online.offer 반영 (+ 가격 기록). 반영된 offer 번호를 돌려준다.
pub async fn match_raw(pool: &PgPool, id: i64, variant_id: i64) -> AppResult<i64> {
    if !repositories::product::variant_exists(pool, variant_id).await? {
        return Err(AppError::NotFound("버전"));
    }
    let mut tx = pool.begin().await?;
    let raw = repositories::admin::lock_raw_listing(&mut tx, id).await?.ok_or(AppError::NotFound("수집 원본"))?;
    if !matches!(raw.match_state.as_str(), "pending" | "review") {
        return Err(AppError::Conflict(format!("이미 처리한 수집 원본입니다 ({})", raw.match_state)));
    }
    if raw.mall_id.is_none() || raw.price.is_none() {
        return Err(AppError::bad("몰 또는 가격이 없는 수집 원본은 반영할 수 없습니다"));
    }
    let offer_id = repositories::admin::upsert_offer_from_raw(&mut tx, &raw, variant_id).await?;
    repositories::admin::set_match_state(&mut tx, id, "matched", Some(variant_id)).await?;
    tx.commit().await?;
    Ok(offer_id)
}

pub async fn reject_raw(pool: &PgPool, id: i64) -> AppResult<()> {
    let mut tx = pool.begin().await?;
    let raw = repositories::admin::lock_raw_listing(&mut tx, id).await?.ok_or(AppError::NotFound("수집 원본"))?;
    if !matches!(raw.match_state.as_str(), "pending" | "review") {
        return Err(AppError::Conflict(format!("이미 처리한 수집 원본입니다 ({})", raw.match_state)));
    }
    repositories::admin::set_match_state(&mut tx, id, "rejected", None).await?;
    tx.commit().await?;
    Ok(())
}

pub async fn collect_jobs(pool: &PgPool, limit: i64) -> AppResult<Vec<CollectJob>> {
    Ok(repositories::admin::collect_jobs(pool, limit.clamp(1, 200)).await?)
}
