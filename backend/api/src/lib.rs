//! 굿모닝 API 서버 (MVC). 요청 흐름: routes → middleware → controllers → services → repositories → DB
//! 응답 JSON 모양은 views, DB 행 구조체는 models.

use std::sync::Arc;

use axum::Router;
use sqlx::PgPool;

pub mod config;
pub mod controllers;
pub mod error;
pub mod middleware;
pub mod models;
pub mod repositories;
pub mod routes;
pub mod seed;
pub mod services;
pub mod views;

#[derive(Clone)]
pub struct AppState {
    pub pool: PgPool,
    pub config: Arc<config::Config>,
}

/// 전체 라우터 (테스트에서도 이 함수로 서버를 만든다)
pub fn app(state: AppState) -> Router {
    routes::router(state)
}
