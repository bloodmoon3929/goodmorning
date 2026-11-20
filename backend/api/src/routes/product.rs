use axum::{Router, routing::get};

use crate::{AppState, controllers::product as c};

pub fn routes() -> Router<AppState> {
    Router::new().route("/products", get(c::products)).route("/products/new", get(c::new_products)).route("/products/{id}", get(c::product_detail))
}
