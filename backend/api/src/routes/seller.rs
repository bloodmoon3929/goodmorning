use axum::{
    Router,
    middleware::from_fn_with_state,
    routing::{get, post, put},
};

use crate::{AppState, controllers::seller as c, middleware::seller::require_store_member};

pub fn routes(state: AppState) -> Router<AppState> {
    // {store_id}가 들어간 주소는 본인 매장인지 먼저 확인한다
    let per_store = Router::new()
        .route("/seller/stores/{store_id}", get(c::store))
        .route("/seller/stores/{store_id}/stock", put(c::save_stock))
        .route("/seller/stores/{store_id}/stock/confirm", post(c::confirm_all))
        .route("/seller/stores/{store_id}/reports", get(c::reports))
        .route("/seller/stores/{store_id}/reports/{report_id}/approve", post(c::approve_report))
        .route("/seller/stores/{store_id}/reports/{report_id}/reject", post(c::reject_report))
        .route("/seller/stores/{store_id}/product-requests", post(c::request_product))
        .route_layer(from_fn_with_state(state, require_store_member));
    Router::new().route("/seller/stores", get(c::my_stores)).merge(per_store)
}
