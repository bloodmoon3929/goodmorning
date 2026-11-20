use chrono::{DateTime, Utc};
use sqlx::FromRow;

/// online.offer + 몰 이름
#[derive(Debug, Clone, FromRow)]
pub struct Offer {
    pub id: i64,
    pub variant_id: i64,
    pub mall_id: i64,
    pub mall_name: String,
    pub title: Option<String>,
    pub url: String,
    pub price: i32,
    pub shipping_fee: Option<i32>,
    pub total_price: Option<i32>,
    pub sold_out: bool,
    pub source: String,
    pub observed_at: DateTime<Utc>,
}
