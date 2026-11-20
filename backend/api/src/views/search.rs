use serde::Serialize;

use super::{catalog::IpView, product::ProductCard};
use crate::services::search::SearchResult;

#[derive(Serialize)]
pub struct AliasView {
    /// 사용자가 입력한 별칭 (먼작귀)
    pub alias: String,
    /// 같이 찾은 IP 이름 (치이카와)
    pub ip_name: String,
}

#[derive(Serialize)]
pub struct SearchView {
    pub items: Vec<ProductCard>,
    /// 조건에 맞는 전체 개수 (items는 limit · offset 만큼)
    pub total: usize,
    pub alias: Option<AliasView>,
    pub ips: Vec<IpView>,
}

impl From<SearchResult> for SearchView {
    fn from(r: SearchResult) -> Self {
        Self {
            items: r.items.into_iter().map(Into::into).collect(),
            total: r.total,
            alias: r.alias.map(|a| AliasView { alias: a.alias, ip_name: a.ip_name }),
            ips: r.ips.into_iter().map(Into::into).collect(),
        }
    }
}
