use std::sync::Arc;

use goodmorning_api::{AppState, app, config::Config, seed};
use sqlx::postgres::PgPoolOptions;
use tracing_subscriber::EnvFilter;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenvy::dotenv().ok();
    tracing_subscriber::fmt().with_env_filter(EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"))).init();

    let config = Config::from_env()?;
    let pool = PgPoolOptions::new().max_connections(config.db_max_connections).connect(&config.database_url).await?;

    if config.run_migrations {
        sqlx::migrate!("../db/migrations").run(&pool).await?;
        tracing::info!("마이그레이션 완료");
    }
    if config.seed_dev_data && seed::load_if_empty(&pool).await? {
        tracing::info!("개발용 가상 데이터를 넣었습니다");
    }

    let listener = tokio::net::TcpListener::bind(&config.bind_addr).await?;
    tracing::info!("API 서버 시작: http://{}", config.bind_addr);
    let state = AppState { pool, config: Arc::new(config) };
    axum::serve(listener, app(state)).with_graceful_shutdown(shutdown_signal()).await?;
    Ok(())
}

async fn shutdown_signal() {
    let _ = tokio::signal::ctrl_c().await;
}
