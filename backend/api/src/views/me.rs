use chrono::{DateTime, NaiveDate, Utc};
use serde::Serialize;

use super::product::ProductCard;
use crate::models::{
    account::{Alert, Issue, Notification, Purchase, Visit, Wish},
    catalog::ProductSummary,
};

#[derive(Serialize)]
pub struct WishView {
    pub variant_id: i64,
    pub variant_name: String,
    pub created_at: DateTime<Utc>,
    pub product: ProductCard,
}

impl From<(Wish, ProductSummary)> for WishView {
    fn from((w, s): (Wish, ProductSummary)) -> Self {
        Self { variant_id: w.variant_id, variant_name: w.variant_name, created_at: w.created_at, product: s.into() }
    }
}

#[derive(Serialize)]
pub struct AlertView {
    pub id: i64,
    /// price(목표가 이하) · restock(재입고) · stock_in(매장 입고)
    #[serde(rename = "type")]
    pub kind: String,
    pub variant_id: Option<i64>,
    pub variant_name: Option<String>,
    pub product_id: Option<i64>,
    pub product_name: Option<String>,
    pub store_id: Option<i64>,
    pub store_name: Option<String>,
    pub target_price: Option<i32>,
    pub is_active: bool,
}

impl From<Alert> for AlertView {
    fn from(a: Alert) -> Self {
        Self {
            id: a.id,
            kind: a.kind,
            variant_id: a.variant_id,
            variant_name: a.variant_name,
            product_id: a.product_id,
            product_name: a.product_name,
            store_id: a.store_id,
            store_name: a.store_name,
            target_price: a.target_price,
            is_active: a.is_active,
        }
    }
}

#[derive(Serialize)]
pub struct NotificationView {
    pub id: i64,
    /// price · restock · stock_in · report · issue · new_goods
    #[serde(rename = "type")]
    pub kind: String,
    pub title: String,
    pub body: Option<String>,
    pub link: Option<String>,
    pub image_url: Option<String>,
    pub read: bool,
    pub created_at: DateTime<Utc>,
}

impl From<Notification> for NotificationView {
    fn from(n: Notification) -> Self {
        Self {
            id: n.id,
            kind: n.kind,
            title: n.title,
            body: n.body,
            link: n.link,
            image_url: n.image_url,
            read: n.read_at.is_some(),
            created_at: n.created_at,
        }
    }
}

/// 이동 기록: 구매하러 가기를 누른 시점의 몰 · 가격
#[derive(Serialize)]
pub struct VisitView {
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
    pub total_snapshot: Option<i32>,
    pub purchased: bool,
    pub purchase_id: Option<i64>,
}

impl From<Visit> for VisitView {
    fn from(v: Visit) -> Self {
        Self {
            total_snapshot: v.shipping_snapshot.map(|s| v.price_snapshot + s),
            purchased: v.purchase_id.is_some(),
            id: v.id,
            clicked_at: v.clicked_at,
            offer_id: v.offer_id,
            mall_name: v.mall_name,
            product_id: v.product_id,
            product_name: v.product_name,
            variant_id: v.variant_id,
            variant_name: v.variant_name,
            price_snapshot: v.price_snapshot,
            shipping_snapshot: v.shipping_snapshot,
            purchase_id: v.purchase_id,
        }
    }
}

#[derive(Serialize)]
pub struct PurchaseView {
    pub id: i64,
    /// online(이동 기록에서) · offline(매장에서)
    pub channel: &'static str,
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
}

impl From<Purchase> for PurchaseView {
    fn from(p: Purchase) -> Self {
        Self {
            channel: if p.click_id.is_some() { "online" } else { "offline" },
            id: p.id,
            product_id: p.product_id,
            product_name: p.product_name,
            variant_id: p.variant_id,
            variant_name: p.variant_name,
            click_id: p.click_id,
            mall_name: p.mall_name,
            store_id: p.store_id,
            store_name: p.store_name,
            price: p.price,
            purchased_on: p.purchased_on,
        }
    }
}

#[derive(Serialize)]
pub struct IssueView {
    pub id: i64,
    /// price · stock · fake · etc
    #[serde(rename = "type")]
    pub kind: String,
    pub content: String,
    pub click_id: Option<i64>,
    pub purchase_id: Option<i64>,
    pub mall_name: Option<String>,
    pub product_name: Option<String>,
    /// 구매하러 가기를 눌렀을 때 가격 (배송비 포함)
    pub price_snapshot_total: Option<i32>,
    /// 문의할 때 가격 (배송비 포함)
    pub price_now: Option<i32>,
    /// open · answered · closed
    pub state: String,
    pub answer: Option<String>,
    pub created_at: DateTime<Utc>,
}

impl From<Issue> for IssueView {
    fn from(i: Issue) -> Self {
        Self {
            price_snapshot_total: i.price_snapshot.map(|p| p + i.shipping_snapshot.unwrap_or(0)),
            id: i.id,
            kind: i.kind,
            content: i.content,
            click_id: i.click_id,
            purchase_id: i.purchase_id,
            mall_name: i.mall_name,
            product_name: i.product_name,
            price_now: i.price_now,
            state: i.state,
            answer: i.answer,
            created_at: i.created_at,
        }
    }
}
