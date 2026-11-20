use chrono::{DateTime, NaiveDate, Utc};
use sqlx::FromRow;

/// account.app_user (password_hash가 있으므로 그대로 응답에 쓰지 않는다)
#[derive(Debug, Clone, FromRow)]
pub struct AppUser {
    pub id: i64,
    pub email: Option<String>,
    pub password_hash: Option<String>,
    pub provider: String,
    pub nickname: String,
    pub home_area: Option<String>,
    pub role: String,
    pub agree_location: bool,
    pub agree_push: bool,
    pub created_at: DateTime<Utc>,
}

/// account.notification
#[derive(Debug, Clone, FromRow)]
pub struct Notification {
    pub id: i64,
    #[sqlx(rename = "type")]
    pub kind: String,
    pub title: String,
    pub body: Option<String>,
    pub link: Option<String>,
    pub image_url: Option<String>,
    pub read_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
}

/// account.outbound_click + 몰 · 상품 이름 + 구매 여부
#[derive(Debug, Clone, FromRow)]
pub struct Visit {
    pub id: i64,
    pub clicked_at: DateTime<Utc>,
    pub offer_id: i64,
    pub mall_name: String,
    pub product_id: i64,
    pub product_name: String,
    pub variant_id: i64,
    pub variant_name: String,
    pub price_snapshot: i32,
    pub shipping_snapshot: Option<i32>,
    pub purchase_id: Option<i64>,
}

/// account.purchase + 이름
#[derive(Debug, Clone, FromRow)]
pub struct Purchase {
    pub id: i64,
    pub product_id: i64,
    pub product_name: String,
    pub variant_id: i64,
    pub variant_name: String,
    pub click_id: Option<i64>,
    pub mall_name: Option<String>,
    pub store_id: Option<i64>,
    pub store_name: Option<String>,
    pub price: Option<i32>,
    pub purchased_on: Option<NaiveDate>,
    pub created_at: DateTime<Utc>,
}

/// account.issue + 이동 기록 스냅샷
#[derive(Debug, Clone, FromRow)]
pub struct Issue {
    pub id: i64,
    pub click_id: Option<i64>,
    pub purchase_id: Option<i64>,
    #[sqlx(rename = "type")]
    pub kind: String,
    pub content: String,
    pub price_now: Option<i32>,
    pub price_snapshot: Option<i32>,
    pub shipping_snapshot: Option<i32>,
    pub mall_name: Option<String>,
    pub product_name: Option<String>,
    pub state: String,
    pub answer: Option<String>,
    pub created_at: DateTime<Utc>,
}

/// account.alert + 이름
#[derive(Debug, Clone, FromRow)]
pub struct Alert {
    pub id: i64,
    pub variant_id: Option<i64>,
    pub variant_name: Option<String>,
    pub product_id: Option<i64>,
    pub product_name: Option<String>,
    pub store_id: Option<i64>,
    pub store_name: Option<String>,
    #[sqlx(rename = "type")]
    pub kind: String,
    pub target_price: Option<i32>,
    pub is_active: bool,
}

/// 찜한 버전
#[derive(Debug, Clone, FromRow)]
pub struct Wish {
    pub product_id: i64,
    pub variant_id: i64,
    pub variant_name: String,
    pub created_at: DateTime<Utc>,
}

/// 저장한 매장
#[derive(Debug, Clone, FromRow)]
pub struct SavedStore {
    pub store_id: i64,
    pub created_at: DateTime<Utc>,
}
