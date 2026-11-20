use chrono::{DateTime, NaiveDate, Utc};
use serde_json::Value;
use sqlx::{FromRow, types::Json};

/// offline.store + 거리 · 사장님 여부 · 내 IP 재고 집계
#[derive(Debug, Clone, FromRow)]
pub struct Store {
    pub id: i64,
    pub name: String,
    pub kind: Option<String>,
    pub address: String,
    pub lat: f64,
    pub lng: f64,
    pub phone: Option<String>,
    pub hours: Option<Json<Value>>,
    pub popup_until: Option<NaiveDate>,
    pub info_source: String,
    pub is_closed: bool,
    pub updated_at: DateTime<Utc>,
    pub distance_m: f64,
    /// 판매자 계정이 연결된 매장 (제보 반영 방식이 다르다)
    pub has_owner: bool,
    /// 내 IP 굿즈 중 재고 있음(많음 · 적음, 48시간 안 확인) 수
    pub my_ip_in_stock: i64,
    pub my_ip_total: i64,
    /// 내 IP 굿즈 중 확인 필요(오래됨 포함) 수
    pub my_ip_unknown: i64,
}

/// 상품 상세의 매장별 재고 한 줄
#[derive(Debug, Clone, FromRow)]
pub struct StockAtStore {
    pub store_id: i64,
    pub store_name: String,
    pub store_kind: Option<String>,
    pub popup_until: Option<NaiveDate>,
    pub distance_m: f64,
    pub has_owner: bool,
    pub variant_id: i64,
    pub status: String,
    pub source: String,
    pub confirmed_at: DateTime<Utc>,
    pub price: Option<i32>,
}

/// 매장 상세 · 판매자 센터의 재고 한 줄
#[derive(Debug, Clone, FromRow)]
pub struct StoreItem {
    pub product_id: i64,
    pub product_name: String,
    pub product_image: Option<String>,
    pub ip_name: String,
    #[sqlx(rename = "type")]
    pub kind: String,
    pub variant_id: i64,
    pub variant_name: String,
    pub status: String,
    pub source: String,
    pub confirmed_at: DateTime<Utc>,
    pub price: Option<i32>,
}

/// offline.stock_report
#[derive(Debug, Clone, FromRow)]
pub struct StockReport {
    pub id: i64,
    pub store_id: i64,
    pub store_name: String,
    pub variant_id: i64,
    pub variant_name: String,
    pub product_id: i64,
    pub product_name: String,
    pub user_id: i64,
    pub status: String,
    pub photo_url: Option<String>,
    pub state: String,
    pub created_at: DateTime<Utc>,
}
