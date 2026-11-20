use chrono::{DateTime, Utc};
use serde_json::Value;
use sqlx::{FromRow, types::Json};

/// ingest.raw_listing + 몰 이름
#[derive(Debug, Clone, FromRow)]
pub struct RawListing {
    pub id: i64,
    pub mall_id: Option<i64>,
    pub mall_name: Option<String>,
    pub source: String,
    pub source_url: String,
    pub title: Option<String>,
    pub price: Option<i32>,
    pub shipping_fee: Option<i32>,
    pub image_url: Option<String>,
    pub payload: Option<Json<Value>>,
    pub match_state: String,
    pub matched_variant_id: Option<i64>,
    pub match_score: Option<f32>,
    pub collected_at: DateTime<Utc>,
}

/// ingest.collect_job + 몰 이름
#[derive(Debug, Clone, FromRow)]
pub struct CollectJob {
    pub id: i64,
    pub mall_id: Option<i64>,
    pub mall_name: Option<String>,
    pub kind: String,
    pub status: String,
    pub item_count: i32,
    pub error: Option<String>,
    pub started_at: DateTime<Utc>,
    pub finished_at: Option<DateTime<Utc>>,
}
