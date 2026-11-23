use axum::{
    Router,
    routing::{get, patch, post},
};

use crate::{AppState, controllers::admin as c};

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/health", get(c::health))
        .route("/admin/raw-listings", get(c::raw_listings))
        .route("/admin/raw-listings/{id}/match", post(c::match_raw))
        .route("/admin/raw-listings/{id}/reject", post(c::reject_raw))
        .route("/admin/raw-listings/{id}/candidates", get(c::raw_candidates))
        .route("/admin/collect-jobs", get(c::collect_jobs))
        .route("/admin/malls", get(c::malls))
        .route("/admin/malls/{id}", patch(c::update_mall))
        .route("/admin/collect-runs", get(c::runs).post(c::start_run))
        .route("/admin/collect-runs/{id}", get(c::run_detail))
        .route("/admin/collector", get(c::collector))
}
