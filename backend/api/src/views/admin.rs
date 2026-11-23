use chrono::{DateTime, Utc};
use serde::Serialize;
use serde_json::Value;

use crate::{
    models::{
        ingest::{CollectEvent, CollectJob, CollectRun, RawListing, VariantCandidate},
        online::MallStat,
    },
    services::admin::{CollectorStatus, RunDetail},
};

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

#[derive(Serialize)]
pub struct MallView {
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

impl From<MallStat> for MallView {
    fn from(m: MallStat) -> Self {
        Self {
            id: m.id,
            name: m.name,
            site_url: m.site_url,
            source: m.source,
            api_name: m.api_name,
            crawl_allowed: m.crawl_allowed,
            is_active: m.is_active,
            offer_count: m.offer_count,
            raw_count: m.raw_count,
        }
    }
}

#[derive(Serialize)]
pub struct RunView {
    pub id: i64,
    pub kind: String,
    pub params: Value,
    pub status: String,
    pub item_count: i32,
    pub error: Option<String>,
    pub created_at: DateTime<Utc>,
    pub started_at: Option<DateTime<Utc>>,
    pub finished_at: Option<DateTime<Utc>>,
}

impl From<CollectRun> for RunView {
    fn from(r: CollectRun) -> Self {
        Self {
            id: r.id,
            kind: r.kind,
            params: r.params.0,
            status: r.status,
            item_count: r.item_count,
            error: r.error,
            created_at: r.created_at,
            started_at: r.started_at,
            finished_at: r.finished_at,
        }
    }
}

#[derive(Serialize)]
pub struct EventView {
    pub id: i64,
    pub at: DateTime<Utc>,
    pub step: String,
    pub level: String,
    pub message: String,
    pub data: Option<Value>,
}

impl From<CollectEvent> for EventView {
    fn from(e: CollectEvent) -> Self {
        Self { id: e.id, at: e.at, step: e.step, level: e.level, message: e.message, data: e.data.map(|d| d.0) }
    }
}

/// 실행 하나: 상태 + after 뒤의 새 기록 + 몰별 작업
#[derive(Serialize)]
pub struct RunDetailView {
    pub run: RunView,
    pub events: Vec<EventView>,
    pub jobs: Vec<CollectJobView>,
}

impl From<RunDetail> for RunDetailView {
    fn from(d: RunDetail) -> Self {
        Self { run: d.run.into(), events: d.events.into_iter().map(Into::into).collect(), jobs: d.jobs.into_iter().map(Into::into).collect() }
    }
}

#[derive(Serialize)]
pub struct CollectorStatusView {
    pub worker_alive: bool,
    pub worker_name: Option<String>,
    pub worker_seen_at: Option<DateTime<Utc>>,
    pub queued: i64,
    pub running: i64,
}

impl From<CollectorStatus> for CollectorStatusView {
    fn from(s: CollectorStatus) -> Self {
        Self {
            worker_alive: s.alive,
            worker_name: s.worker.as_ref().map(|w| w.name.clone()),
            worker_seen_at: s.worker.map(|w| w.seen_at),
            queued: s.queued,
            running: s.running,
        }
    }
}

#[derive(Serialize)]
pub struct CandidateView {
    pub variant_id: i64,
    pub variant_name: String,
    pub product_id: i64,
    pub product_name: String,
    pub ip_name: String,
    pub hits: i32,
    /// 수집할 때 이 버전의 검색어로 찾은 것인지
    pub from_query: bool,
}

#[derive(Serialize)]
pub struct CandidatesView {
    pub raw: RawListingView,
    pub items: Vec<CandidateView>,
}

impl CandidatesView {
    pub fn new(raw: RawListing, list: Vec<VariantCandidate>, hint: Option<i64>) -> Self {
        Self {
            raw: raw.into(),
            items: list
                .into_iter()
                .map(|c| CandidateView {
                    from_query: Some(c.variant_id) == hint,
                    variant_id: c.variant_id,
                    variant_name: c.variant_name,
                    product_id: c.product_id,
                    product_name: c.product_name,
                    ip_name: c.ip_name,
                    hits: c.hits,
                })
                .collect(),
        }
    }
}
