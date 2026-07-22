import asyncio
import uuid
import dramatiq
import structlog
from datetime import date

from metrify.tasks.broker import redis_broker  # noqa
from metrify.database import async_session_factory
from metrify.services.usage_aggregation import UsageAggregationService

logger = structlog.get_logger()


@dramatiq.actor(max_retries=3, min_backoff=10_000)
def aggregate_usage_task(organization_id: str, period_start: str, period_end: str):
    asyncio.run(_aggregate(uuid.UUID(organization_id), date.fromisoformat(period_start), date.fromisoformat(period_end)))


async def _aggregate(org_id: uuid.UUID, start: date, end: date):
    async with async_session_factory() as session:
        service = UsageAggregationService(session)
        await service.aggregate_period(org_id, start, end)
        await session.commit()
