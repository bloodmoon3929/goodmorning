//! IP · 캐릭터

use sqlx::PgPool;

use crate::models::catalog::{Character, Ip, IpStat};

const IP_SELECT: &str = "
    SELECT ip.id, ip.name, ip.category, ip.image_url,
           COALESCE(array_agg(a.alias ORDER BY a.id) FILTER (WHERE a.alias IS NOT NULL), '{}') AS aliases
    FROM catalog.ip ip
    LEFT JOIN catalog.ip_alias a ON a.ip_id = ip.id";

pub async fn ips(pool: &PgPool) -> sqlx::Result<Vec<Ip>> {
    sqlx::query_as(&format!("{IP_SELECT} WHERE ip.is_active GROUP BY ip.id ORDER BY ip.id")).fetch_all(pool).await
}

pub async fn ip(pool: &PgPool, id: i64) -> sqlx::Result<Option<Ip>> {
    sqlx::query_as(&format!("{IP_SELECT} WHERE ip.id = $1 AND ip.is_active GROUP BY ip.id")).bind(id).fetch_optional(pool).await
}

pub async fn ips_by_ids(pool: &PgPool, ids: &[i64]) -> sqlx::Result<Vec<Ip>> {
    sqlx::query_as(&format!("{IP_SELECT} WHERE ip.id = ANY($1) AND ip.is_active GROUP BY ip.id")).bind(ids).fetch_all(pool).await
}

pub async fn ip_stats(pool: &PgPool, ids: &[i64]) -> sqlx::Result<Vec<IpStat>> {
    sqlx::query_as(
        "SELECT ip.id,
                (SELECT count(*) FROM catalog.character c WHERE c.ip_id = ip.id) AS character_count,
                (SELECT count(*) FROM catalog.product p WHERE p.ip_id = ip.id) AS goods_count
         FROM catalog.ip ip
         WHERE ip.id = ANY($1) AND ip.is_active",
    )
    .bind(ids)
    .fetch_all(pool)
    .await
}

pub async fn characters_of_ip(pool: &PgPool, ip_id: i64) -> sqlx::Result<Vec<Character>> {
    sqlx::query_as("SELECT id, ip_id, name, image_url FROM catalog.character WHERE ip_id = $1 ORDER BY id").bind(ip_id).fetch_all(pool).await
}

pub async fn character(pool: &PgPool, id: i64) -> sqlx::Result<Option<Character>> {
    sqlx::query_as("SELECT id, ip_id, name, image_url FROM catalog.character WHERE id = $1").bind(id).fetch_optional(pool).await
}

pub async fn characters_of_product(pool: &PgPool, product_id: i64) -> sqlx::Result<Vec<Character>> {
    sqlx::query_as(
        "SELECT c.id, c.ip_id, c.name, c.image_url
         FROM catalog.product_character pc JOIN catalog.character c ON c.id = pc.character_id
         WHERE pc.product_id = $1 ORDER BY c.id",
    )
    .bind(product_id)
    .fetch_all(pool)
    .await
}

pub async fn existing_ip_ids(pool: &PgPool, ids: &[i64]) -> sqlx::Result<Vec<i64>> {
    sqlx::query_scalar("SELECT id FROM catalog.ip WHERE id = ANY($1) AND is_active").bind(ids).fetch_all(pool).await
}
