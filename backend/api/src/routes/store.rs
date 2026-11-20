use axum::{Router, routing::get};

use crate::{AppState, controllers::store as c};

pub fn routes() -> Router<AppState> {
    Router::new().route("/stores", get(c::stores)).route("/stores/{id}", get(c::store_detail))
}
