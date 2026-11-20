//! 환경 변수 · DB 연결 설정

use std::env;

#[derive(Debug, Clone)]
pub struct Config {
    pub database_url: String,
    pub db_max_connections: u32,
    pub bind_addr: String,
    pub jwt_secret: String,
    pub jwt_ttl_hours: i64,
    pub run_migrations: bool,
    pub seed_dev_data: bool,
    /// 쉼표로 구분한 허용 출처. 비우면 모든 출처 허용 (개발용)
    pub cors_origins: Vec<String>,
}

#[derive(Debug, thiserror::Error)]
pub enum ConfigError {
    #[error("환경 변수 {0}가 없습니다")]
    Missing(&'static str),
    #[error("환경 변수 {0} 값이 올바르지 않습니다")]
    Invalid(&'static str),
}

impl Config {
    pub fn from_env() -> Result<Self, ConfigError> {
        let jwt_secret = required("JWT_SECRET")?;
        if jwt_secret.len() < 16 {
            return Err(ConfigError::Invalid("JWT_SECRET (16자 이상)"));
        }
        Ok(Self {
            database_url: required("DATABASE_URL")?,
            db_max_connections: parse_or("DB_MAX_CONNECTIONS", 10)?,
            bind_addr: env::var("BIND_ADDR").unwrap_or_else(|_| "127.0.0.1:8080".into()),
            jwt_secret,
            jwt_ttl_hours: parse_or("JWT_TTL_HOURS", 24 * 7)?,
            run_migrations: flag("RUN_MIGRATIONS"),
            seed_dev_data: flag("SEED_DEV_DATA"),
            cors_origins: env::var("CORS_ORIGINS")
                .unwrap_or_default()
                .split(',')
                .map(str::trim)
                .filter(|s| !s.is_empty())
                .map(String::from)
                .collect(),
        })
    }
}

fn required(key: &'static str) -> Result<String, ConfigError> {
    env::var(key).map_err(|_| ConfigError::Missing(key))
}

fn parse_or<T: std::str::FromStr>(key: &'static str, default: T) -> Result<T, ConfigError> {
    match env::var(key) {
        Ok(v) => v.parse().map_err(|_| ConfigError::Invalid(key)),
        Err(_) => Ok(default),
    }
}

fn flag(key: &str) -> bool {
    matches!(env::var(key).as_deref(), Ok("1" | "true" | "TRUE" | "yes"))
}
