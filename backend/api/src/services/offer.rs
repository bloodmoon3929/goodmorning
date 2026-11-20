//! 구매하러 가기: 누른 시점의 몰 · 가격 · 배송비를 이동 기록으로 저장한 뒤 외부 몰 주소를 준다.
//! 실제 결제는 외부 몰에서 일어나므로 이 기록이 구매 추적과 문의 확인의 기준이 된다.

use sqlx::PgPool;

use crate::{
    error::{AppError, AppResult},
    middleware::AuthUser,
    repositories,
};

pub struct Outbound {
    pub click_id: i64,
    pub url: String,
}

pub async fn go(pool: &PgPool, offer_id: i64, user: Option<AuthUser>) -> AppResult<Outbound> {
    let offer = repositories::offer::offer(pool, offer_id).await?.ok_or(AppError::NotFound("판매처"))?;
    if offer.sold_out {
        return Err(AppError::Conflict("품절된 판매처입니다".into()));
    }
    let click_id = repositories::offer::insert_click(pool, user.map(|u| u.id), &offer).await?;
    Ok(Outbound { click_id, url: offer.url })
}
