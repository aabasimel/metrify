import asyncio
import uuid
import dramatiq
import structlog
from datetime import date

from metrify.tasks.broker import redis_broker  # noqa
from metrify.database import async_session_factory
from metrify.models.organization import Organization
from metrify.services.cost_puller import CostPullerService

logger = structlog.get_logger()


@dramatiq.actor(max_retries=3, min_backoff=30_000)
def pull_costs_task(organization_id: str, cost_date: str | None = None):
    asyncio.run(_pull(uuid.UUID(organization_id), date.fromisoformat(cost_date) if cost_date else None))


async def _pull(org_id: uuid.UUID, cost_date: date | None):
    async with async_session_factory() as session:
        org = await session.get(Organization, org_id)
        if not org:
            return
        service = CostPullerService(session)
        await service.pull_and_attribute(org, cost_date)
        await session.commit()
