use chrono::{DateTime, NaiveDate, Utc};
use serde::Serialize;
use serde_json::Value;

use super::km;
use crate::{
    models::offline::{Store, StoreItem},
    services::{
        rules::{today_hours, type_label},
        store::{StoreDetail, marker_status},
    },
};

#[derive(Serialize)]
pub struct HoursToday {
    pub open: String,
    pub close: String,
}

/// 매장 찾기 리스트 · 지도 마커 · 홈의 내 주변 재고 카드
#[derive(Serialize)]
pub struct StoreView {
    pub id: i64,
    pub name: String,
    pub kind: Option<String>,
    pub address: String,
    pub lat: f64,
    pub lng: f64,
    pub phone: Option<String>,
    pub distance_km: f64,
    /// 오늘 영업시간 (휴무면 null)
    pub today: Option<HoursToday>,
    pub open_now: bool,
    /// 팝업스토어 종료일
    pub popup_until: Option<NaiveDate>,
    /// owner · report · crawl
    pub info_source: String,
    pub updated_at: DateTime<Utc>,
    pub has_owner: bool,
    /// 내 IP 굿즈 중 재고 있는 수
    pub my_ip_stock: i64,
    /// 지도 마커 색: many · few · none · unknown
    pub marker_status: &'static str,
}

impl From<Store> for StoreView {
    fn from(s: Store) -> Self {
        let (today, open_now) = today_hours(s.hours.as_ref().map(|h| &h.0), Utc::now());
        Self {
            marker_status: marker_status(&s),
            id: s.id,
            name: s.name,
            kind: s.kind,
            address: s.address,
            lat: s.lat,
            lng: s.lng,
            phone: s.phone,
            distance_km: km(s.distance_m),
            today: today.map(|(open, close)| HoursToday { open, close }),
            open_now,
            popup_until: s.popup_until,
            info_source: s.info_source,
            updated_at: s.updated_at,
            has_owner: s.has_owner,
            my_ip_stock: s.my_ip_in_stock,
        }
    }
}

#[derive(Serialize)]
pub struct StoreItemView {
    pub product_id: i64,
    pub product_name: String,
    pub product_image: Option<String>,
    pub ip_name: String,
    #[serde(rename = "type")]
    pub kind: String,
    pub type_label: &'static str,
    pub variant_id: i64,
    pub variant_name: String,
    pub status: String,
    pub source: String,
    pub confirmed_at: DateTime<Utc>,
    pub price: Option<i32>,
}

impl From<StoreItem> for StoreItemView {
    fn from(i: StoreItem) -> Self {
        Self {
            type_label: type_label(&i.kind),
            product_id: i.product_id,
            product_name: i.product_name,
            product_image: i.product_image,
            ip_name: i.ip_name,
            kind: i.kind,
            variant_id: i.variant_id,
            variant_name: i.variant_name,
            status: i.status,
            source: i.source,
            confirmed_at: i.confirmed_at,
            price: i.price,
        }
    }
}

#[derive(Serialize)]
pub struct StoreDetailView {
    pub store: StoreView,
    /// 요일별 영업시간 원본 ({"mon": {"open", "close"}, "tue": null …})
    pub hours: Option<Value>,
    pub items: Vec<StoreItemView>,
    pub saved: bool,
}

impl From<StoreDetail> for StoreDetailView {
    fn from(d: StoreDetail) -> Self {
        let hours = d.store.hours.as_ref().map(|h| h.0.clone());
        Self { store: d.store.into(), hours, items: d.items.into_iter().map(Into::into).collect(), saved: d.saved }
    }
}
