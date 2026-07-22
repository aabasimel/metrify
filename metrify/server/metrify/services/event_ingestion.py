import uuid
import structlog
from datetime import datetime, timezone
from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession

from metrify.models.event import Event
from metrify.models.organization import Organization
from metrify.repositories.event import EventRepository
from metrify.repositories.customer import CustomerRepository
from metrify.schemas.event import EventCreate, EventBatchResponse
from metrify.config import get_settings

logger = structlog.get_logger()
settings = get_settings()


class EventIngestionService:
    def __init__(self, session: AsyncSession, redis: Redis):
        self.session = session
        self.redis = redis
        self.event_repo = EventRepository(session)
        self.customer_repo = CustomerRepository(session)

    async def ingest_batch(
        self, organization: Organization, events: list[EventCreate],
    ) -> EventBatchResponse:
        accepted = 0
        rejected = 0
        errors: list[str] = []

        idem_keys = [e.idempotency_key for e in events if e.idempotency_key]
        existing_keys = await self.event_repo.check_idempotency(
            organization.id, idem_keys
        )

        customer_cache: dict[str, uuid.UUID] = {}
        db_events: list[Event] = []

        for i, event_data in enumerate(events):
            if event_data.idempotency_key and event_data.idempotency_key in existing_keys:
                rejected += 1
                errors.append(f"Event {i}: duplicate idempotency_key")
                continue

            ext_id = event_data.customer_id
            if ext_id not in customer_cache:
                customer = await self.customer_repo.get_or_create(
                    organization.id, ext_id
                )
                customer_cache[ext_id] = customer.id

            event = Event(
                organization_id=organization.id,
                customer_id=customer_cache[ext_id],
                event_name=event_data.event_name,
                units=event_data.units,
                properties=event_data.properties,
                timestamp=event_data.timestamp or datetime.now(timezone.utc),
                idempotency_key=event_data.idempotency_key,
            )
            db_events.append(event)
            accepted += 1

        if db_events:
            await self.event_repo.create_many(db_events)
            pipe = self.redis.pipeline()
            for event in db_events:
                counter_key = f"metrify:counter:{organization.id}:{event.customer_id}:{event.event_name}"
                pipe.incrby(counter_key, event.units)
                pipe.expire(counter_key, 86400 * 35)
            await pipe.execute()

        logger.info("batch_ingested", org=str(organization.id), accepted=accepted, rejected=rejected)
        return EventBatchResponse(accepted=accepted, rejected=rejected, errors=errors)
