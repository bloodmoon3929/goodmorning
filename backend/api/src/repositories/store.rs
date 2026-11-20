//! 매장 · 매장 재고

use sqlx::PgPool;

use super::{POINT_SQL, TODAY_KST_SQL};
use crate::models::offline::{Store, StoreItem};

/// 매장 목록 · 상세에 같이 쓰는 SELECT.
/// $1 내 IP 번호들 (비우면 전체), $2 경도, $3 위도, $4 재고 신선도(시간)
fn store_select() -> String {
    format!(
        "SELECT s.id, s.name, s.kind, s.address,
                ST_Y(s.location::geometry) AS lat, ST_X(s.location::geometry) AS lng,
                s.phone, s.hours, s.popup_until, s.info_source, s.is_closed, s.updated_at,
                ST_Distance(s.location, me.pt) AS distance_m,
                EXISTS (SELECT 1 FROM account.seller_member sm WHERE sm.store_id = s.id) AS has_owner,
                COALESCE(k.in_stock, 0) AS my_ip_in_stock,
                COALESCE(k.total, 0) AS my_ip_total,
                COALESCE(k.unknown, 0) AS my_ip_unknown
         FROM offline.store s
         CROSS JOIN (SELECT {POINT_SQL} AS pt) me
         LEFT JOIN LATERAL (
             SELECT count(*) FILTER (WHERE x.eff IN ('many', 'few')) AS in_stock,
                    count(*) AS total,
                    count(*) FILTER (WHERE x.eff = 'unknown') AS unknown
             FROM (
                 SELECT CASE WHEN st.confirmed_at <= now() - make_interval(hours => $4) THEN 'unknown' ELSE st.status END AS eff
                 FROM offline.stock st
                 JOIN catalog.variant v ON v.id = st.variant_id
                 JOIN catalog.product p ON p.id = v.product_id
                 WHERE st.store_id = s.id AND (cardinality($1::bigint[]) = 0 OR p.ip_id = ANY($1))
             ) x
         ) k ON true"
    )
}

/// 거리순 매장 목록. $5 반경(m), NULL이면 제한 없음
pub async fn stores(pool: &PgPool, ip_ids: &[i64], lng: f64, lat: f64, stale_hours: i32, radius_m: Option<f64>) -> sqlx::Result<Vec<Store>> {
    let sql = format!(
        "{} WHERE NOT s.is_closed
              AND (s.popup_until IS NULL OR s.popup_until >= {TODAY_KST_SQL})
              AND ($5::float8 IS NULL OR ST_DWithin(s.location, me.pt, $5))
            ORDER BY distance_m",
        store_select()
    );
    sqlx::query_as(&sql).bind(ip_ids).bind(lng).bind(lat).bind(stale_hours).bind(radius_m).fetch_all(pool).await
}

/// 매장 하나 ($5 매장 번호)
pub async fn store(pool: &PgPool, id: i64, ip_ids: &[i64], lng: f64, lat: f64, stale_hours: i32) -> sqlx::Result<Option<Store>> {
    let sql = format!("{} WHERE s.id = $5", store_select());
    sqlx::query_as(&sql).bind(ip_ids).bind(lng).bind(lat).bind(stale_hours).bind(id).fetch_optional(pool).await
}

/// 매장에서 다루는 굿즈 재고 (저장된 상태 그대로)
pub async fn items(pool: &PgPool, store_id: i64) -> sqlx::Result<Vec<StoreItem>> {
    sqlx::query_as(
        "SELECT p.id AS product_id, p.name AS product_name, p.image_url AS product_image, ip.name AS ip_name, p.type,
                v.id AS variant_id, v.name AS variant_name, st.status, st.source, st.confirmed_at, st.price
         FROM offline.stock st
         JOIN catalog.variant v ON v.id = st.variant_id
         JOIN catalog.product p ON p.id = v.product_id
         JOIN catalog.ip ip ON ip.id = p.ip_id
         WHERE st.store_id = $1
         ORDER BY ip.id, p.id, v.is_default DESC, v.id",
    )
    .bind(store_id)
    .fetch_all(pool)
    .await
}

pub async fn is_saved(pool: &PgPool, user_id: i64, store_id: i64) -> sqlx::Result<bool> {
    sqlx::query_scalar("SELECT EXISTS (SELECT 1 FROM account.saved_store WHERE user_id = $1 AND store_id = $2)")
        .bind(user_id)
        .bind(store_id)
        .fetch_one(pool)
        .await
}

pub async fn exists(pool: &PgPool, store_id: i64) -> sqlx::Result<bool> {
    sqlx::query_scalar("SELECT EXISTS (SELECT 1 FROM offline.store WHERE id = $1)").bind(store_id).fetch_one(pool).await
}
