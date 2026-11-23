//! 관리자 페이지 (/console/) — HTML · JS · CSS · 로고를 바이너리에 넣어서 내려준다 (빌드 단계 없음).
//! 화면에서 쓰는 데이터는 모두 /admin/* API (운영자 로그인 필요).

use axum::{
    http::header,
    response::{IntoResponse, Redirect},
};

const INDEX: &str = include_str!("../../console/index.html");
const APP_JS: &str = include_str!("../../console/app.js");
const STYLE: &str = include_str!("../../console/style.css");
const LOGO: &[u8] = include_bytes!("../../console/logo.png");

pub async fn redirect() -> Redirect {
    Redirect::permanent("/console/")
}

pub async fn index() -> impl IntoResponse {
    ([(header::CONTENT_TYPE, "text/html; charset=utf-8"), (header::CACHE_CONTROL, "no-cache")], INDEX)
}

pub async fn app_js() -> impl IntoResponse {
    ([(header::CONTENT_TYPE, "text/javascript; charset=utf-8"), (header::CACHE_CONTROL, "no-cache")], APP_JS)
}

pub async fn style() -> impl IntoResponse {
    ([(header::CONTENT_TYPE, "text/css; charset=utf-8"), (header::CACHE_CONTROL, "no-cache")], STYLE)
}

pub async fn logo() -> impl IntoResponse {
    ([(header::CONTENT_TYPE, "image/png")], LOGO)
}
