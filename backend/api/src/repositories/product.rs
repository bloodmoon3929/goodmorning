//! 상품 · 버전 · 몰별 가격 · 매장별 재고

use sqlx::PgPool;

use super::{POINT_SQL, TODAY_KST_SQL};
use crate::models::{
    catalog::{Product, ProductSummary, SimilarCandidate},
    offline::StockAtStore,
    online::Offer,
};

/// 상품 요약을 계산할 때 필요한 기준값 (services가 정한다)
#[derive(Debug, Clone, Copy)]
pub struct SummaryParams {
    pub lng: f64,
    pub lat: f64,
    pub stale_hours: i32,
    pub nearby_m: f64,
}

/// 상품 카드 한 줄: 버전 목록, 캐릭터, 온라인 몰 수 · 최저 총액, 근처 재고 매장 수 · 가장 가까운 거리
/// $1 상품 번호들, $2 경도, $3 위도, $4 재고 신선도(시간), $5 근처 거리(m)
pub async fn summaries(pool: &PgPool, ids: &[i64], p: SummaryParams) -> sqlx::Result<Vec<ProductSummary>> {
    let sql = format!(
        "SELECT p.id, p.ip_id, ip.name AS ip_name, p.name, p.type, p.image_url, p.release_date,
                COALESCE(ch.ids, '{{}}') AS character_ids,
                COALESCE(ch.names, '{{}}') AS character_names,
                COALESCE(vs.list, '[]') AS variants,
                COALESCE(onl.malls, 0) AS online_malls,
                onl.min_total,
                COALESCE(offl.stores, 0) AS nearby_stores,
                offl.nearest_m,
                (SELECT count(*) FROM account.wishlist w JOIN catalog.variant v ON v.id = w.variant_id WHERE v.product_id = p.id)
              + (SELECT count(*) FROM account.outbound_click c WHERE c.variant_id IN (SELECT id FROM catalog.variant WHERE product_id = p.id))
                AS popularity
         FROM catalog.product p
         JOIN catalog.ip ip ON ip.id = p.ip_id
         CROSS JOIN (SELECT {POINT_SQL} AS pt) me
         LEFT JOIN LATERAL (
             SELECT array_agg(c.id ORDER BY c.id) AS ids, array_agg(c.name ORDER BY c.id) AS names
             FROM catalog.product_character pc JOIN catalog.character c ON c.id = pc.character_id
             WHERE pc.product_id = p.id
         ) ch ON true
         LEFT JOIN LATERAL (
             SELECT json_agg(json_build_object('id', v.id, 'name', v.name, 'attrs', v.attrs, 'is_default', v.is_default)
                             ORDER BY v.is_default DESC, v.id) AS list
             FROM catalog.variant v WHERE v.product_id = p.id
         ) vs ON true
         LEFT JOIN LATERAL (
             SELECT count(DISTINCT o.mall_id) AS malls, min(o.total_price) AS min_total
             FROM online.offer o
             JOIN catalog.variant v ON v.id = o.variant_id
             JOIN online.mall m ON m.id = o.mall_id AND m.is_active
             WHERE v.product_id = p.id AND NOT o.sold_out
         ) onl ON true
         LEFT JOIN LATERAL (
             SELECT count(DISTINCT s.id) AS stores, min(ST_Distance(s.location, me.pt)) AS nearest_m
             FROM offline.stock st
             JOIN catalog.variant v ON v.id = st.variant_id
             JOIN offline.store s ON s.id = st.store_id
             WHERE v.product_id = p.id
               AND st.status IN ('many', 'few')
               AND st.confirmed_at > now() - make_interval(hours => $4)
               AND NOT s.is_closed
               AND (s.popup_until IS NULL OR s.popup_until >= {TODAY_KST_SQL})
               AND ST_DWithin(s.location, me.pt, $5)
         ) offl ON true
         WHERE p.id = ANY($1) AND ip.is_active"
    );
    sqlx::query_as(&sql).bind(ids).bind(p.lng).bind(p.lat).bind(p.stale_hours).bind(p.nearby_m).fetch_all(pool).await
}

pub async fn product(pool: &PgPool, id: i64) -> sqlx::Result<Option<Product>> {
    sqlx::query_as(
        "SELECT p.id, p.ip_id, ip.name AS ip_name, p.name, p.type, p.maker, p.description, p.release_date, p.image_url, p.created_at
         FROM catalog.product p JOIN catalog.ip ip ON ip.id = p.ip_id
         WHERE p.id = $1 AND ip.is_active",
    )
    .bind(id)
    .fetch_optional(pool)
    .await
}

/// 신상품: 발매일이 최근인 순서
pub async fn new_product_ids(pool: &PgPool, ip_ids: &[i64], limit: i64) -> sqlx::Result<Vec<i64>> {
    sqlx::query_scalar(
        "SELECT p.id FROM catalog.product p JOIN catalog.ip ip ON ip.id = p.ip_id
         WHERE ip.is_active AND (cardinality($1::bigint[]) = 0 OR p.ip_id = ANY($1))
         ORDER BY p.release_date DESC NULLS LAST, p.id DESC
         LIMIT $2",
    )
    .bind(ip_ids)
    .bind(limit)
    .fetch_all(pool)
    .await
}

pub async fn ids_of_ip(pool: &PgPool, ip_id: i64) -> sqlx::Result<Vec<i64>> {
    sqlx::query_scalar("SELECT id FROM catalog.product WHERE ip_id = $1 ORDER BY id").bind(ip_id).fetch_all(pool).await
}

pub async fn ids_of_character(pool: &PgPool, character_id: i64) -> sqlx::Result<Vec<i64>> {
    sqlx::query_scalar("SELECT product_id FROM catalog.product_character WHERE character_id = $1 ORDER BY product_id")
        .bind(character_id)
        .fetch_all(pool)
        .await
}

/// 몰별 가격 (활성 몰만). 정렬은 services에서 한다.
pub async fn offers(pool: &PgPool, product_id: i64) -> sqlx::Result<Vec<Offer>> {
    sqlx::query_as(
        "SELECT o.id, o.variant_id, o.mall_id, m.name AS mall_name, o.title, o.url, o.price, o.shipping_fee, o.total_price,
                o.sold_out, o.source, o.observed_at
         FROM online.offer o
         JOIN online.mall m ON m.id = o.mall_id AND m.is_active
         JOIN catalog.variant v ON v.id = o.variant_id
         WHERE v.product_id = $1",
    )
    .bind(product_id)
    .fetch_all(pool)
    .await
}

/// 매장별 재고 (폐업 · 끝난 팝업 제외). 상태는 저장된 값 그대로이고, 신선도는 services에서 판단한다.
pub async fn stocks(pool: &PgPool, product_id: i64, lng: f64, lat: f64) -> sqlx::Result<Vec<StockAtStore>> {
    let sql = format!(
        "SELECT s.id AS store_id, s.name AS store_name, s.kind AS store_kind, s.popup_until,
                ST_Distance(s.location, me.pt) AS distance_m,
                EXISTS (SELECT 1 FROM account.seller_member sm WHERE sm.store_id = s.id) AS has_owner,
                st.variant_id, st.status, st.source, st.confirmed_at, st.price
         FROM offline.stock st
         JOIN catalog.variant v ON v.id = st.variant_id
         JOIN offline.store s ON s.id = st.store_id
         CROSS JOIN (SELECT {POINT_SQL} AS pt) me
         WHERE v.product_id = $1 AND NOT s.is_closed
           AND (s.popup_until IS NULL OR s.popup_until >= {TODAY_KST_SQL})
         ORDER BY distance_m"
    );
    sqlx::query_as(&sql).bind(product_id).bind(lng).bind(lat).fetch_all(pool).await
}

/// 비슷한 상품 후보: 같은 IP이거나 같은 품목
pub async fn similar_candidates(pool: &PgPool, product_id: i64) -> sqlx::Result<Vec<SimilarCandidate>> {
    sqlx::query_as(
        "SELECT p.id, p.ip_id,
                (SELECT count(*) FROM catalog.product_character a
                 JOIN catalog.product_character b ON a.character_id = b.character_id
                 WHERE a.product_id = p.id AND b.product_id = $1) AS shared_characters,
                p.type = me.type AS same_type,
                p.ip_id = me.ip_id AS same_ip
         FROM catalog.product p
         JOIN catalog.ip ip ON ip.id = p.ip_id AND ip.is_active
         CROSS JOIN (SELECT type, ip_id FROM catalog.product WHERE id = $1) me
         WHERE p.id <> $1 AND (p.ip_id = me.ip_id OR p.type = me.type)",
    )
    .bind(product_id)
    .fetch_all(pool)
    .await
}

pub async fn wished_variant_ids(pool: &PgPool, user_id: i64, product_id: i64) -> sqlx::Result<Vec<i64>> {
    sqlx::query_scalar(
        "SELECT w.variant_id FROM account.wishlist w JOIN catalog.variant v ON v.id = w.variant_id
         WHERE w.user_id = $1 AND v.product_id = $2 ORDER BY w.variant_id",
    )
    .bind(user_id)
    .bind(product_id)
    .fetch_all(pool)
    .await
}

pub async fn variant_exists(pool: &PgPool, variant_id: i64) -> sqlx::Result<bool> {
    sqlx::query_scalar("SELECT EXISTS (SELECT 1 FROM catalog.variant WHERE id = $1)").bind(variant_id).fetch_one(pool).await
}
