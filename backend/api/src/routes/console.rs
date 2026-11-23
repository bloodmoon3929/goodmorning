use axum::{Router, routing::get};

use crate::{AppState, controllers::console as c};

/// 관리자 페이지: http://localhost:8080/console/
pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/console", get(c::redirect))
        .route("/console/", get(c::index))
        .route("/console/app.js", get(c::app_js))
        .route("/console/style.css", get(c::style))
        .route("/console/logo.png", get(c::logo))
}
