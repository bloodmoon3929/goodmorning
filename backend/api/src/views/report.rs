use chrono::{DateTime, Utc};
use serde::Serialize;

use crate::{models::offline::StockReport, services::report::ReportOutcome};

#[derive(Serialize)]
pub struct ReportOutcomeView {
    pub id: i64,
    /// pending(검토 대기) · approved(반영됨)
    pub state: &'static str,
    pub applied: bool,
}

impl From<ReportOutcome> for ReportOutcomeView {
    fn from(o: ReportOutcome) -> Self {
        Self { id: o.id, state: o.state, applied: o.applied }
    }
}

#[derive(Serialize)]
pub struct StockReportView {
    pub id: i64,
    pub store_id: i64,
    pub store_name: String,
    pub product_id: i64,
    pub product_name: String,
    pub variant_id: i64,
    pub variant_name: String,
    pub user_id: i64,
    pub status: String,
    pub photo_url: Option<String>,
    pub state: String,
    pub created_at: DateTime<Utc>,
}

impl From<StockReport> for StockReportView {
    fn from(r: StockReport) -> Self {
        Self {
            id: r.id,
            store_id: r.store_id,
            store_name: r.store_name,
            product_id: r.product_id,
            product_name: r.product_name,
            variant_id: r.variant_id,
            variant_name: r.variant_name,
            user_id: r.user_id,
            status: r.status,
            photo_url: r.photo_url,
            state: r.state,
            created_at: r.created_at,
        }
    }
}
