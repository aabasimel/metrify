import uuid
from datetime import datetime
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from metrify.models.event import Event
from metrify.repositories.base import BaseRepository


class EventRepository(BaseRepository[Event]):
    def __init__(self, session: AsyncSession):
        super().__init__(session, Event)

    async def get_usage_by_customer_and_event(
        self, organization_id: uuid.UUID, start: datetime, end: datetime,
    ) -> list[dict]:
        stmt = (
            select(
                Event.customer_id,
                Event.event_name,
                func.sum(Event.units).label("total_units"),
                func.count(Event.id).label("event_count"),
            )
            .where(
                Event.organization_id == organization_id,
                Event.timestamp >= start,
                Event.timestamp < end,
            )
            .group_by(Event.customer_id, Event.event_name)
        )
        result = await self.session.execute(stmt)
        return [dict(row._mapping) for row in result.all()]

    async def check_idempotency(
        self, organization_id: uuid.UUID, keys: list[str]
    ) -> set[str]:
        if not keys:
            return set()
        stmt = select(Event.idempotency_key).where(
            Event.organization_id == organization_id,
            Event.idempotency_key.in_(keys),
        )
        result = await self.session.execute(stmt)
        return {row[0] for row in result.all()}
