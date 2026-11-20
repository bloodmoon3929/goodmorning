//! DB 접근만. 값은 항상 bind 매개변수로 넘긴다 (SQL 인젝션 방지).
//! 업무 규칙(48시간, 근처 거리 …)은 services가 정해서 인자로 넘긴다.

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

/// 위치 매개변수 묶음 (경도 · 위도 순서는 PostGIS ST_MakePoint와 같다)
pub const POINT_SQL: &str = "ST_SetSRID(ST_MakePoint($2, $3), 4326)::geography";

/// 한국 시간 기준 오늘 (팝업 종료일 비교)
pub const TODAY_KST_SQL: &str = "(now() AT TIME ZONE 'Asia/Seoul')::date";
