//! API 통합 테스트: 실제 PostgreSQL(+PostGIS, pgvector)에 붙어서 라우터를 그대로 부른다.
//! DATABASE_URL이 없으면 건너뛴다. 실행: backend/README.md "테스트".
//! 개발용 가상 데이터(db/seed)를 기준으로 하고, 바꾸는 테스트는 매번 새 회원을 만들어 다시 돌려도 된다.

use std::sync::{Arc, OnceLock};

use axum::{
    Router,
    body::Body,
    http::{Request, StatusCode, header},
};
use goodmorning_api::{AppState, app, config::Config};
use http_body_util::BodyExt;
use serde_json::{Value, json};
use sqlx::{PgPool, postgres::PgPoolOptions};
use tower::ServiceExt;

static INIT: OnceLock<()> = OnceLock::new();

/// 마이그레이션 · 가상 데이터는 테스트 전체에서 한 번만
fn init_db(url: &str) {
    INIT.get_or_init(|| {
        let url = url.to_string();
        std::thread::spawn(move || {
            tokio::runtime::Runtime::new().unwrap().block_on(async {
                let pool = PgPoolOptions::new().max_connections(1).connect(&url).await.unwrap();
                sqlx::migrate!("../db/migrations").run(&pool).await.unwrap();
                goodmorning_api::seed::load_if_empty(&pool).await.unwrap();
            })
        })
        .join()
        .unwrap();
    });
}

async fn setup() -> Option<(Router, PgPool)> {
    let Ok(url) = std::env::var("DATABASE_URL") else {
        eprintln!("DATABASE_URL이 없어 통합 테스트를 건너뜁니다");
        return None;
    };
    init_db(&url);
    let pool = PgPoolOptions::new().max_connections(5).connect(&url).await.unwrap();
    let config = Config {
        database_url: url,
        db_max_connections: 5,
        bind_addr: String::new(),
        jwt_secret: "integration-test-secret".into(),
        jwt_ttl_hours: 1,
        run_migrations: false,
        seed_dev_data: false,
        cors_origins: vec![],
    };
    Some((app(AppState { pool: pool.clone(), config: Arc::new(config) }), pool))
}

async fn call(app: &Router, method: &str, uri: &str, token: Option<&str>, body: Option<Value>) -> (StatusCode, Value) {
    let mut req = Request::builder().method(method).uri(uri);
    if let Some(t) = token {
        req = req.header(header::AUTHORIZATION, format!("Bearer {t}"));
    }
    let req = match body {
        Some(b) => req.header(header::CONTENT_TYPE, "application/json").body(Body::from(b.to_string())).unwrap(),
        None => req.body(Body::empty()).unwrap(),
    };
    let res = app.clone().oneshot(req).await.unwrap();
    let status = res.status();
    let bytes = res.into_body().collect().await.unwrap().to_bytes();
    let value =
        if bytes.is_empty() { Value::Null } else { serde_json::from_slice(&bytes).unwrap_or(Value::String(String::from_utf8_lossy(&bytes).into())) };
    (status, value)
}

fn unique(prefix: &str) -> String {
    let nanos = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_nanos();
    format!("{prefix}-{nanos}@test.example")
}

async fn signup(app: &Router, ip_ids: Value) -> (String, i64) {
    let (st, body) = call(
        app,
        "POST",
        "/auth/signup",
        None,
        Some(json!({"email": unique("user"), "password": "password1234", "nickname": "테스터", "ip_ids": ip_ids})),
    )
    .await;
    assert_eq!(st, StatusCode::CREATED, "{body}");
    (body["token"].as_str().unwrap().to_string(), body["user"]["id"].as_i64().unwrap())
}

async fn login(app: &Router, email: &str) -> String {
    let (st, body) = call(app, "POST", "/auth/login", None, Some(json!({"email": email, "password": "goodmorning1234"}))).await;
    assert_eq!(st, StatusCode::OK, "{body}");
    body["token"].as_str().unwrap().to_string()
}

/// 이름으로 상품 · 버전 번호 찾기 (검색 API 사용)
async fn product_by_name(app: &Router, name: &str) -> Value {
    let uri = format!("/search?q={}&limit=100", urlencode(name));
    let (_, body) = call(app, "GET", &uri, None, None).await;
    body["items"].as_array().unwrap().iter().find(|p| p["name"] == name).cloned().unwrap_or_else(|| panic!("{name} 없음"))
}

fn variant_id(product: &Value, variant_name: &str) -> i64 {
    product["variants"].as_array().unwrap().iter().find(|v| v["name"] == variant_name).unwrap()["id"].as_i64().unwrap()
}

async fn store_id(app: &Router, name: &str) -> i64 {
    let (_, body) = call(app, "GET", "/stores", None, None).await;
    body["items"].as_array().unwrap().iter().find(|s| s["name"] == name).unwrap()["id"].as_i64().unwrap()
}

fn urlencode(s: &str) -> String {
    s.bytes()
        .map(|b| match b {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => (b as char).to_string(),
            _ => format!("%{b:02X}"),
        })
        .collect()
}

#[tokio::test]
async fn product_detail_sorts_offers_and_limits_similar_per_ip() {
    let Some((app, _)) = setup().await else { return };
    let kuromi = product_by_name(&app, "쿠로미 마스코트 인형").await;
    let id = kuromi["id"].as_i64().unwrap();
    let v10 = variant_id(&kuromi, "일반 10cm");

    let (st, d) = call(&app, "GET", &format!("/products/{id}"), None, None).await;
    assert_eq!(st, StatusCode::OK);
    // 일반 10cm: A 12,900 → B 11,900+3,000 → 공식 15,000 → C 품절(맨 아래)
    let rows: Vec<(String, Option<i64>, bool)> = d["offers"]
        .as_array()
        .unwrap()
        .iter()
        .filter(|o| o["variant_id"] == v10)
        .map(|o| (o["mall_name"].as_str().unwrap().to_string(), o["total_price"].as_i64(), o["sold_out"].as_bool().unwrap()))
        .collect();
    assert_eq!(rows[0], ("오픈마켓 A".into(), Some(12900), false));
    assert_eq!(rows[1], ("오픈마켓 B".into(), Some(14900), false));
    assert_eq!(rows[2], ("공식 온라인몰".into(), Some(15000), false));
    assert!(rows[3].2, "품절은 맨 아래");
    // 품절 몰은 몰 수에서 빠진다
    assert_eq!(d["product"]["channels"]["min_total"], 12900);
    assert_eq!(d["product"]["channels"]["online_malls"], 3);
    // 비슷한 상품: 한 IP에서 최대 2개
    let similar = d["similar"].as_array().unwrap();
    assert!(!similar.is_empty() && similar.len() <= 4);
    for ip in similar.iter().map(|s| &s["ip_id"]) {
        assert!(similar.iter().filter(|s| &s["ip_id"] == ip).count() <= 2);
    }
    assert!(similar.iter().all(|s| s["id"] != id));
}

#[tokio::test]
async fn search_expands_alias_and_filters() {
    let Some((app, _)) = setup().await else { return };
    let (st, d) = call(&app, "GET", &format!("/search?q={}", urlencode("먼작귀 키링")), None, None).await;
    assert_eq!(st, StatusCode::OK);
    assert_eq!(d["alias"], json!({"alias": "먼작귀", "ip_name": "치이카와"}));
    let items = d["items"].as_array().unwrap();
    assert!(!items.is_empty());
    assert!(items.iter().all(|p| p["ip_name"] == "치이카와"));
    // 최저가순: 판매처 없는 상품은 맨 뒤
    let totals: Vec<Option<i64>> = items.iter().map(|p| p["channels"]["min_total"].as_i64()).collect();
    let known: Vec<i64> = totals.iter().flatten().copied().collect();
    assert!(known.windows(2).all(|w| w[0] <= w[1]));
    assert!(totals.iter().skip_while(|t| t.is_some()).all(|t| t.is_none()));

    let (_, d) = call(&app, "GET", "/search?type=figure&max_price=20000", None, None).await;
    assert!(d["items"].as_array().unwrap().iter().all(|p| p["type"] == "figure" && p["channels"]["min_total"].as_i64().unwrap() <= 20000));

    let (st, _) = call(&app, "GET", "/search?type=hat", None, None).await;
    assert_eq!(st, StatusCode::BAD_REQUEST);
}

#[tokio::test]
async fn stores_sorted_by_distance_and_stale_stock_needs_check() {
    let Some((app, _)) = setup().await else { return };
    // 용산역 근처에서
    let (st, d) = call(&app, "GET", "/stores?lat=37.5299&lng=126.9648&limit=3", None, None).await;
    assert_eq!(st, StatusCode::OK);
    let items = d["items"].as_array().unwrap();
    assert_eq!(items.len(), 3);
    assert_eq!(items[0]["name"], "피규어샵 용산점");
    let dist: Vec<f64> = items.iter().map(|s| s["distance_km"].as_f64().unwrap()).collect();
    assert!(dist.windows(2).all(|w| w[0] <= w[1]));

    let yongsan = items[0]["id"].as_i64().unwrap();
    let (_, d) = call(&app, "GET", &format!("/stores/{yongsan}"), None, None).await;
    // 3일 전에 수집된 재고는 확인 필요
    let danbo = d["items"].as_array().unwrap().iter().find(|i| i["product_name"] == "리볼텍 단보 피규어").unwrap();
    assert_eq!(danbo["status"], "unknown");
    assert!(d["store"]["has_owner"].as_bool().unwrap());
}

#[tokio::test]
async fn signup_login_and_my_ips() {
    let Some((app, _)) = setup().await else { return };
    let email = unique("signup");
    let body = json!({"email": email, "password": "password1234", "nickname": "새회원", "ip_ids": [2, 1, 2]});
    let (st, d) = call(&app, "POST", "/auth/signup", None, Some(body.clone())).await;
    assert_eq!(st, StatusCode::CREATED, "{d}");
    assert_eq!(d["user"]["ip_ids"], json!([2, 1]));
    assert!(d["user"].get("password_hash").is_none());

    let (st, _) = call(&app, "POST", "/auth/signup", None, Some(body)).await;
    assert_eq!(st, StatusCode::CONFLICT);
    let (_, d) = call(&app, "GET", &format!("/auth/email-taken?email={}", urlencode(&email)), None, None).await;
    assert_eq!(d["taken"], true);

    let (st, _) = call(&app, "POST", "/auth/login", None, Some(json!({"email": email, "password": "wrong-password"}))).await;
    assert_eq!(st, StatusCode::BAD_REQUEST);
    let (st, d) = call(&app, "POST", "/auth/login", None, Some(json!({"email": email, "password": "password1234"}))).await;
    assert_eq!(st, StatusCode::OK);
    let token = d["token"].as_str().unwrap();

    let (_, d) = call(&app, "PUT", "/me/ips", Some(token), Some(json!({"ip_ids": [4, 3]}))).await;
    assert_eq!(d["ip_ids"], json!([4, 3]));
    let (_, d) = call(&app, "GET", "/me", Some(token), None).await;
    assert_eq!(d["ip_ids"], json!([4, 3]));

    // 신상품은 내 IP 기준
    let (_, d) = call(&app, "GET", "/products/new", Some(token), None).await;
    assert!(d["items"].as_array().unwrap().iter().all(|p| p["ip_id"] == 4 || p["ip_id"] == 3));

    let (st, _) = call(&app, "GET", "/me", Some("not-a-token"), None).await;
    assert_eq!(st, StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn wishlist_saved_store_and_alerts() {
    let Some((app, _)) = setup().await else { return };
    let (token, _) = signup(&app, json!([1])).await;
    let kuromi = product_by_name(&app, "쿠로미 마스코트 인형").await;
    let v20 = variant_id(&kuromi, "빅 20cm");

    let (st, _) = call(&app, "PUT", &format!("/me/wishlist/{v20}"), Some(&token), None).await;
    assert_eq!(st, StatusCode::OK);
    let (_, d) = call(&app, "GET", "/me/wishlist", Some(&token), None).await;
    assert_eq!(d["items"][0]["variant_name"], "빅 20cm");
    let (_, d) = call(&app, "GET", &format!("/products/{}", kuromi["id"]), Some(&token), None).await;
    assert_eq!(d["wished_variant_ids"], json!([v20]));
    call(&app, "DELETE", &format!("/me/wishlist/{v20}"), Some(&token), None).await;
    let (_, d) = call(&app, "GET", "/me/wishlist", Some(&token), None).await;
    assert_eq!(d["items"], json!([]));

    let yongsan = store_id(&app, "피규어샵 용산점").await;
    call(&app, "PUT", &format!("/me/saved-stores/{yongsan}"), Some(&token), None).await;
    let (_, d) = call(&app, "GET", "/me/saved-stores", Some(&token), None).await;
    assert_eq!(d["items"][0]["id"], yongsan);

    let (st, _) = call(&app, "POST", "/me/alerts", Some(&token), Some(json!({"type": "price", "variant_id": v20}))).await;
    assert_eq!(st, StatusCode::BAD_REQUEST, "목표가 없는 가격 알림");
    let (st, a) = call(&app, "POST", "/me/alerts", Some(&token), Some(json!({"type": "price", "variant_id": v20, "target_price": 20000}))).await;
    assert_eq!(st, StatusCode::CREATED);
    assert_eq!(a["product_name"], "쿠로미 마스코트 인형");
    let (st, _) = call(&app, "DELETE", &format!("/me/alerts/{}", a["id"]), Some(&token), None).await;
    assert_eq!(st, StatusCode::OK);
}

#[tokio::test]
async fn outbound_click_purchase_and_issue() {
    let Some((app, _)) = setup().await else { return };
    let (token, _) = signup(&app, json!([1])).await;
    let kuromi = product_by_name(&app, "쿠로미 마스코트 인형").await;
    let (_, d) = call(&app, "GET", &format!("/products/{}", kuromi["id"]), None, None).await;
    let offers = d["offers"].as_array().unwrap();
    let sold_out = offers.iter().find(|o| o["sold_out"] == true).unwrap();
    let cheapest = &offers[0];

    let (st, _) = call(&app, "POST", &format!("/offers/{}/click", sold_out["id"]), Some(&token), None).await;
    assert_eq!(st, StatusCode::CONFLICT, "품절은 구매하러 가기를 막는다");

    // 링크용은 302로 외부 몰로 보낸다
    let req = Request::builder().uri(format!("/offers/{}/go", cheapest["id"])).body(Body::empty()).unwrap();
    let res = app.clone().oneshot(req).await.unwrap();
    assert_eq!(res.status(), StatusCode::FOUND);
    assert!(res.headers()[header::LOCATION].to_str().unwrap().starts_with("https://"));

    let (st, out) = call(&app, "POST", &format!("/offers/{}/click", cheapest["id"]), Some(&token), None).await;
    assert_eq!(st, StatusCode::OK);
    let click_id = out["click_id"].as_i64().unwrap();

    let (_, d) = call(&app, "GET", "/me/visits", Some(&token), None).await;
    let visit = &d["items"][0];
    assert_eq!(visit["id"], click_id);
    assert_eq!(visit["price_snapshot"], cheapest["price"]);
    assert_eq!(visit["purchased"], false);

    let (st, p) = call(&app, "POST", "/me/purchases", Some(&token), Some(json!({"click_id": click_id}))).await;
    assert_eq!(st, StatusCode::CREATED, "{p}");
    assert_eq!(p["channel"], "online");
    let (st, _) = call(&app, "POST", "/me/purchases", Some(&token), Some(json!({"click_id": click_id}))).await;
    assert_eq!(st, StatusCode::CONFLICT);

    let (st, i) =
        call(&app, "POST", "/me/issues", Some(&token), Some(json!({"click_id": click_id, "type": "price", "content": "결제 화면 가격이 달라요"})))
            .await;
    assert_eq!(st, StatusCode::CREATED, "{i}");
    assert_eq!(i["price_now"], cheapest["total_price"]);
    assert_eq!(i["price_snapshot_total"], cheapest["total_price"]);
    assert_eq!(i["state"], "open");

    // 다른 회원의 이동 기록으로는 못 한다
    let (other, _) = signup(&app, json!([])).await;
    let (st, _) = call(&app, "POST", "/me/purchases", Some(&other), Some(json!({"click_id": click_id}))).await;
    assert_eq!(st, StatusCode::NOT_FOUND);
}

#[tokio::test]
async fn store_without_owner_applies_after_two_reporters() {
    let Some((app, _)) = setup().await else { return };
    let kondae = store_id(&app, "키덜트샵 건대점").await;
    let pikachu = product_by_name(&app, "피카츄 인형").await;
    let vm = variant_id(&pikachu, "M");
    let (a, _) = signup(&app, json!([])).await;
    let (b, _) = signup(&app, json!([])).await;
    let report = json!({"store_id": kondae, "variant_id": vm, "status": "few"});

    let (st, r1) = call(&app, "POST", "/stock-reports", Some(&a), Some(report.clone())).await;
    assert_eq!(st, StatusCode::CREATED, "{r1}");
    assert_eq!(r1["state"], "pending");
    // 같은 회원이 또 보내도 2명이 되지 않는다
    let (_, r1b) = call(&app, "POST", "/stock-reports", Some(&a), Some(report.clone())).await;
    assert_eq!(r1b["state"], "pending");

    let (_, r2) = call(&app, "POST", "/stock-reports", Some(&b), Some(report)).await;
    assert_eq!(r2["state"], "approved");
    assert_eq!(r2["applied"], true);

    let (_, d) = call(&app, "GET", &format!("/stores/{kondae}"), None, None).await;
    let item = d["items"].as_array().unwrap().iter().find(|i| i["variant_id"] == vm).unwrap();
    assert_eq!(item["status"], "few");
    assert_eq!(item["source"], "report");

    let (_, n) = call(&app, "GET", "/me/notifications", Some(&a), None).await;
    assert_eq!(n["items"][0]["type"], "report");
    let (_, mine) = call(&app, "GET", "/me/stock-reports", Some(&a), None).await;
    assert!(mine["items"].as_array().unwrap().iter().any(|r| r["state"] == "approved"));
}

#[tokio::test]
async fn owner_approves_reports_only_for_own_store() {
    let Some((app, _)) = setup().await else { return };
    let yongsan = store_id(&app, "피규어샵 용산점").await;
    let zaku = product_by_name(&app, "HG 1/144 자쿠 II").await;
    let v = variant_id(&zaku, "단품");
    let (reporter, _) = signup(&app, json!([])).await;
    let (_, r) = call(&app, "POST", "/stock-reports", Some(&reporter), Some(json!({"store_id": yongsan, "variant_id": v, "status": "few"}))).await;
    assert_eq!(r["state"], "pending", "사장님이 있는 매장은 바로 반영하지 않는다");
    let report_id = r["id"].as_i64().unwrap();

    let hongdae_owner = login(&app, "owner.hongdae@example.com").await;
    let (st, _) = call(&app, "GET", &format!("/seller/stores/{yongsan}"), Some(&hongdae_owner), None).await;
    assert_eq!(st, StatusCode::FORBIDDEN);
    let (st, _) = call(&app, "POST", &format!("/seller/stores/{yongsan}/reports/{report_id}/approve"), Some(&hongdae_owner), None).await;
    assert_eq!(st, StatusCode::FORBIDDEN);

    let owner = login(&app, "owner.yongsan@example.com").await;
    let (_, pending) = call(&app, "GET", &format!("/seller/stores/{yongsan}/reports?state=pending"), Some(&owner), None).await;
    assert!(pending["items"].as_array().unwrap().iter().any(|x| x["id"] == report_id));
    let (st, done) = call(&app, "POST", &format!("/seller/stores/{yongsan}/reports/{report_id}/approve"), Some(&owner), None).await;
    assert_eq!(st, StatusCode::OK, "{done}");
    assert_eq!(done["state"], "approved");
    let (st, _) = call(&app, "POST", &format!("/seller/stores/{yongsan}/reports/{report_id}/approve"), Some(&owner), None).await;
    assert_eq!(st, StatusCode::NOT_FOUND, "이미 처리한 제보");

    let (_, n) = call(&app, "GET", "/me/notifications", Some(&reporter), None).await;
    assert_eq!(n["items"][0]["title"], "재고 제보가 반영됐어요");
}

#[tokio::test]
async fn seller_saves_stock_and_confirms_all() {
    let Some((app, _)) = setup().await else { return };
    let yongsan = store_id(&app, "피규어샵 용산점").await;
    let rg = product_by_name(&app, "RG 1/144 RX-78-2 건담").await;
    let v2 = variant_id(&rg, "Ver. 2.0");
    let owner = login(&app, "owner.yongsan@example.com").await;

    let (st, _) =
        call(&app, "PUT", &format!("/seller/stores/{yongsan}/stock"), Some(&owner), Some(json!({"items": [{"variant_id": v2, "status": "lots"}]})))
            .await;
    assert_eq!(st, StatusCode::BAD_REQUEST);
    let (st, d) =
        call(&app, "PUT", &format!("/seller/stores/{yongsan}/stock"), Some(&owner), Some(json!({"items": [{"variant_id": v2, "status": "many"}]})))
            .await;
    assert_eq!(st, StatusCode::OK, "{d}");
    assert_eq!(d["count"], 1);

    let (st, d) = call(&app, "POST", &format!("/seller/stores/{yongsan}/stock/confirm"), Some(&owner), None).await;
    assert_eq!(st, StatusCode::OK);
    assert!(d["count"].as_u64().unwrap() >= 6);
    let (_, s) = call(&app, "GET", &format!("/seller/stores/{yongsan}"), Some(&owner), None).await;
    let item = s["items"].as_array().unwrap().iter().find(|i| i["variant_id"] == v2).unwrap();
    assert_eq!((item["status"].as_str(), item["source"].as_str()), (Some("many"), Some("owner")));
    assert!(s["last_confirmed_at"].is_string());

    let (user, _) = signup(&app, json!([])).await;
    let (st, _) = call(&app, "POST", &format!("/seller/stores/{yongsan}/stock/confirm"), Some(&user), None).await;
    assert_eq!(st, StatusCode::FORBIDDEN);
    let (st, _) = call(&app, "GET", "/seller/stores", None, None).await;
    assert_eq!(st, StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn admin_matches_collected_listing_into_offer() {
    let Some((app, pool)) = setup().await else { return };
    let eevee = product_by_name(&app, "이브이 피규어").await;
    let v = variant_id(&eevee, "단품");
    // 수집기가 넣은 것과 같은 모양의 원본 한 줄
    let url = format!("https://mall-b.example/goods/test-{}", unique("raw"));
    let raw_id: i64 = sqlx::query_scalar(
        "INSERT INTO ingest.raw_listing (mall_id, source, source_url, title, price, shipping_fee, payload, collected_at)
         SELECT id, 'api', $1, '이브이 피규어 정품', 29900, 0, '{\"sold_out\": false}', now() FROM online.mall WHERE name = '오픈마켓 B'
         RETURNING id",
    )
    .bind(&url)
    .fetch_one(&pool)
    .await
    .unwrap();

    let user = login(&app, "goods@example.com").await;
    let (st, _) = call(&app, "GET", "/admin/raw-listings", Some(&user), None).await;
    assert_eq!(st, StatusCode::FORBIDDEN);

    let admin = login(&app, "admin@example.com").await;
    let (_, list) = call(&app, "GET", "/admin/raw-listings?state=pending", Some(&admin), None).await;
    assert!(list["items"].as_array().unwrap().iter().any(|r| r["id"] == raw_id));
    let (st, m) = call(&app, "POST", &format!("/admin/raw-listings/{raw_id}/match"), Some(&admin), Some(json!({"variant_id": v}))).await;
    assert_eq!(st, StatusCode::OK, "{m}");
    let (st, _) = call(&app, "POST", &format!("/admin/raw-listings/{raw_id}/match"), Some(&admin), Some(json!({"variant_id": v}))).await;
    assert_eq!(st, StatusCode::CONFLICT);

    let (_, d) = call(&app, "GET", &format!("/products/{}", eevee["id"]), None, None).await;
    let offer = d["offers"].as_array().unwrap().iter().find(|o| o["id"] == m["id"]).unwrap();
    assert_eq!(offer["price"], 29900);
    assert_eq!(offer["mall_name"], "오픈마켓 B");
    // 32,000원(오픈마켓 A)보다 앞에 온다
    let pos = |id: &Value| d["offers"].as_array().unwrap().iter().position(|o| &o["id"] == id).unwrap();
    let a = d["offers"].as_array().unwrap().iter().find(|o| o["mall_name"] == "오픈마켓 A").unwrap();
    assert!(pos(&m["id"]) < pos(&a["id"]));
}

#[tokio::test]
async fn admin_console_queues_run_streams_events_and_suggests_matches() {
    let Some((app, pool)) = setup().await else { return };
    let user = login(&app, "goods@example.com").await;
    let (st, _) = call(&app, "POST", "/admin/collect-runs", Some(&user), Some(json!({"kind": "crawl"}))).await;
    assert_eq!(st, StatusCode::FORBIDDEN);
    let admin = login(&app, "admin@example.com").await;

    // 몰 목록 · 수집 허용 끄고 켜기
    let (_, malls) = call(&app, "GET", "/admin/malls", Some(&admin), None).await;
    let demo = malls["items"].as_array().unwrap().iter().find(|m| m["name"] == "데모 몰 A (정적 HTML)").unwrap().clone();
    let mall_id = demo["id"].as_i64().unwrap();
    for allowed in [false, true] {
        let (st, _) = call(&app, "PATCH", &format!("/admin/malls/{mall_id}"), Some(&admin), Some(json!({"crawl_allowed": allowed}))).await;
        assert_eq!(st, StatusCode::OK);
        let now: bool = sqlx::query_scalar("SELECT crawl_allowed FROM online.mall WHERE id = $1").bind(mall_id).fetch_one(&pool).await.unwrap();
        assert_eq!(now, allowed);
    }
    let (st, _) = call(&app, "PATCH", "/admin/malls/999999", Some(&admin), Some(json!({"crawl_allowed": true}))).await;
    assert_eq!(st, StatusCode::NOT_FOUND);

    // 잘못된 요청
    let (st, _) = call(&app, "POST", "/admin/collect-runs", Some(&admin), Some(json!({"kind": "ftp"}))).await;
    assert_eq!(st, StatusCode::BAD_REQUEST);
    let (st, _) = call(&app, "POST", "/admin/collect-runs", Some(&admin), Some(json!({"kind": "crawl", "mall": "없는 몰"}))).await;
    assert_eq!(st, StatusCode::NOT_FOUND);
    let (st, _) = call(&app, "POST", "/admin/collect-runs", Some(&admin), Some(json!({"kind": "api", "mall": "데모 몰 A (정적 HTML)"}))).await;
    assert_eq!(st, StatusCode::BAD_REQUEST);
    // 공식몰 공개 API: 검색어가 있어야 하고, 모르는 provider는 거절
    let (st, _) = call(&app, "POST", "/admin/collect-runs", Some(&admin), Some(json!({"kind": "api", "provider": "chiikawa_market"}))).await;
    assert_eq!(st, StatusCode::BAD_REQUEST);
    let (st, _) = call(&app, "POST", "/admin/collect-runs", Some(&admin), Some(json!({"kind": "api", "provider": "amazon", "keyword": "x"}))).await;
    assert_eq!(st, StatusCode::BAD_REQUEST);
    let (st, r) =
        call(&app, "POST", "/admin/collect-runs", Some(&admin), Some(json!({"kind": "api", "provider": "chiikawa_market", "keyword": "ハチワレ"})))
            .await;
    assert_eq!(st, StatusCode::CREATED);
    let (_, d) = call(&app, "GET", &format!("/admin/collect-runs/{}", r["id"]), Some(&admin), None).await;
    assert_eq!(d["run"]["params"]["provider"], "chiikawa_market");
    sqlx::query("UPDATE ingest.collect_run SET status = 'failed', error = '통합 테스트' WHERE id = $1")
        .bind(r["id"].as_i64().unwrap())
        .execute(&pool)
        .await
        .unwrap();

    // [수집 시작] → 대기열 (검색어 수는 10개까지로 줄인다)
    let body = json!({"kind": "crawl", "mall": "데모 몰 A (정적 HTML)", "keyword": " 쿠로미 ", "max_queries": 99});
    let (st, r) = call(&app, "POST", "/admin/collect-runs", Some(&admin), Some(body)).await;
    assert_eq!(st, StatusCode::CREATED, "{r}");
    let run_id = r["id"].as_i64().unwrap();
    let (_, d) = call(&app, "GET", &format!("/admin/collect-runs/{run_id}"), Some(&admin), None).await;
    assert_eq!(d["run"]["status"], "queued");
    assert_eq!(d["run"]["params"], json!({"mall": "데모 몰 A (정적 HTML)", "keyword": "쿠로미", "max_queries": 10, "provider": null}));
    assert_eq!(d["events"], json!([]));
    let (_, runs) = call(&app, "GET", "/admin/collect-runs", Some(&admin), None).await;
    assert!(runs["items"].as_array().unwrap().iter().any(|r| r["id"] == run_id));

    // 워커가 남기는 것과 같은 기록 → after 뒤의 새 기록만 받는다
    for (step, msg) in [("robots", "robots.txt 200"), ("parse", "상품 1개 읽음")] {
        sqlx::query("INSERT INTO ingest.collect_event (run_id, step, message, data) VALUES ($1, $2, $3, '{\"status\": 200}')")
            .bind(run_id)
            .bind(step)
            .bind(msg)
            .execute(&pool)
            .await
            .unwrap();
    }
    let (_, d) = call(&app, "GET", &format!("/admin/collect-runs/{run_id}?after=0"), Some(&admin), None).await;
    let events = d["events"].as_array().unwrap();
    assert_eq!(events.len(), 2);
    assert_eq!((events[0]["step"].as_str(), events[0]["data"]["status"].as_i64()), (Some("robots"), Some(200)));
    let first = events[0]["id"].as_i64().unwrap();
    let (_, d) = call(&app, "GET", &format!("/admin/collect-runs/{run_id}?after={first}"), Some(&admin), None).await;
    assert_eq!(d["events"].as_array().unwrap().len(), 1);

    // 이 실행에서 모은 원본 + 매칭 후보 (수집 검색어의 버전이 맨 앞)
    let kuromi = product_by_name(&app, "쿠로미 마스코트 인형").await;
    let small = variant_id(&kuromi, "일반 10cm");
    let job_id: i64 = sqlx::query_scalar("INSERT INTO ingest.collect_job (mall_id, kind, run_id) VALUES ($1, 'crawl', $2) RETURNING id")
        .bind(mall_id)
        .bind(run_id)
        .fetch_one(&pool)
        .await
        .unwrap();
    let raw_id: i64 = sqlx::query_scalar(
        "INSERT INTO ingest.raw_listing (mall_id, source, source_url, title, price, shipping_fee, payload, collected_at, job_id)
         VALUES ($1, 'crawl', $2, '[산리오 정품] 쿠로미 마스코트 인형 10cm', 12500, 3000, jsonb_build_object('query_variant_id', $3::bigint), now(), $4)
         RETURNING id",
    )
    .bind(mall_id)
    .bind(format!("http://127.0.0.1:8091/goods/{}", unique("g")))
    .bind(small)
    .bind(job_id)
    .fetch_one(&pool)
    .await
    .unwrap();
    let (_, list) = call(&app, "GET", &format!("/admin/raw-listings?run_id={run_id}"), Some(&admin), None).await;
    assert_eq!(list["items"].as_array().unwrap().iter().map(|r| r["id"].as_i64().unwrap()).collect::<Vec<_>>(), vec![raw_id]);
    let _ = &list;
    let (_, c) = call(&app, "GET", &format!("/admin/raw-listings/{raw_id}/candidates"), Some(&admin), None).await;
    assert_eq!(c["items"][0]["variant_id"], small);
    assert_eq!(c["items"][0]["from_query"], true);
    assert!(c["items"][0]["hits"].as_i64().unwrap() >= 4, "{c}");
    let (_, d) = call(&app, "GET", &format!("/admin/collect-runs/{run_id}"), Some(&admin), None).await;
    assert_eq!(d["jobs"][0]["mall_name"], "데모 몰 A (정적 HTML)");

    // 띄어쓰기 없는 일본어 제목도 별칭(ちいかわ)으로 치이카와 버전이 앞에 온다
    let jp: i64 = sqlx::query_scalar(
        "INSERT INTO ingest.raw_listing (mall_id, source, source_url, title, price, collected_at, job_id)
         VALUES ($1, 'api', $2, 'まじかるちいかわ マジカルチャージマスコット（ハチワレ）', 13931, now(), $3) RETURNING id",
    )
    .bind(mall_id)
    .bind(format!("https://chiikawamarket.jp/products/{}", unique("p")))
    .bind(job_id)
    .fetch_one(&pool)
    .await
    .unwrap();
    let (_, c) = call(&app, "GET", &format!("/admin/raw-listings/{jp}/candidates"), Some(&admin), None).await;
    assert_eq!(c["items"][0]["ip_name"], "치이카와", "{c}");

    // 수집기 연결 상태
    sqlx::query("INSERT INTO ingest.collect_worker (name, pid) VALUES ('test-worker', 1) ON CONFLICT (name) DO UPDATE SET seen_at = now()")
        .execute(&pool)
        .await
        .unwrap();
    let (_, s) = call(&app, "GET", "/admin/collector", Some(&admin), None).await;
    assert_eq!(s["worker_alive"], true);
    assert!(s["queued"].as_i64().unwrap() >= 1);

    // 테스트로 넣은 실행은 워커가 가져가지 않게 끝낸다
    sqlx::query("UPDATE ingest.collect_run SET status = 'failed', error = '통합 테스트' WHERE id = $1").bind(run_id).execute(&pool).await.unwrap();
    sqlx::query("DELETE FROM ingest.collect_worker WHERE name = 'test-worker'").execute(&pool).await.unwrap();

    // 관리자 페이지 파일
    let (st, page) = call(&app, "GET", "/console/", None, None).await;
    assert_eq!(st, StatusCode::OK);
    assert!(page.as_str().unwrap().contains("수집 관리"));
}
