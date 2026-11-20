use axum::{
    Router,
    routing::{get, post},
};

use crate::{AppState, controllers::offer as c};

pub fn routes() -> Router<AppState> {
    Router::new().route("/offers/{id}/click", post(c::click)).route("/offers/{id}/go", get(c::go))
}
