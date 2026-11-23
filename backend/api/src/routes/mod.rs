//! URL ↔ 컨트롤러 연결. 화면 명세의 버튼 하나 = API 하나 = route 한 줄.
//! 전체 목록과 화면 대응은 backend/README.md의 API 명세 표.

mod admin;
mod auth;
mod catalog;
mod console;
mod me;
mod offer;
mod product;
mod report;
mod search;
mod seller;
mod store;

use axum::{Router, http::HeaderValue};
use tower_http::{
    cors::{AllowOrigin, Any, CorsLayer},
    trace::TraceLayer,
};

use crate::AppState;

pub fn router(state: AppState) -> Router {
    let cors = cors(&state.config.cors_origins);
    Router::new()
        .merge(admin::routes())
        .merge(auth::routes())
        .merge(catalog::routes())
        .merge(console::routes())
        .merge(me::routes())
        .merge(offer::routes())
        .merge(product::routes())
        .merge(report::routes())
        .merge(search::routes())
        .merge(seller::routes(state.clone()))
        .merge(store::routes())
        .layer(TraceLayer::new_for_http())
        .layer(cors)
        .with_state(state)
}

fn cors(origins: &[String]) -> CorsLayer {
    // allow_private_network: GitHub Pages에 올린 관리자 페이지(https)가 이 PC의 API(localhost)를 부를 수 있게 (Chrome 사설망 접근 확인)
    let layer = CorsLayer::new().allow_methods(Any).allow_headers(Any).allow_private_network(true);
    if origins.is_empty() {
        return layer.allow_origin(Any);
    }
    let list: Vec<HeaderValue> = origins.iter().filter_map(|o| o.parse().ok()).collect();
    layer.allow_origin(AllowOrigin::list(list))
}
