//! 텍스트 검색 · 품목으로 보기

use sqlx::PgPool;

use super::{
    product,
    rules::{self, Channel, GeoPoint},
};
use crate::{
    error::{AppError, AppResult},
    models::catalog::{AliasHit, Ip, ProductSummary},
    repositories,
};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum Sort {
    #[default]
    Lowest,
    Nearest,
    Newest,
    Popular,
}

impl Sort {
    pub fn parse(s: Option<&str>, default: Self) -> AppResult<Self> {
        match s {
            None | Some("") => Ok(default),
            Some("lowest") => Ok(Self::Lowest),
            Some("nearest") => Ok(Self::Nearest),
            Some("newest") => Ok(Self::Newest),
            Some("popular") => Ok(Self::Popular),
            Some(_) => Err(AppError::bad("sort는 lowest · nearest · newest · popular 중 하나입니다")),
        }
    }

    /// 값이 없는 상품(판매처 없음 · 근처 재고 없음)은 뒤로
    pub fn apply(self, list: &mut [ProductSummary]) {
        match self {
            Self::Lowest => list.sort_by_key(|s| (s.min_total.is_none(), s.min_total.unwrap_or(0), s.id)),
            Self::Nearest => list.sort_by(|a, b| {
                let key = |s: &ProductSummary| s.nearest_m.unwrap_or(f64::MAX);
                key(a).total_cmp(&key(b)).then(a.id.cmp(&b.id))
            }),
            Self::Newest => list.sort_by_key(|s| (std::cmp::Reverse(s.release_date), s.id)),
            Self::Popular => list.sort_by_key(|s| (std::cmp::Reverse(s.popularity), s.id)),
        }
    }
}

pub struct SearchParams {
    pub text: String,
    pub kind: Option<String>,
    pub max_price: Option<i32>,
    pub sort: Sort,
    pub channel: Channel,
    pub point: GeoPoint,
    pub limit: usize,
    pub offset: usize,
}

pub struct SearchResult {
    pub items: Vec<ProductSummary>,
    pub total: usize,
    pub alias: Option<AliasHit>,
    pub ips: Vec<Ip>,
}

pub async fn search(pool: &PgPool, p: SearchParams) -> AppResult<SearchResult> {
    let words = rules::words(&p.text);
    let ids = repositories::search::product_ids(pool, &words).await?;
    let mut list: Vec<ProductSummary> = product::summaries(pool, &ids, p.point)
        .await?
        .into_iter()
        .filter(|s| p.channel.keeps(s))
        .filter(|s| p.kind.as_deref().is_none_or(|k| s.kind == k))
        // 가격 조건은 배송비 포함 최저 총액 기준
        .filter(|s| p.max_price.is_none_or(|max| s.min_total.is_some_and(|t| t <= max)))
        .collect();
    p.sort.apply(&mut list);
    let total = list.len();
    let items = list.into_iter().skip(p.offset).take(p.limit).collect();

    let (alias, ips) = if words.is_empty() {
        (None, vec![])
    } else {
        (repositories::search::alias_hit(pool, &words).await?, repositories::search::ips(pool, &words).await?)
    };
    Ok(SearchResult { items, total, alias, ips })
}
