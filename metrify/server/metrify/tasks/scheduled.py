import structlog
from datetime import date, timedelta
from sqlalchemy import select
from apscheduler.schedulers.asyncio import AsyncIOScheduler

from metrify.database import async_session_factory
from metrify.models.organization import Organization
from metrify.tasks.pull_costs import pull_costs_task
from metrify.tasks.aggregate_usage import aggregate_usage_task

logger = structlog.get_logger()
scheduler = AsyncIOScheduler()


async def daily_cost_pull():
    yesterday = (date.today() - timedelta(days=1)).isoformat()
    async with async_session_factory() as session:
        result = await session.execute(select(Organization.id))
        org_ids = [str(row[0]) for row in result.all()]
    for org_id in org_ids:
        pull_costs_task.send(org_id, yesterday)


async def daily_usage_aggregate():
    yesterday = date.today() - timedelta(days=1)
    today = date.today()
    async with async_session_factory() as session:
        result = await session.execute(select(Organization.id))
        org_ids = [str(row[0]) for row in result.all()]
    for org_id in org_ids:
        aggregate_usage_task.send(org_id, yesterday.isoformat(), today.isoformat())


def start_scheduler():
    scheduler.add_job(daily_cost_pull, "cron", hour=6, minute=0)
    scheduler.add_job(daily_usage_aggregate, "cron", hour=7, minute=0)
    scheduler.start()
