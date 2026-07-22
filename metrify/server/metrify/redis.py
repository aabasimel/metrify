import redis.asyncio as redis
from metrify.config import get_settings

settings = get_settings()

redis_pool = redis.ConnectionPool.from_url(
    settings.redis_url,
    decode_responses=True,
    max_connections=50,
)


async def get_redis() -> redis.Redis:
    return redis.Redis(connection_pool=redis_pool)
