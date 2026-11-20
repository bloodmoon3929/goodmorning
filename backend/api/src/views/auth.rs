use serde::Serialize;

use crate::services::auth::{Profile, Session};

#[derive(Serialize)]
pub struct MeView {
    pub id: i64,
    pub email: Option<String>,
    pub nickname: String,
    pub home_area: Option<String>,
    /// user · seller · admin
    pub role: String,
    pub agree_location: bool,
    pub agree_push: bool,
    /// 내 IP (보이는 순서)
    pub ip_ids: Vec<i64>,
    /// 판매자 센터에서 관리하는 매장
    pub seller_store_ids: Vec<i64>,
}

impl From<Profile> for MeView {
    fn from(p: Profile) -> Self {
        Self {
            id: p.user.id,
            email: p.user.email,
            nickname: p.user.nickname,
            home_area: p.user.home_area,
            role: p.user.role,
            agree_location: p.user.agree_location,
            agree_push: p.user.agree_push,
            ip_ids: p.ip_ids,
            seller_store_ids: p.seller_store_ids,
        }
    }
}

#[derive(Serialize)]
pub struct SessionView {
    pub token: String,
    pub user: MeView,
}

impl From<Session> for SessionView {
    fn from(s: Session) -> Self {
        Self { token: s.token, user: s.profile.into() }
    }
}

#[derive(Serialize)]
pub struct EmailTakenView {
    pub taken: bool,
}
