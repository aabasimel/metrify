import uuid
from datetime import datetime
from pydantic import BaseModel, Field


class EventCreate(BaseModel):
    event_name: str = Field(..., max_length=255)
    customer_id: str = Field(..., max_length=255)
    units: int = Field(default=1, ge=0)
    properties: dict | None = None
    timestamp: datetime | None = None
    idempotency_key: str | None = Field(default=None, max_length=255)
    project_slug: str | None = None


class EventBatchCreate(BaseModel):
    events: list[EventCreate] = Field(..., max_length=1000)


class EventResponse(BaseModel):
    id: uuid.UUID
    event_name: str
    customer_id: str
    units: int
    timestamp: datetime
    ingested_at: datetime
    model_config = {"from_attributes": True}


class EventBatchResponse(BaseModel):
    accepted: int
    rejected: int
    errors: list[str] = []
