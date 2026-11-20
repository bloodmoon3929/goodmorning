//! 로그인 · 회원가입

use axum::{
    Json,
    extract::{Query, State},
    http::StatusCode,
};
use serde::Deserialize;

use crate::{
    AppState,
    error::AppResult,
    middleware::AuthUser,
    services::{self, auth::SignupInput},
    views::auth::{EmailTakenView, MeView, SessionView},
};

#[derive(Deserialize)]
pub struct SignupBody {
    email: String,
    password: String,
    nickname: String,
    home_area: Option<String>,
    #[serde(default)]
    agree_location: bool,
    #[serde(default)]
    agree_push: bool,
    /// 회원가입 IP 고르기에서 고른 순서
    #[serde(default)]
    ip_ids: Vec<i64>,
}

/// POST /auth/signup
pub async fn signup(State(s): State<AppState>, Json(b): Json<SignupBody>) -> AppResult<(StatusCode, Json<SessionView>)> {
    let input = SignupInput {
        email: b.email,
        password: b.password,
        nickname: b.nickname,
        home_area: b.home_area,
        agree_location: b.agree_location,
        agree_push: b.agree_push,
        ip_ids: b.ip_ids,
    };
    let session = services::auth::signup(&s.pool, &s.config, input).await?;
    Ok((StatusCode::CREATED, Json(session.into())))
}

#[derive(Deserialize)]
pub struct LoginBody {
    email: String,
    password: String,
}

/// POST /auth/login
pub async fn login(State(s): State<AppState>, Json(b): Json<LoginBody>) -> AppResult<Json<SessionView>> {
    Ok(Json(services::auth::login(&s.pool, &s.config, &b.email, &b.password).await?.into()))
}

#[derive(Deserialize)]
pub struct EmailQuery {
    email: String,
}

/// GET /auth/email-taken?email= — 회원가입 이메일 중복 확인
pub async fn email_taken(State(s): State<AppState>, Query(q): Query<EmailQuery>) -> AppResult<Json<EmailTakenView>> {
    Ok(Json(EmailTakenView { taken: services::auth::email_taken(&s.pool, &q.email).await? }))
}

/// GET /me
pub async fn me(State(s): State<AppState>, user: AuthUser) -> AppResult<Json<MeView>> {
    Ok(Json(services::auth::me(&s.pool, user).await?.into()))
}
