use chrono::{DateTime, Utc};
use serde::Serialize;

use super::store::{StoreItemView, StoreView};
use crate::services::seller::SellerStore;

#[derive(Serialize)]
pub struct SellerStoreView {
    pub store: StoreView,
    /// 저장된 재고 상태 (확인 시각이 오래돼도 그대로, 사장님이 고칠 값)
    pub items: Vec<StoreItemView>,
    pub total_items: i64,
    pub last_confirmed_at: Option<DateTime<Utc>>,
    pub pending_reports: i64,
}

impl From<SellerStore> for SellerStoreView {
    fn from(s: SellerStore) -> Self {
        Self {
            store: s.store.into(),
            items: s.items.into_iter().map(Into::into).collect(),
            total_items: s.total_items,
            last_confirmed_at: s.last_confirmed_at,
            pending_reports: s.pending_reports,
        }
    }
}
