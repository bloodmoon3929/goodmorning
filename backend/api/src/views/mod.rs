//! V: 앱에 내려줄 JSON 모양. 화면에 필요한 필드만 담는다 (비밀번호 해시 같은 DB 컬럼은 여기로 오지 않는다).
//! 시각은 RFC 3339 (UTC), 거리는 km, 가격은 원.

pub mod admin;
pub mod auth;
pub mod catalog;
pub mod me;
pub mod offer;
pub mod product;
pub mod report;
pub mod search;
pub mod seller;
pub mod store;

use serde::Serialize;

/// 목록 응답 공통 모양
#[derive(Serialize)]
pub struct List<T: Serialize> {
    pub items: Vec<T>,
}

impl<T: Serialize> List<T> {
    pub fn of(items: Vec<T>) -> Self {
        Self { items }
    }
}

/// 만들기 · 바꾸기 결과
#[derive(Serialize)]
pub struct Done {
    pub ok: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub id: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub count: Option<u64>,
}

impl Done {
    pub fn ok() -> Self {
        Self { ok: true, id: None, count: None }
    }
    pub fn id(id: i64) -> Self {
        Self { ok: true, id: Some(id), count: None }
    }
    pub fn count(n: u64) -> Self {
        Self { ok: true, id: None, count: Some(n) }
    }
}

pub fn km(meters: f64) -> f64 {
    (meters / 100.0).round() / 10.0
}
