//! 개발용 가상 데이터 (backend/db/seed/dev_seed.sql). SEED_DEV_DATA=true 이고 catalog.ip가 비어 있을 때만 넣는다.

use sqlx::PgPool;

const DEV_SEED: &str = include_str!("../../db/seed/dev_seed.sql");

pub async fn load_if_empty(pool: &PgPool) -> Result<bool, sqlx::Error> {
    let count: i64 = sqlx::query_scalar("SELECT count(*) FROM catalog.ip").fetch_one(pool).await?;
    if count > 0 {
        return Ok(false);
    }
    // 여러 문장이 든 SQL 파일이므로 매개변수 없이 한 번에 실행한다 (파일 안에 BEGIN/COMMIT)
    sqlx::raw_sql(DEV_SEED).execute(pool).await?;
    Ok(true)
}
