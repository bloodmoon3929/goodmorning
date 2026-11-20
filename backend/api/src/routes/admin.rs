use axum::{
    Router,
    routing::{get, post},
};

use crate::{AppState, controllers::admin as c};

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/health", get(c::health))
        .route("/admin/raw-listings", get(c::raw_listings))
        .route("/admin/raw-listings/{id}/match", post(c::match_raw))
        .route("/admin/raw-listings/{id}/reject", post(c::reject_raw))
        .route("/admin/collect-jobs", get(c::collect_jobs))
}
