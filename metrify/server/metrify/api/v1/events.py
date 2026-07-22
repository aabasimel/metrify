from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from redis.asyncio import Redis

from metrify.database import get_db_session
from metrify.redis import get_redis
from metrify.api.deps import get_current_organization
from metrify.models.organization import Organization
from metrify.schemas.event import EventBatchCreate, EventBatchResponse, EventCreate
from metrify.services.event_ingestion import EventIngestionService

router = APIRouter(prefix="/events", tags=["Events"])


@router.post("/batch", response_model=EventBatchResponse)
async def ingest_event_batch(
    payload: EventBatchCreate,
    organization: Organization = Depends(get_current_organization),
    session: AsyncSession = Depends(get_db_session),
    redis: Redis = Depends(get_redis),
):
    service = EventIngestionService(session, redis)
    return await service.ingest_batch(organization, payload.events)


@router.post("/single", response_model=EventBatchResponse)
async def ingest_single_event(
    payload: EventCreate,
    organization: Organization = Depends(get_current_organization),
    session: AsyncSession = Depends(get_db_session),
    redis: Redis = Depends(get_redis),
):
    service = EventIngestionService(session, redis)
    return await service.ingest_batch(organization, [payload])
