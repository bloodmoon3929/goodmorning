use axum::{Router, routing::get};

use crate::{AppState, controllers::catalog as c};

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/ips", get(c::list_ips))
        .route("/ips/stats", get(c::ip_stats))
        .route("/ips/{id}", get(c::ip_detail))
        .route("/characters/{id}", get(c::character_detail))
}
