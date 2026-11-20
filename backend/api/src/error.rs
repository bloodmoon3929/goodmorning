//! 에러 → HTTP 응답. 응답 본문: {"error": "not_found", "message": "…"}

use axum::{
    Json,
    http::StatusCode,
    response::{IntoResponse, Response},
};
use serde_json::json;

#[derive(Debug, thiserror::Error)]
pub enum AppError {
    #[error("{0}")]
    BadRequest(String),
    #[error("로그인이 필요합니다")]
    Unauthorized,
    #[error("{0}")]
    Forbidden(&'static str),
    #[error("{0}을(를) 찾을 수 없습니다")]
    NotFound(&'static str),
    #[error("{0}")]
    Conflict(String),
    #[error("DB 오류")]
    Db(#[source] sqlx::Error),
    #[error("서버 오류")]
    Internal(String),
}

pub type AppResult<T> = Result<T, AppError>;

impl AppError {
    pub fn bad(msg: impl Into<String>) -> Self {
        Self::BadRequest(msg.into())
    }

    fn status_and_code(&self) -> (StatusCode, &'static str) {
        match self {
            Self::BadRequest(_) => (StatusCode::BAD_REQUEST, "bad_request"),
            Self::Unauthorized => (StatusCode::UNAUTHORIZED, "unauthorized"),
            Self::Forbidden(_) => (StatusCode::FORBIDDEN, "forbidden"),
            Self::NotFound(_) => (StatusCode::NOT_FOUND, "not_found"),
            Self::Conflict(_) => (StatusCode::CONFLICT, "conflict"),
            Self::Db(_) | Self::Internal(_) => (StatusCode::INTERNAL_SERVER_ERROR, "internal"),
        }
    }
}

impl From<sqlx::Error> for AppError {
    fn from(e: sqlx::Error) -> Self {
        if let sqlx::Error::Database(db) = &e {
            // PostgreSQL 오류 코드: 23505 중복, 23503 없는 대상 참조, 23514 CHECK 위반
            match db.code().as_deref() {
                Some("23505") => return Self::Conflict("이미 있는 값입니다".into()),
                Some("23503") => return Self::BadRequest("존재하지 않는 대상을 가리킵니다".into()),
                Some("23514") => return Self::BadRequest("허용되지 않는 값입니다".into()),
                _ => {}
            }
        }
        if matches!(e, sqlx::Error::RowNotFound) {
            return Self::NotFound("대상");
        }
        Self::Db(e)
    }
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, code) = self.status_and_code();
        match &self {
            Self::Db(e) => tracing::error!(error = ?e, "DB 오류"),
            Self::Internal(e) => tracing::error!(error = %e, "서버 오류"),
            _ => {}
        }
        (status, Json(json!({ "error": code, "message": self.to_string() }))).into_response()
    }
}
