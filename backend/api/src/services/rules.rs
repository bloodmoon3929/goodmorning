//! 여러 화면이 함께 쓰는 규칙 (루트 README.md 요구사항 · 예외 상황)

use chrono::{DateTime, Datelike, FixedOffset, NaiveTime, Utc, Weekday};
use serde_json::Value;

use crate::{
    error::{AppError, AppResult},
    models::{catalog::ProductSummary, online::Offer},
    repositories::product::SummaryParams,
};

/// 확인한 지 48시간이 지난 재고는 '확인 필요'
pub const STALE_HOURS: i32 = 48;
/// 내 주변 재고로 보는 거리 (상품 카드의 '근처 n곳 재고')
pub const NEARBY_KM: f64 = 7.0;
/// 위치 권한이 없을 때 기준 위치: 서울시청
pub const DEFAULT_POINT: GeoPoint = GeoPoint { lat: 37.5663, lng: 126.9779 };

/// 한국 시간 (서머타임 없음)
pub fn kst() -> FixedOffset {
    FixedOffset::east_opt(9 * 3600).expect("+09:00")
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct GeoPoint {
    pub lat: f64,
    pub lng: f64,
}

impl GeoPoint {
    /// 둘 다 있으면 그 위치, 둘 다 없으면 서울시청. 하나만 있거나 범위를 벗어나면 400.
    pub fn from_query(lat: Option<f64>, lng: Option<f64>) -> AppResult<Self> {
        match (lat, lng) {
            (None, None) => Ok(DEFAULT_POINT),
            (Some(lat), Some(lng)) if (-90.0..=90.0).contains(&lat) && (-180.0..=180.0).contains(&lng) => Ok(Self { lat, lng }),
            _ => Err(AppError::bad("lat · lng는 함께, 올바른 범위로 보내야 합니다")),
        }
    }

    pub fn summary_params(self) -> SummaryParams {
        SummaryParams { lng: self.lng, lat: self.lat, stale_hours: STALE_HOURS, nearby_m: NEARBY_KM * 1000.0 }
    }
}

/// 판매 경로 필터 (전체 / 온라인 / 오프라인)
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum Channel {
    #[default]
    All,
    Online,
    Offline,
}

impl Channel {
    pub fn parse(s: Option<&str>) -> AppResult<Self> {
        match s.unwrap_or("all") {
            "all" | "" => Ok(Self::All),
            "online" => Ok(Self::Online),
            "offline" => Ok(Self::Offline),
            _ => Err(AppError::bad("channel은 all · online · offline 중 하나입니다")),
        }
    }

    pub fn keeps(self, s: &ProductSummary) -> bool {
        match self {
            Self::All => true,
            Self::Online => s.online_malls > 0,
            Self::Offline => s.nearby_stores > 0,
        }
    }
}

/// 화면에 보일 재고 상태: 48시간이 지나면 저장된 값과 상관없이 'unknown'(확인 필요)
pub fn effective_status(status: &str, confirmed_at: DateTime<Utc>, now: DateTime<Utc>) -> &'static str {
    if now - confirmed_at >= chrono::Duration::hours(STALE_HOURS as i64) {
        return "unknown";
    }
    match status {
        "many" => "many",
        "few" => "few",
        "none" => "none",
        _ => "unknown",
    }
}

pub fn is_stock_status(s: &str) -> bool {
    matches!(s, "many" | "few" | "none")
}

/// 몰별 가격 정렬: 품절은 맨 아래, 나머지는 배송비 포함 총액 오름차순 (배송비를 모르면 그 뒤)
pub fn sort_offers(offers: &mut [Offer]) {
    offers.sort_by_key(|o| (o.sold_out, o.total_price.is_none(), o.total_price.unwrap_or(o.price), o.id));
}

pub const PRODUCT_TYPES: [&str; 6] = ["figure", "doll", "keyring", "acrylic", "plamodel", "random"];

pub fn type_label(kind: &str) -> &'static str {
    match kind {
        "figure" => "피규어",
        "doll" => "인형",
        "keyring" => "키링",
        "acrylic" => "아크릴",
        "plamodel" => "프라모델",
        "random" => "랜덤",
        _ => "기타",
    }
}

pub fn status_label(status: &str) -> &'static str {
    match status {
        "many" => "재고 많음",
        "few" => "재고 적음",
        "none" => "재고 없음",
        _ => "확인 필요",
    }
}

/// 영업시간 JSON에서 오늘(한국 시간) 여는 · 닫는 시각과 지금 영업 중인지
pub fn today_hours(hours: Option<&Value>, now: DateTime<Utc>) -> (Option<(String, String)>, bool) {
    let local = now.with_timezone(&kst());
    let key = match local.weekday() {
        Weekday::Mon => "mon",
        Weekday::Tue => "tue",
        Weekday::Wed => "wed",
        Weekday::Thu => "thu",
        Weekday::Fri => "fri",
        Weekday::Sat => "sat",
        Weekday::Sun => "sun",
    };
    let Some(day) = hours.and_then(|h| h.get(key)).filter(|d| !d.is_null()) else {
        return (None, false);
    };
    let (Some(open), Some(close)) = (day.get("open").and_then(Value::as_str), day.get("close").and_then(Value::as_str)) else {
        return (None, false);
    };
    let parse = |s: &str| NaiveTime::parse_from_str(s, "%H:%M").ok();
    let open_now = match (parse(open), parse(close)) {
        (Some(o), Some(c)) => {
            let t = local.time();
            if o <= c { t >= o && t < c } else { t >= o || t < c } // 자정을 넘기는 영업
        }
        _ => false,
    };
    (Some((open.to_string(), close.to_string())), open_now)
}

/// 검색어 → 소문자 낱말 (최대 10개, 낱말당 50자)
pub fn words(text: &str) -> Vec<String> {
    text.split_whitespace().take(10).map(|w| w.chars().take(50).collect::<String>().to_lowercase()).collect()
}

/// 쪽 나누기 기본값: 20개씩, 최대 100개
pub fn page(limit: Option<i64>, offset: Option<i64>) -> (usize, usize) {
    (limit.unwrap_or(20).clamp(1, 100) as usize, offset.unwrap_or(0).max(0) as usize)
}

#[cfg(test)]
mod tests {
    use chrono::TimeZone;
    use serde_json::json;

    use super::*;

    fn offer(id: i64, price: i32, shipping: Option<i32>, sold_out: bool) -> Offer {
        Offer {
            id,
            variant_id: 1,
            mall_id: id,
            mall_name: format!("몰 {id}"),
            title: None,
            url: String::new(),
            price,
            shipping_fee: shipping,
            total_price: shipping.map(|s| price + s),
            sold_out,
            source: "api".into(),
            observed_at: Utc::now(),
        }
    }

    #[test]
    fn stale_stock_becomes_unknown() {
        let now = Utc::now();
        assert_eq!(effective_status("many", now - chrono::Duration::hours(47), now), "many");
        assert_eq!(effective_status("many", now - chrono::Duration::hours(48), now), "unknown");
        assert_eq!(effective_status("none", now - chrono::Duration::minutes(5), now), "none");
    }

    #[test]
    fn offers_sorted_by_total_with_sold_out_last() {
        // 쿠로미 마스코트 인형 일반 10cm: A 12,900(무료) · B 11,900+3,000 · 공식 15,000 · C 품절
        let mut list =
            vec![offer(4, 0, Some(0), true), offer(3, 15000, Some(0), false), offer(2, 11900, Some(3000), false), offer(1, 12900, Some(0), false)];
        sort_offers(&mut list);
        let ids: Vec<i64> = list.iter().map(|o| o.id).collect();
        assert_eq!(ids, vec![1, 2, 3, 4]);
    }

    #[test]
    fn unknown_shipping_goes_after_known_totals() {
        let mut list = vec![offer(1, 9000, None, false), offer(2, 12000, Some(0), false)];
        sort_offers(&mut list);
        assert_eq!(list[0].id, 2);
    }

    #[test]
    fn hours_today_and_open_now() {
        let hours = json!({"mon": {"open": "10:30", "close": "20:30"}, "tue": null});
        // 2026-11-23은 월요일. 한국 시간 12:00 = UTC 03:00
        let mon_noon = Utc.with_ymd_and_hms(2026, 11, 23, 3, 0, 0).unwrap();
        assert_eq!(today_hours(Some(&hours), mon_noon), (Some(("10:30".into(), "20:30".into())), true));
        let mon_night = Utc.with_ymd_and_hms(2026, 11, 23, 12, 0, 0).unwrap(); // 21:00
        assert!(!today_hours(Some(&hours), mon_night).1);
        let tue = Utc.with_ymd_and_hms(2026, 11, 24, 3, 0, 0).unwrap();
        assert_eq!(today_hours(Some(&hours), tue), (None, false));
    }

    #[test]
    fn geo_point_rules() {
        assert_eq!(GeoPoint::from_query(None, None).unwrap(), DEFAULT_POINT);
        assert!(GeoPoint::from_query(Some(37.5), None).is_err());
        assert!(GeoPoint::from_query(Some(95.0), Some(127.0)).is_err());
    }

    #[test]
    fn words_are_lowercased_and_limited() {
        assert_eq!(words("  Chiikawa   키링 "), vec!["chiikawa", "키링"]);
        assert_eq!(words(&"a ".repeat(30)).len(), 10);
    }
}
