//! 판매자 권한: /seller/stores/{store_id}/… 는 그 매장에 연결된 판매자(또는 운영자)만 쓸 수 있다.

use std::collections::HashMap;

use axum::{
    extract::{Path, Request, State},
    middleware::Next,
    response::Response,
};

use crate::{
    AppState,
    error::{AppError, AppResult},
    middleware::AuthUser,
    services,
};

pub async fn require_store_member(
    State(state): State<AppState>,
    user: AuthUser,
    Path(params): Path<HashMap<String, String>>,
    req: Request,
    next: Next,
) -> AppResult<Response> {
    let store_id: i64 = params.get("store_id").and_then(|v| v.parse().ok()).ok_or_else(|| AppError::bad("매장 번호가 올바르지 않습니다"))?;
    services::seller::ensure_store_member(&state.pool, user, store_id).await?;
    Ok(next.run(req).await)
}
