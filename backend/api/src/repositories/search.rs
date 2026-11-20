//! 텍스트 검색: 상품명 · IP 이름 · 별칭 · 캐릭터 · 품목 · 버전 이름에 검색어가 모두 들어 있는 상품
//! (텍스트 임베딩 유사도는 AI 서버가 생기면 더한다)

use sqlx::PgPool;

use crate::models::catalog::{AliasHit, Ip};

pub async fn product_ids(pool: &PgPool, words: &[String]) -> sqlx::Result<Vec<i64>> {
    sqlx::query_scalar(
        "SELECT p.id
         FROM catalog.product p
         JOIN catalog.ip ip ON ip.id = p.ip_id AND ip.is_active
         CROSS JOIN LATERAL (
             SELECT lower(concat_ws(' ',
                 p.name, ip.name,
                 (SELECT string_agg(a.alias, ' ') FROM catalog.ip_alias a WHERE a.ip_id = ip.id),
                 (SELECT string_agg(c.name, ' ') FROM catalog.product_character pc
                  JOIN catalog.character c ON c.id = pc.character_id WHERE pc.product_id = p.id),
                 CASE p.type WHEN 'figure' THEN '피규어' WHEN 'doll' THEN '인형' WHEN 'keyring' THEN '키링'
                             WHEN 'acrylic' THEN '아크릴' WHEN 'plamodel' THEN '프라모델' WHEN 'random' THEN '랜덤' END,
                 (SELECT string_agg(v.name, ' ') FROM catalog.variant v WHERE v.product_id = p.id)
             )) AS hay
         ) h
         WHERE NOT EXISTS (SELECT 1 FROM unnest($1::text[]) w WHERE strpos(h.hay, w) = 0)",
    )
    .bind(words)
    .fetch_all(pool)
    .await
}

/// 검색어가 IP 이름이 아닌 별칭과 맞으면 안내한다 (먼작귀 → 치이카와)
pub async fn alias_hit(pool: &PgPool, words: &[String]) -> sqlx::Result<Option<AliasHit>> {
    sqlx::query_as(
        "SELECT a.alias, ip.name AS ip_name
         FROM catalog.ip_alias a JOIN catalog.ip ip ON ip.id = a.ip_id AND ip.is_active
         WHERE lower(a.alias) <> lower(ip.name)
           AND EXISTS (SELECT 1 FROM unnest($1::text[]) w
                       WHERE char_length(w) >= 2 AND (strpos(lower(a.alias), w) > 0 OR strpos(w, lower(a.alias)) > 0))
         ORDER BY a.id
         LIMIT 1",
    )
    .bind(words)
    .fetch_optional(pool)
    .await
}

/// 이름이나 별칭에 검색어가 들어 있는 IP
pub async fn ips(pool: &PgPool, words: &[String]) -> sqlx::Result<Vec<Ip>> {
    sqlx::query_as(
        "SELECT ip.id, ip.name, ip.category, ip.image_url,
                COALESCE(array_agg(a.alias ORDER BY a.id) FILTER (WHERE a.alias IS NOT NULL), '{}') AS aliases
         FROM catalog.ip ip
         LEFT JOIN catalog.ip_alias a ON a.ip_id = ip.id
         WHERE ip.is_active
         GROUP BY ip.id
         HAVING EXISTS (SELECT 1 FROM unnest($1::text[]) w
                        WHERE strpos(lower(ip.name), w) > 0
                           OR strpos(lower(COALESCE(string_agg(a.alias, ' '), '')), w) > 0)
         ORDER BY ip.id",
    )
    .bind(words)
    .fetch_all(pool)
    .await
}
