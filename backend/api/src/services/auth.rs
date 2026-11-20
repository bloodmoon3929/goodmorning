//! 회원가입 · 로그인 (이메일). SNS 로그인(카카오 · 네이버 · 애플)은 아직 없다.

use argon2::{
    Argon2,
    password_hash::{PasswordHash, PasswordHasher, PasswordVerifier, SaltString, rand_core::OsRng},
};
use sqlx::PgPool;

use crate::{
    config::Config,
    error::{AppError, AppResult},
    middleware::{AuthUser, Role, auth::issue_token},
    models::account::AppUser,
    repositories::{self, auth::NewUser},
};

pub struct Profile {
    pub user: AppUser,
    pub ip_ids: Vec<i64>,
    pub seller_store_ids: Vec<i64>,
}

pub struct Session {
    pub token: String,
    pub profile: Profile,
}

pub struct SignupInput {
    pub email: String,
    pub password: String,
    pub nickname: String,
    pub home_area: Option<String>,
    pub agree_location: bool,
    pub agree_push: bool,
    pub ip_ids: Vec<i64>,
}

pub fn valid_email(email: &str) -> bool {
    let Some((local, domain)) = email.split_once('@') else { return false };
    email.len() <= 254
        && !local.is_empty()
        && domain.contains('.')
        && !domain.starts_with('.')
        && !domain.ends_with('.')
        && !email.contains(char::is_whitespace)
}

pub async fn email_taken(pool: &PgPool, email: &str) -> AppResult<bool> {
    if !valid_email(email.trim()) {
        return Err(AppError::bad("이메일 형식이 올바르지 않습니다"));
    }
    Ok(repositories::auth::email_taken(pool, email.trim()).await?)
}

pub async fn signup(pool: &PgPool, config: &Config, input: SignupInput) -> AppResult<Session> {
    let email = input.email.trim().to_lowercase();
    let nickname = input.nickname.trim();
    if !valid_email(&email) {
        return Err(AppError::bad("이메일 형식이 올바르지 않습니다"));
    }
    if input.password.chars().count() < 8 || input.password.len() > 128 {
        return Err(AppError::bad("비밀번호는 8자 이상이어야 합니다"));
    }
    if nickname.is_empty() || nickname.chars().count() > 20 {
        return Err(AppError::bad("닉네임은 1~20자입니다"));
    }
    if repositories::auth::email_taken(pool, &email).await? {
        return Err(AppError::Conflict("이미 가입한 이메일입니다".into()));
    }
    let ip_ids = dedup(&input.ip_ids);
    if repositories::catalog::existing_ip_ids(pool, &ip_ids).await?.len() != ip_ids.len() {
        return Err(AppError::bad("없는 IP가 들어 있습니다"));
    }

    let password = input.password;
    let hash = tokio::task::spawn_blocking(move || hash_password(&password)).await.map_err(|e| AppError::Internal(e.to_string()))??;

    let mut tx = pool.begin().await?;
    let user = repositories::auth::insert_user(
        &mut tx,
        NewUser {
            email: &email,
            password_hash: &hash,
            nickname,
            home_area: input.home_area.as_deref().map(str::trim).filter(|s| !s.is_empty()),
            agree_location: input.agree_location,
            agree_push: input.agree_push,
        },
    )
    .await?;
    repositories::auth::replace_user_ips(&mut tx, user.id, &ip_ids).await?;
    tx.commit().await?;

    let token = issue_token(&config.jwt_secret, config.jwt_ttl_hours, user.id, Role::parse(&user.role))?;
    Ok(Session { token, profile: Profile { user, ip_ids, seller_store_ids: vec![] } })
}

pub async fn login(pool: &PgPool, config: &Config, email: &str, password: &str) -> AppResult<Session> {
    let wrong = || AppError::BadRequest("이메일 또는 비밀번호가 맞지 않습니다".into());
    let user = repositories::auth::user_by_email(pool, email.trim()).await?.ok_or_else(wrong)?;
    let hash = user.password_hash.clone().ok_or_else(wrong)?;
    let password = password.to_string();
    let ok = tokio::task::spawn_blocking(move || verify_password(&password, &hash)).await.map_err(|e| AppError::Internal(e.to_string()))?;
    if !ok {
        return Err(wrong());
    }
    let token = issue_token(&config.jwt_secret, config.jwt_ttl_hours, user.id, Role::parse(&user.role))?;
    let profile = profile_of(pool, user).await?;
    Ok(Session { token, profile })
}

pub async fn me(pool: &PgPool, user: AuthUser) -> AppResult<Profile> {
    let row = repositories::auth::user_by_id(pool, user.id).await?.ok_or(AppError::Unauthorized)?;
    profile_of(pool, row).await
}

async fn profile_of(pool: &PgPool, user: AppUser) -> AppResult<Profile> {
    let ip_ids = repositories::auth::user_ip_ids(pool, user.id).await?;
    let seller_store_ids = repositories::auth::seller_store_ids(pool, user.id).await?;
    Ok(Profile { user, ip_ids, seller_store_ids })
}

fn hash_password(password: &str) -> AppResult<String> {
    let salt = SaltString::generate(&mut OsRng);
    Argon2::default().hash_password(password.as_bytes(), &salt).map(|h| h.to_string()).map_err(|e| AppError::Internal(e.to_string()))
}

fn verify_password(password: &str, hash: &str) -> bool {
    PasswordHash::new(hash).is_ok_and(|parsed| Argon2::default().verify_password(password.as_bytes(), &parsed).is_ok())
}

/// 순서를 지키며 중복 제거
pub fn dedup(ids: &[i64]) -> Vec<i64> {
    let mut seen = std::collections::HashSet::new();
    ids.iter().copied().filter(|id| seen.insert(*id)).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn email_rules() {
        assert!(valid_email("goods@example.com"));
        assert!(!valid_email("goods.example.com"));
        assert!(!valid_email("goods@example"));
        assert!(!valid_email("go ods@example.com"));
    }

    #[test]
    fn password_hash_round_trip_and_seed_hash() {
        let hash = hash_password("goodmorning1234").unwrap();
        assert!(verify_password("goodmorning1234", &hash));
        assert!(!verify_password("wrong-password", &hash));
        // db/seed/dev_seed.sql 계정 비밀번호 (Python argon2-cffi로 만든 해시와 호환)
        let seed = "$argon2id$v=19$m=65536,t=3,p=4$nCbEVyH2YEnS/wMzp4klLw$Pi5wfIqeRPUo1hXZZFyBEj43IhnlkYefb0LWNBrInCw";
        assert!(verify_password("goodmorning1234", seed));
    }

    #[test]
    fn dedup_keeps_order() {
        assert_eq!(dedup(&[3, 1, 3, 2, 1]), vec![3, 1, 2]);
    }
}
