//! 구매하러 가기: 누른 시점의 몰 · 가격을 이동 기록으로 남긴다

use sqlx::PgPool;

use crate::models::online::Offer;

pub async fn offer(pool: &PgPool, id: i64) -> sqlx::Result<Option<Offer>> {
    sqlx::query_as(
        "SELECT o.id, o.variant_id, o.mall_id, m.name AS mall_name, o.title, o.url, o.price, o.shipping_fee, o.total_price,
                o.sold_out, o.source, o.observed_at
         FROM online.offer o JOIN online.mall m ON m.id = o.mall_id AND m.is_active
         WHERE o.id = $1",
    )
    .bind(id)
    .fetch_optional(pool)
    .await
}

pub async fn insert_click(pool: &PgPool, user_id: Option<i64>, offer: &Offer) -> sqlx::Result<i64> {
    sqlx::query_scalar(
        "INSERT INTO account.outbound_click (user_id, offer_id, variant_id, price_snapshot, shipping_snapshot)
         VALUES ($1, $2, $3, $4, $5) RETURNING id",
    )
    .bind(user_id)
    .bind(offer.id)
    .bind(offer.variant_id)
    .bind(offer.price)
    .bind(offer.shipping_fee)
    .fetch_one(pool)
    .await
}
