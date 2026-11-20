use axum::{
    Router,
    routing::{delete, get, post, put},
};

use crate::{AppState, controllers::me as c};

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/me/ips", put(c::set_my_ips))
        .route("/me/ip-requests", post(c::request_ip))
        .route("/me/wishlist", get(c::wishlist))
        .route("/me/wishlist/{variant_id}", put(c::add_wish).delete(c::remove_wish))
        .route("/me/saved-stores", get(c::saved_stores))
        .route("/me/saved-stores/{store_id}", put(c::save_store).delete(c::unsave_store))
        .route("/me/alerts", get(c::alerts).post(c::create_alert))
        .route("/me/alerts/{id}", delete(c::delete_alert))
        .route("/me/notifications", get(c::notifications))
        .route("/me/notifications/read-all", post(c::read_all_notifications))
        .route("/me/notifications/{id}/read", post(c::read_notification))
        .route("/me/visits", get(c::visits))
        .route("/me/purchases", get(c::purchases).post(c::create_purchase))
        .route("/me/issues", get(c::issues).post(c::create_issue))
}
