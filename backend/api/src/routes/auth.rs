use axum::{
    Router,
    routing::{get, post},
};

use crate::{AppState, controllers::auth as c};

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/auth/signup", post(c::signup))
        .route("/auth/login", post(c::login))
        .route("/auth/email-taken", get(c::email_taken))
        .route("/me", get(c::me))
}
