//! IP 목록 · IP 화면 · 캐릭터 화면

use std::collections::HashMap;

use sqlx::PgPool;

use super::{
    product,
    rules::{Channel, GeoPoint},
    search::Sort,
};
use crate::{
    error::{AppError, AppResult},
    models::catalog::{Character, Ip, IpStat, ProductSummary},
    repositories,
};

pub async fn ips(pool: &PgPool) -> AppResult<Vec<Ip>> {
    Ok(repositories::catalog::ips(pool).await?)
}

/// 굿즈 탐색의 내 IP 타일: 캐릭터 수 · 굿즈 수 (ids 순서대로)
pub async fn ip_stats(pool: &PgPool, ids: &[i64]) -> AppResult<Vec<(Ip, IpStat)>> {
    let mut ips: HashMap<i64, Ip> = repositories::catalog::ips_by_ids(pool, ids).await?.into_iter().map(|ip| (ip.id, ip)).collect();
    let mut stats: HashMap<i64, IpStat> = repositories::catalog::ip_stats(pool, ids).await?.into_iter().map(|s| (s.id, s)).collect();
    Ok(ids.iter().filter_map(|id| Some((ips.remove(id)?, stats.remove(id)?))).collect())
}

pub struct IpDetail {
    pub ip: Ip,
    pub characters: Vec<Character>,
    pub products: Vec<ProductSummary>,
}

pub struct ListFilter {
    pub channel: Channel,
    pub kind: Option<String>,
    pub sort: Sort,
}

pub async fn ip_detail(pool: &PgPool, id: i64, point: GeoPoint, filter: ListFilter) -> AppResult<IpDetail> {
    let ip = repositories::catalog::ip(pool, id).await?.ok_or(AppError::NotFound("IP"))?;
    let characters = repositories::catalog::characters_of_ip(pool, id).await?;
    let ids = repositories::product::ids_of_ip(pool, id).await?;
    let mut products: Vec<ProductSummary> = product::summaries(pool, &ids, point)
        .await?
        .into_iter()
        .filter(|s| filter.channel.keeps(s) && filter.kind.as_deref().is_none_or(|k| s.kind == k))
        .collect();
    filter.sort.apply(&mut products);
    Ok(IpDetail { ip, characters, products })
}

pub struct CharacterDetail {
    pub character: Character,
    pub ip: Ip,
    /// 품목별 묶음 (피규어 · 인형 · 키링 … 순서)
    pub groups: Vec<(String, Vec<ProductSummary>)>,
}

pub async fn character_detail(pool: &PgPool, id: i64, point: GeoPoint, channel: Channel) -> AppResult<CharacterDetail> {
    let character = repositories::catalog::character(pool, id).await?.ok_or(AppError::NotFound("캐릭터"))?;
    let ip = repositories::catalog::ip(pool, character.ip_id).await?.ok_or(AppError::NotFound("IP"))?;
    let ids = repositories::product::ids_of_character(pool, id).await?;
    let list = product::summaries(pool, &ids, point).await?;
    let groups = super::rules::PRODUCT_TYPES
        .iter()
        .map(|t| {
            let items: Vec<ProductSummary> = list.iter().filter(|s| s.kind == *t && channel.keeps(s)).cloned().collect();
            (t.to_string(), items)
        })
        .filter(|(_, items)| !items.is_empty())
        .collect();
    Ok(CharacterDetail { character, ip, groups })
}
