//! C: 입력 검사 → 서비스 호출 → view로 응답. SQL을 직접 쓰지 않는다.

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

use serde::Deserialize;

use crate::{
    error::{AppError, AppResult},
    services::rules::GeoPoint,
};

/// `ids=1,2,3` 처럼 쉼표로 구분한 번호 목록. 값이 없으면 None
pub fn id_list(raw: Option<&str>) -> AppResult<Option<Vec<i64>>> {
    let Some(raw) = raw else { return Ok(None) };
    let ids: Result<Vec<i64>, _> = raw.split(',').map(str::trim).filter(|s| !s.is_empty()).map(str::parse).collect();
    let ids = ids.map_err(|_| AppError::bad("번호 목록은 1,2,3 형식입니다"))?;
    if ids.len() > 200 {
        return Err(AppError::bad("번호는 한 번에 200개까지입니다"));
    }
    Ok(Some(ids))
}

/// 위치 쿼리 (?lat=37.5&lng=126.9). 없으면 서울시청 기준
#[derive(Debug, Default, Deserialize)]
pub struct LocationQuery {
    pub lat: Option<f64>,
    pub lng: Option<f64>,
}

impl LocationQuery {
    pub fn point(&self) -> AppResult<GeoPoint> {
        GeoPoint::from_query(self.lat, self.lng)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_id_lists() {
        assert_eq!(id_list(None).unwrap(), None);
        assert_eq!(id_list(Some("")).unwrap(), Some(vec![]));
        assert_eq!(id_list(Some("3, 1,2")).unwrap(), Some(vec![3, 1, 2]));
        assert!(id_list(Some("1,a")).is_err());
    }
}
