use serde::Serialize;

use crate::services::offer::Outbound;

#[derive(Serialize)]
pub struct OutboundView {
    pub click_id: i64,
    /// 앱이 열 외부 몰 주소
    pub url: String,
}

impl From<Outbound> for OutboundView {
    fn from(o: Outbound) -> Self {
        Self { click_id: o.click_id, url: o.url }
    }
}
