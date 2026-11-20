//! 회원 가입 · 로그인

use sqlx::{PgPool, Postgres, Transaction};

use crate::models::account::AppUser;

const USER_COLUMNS: &str = "id, email, password_hash, provider, nickname, home_area, role, agree_location, agree_push, created_at";

pub async fn user_by_email(pool: &PgPool, email: &str) -> sqlx::Result<Option<AppUser>> {
    sqlx::query_as(&format!("SELECT {USER_COLUMNS} FROM account.app_user WHERE lower(email) = lower($1)")).bind(email).fetch_optional(pool).await
}

pub async fn user_by_id(pool: &PgPool, id: i64) -> sqlx::Result<Option<AppUser>> {
    sqlx::query_as(&format!("SELECT {USER_COLUMNS} FROM account.app_user WHERE id = $1")).bind(id).fetch_optional(pool).await
}

pub async fn email_taken(pool: &PgPool, email: &str) -> sqlx::Result<bool> {
    sqlx::query_scalar("SELECT EXISTS (SELECT 1 FROM account.app_user WHERE lower(email) = lower($1))").bind(email).fetch_one(pool).await
}

pub struct NewUser<'a> {
    pub email: &'a str,
    pub password_hash: &'a str,
    pub nickname: &'a str,
    pub home_area: Option<&'a str>,
    pub agree_location: bool,
    pub agree_push: bool,
}

pub async fn insert_user(tx: &mut Transaction<'_, Postgres>, u: NewUser<'_>) -> sqlx::Result<AppUser> {
    sqlx::query_as(&format!(
        "INSERT INTO account.app_user (email, password_hash, provider, nickname, home_area, agree_location, agree_push)
         VALUES ($1, $2, 'email', $3, $4, $5, $6)
         RETURNING {USER_COLUMNS}"
    ))
    .bind(u.email)
    .bind(u.password_hash)
    .bind(u.nickname)
    .bind(u.home_area)
    .bind(u.agree_location)
    .bind(u.agree_push)
    .fetch_one(&mut **tx)
    .await
}

/// 내 IP를 순서대로 다시 저장 (회원가입 · IP 목록 조정)
pub async fn replace_user_ips(tx: &mut Transaction<'_, Postgres>, user_id: i64, ip_ids: &[i64]) -> sqlx::Result<()> {
    sqlx::query("DELETE FROM account.user_ip WHERE user_id = $1").bind(user_id).execute(&mut **tx).await?;
    sqlx::query(
        "INSERT INTO account.user_ip (user_id, ip_id, sort_order)
         SELECT $1, ip_id, ord::smallint FROM unnest($2::bigint[]) WITH ORDINALITY AS t (ip_id, ord)",
    )
    .bind(user_id)
    .bind(ip_ids)
    .execute(&mut **tx)
    .await?;
    Ok(())
}

pub async fn user_ip_ids(pool: &PgPool, user_id: i64) -> sqlx::Result<Vec<i64>> {
    sqlx::query_scalar("SELECT ip_id FROM account.user_ip WHERE user_id = $1 ORDER BY sort_order").bind(user_id).fetch_all(pool).await
}

pub async fn seller_store_ids(pool: &PgPool, user_id: i64) -> sqlx::Result<Vec<i64>> {
    sqlx::query_scalar("SELECT store_id FROM account.seller_member WHERE user_id = $1 AND store_id IS NOT NULL ORDER BY store_id")
        .bind(user_id)
        .fetch_all(pool)
        .await
}
