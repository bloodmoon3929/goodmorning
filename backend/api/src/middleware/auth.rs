//! 로그인 확인. `Authorization: Bearer <JWT>` 를 읽어 회원 번호와 역할을 꺼낸다.

use axum::{extract::FromRequestParts, http::request::Parts};
use chrono::Utc;
use jsonwebtoken::{DecodingKey, EncodingKey, Header, Validation, decode, encode};
use serde::{Deserialize, Serialize};

use crate::{
    AppState,
    error::{AppError, AppResult},
};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Role {
    User,
    Seller,
    Admin,
}

impl Role {
    pub fn parse(s: &str) -> Self {
        match s {
            "seller" => Self::Seller,
            "admin" => Self::Admin,
            _ => Self::User,
        }
    }
}

#[derive(Debug, Serialize, Deserialize)]
struct Claims {
    sub: String,
    role: Role,
    exp: i64,
    iat: i64,
}

/// 로그인한 회원 (없으면 401)
#[derive(Debug, Clone, Copy)]
pub struct AuthUser {
    pub id: i64,
    pub role: Role,
}

/// 로그인은 선택 (둘러보기도 되는 화면)
#[derive(Debug, Clone, Copy)]
pub struct MaybeUser(pub Option<AuthUser>);

/// 운영자만
#[derive(Debug, Clone, Copy)]
pub struct AdminUser(pub AuthUser);

pub fn issue_token(secret: &str, ttl_hours: i64, user_id: i64, role: Role) -> AppResult<String> {
    let now = Utc::now().timestamp();
    let claims = Claims { sub: user_id.to_string(), role, iat: now, exp: now + ttl_hours * 3600 };
    encode(&Header::default(), &claims, &EncodingKey::from_secret(secret.as_bytes())).map_err(|e| AppError::Internal(e.to_string()))
}

fn verify_token(secret: &str, token: &str) -> AppResult<AuthUser> {
    let data = decode::<Claims>(token, &DecodingKey::from_secret(secret.as_bytes()), &Validation::default()).map_err(|_| AppError::Unauthorized)?;
    let id = data.claims.sub.parse().map_err(|_| AppError::Unauthorized)?;
    Ok(AuthUser { id, role: data.claims.role })
}

fn bearer(parts: &Parts) -> Option<&str> {
    parts.headers.get(axum::http::header::AUTHORIZATION)?.to_str().ok()?.strip_prefix("Bearer ").map(str::trim)
}

impl FromRequestParts<AppState> for AuthUser {
    type Rejection = AppError;

    async fn from_request_parts(parts: &mut Parts, state: &AppState) -> Result<Self, Self::Rejection> {
        let token = bearer(parts).ok_or(AppError::Unauthorized)?;
        verify_token(&state.config.jwt_secret, token)
    }
}

impl FromRequestParts<AppState> for MaybeUser {
    type Rejection = AppError;

    async fn from_request_parts(parts: &mut Parts, state: &AppState) -> Result<Self, Self::Rejection> {
        match bearer(parts) {
            None => Ok(Self(None)),
            // 토큰을 보냈는데 틀리면 비로그인으로 넘기지 않고 401 (만료를 앱이 알 수 있게)
            Some(token) => verify_token(&state.config.jwt_secret, token).map(|u| Self(Some(u))),
        }
    }
}

impl FromRequestParts<AppState> for AdminUser {
    type Rejection = AppError;

    async fn from_request_parts(parts: &mut Parts, state: &AppState) -> Result<Self, Self::Rejection> {
        let user = AuthUser::from_request_parts(parts, state).await?;
        if user.role != Role::Admin {
            return Err(AppError::Forbidden("운영자만 할 수 있습니다"));
        }
        Ok(Self(user))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn token_round_trip() {
        let secret = "test-secret-0123456789";
        let token = issue_token(secret, 1, 42, Role::Seller).unwrap();
        let user = verify_token(secret, &token).unwrap();
        assert_eq!(user.id, 42);
        assert_eq!(user.role, Role::Seller);
        assert!(verify_token("other-secret-0123456789", &token).is_err());
    }
}
