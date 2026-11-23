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

/// online.mall + 판매처 · 수집 원본 수 (관리자 페이지)
#[derive(Debug, Clone, FromRow)]
pub struct MallStat {
    pub id: i64,
    pub name: String,
    pub site_url: Option<String>,
    pub source: String,
    pub api_name: Option<String>,
    pub crawl_allowed: bool,
    pub is_active: bool,
    pub offer_count: i64,
    pub raw_count: i64,
}
