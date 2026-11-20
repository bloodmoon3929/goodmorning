use axum::{Router, routing::get};

use crate::{AppState, controllers::search as c};

pub fn routes() -> Router<AppState> {
    Router::new().route("/search", get(c::search))
}
