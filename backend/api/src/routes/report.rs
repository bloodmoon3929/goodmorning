use axum::{
    Router,
    routing::{get, post},
};

use crate::{AppState, controllers::report as c};

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/stock-reports", post(c::create_stock_report))
        .route("/me/stock-reports", get(c::my_reports))
        .route("/store-suggestions", post(c::create_store_suggestion))
}
