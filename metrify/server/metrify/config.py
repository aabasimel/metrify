from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    app_name: str = "Metrify"
    debug: bool = False
    api_key_header: str = "X-Metrify-Key"

    database_url: str = "postgresql+asyncpg://metrify:metrify@localhost:5432/metrify"
    database_pool_size: int = 20
    database_max_overflow: int = 10

    redis_url: str = "redis://localhost:6379/0"
    redis_event_buffer_key: str = "metrify:events:buffer"
    redis_event_buffer_flush_size: int = 1000
    redis_event_buffer_flush_interval_seconds: int = 5

    stripe_secret_key: str = ""
    stripe_webhook_secret: str = ""

    openai_admin_key: str = ""
    anthropic_admin_key: str = ""

    default_vat_country: str = "DE"
    oss_threshold_eur: int = 10000

    sentry_dsn: str = ""

    posthog_api_key: str = ""
    posthog_host: str = "https://eu.posthog.com"

    model_config = {"env_file": ".env", "env_prefix": "METRIFY_"}


@lru_cache
def get_settings() -> Settings:
    return Settings()
