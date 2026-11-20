//! 구매하러 가기

use axum::{
    Json,
    extract::{Path, State},
    http::{StatusCode, header},
    response::{IntoResponse, Response},
};

use crate::{AppState, error::AppResult, middleware::MaybeUser, services, views::offer::OutboundView};

/// POST /offers/{id}/click — 앱용: 이동 기록을 남기고 열 주소를 JSON으로 준다
pub async fn click(State(s): State<AppState>, MaybeUser(user): MaybeUser, Path(id): Path<i64>) -> AppResult<Json<OutboundView>> {
    Ok(Json(services::offer::go(&s.pool, id, user).await?.into()))
}

/// GET /offers/{id}/go — 링크용: 이동 기록을 남기고 외부 몰로 302 이동
pub async fn go(State(s): State<AppState>, MaybeUser(user): MaybeUser, Path(id): Path<i64>) -> AppResult<Response> {
    let out = services::offer::go(&s.pool, id, user).await?;
    Ok((StatusCode::FOUND, [(header::LOCATION, out.url)]).into_response())
}
