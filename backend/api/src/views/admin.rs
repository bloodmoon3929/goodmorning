use chrono::{DateTime, Utc};
use serde::Serialize;
use serde_json::Value;

use crate::models::ingest::{CollectJob, RawListing};

#[derive(Serialize)]
pub struct RawListingView {
    pub id: i64,
    pub mall_id: Option<i64>,
    pub mall_name: Option<String>,
    pub source: String,
    pub source_url: String,
    pub title: Option<String>,
    pub price: Option<i32>,
    pub shipping_fee: Option<i32>,
    pub image_url: Option<String>,
    pub payload: Option<Value>,
    pub match_state: String,
    pub matched_variant_id: Option<i64>,
    pub match_score: Option<f32>,
    pub collected_at: DateTime<Utc>,
}

impl From<RawListing> for RawListingView {
    fn from(r: RawListing) -> Self {
        Self {
            id: r.id,
            mall_id: r.mall_id,
            mall_name: r.mall_name,
            source: r.source,
            source_url: r.source_url,
            title: r.title,
            price: r.price,
            shipping_fee: r.shipping_fee,
            image_url: r.image_url,
            payload: r.payload.map(|p| p.0),
            match_state: r.match_state,
            matched_variant_id: r.matched_variant_id,
            match_score: r.match_score,
            collected_at: r.collected_at,
        }
    }
}

#[derive(Serialize)]
pub struct CollectJobView {
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

impl From<CollectJob> for CollectJobView {
    fn from(j: CollectJob) -> Self {
        Self {
            id: j.id,
            mall_id: j.mall_id,
            mall_name: j.mall_name,
            kind: j.kind,
            status: j.status,
            item_count: j.item_count,
            error: j.error,
            started_at: j.started_at,
            finished_at: j.finished_at,
        }
    }
}
