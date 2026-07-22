import asyncio
import uuid
import dramatiq
import structlog
from datetime import date

from metrify.tasks.broker import redis_broker  # noqa
from metrify.database import async_session_factory
from metrify.services.billing_sync import BillingSyncService

logger = structlog.get_logger()


@dramatiq.actor(max_retries=2, min_backoff=60_000)
def sync_billing_task(organization_id: str, period_start: str, period_end: str, dry_run: bool = False):
    asyncio.run(_sync(uuid.UUID(organization_id), date.fromisoformat(period_start), date.fromisoformat(period_end), dry_run))


async def _sync(org_id: uuid.UUID, start: date, end: date, dry_run: bool):
    async with async_session_factory() as session:
        service = BillingSyncService(session)
        await service.sync_to_stripe(org_id, start, end, dry_run)
        await session.commit()
