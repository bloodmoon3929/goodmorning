use chrono::{DateTime, NaiveDate, Utc};
use serde::Deserialize;
use serde_json::Value;
use sqlx::{FromRow, types::Json};

/// catalog.ip + 별칭
#[derive(Debug, Clone, FromRow)]
pub struct Ip {
    pub id: i64,
    pub name: String,
    pub category: String,
    pub image_url: Option<String>,
    pub aliases: Vec<String>,
}

#[derive(Debug, Clone, FromRow)]
pub struct IpStat {
    pub id: i64,
    pub character_count: i64,
    pub goods_count: i64,
}

/// catalog.character
#[derive(Debug, Clone, FromRow)]
pub struct Character {
    pub id: i64,
    pub ip_id: i64,
    pub name: String,
    pub image_url: Option<String>,
}

/// catalog.variant (상품 행에 JSON으로 묶여 온다)
#[derive(Debug, Clone, Deserialize)]
pub struct Variant {
    pub id: i64,
    pub name: String,
    pub attrs: Option<Value>,
    pub is_default: bool,
}

/// catalog.product + IP 이름
#[derive(Debug, Clone, FromRow)]
pub struct Product {
    pub id: i64,
    pub ip_id: i64,
    pub ip_name: String,
    pub name: String,
    #[sqlx(rename = "type")]
    pub kind: String,
    pub maker: Option<String>,
    pub description: Option<String>,
    pub release_date: Option<NaiveDate>,
    pub image_url: Option<String>,
    pub created_at: DateTime<Utc>,
}

/// 목록 · 카드에 쓰는 상품 한 줄: 상품 + IP · 캐릭터 이름 + 버전 + 판매 경로 요약
#[derive(Debug, Clone, FromRow)]
pub struct ProductSummary {
    pub id: i64,
    pub ip_id: i64,
    pub ip_name: String,
    pub name: String,
    #[sqlx(rename = "type")]
    pub kind: String,
    pub image_url: Option<String>,
    pub release_date: Option<NaiveDate>,
    pub character_ids: Vec<i64>,
    pub character_names: Vec<String>,
    pub variants: Json<Vec<Variant>>,
    /// 온라인: 품절 아닌 판매 몰 수
    pub online_malls: i64,
    /// 배송비 포함 최저 총액 (배송비를 아는 판매만)
    pub min_total: Option<i32>,
    /// 오프라인: 근처에 재고 있는 매장 수 (48시간 안에 확인된 것만)
    pub nearby_stores: i64,
    pub nearest_m: Option<f64>,
    /// 인기 = 찜 수 + 구매하러 가기 수
    pub popularity: i64,
}

/// 비슷한 상품 후보와 점수 재료
#[derive(Debug, Clone, FromRow)]
pub struct SimilarCandidate {
    pub id: i64,
    pub ip_id: i64,
    pub shared_characters: i64,
    pub same_type: bool,
    pub same_ip: bool,
}

/// 검색어 별칭 안내 (먼작귀 → 치이카와)
#[derive(Debug, Clone, FromRow)]
pub struct AliasHit {
    pub alias: String,
    pub ip_name: String,
}
