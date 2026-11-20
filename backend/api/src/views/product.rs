use chrono::{DateTime, NaiveDate, Utc};
use serde::Serialize;
use serde_json::Value;

use super::{catalog::CharacterView, km};
use crate::{
    models::{
        catalog::{ProductSummary, Variant},
        offline::StockAtStore,
        online::Offer,
    },
    services::{product::ProductDetail, rules::type_label},
};

#[derive(Serialize)]
pub struct VariantView {
    pub id: i64,
    pub name: String,
    pub attrs: Option<Value>,
    pub is_default: bool,
}

impl From<Variant> for VariantView {
    fn from(v: Variant) -> Self {
        Self { id: v.id, name: v.name, attrs: v.attrs, is_default: v.is_default }
    }
}

/// 상품 카드의 배지 두 개: `온라인 4곳 · 최저 12,900원` / `근처 2곳 재고`
#[derive(Serialize)]
pub struct ChannelView {
    pub online_malls: i64,
    /// 배송비 포함 최저 총액
    pub min_total: Option<i32>,
    pub nearby_stores: i64,
    pub nearest_km: Option<f64>,
    pub has_online: bool,
    pub has_offline: bool,
}

/// 목록 · 카드에 쓰는 상품 한 줄
#[derive(Serialize)]
pub struct ProductCard {
    pub id: i64,
    pub ip_id: i64,
    pub ip_name: String,
    pub name: String,
    /// figure · doll · keyring · acrylic · plamodel · random
    #[serde(rename = "type")]
    pub kind: String,
    pub type_label: &'static str,
    pub image_url: Option<String>,
    pub release_date: Option<NaiveDate>,
    pub character_ids: Vec<i64>,
    pub character_names: Vec<String>,
    pub variants: Vec<VariantView>,
    pub channels: ChannelView,
    pub popularity: i64,
}

impl From<ProductSummary> for ProductCard {
    fn from(s: ProductSummary) -> Self {
        let has_online = s.online_malls > 0 && s.min_total.is_some();
        Self {
            id: s.id,
            ip_id: s.ip_id,
            ip_name: s.ip_name,
            type_label: type_label(&s.kind),
            kind: s.kind,
            name: s.name,
            image_url: s.image_url,
            release_date: s.release_date,
            character_ids: s.character_ids,
            character_names: s.character_names,
            variants: s.variants.0.into_iter().map(Into::into).collect(),
            channels: ChannelView {
                online_malls: s.online_malls,
                min_total: s.min_total,
                nearby_stores: s.nearby_stores,
                nearest_km: s.nearest_m.map(km),
                has_online,
                has_offline: s.nearby_stores > 0,
            },
            popularity: s.popularity,
        }
    }
}

/// 몰별 가격 한 줄. 외부 몰로 갈 때는 go_url(이동 기록을 남김)을 쓴다.
#[derive(Serialize)]
pub struct OfferView {
    pub id: i64,
    pub variant_id: i64,
    pub mall_id: i64,
    pub mall_name: String,
    pub title: Option<String>,
    pub price: i32,
    /// null: 배송비를 알 수 없음
    pub shipping_fee: Option<i32>,
    pub total_price: Option<i32>,
    pub sold_out: bool,
    /// api · crawl · seller
    pub source: String,
    pub observed_at: DateTime<Utc>,
    pub go_url: String,
}

impl From<Offer> for OfferView {
    fn from(o: Offer) -> Self {
        Self {
            go_url: format!("/offers/{}/go", o.id),
            id: o.id,
            variant_id: o.variant_id,
            mall_id: o.mall_id,
            mall_name: o.mall_name,
            title: o.title,
            price: o.price,
            shipping_fee: o.shipping_fee,
            total_price: o.total_price,
            sold_out: o.sold_out,
            source: o.source,
            observed_at: o.observed_at,
        }
    }
}

#[derive(Serialize)]
pub struct StoreBrief {
    pub id: i64,
    pub name: String,
    pub kind: Option<String>,
    pub distance_km: f64,
    pub popup_until: Option<NaiveDate>,
    pub has_owner: bool,
}

/// 상품 상세 · 오프라인 탭의 매장별 재고
#[derive(Serialize)]
pub struct StockAtStoreView {
    pub store: StoreBrief,
    pub variant_id: i64,
    /// many · few · none · unknown(확인 필요, 48시간 지남 포함)
    pub status: String,
    /// owner(사장님 확인) · report(제보) · crawl(수집)
    pub source: String,
    pub confirmed_at: DateTime<Utc>,
    pub price: Option<i32>,
}

impl From<StockAtStore> for StockAtStoreView {
    fn from(s: StockAtStore) -> Self {
        Self {
            store: StoreBrief {
                id: s.store_id,
                name: s.store_name,
                kind: s.store_kind,
                distance_km: km(s.distance_m),
                popup_until: s.popup_until,
                has_owner: s.has_owner,
            },
            variant_id: s.variant_id,
            status: s.status,
            source: s.source,
            confirmed_at: s.confirmed_at,
            price: s.price,
        }
    }
}

#[derive(Serialize)]
pub struct ProductDetailView {
    pub product: ProductCard,
    pub maker: Option<String>,
    pub description: Option<String>,
    pub characters: Vec<CharacterView>,
    pub offers: Vec<OfferView>,
    pub stocks: Vec<StockAtStoreView>,
    pub similar: Vec<ProductCard>,
    pub wished_variant_ids: Vec<i64>,
    /// 판매 경로가 하나도 없으면 true → `현재 판매처 없음` · 재입고 알림 권유
    pub no_seller: bool,
}

impl From<ProductDetail> for ProductDetailView {
    fn from(d: ProductDetail) -> Self {
        let no_seller = d.offers.iter().all(|o| o.sold_out) && d.stocks.iter().all(|s| !matches!(s.status.as_str(), "many" | "few"));
        Self {
            product: d.summary.into(),
            maker: d.product.maker,
            description: d.product.description,
            characters: d.characters.into_iter().map(Into::into).collect(),
            offers: d.offers.into_iter().map(Into::into).collect(),
            stocks: d.stocks.into_iter().map(Into::into).collect(),
            similar: d.similar.into_iter().map(Into::into).collect(),
            wished_variant_ids: d.wished_variant_ids,
            no_seller,
        }
    }
}
