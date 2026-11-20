//! 재고 제보 · 매장 제보
//! - 판매자(사장님)가 있는 매장: 검토 대기로 저장 → 판매자가 승인하면 반영 (services::seller)
//! - 판매자가 없는 매장: 서로 다른 회원 2명이 같은 내용(매장 · 버전 · 상태)을 제보하면 바로 반영

use serde_json::Value;
use sqlx::PgPool;

use super::rules;
use crate::{
    error::{AppError, AppResult},
    middleware::AuthUser,
    models::offline::StockReport,
    repositories,
};

#[derive(Debug)]
pub struct ReportOutcome {
    pub id: i64,
    pub state: &'static str,
    /// 이번 제보로 재고가 바뀌었는지
    pub applied: bool,
}

pub async fn create_stock_report(
    pool: &PgPool,
    user: AuthUser,
    store_id: i64,
    variant_id: i64,
    status: &str,
    photo_url: Option<&str>,
) -> AppResult<ReportOutcome> {
    if !rules::is_stock_status(status) {
        return Err(AppError::bad("status는 many · few · none 중 하나입니다"));
    }
    if !repositories::product::variant_exists(pool, variant_id).await? {
        return Err(AppError::NotFound("버전"));
    }
    let mut tx = pool.begin().await?;
    let store_name = repositories::report::store_name(&mut tx, store_id).await?.ok_or(AppError::NotFound("매장"))?;
    let id = repositories::report::insert_report(&mut tx, store_id, variant_id, user.id, status, photo_url).await?;

    if repositories::report::store_has_owner(&mut tx, store_id).await? {
        tx.commit().await?;
        return Ok(ReportOutcome { id, state: "pending", applied: false });
    }

    let others = repositories::report::pending_same_reports(&mut tx, store_id, variant_id, status, user.id).await?;
    if others.is_empty() {
        tx.commit().await?;
        return Ok(ReportOutcome { id, state: "pending", applied: false });
    }

    let mut ids: Vec<i64> = others.iter().map(|(rid, _)| *rid).collect();
    ids.push(id);
    repositories::report::resolve_reports(&mut tx, &ids, "approved", None).await?;
    repositories::report::upsert_stock(&mut tx, store_id, variant_id, status, None, "report").await?;
    let mut reporters: Vec<i64> = others.iter().map(|(_, uid)| *uid).collect();
    reporters.push(user.id);
    reporters.sort_unstable();
    reporters.dedup();
    let body = format!("{store_name} · {}", rules::status_label(status));
    for uid in reporters {
        repositories::report::insert_notification(&mut tx, uid, "report", "재고 제보가 반영됐어요", &body, &format!("/stores/{store_id}")).await?;
    }
    tx.commit().await?;
    Ok(ReportOutcome { id, state: "approved", applied: true })
}

pub async fn my_reports(pool: &PgPool, user: AuthUser) -> AppResult<Vec<StockReport>> {
    Ok(repositories::report::reports_of_user(pool, user.id).await?)
}

/// 새 매장(new) · 정보 수정(edit) · 폐업(closed) 제보. 관리자 검토 후 반영한다.
pub async fn create_store_suggestion(pool: &PgPool, user: AuthUser, store_id: Option<i64>, kind: &str, content: Value) -> AppResult<i64> {
    match (kind, store_id) {
        ("new", None) | ("edit" | "closed", Some(_)) => {}
        ("new", Some(_)) => return Err(AppError::bad("새 매장 제보에는 store_id를 보내지 않습니다")),
        ("edit" | "closed", None) => return Err(AppError::bad("수정 · 폐업 제보에는 store_id가 필요합니다")),
        _ => return Err(AppError::bad("type은 new · edit · closed 중 하나입니다")),
    }
    if !content.is_object() {
        return Err(AppError::bad("content는 JSON 객체입니다"));
    }
    if let Some(sid) = store_id
        && !repositories::store::exists(pool, sid).await?
    {
        return Err(AppError::NotFound("매장"));
    }
    Ok(repositories::report::insert_store_suggestion(pool, user.id, store_id, kind, content).await?)
}
