//! 상품 카드 · 상품 상세

use std::collections::HashMap;

use chrono::Utc;
use sqlx::PgPool;

use super::rules::{self, Channel, GeoPoint};
use crate::{
    error::{AppError, AppResult},
    middleware::AuthUser,
    models::{
        catalog::{Character, Product, ProductSummary},
        offline::StockAtStore,
        online::Offer,
    },
    repositories,
};

/// 비슷한 상품: 한 IP에 쏠리지 않도록 IP마다 최대 2개, 모두 4개
const SIMILAR_PER_IP: usize = 2;
const SIMILAR_TOTAL: usize = 4;

/// 상품 요약을 ids 순서대로 (없는 번호는 빠진다)
pub async fn summaries(pool: &PgPool, ids: &[i64], point: GeoPoint) -> AppResult<Vec<ProductSummary>> {
    if ids.is_empty() {
        return Ok(vec![]);
    }
    let rows = repositories::product::summaries(pool, ids, point.summary_params()).await?;
    let mut by_id: HashMap<i64, ProductSummary> = rows.into_iter().map(|r| (r.id, r)).collect();
    Ok(ids.iter().filter_map(|id| by_id.remove(id)).collect())
}

/// 내 IP 신상품 (홈)
pub async fn new_products(pool: &PgPool, ip_ids: &[i64], point: GeoPoint, channel: Channel, limit: usize) -> AppResult<Vec<ProductSummary>> {
    let ids = repositories::product::new_product_ids(pool, ip_ids, 200).await?;
    let list = summaries(pool, &ids, point).await?;
    Ok(list.into_iter().filter(|s| channel.keeps(s)).take(limit).collect())
}

pub struct ProductDetail {
    pub product: Product,
    pub summary: ProductSummary,
    pub characters: Vec<Character>,
    /// 품절은 맨 아래, 나머지는 배송비 포함 총액 오름차순
    pub offers: Vec<Offer>,
    /// 가까운 매장 순. status는 48시간 규칙을 적용한 값
    pub stocks: Vec<StockAtStore>,
    pub similar: Vec<ProductSummary>,
    pub wished_variant_ids: Vec<i64>,
}

pub async fn detail(pool: &PgPool, id: i64, point: GeoPoint, user: Option<AuthUser>) -> AppResult<ProductDetail> {
    let product = repositories::product::product(pool, id).await?.ok_or(AppError::NotFound("상품"))?;
    let summary = summaries(pool, &[id], point).await?.pop().ok_or(AppError::NotFound("상품"))?;
    let characters = repositories::catalog::characters_of_product(pool, id).await?;

    let mut offers = repositories::product::offers(pool, id).await?;
    rules::sort_offers(&mut offers);

    let now = Utc::now();
    let mut stocks = repositories::product::stocks(pool, id, point.lng, point.lat).await?;
    for s in &mut stocks {
        s.status = rules::effective_status(&s.status, s.confirmed_at, now).to_string();
    }

    let similar_ids = similar_ids(pool, id).await?;
    let similar = summaries(pool, &similar_ids, point).await?;
    let wished_variant_ids = match user {
        Some(u) => repositories::product::wished_variant_ids(pool, u.id, id).await?,
        None => vec![],
    };
    Ok(ProductDetail { product, summary, characters, offers, stocks, similar, wished_variant_ids })
}

/// 같은 캐릭터 > 같은 품목 > 같은 IP 순으로 점수를 매기고, IP마다 개수를 제한한다
async fn similar_ids(pool: &PgPool, id: i64) -> AppResult<Vec<i64>> {
    let mut candidates = repositories::product::similar_candidates(pool, id).await?;
    candidates.sort_by_key(|c| (std::cmp::Reverse(c.shared_characters * 2 + i64::from(c.same_type) + i64::from(c.same_ip)), c.id));
    let mut per_ip: HashMap<i64, usize> = HashMap::new();
    let mut picked = Vec::new();
    for c in candidates {
        let n = per_ip.entry(c.ip_id).or_default();
        if *n < SIMILAR_PER_IP {
            *n += 1;
            picked.push(c.id);
        }
        if picked.len() == SIMILAR_TOTAL {
            break;
        }
    }
    Ok(picked)
}
