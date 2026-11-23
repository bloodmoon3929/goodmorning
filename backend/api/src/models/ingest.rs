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

/// ingest.collect_run — 관리자 페이지에서 시작한 수집 실행 (수집기 워커가 꺼내 간다)
#[derive(Debug, Clone, FromRow)]
pub struct CollectRun {
    pub id: i64,
    pub kind: String,
    pub params: Json<Value>,
    pub status: String,
    pub requested_by: Option<i64>,
    pub item_count: i32,
    pub error: Option<String>,
    pub created_at: DateTime<Utc>,
    pub started_at: Option<DateTime<Utc>>,
    pub finished_at: Option<DateTime<Utc>>,
}

/// ingest.collect_event — 실행 중 단계 하나 (robots.txt 확인, 페이지 요청, 서명, API 응답, 저장 …)
#[derive(Debug, Clone, FromRow)]
pub struct CollectEvent {
    pub id: i64,
    pub run_id: i64,
    pub at: DateTime<Utc>,
    pub step: String,
    pub level: String,
    pub message: String,
    pub data: Option<Json<Value>>,
}

/// ingest.collect_worker — 수집기 워커 생존 신호
#[derive(Debug, Clone, FromRow)]
pub struct CollectWorker {
    pub name: String,
    pub pid: i32,
    pub seen_at: DateTime<Utc>,
}

/// 매칭 후보: 카탈로그 버전 + 상품 · IP 이름, 제목 낱말이 몇 개 겹치는지
#[derive(Debug, Clone, FromRow)]
pub struct VariantCandidate {
    pub variant_id: i64,
    pub variant_name: String,
    pub product_id: i64,
    pub product_name: String,
    pub ip_name: String,
    pub hits: i32,
}
