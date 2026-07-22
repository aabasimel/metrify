#!/bin/bash
set -e

PROJECT="metrify"
mkdir -p $PROJECT
cd $PROJECT

# ============================================
# SERVER
# ============================================
mkdir -p server/metrify/{models,schemas,repositories,services,api/v1,tasks,utils}
mkdir -p server/alembic/versions
mkdir -p server/tests

# --- pyproject.toml ---
cat > server/pyproject.toml << 'PYPROJECT'
[project]
name = "metrify-server"
version = "0.1.0"
description = "Usage-based billing middleware + cost intelligence for AI startups"
requires-python = ">=3.12"
dependencies = [
    "fastapi>=0.115.0",
    "uvicorn[standard]>=0.30.0",
    "pydantic>=2.9.0",
    "pydantic-settings>=2.5.0",
    "sqlalchemy[asyncio]>=2.0.35",
    "asyncpg>=0.30.0",
    "alembic>=1.14.0",
    "redis[hiredis]>=5.2.0",
    "dramatiq[redis]>=1.17.0",
    "stripe>=11.0.0",
    "httpx>=0.27.0",
    "openai>=1.50.0",
    "anthropic>=0.36.0",
    "structlog>=24.4.0",
    "sentry-sdk[fastapi]>=2.14.0",
    "posthog>=3.7.0",
    "apscheduler>=3.10.0",
    "python-jose[cryptography]>=3.3.0",
    "passlib[bcrypt]>=1.7.4",
]

[project.optional-dependencies]
dev = [
    "pytest>=8.3.0",
    "pytest-asyncio>=0.24.0",
    "httpx>=0.27.0",
    "factory-boy>=3.3.0",
    "ruff>=0.6.0",
    "mypy>=1.11.0",
    "aiosqlite>=0.20.0",
]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.ruff]
target-version = "py312"
line-length = 88

[tool.pytest.ini_options]
asyncio_mode = "auto"
PYPROJECT

# --- config.py ---
cat > server/metrify/config.py << 'EOF'
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
EOF

# --- database.py ---
cat > server/metrify/database.py << 'EOF'
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from metrify.config import get_settings

settings = get_settings()

engine = create_async_engine(
    settings.database_url,
    pool_size=settings.database_pool_size,
    max_overflow=settings.database_max_overflow,
    echo=settings.debug,
)

async_session_factory = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


async def get_db_session():
    async with async_session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
EOF

# --- redis.py ---
cat > server/metrify/redis.py << 'EOF'
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
EOF

# --- models/base.py ---
cat > server/metrify/models/base.py << 'EOF'
import uuid
from datetime import datetime
from sqlalchemy import DateTime, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column
from sqlalchemy.dialects.postgresql import UUID


class Base(DeclarativeBase):
    pass


class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )


class IDMixin:
    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
EOF

# --- models/organization.py ---
cat > server/metrify/models/organization.py << 'EOF'
import uuid
from sqlalchemy import String, Boolean
from sqlalchemy.orm import Mapped, mapped_column, relationship
from metrify.models.base import Base, IDMixin, TimestampMixin


class Organization(Base, IDMixin, TimestampMixin):
    __tablename__ = "organizations"

    name: Mapped[str] = mapped_column(String(255), nullable=False)
    slug: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    stripe_account_id: Mapped[str | None] = mapped_column(String(255))
    api_key_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    api_key_prefix: Mapped[str] = mapped_column(String(12), nullable=False)
    country: Mapped[str] = mapped_column(String(2), default="DE")
    vat_number: Mapped[str | None] = mapped_column(String(20))
    oss_registered: Mapped[bool] = mapped_column(Boolean, default=False)
    openai_api_key_encrypted: Mapped[str | None] = mapped_column(String(500))
    anthropic_api_key_encrypted: Mapped[str | None] = mapped_column(String(500))

    projects: Mapped[list["Project"]] = relationship(back_populates="organization")
    customers: Mapped[list["Customer"]] = relationship(back_populates="organization")
EOF

# --- models/project.py ---
cat > server/metrify/models/project.py << 'EOF'
import uuid
from sqlalchemy import String, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from metrify.models.base import Base, IDMixin, TimestampMixin


class Project(Base, IDMixin, TimestampMixin):
    __tablename__ = "projects"

    organization_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("organizations.id"), nullable=False
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    slug: Mapped[str] = mapped_column(String(255), nullable=False)

    organization: Mapped["Organization"] = relationship(back_populates="projects")
    events: Mapped[list["Event"]] = relationship(back_populates="project")
EOF

# --- models/customer.py ---
cat > server/metrify/models/customer.py << 'EOF'
import uuid
from sqlalchemy import String, ForeignKey, Integer
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from metrify.models.base import Base, IDMixin, TimestampMixin


class Customer(Base, IDMixin, TimestampMixin):
    __tablename__ = "customers"

    organization_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("organizations.id"), nullable=False
    )
    external_id: Mapped[str] = mapped_column(String(255), nullable=False)
    name: Mapped[str | None] = mapped_column(String(255))
    email: Mapped[str | None] = mapped_column(String(255))
    stripe_customer_id: Mapped[str | None] = mapped_column(String(255))
    stripe_subscription_id: Mapped[str | None] = mapped_column(String(255))
    country: Mapped[str | None] = mapped_column(String(2))
    vat_number: Mapped[str | None] = mapped_column(String(20))
    vat_verified: Mapped[bool] = mapped_column(default=False)
    plan_name: Mapped[str | None] = mapped_column(String(100))
    included_units: Mapped[int] = mapped_column(Integer, default=0)
    overage_price_cents: Mapped[int] = mapped_column(Integer, default=0)

    organization: Mapped["Organization"] = relationship(back_populates="customers")
    events: Mapped[list["Event"]] = relationship(back_populates="customer")
    usage_aggregates: Mapped[list["UsageAggregate"]] = relationship(back_populates="customer")
    ai_costs: Mapped[list["AICost"]] = relationship(back_populates="customer")
EOF

# --- models/event.py ---
cat > server/metrify/models/event.py << 'EOF'
import uuid
from datetime import datetime
from sqlalchemy import String, ForeignKey, BigInteger, DateTime, Index
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship
from metrify.models.base import Base, IDMixin


class Event(Base, IDMixin):
    __tablename__ = "events"

    organization_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("organizations.id"), nullable=False
    )
    project_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("projects.id")
    )
    customer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("customers.id"), nullable=False
    )
    event_name: Mapped[str] = mapped_column(String(255), nullable=False)
    units: Mapped[int] = mapped_column(BigInteger, default=1)
    properties: Mapped[dict | None] = mapped_column(JSONB)
    timestamp: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    ingested_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default="now()"
    )
    idempotency_key: Mapped[str | None] = mapped_column(String(255))

    project: Mapped["Project | None"] = relationship(back_populates="events")
    customer: Mapped["Customer"] = relationship(back_populates="events")

    __table_args__ = (
        Index("ix_events_org_customer_name_ts", "organization_id", "customer_id", "event_name", "timestamp"),
        Index("ix_events_org_ts", "organization_id", "timestamp"),
        Index("ix_events_idempotency", "organization_id", "idempotency_key", unique=True),
    )
EOF

# --- models/usage_aggregate.py ---
cat > server/metrify/models/usage_aggregate.py << 'EOF'
import uuid
from datetime import date
from sqlalchemy import String, ForeignKey, BigInteger, Date, Index, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from metrify.models.base import Base, IDMixin, TimestampMixin


class UsageAggregate(Base, IDMixin, TimestampMixin):
    __tablename__ = "usage_aggregates"

    organization_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("organizations.id"), nullable=False
    )
    customer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("customers.id"), nullable=False
    )
    event_name: Mapped[str] = mapped_column(String(255), nullable=False)
    period_start: Mapped[date] = mapped_column(Date, nullable=False)
    period_end: Mapped[date] = mapped_column(Date, nullable=False)
    total_units: Mapped[int] = mapped_column(BigInteger, default=0)
    billable_units: Mapped[int] = mapped_column(BigInteger, default=0)
    amount_cents: Mapped[int] = mapped_column(BigInteger, default=0)
    stripe_invoice_item_id: Mapped[str | None] = mapped_column(String(255))
    synced_to_stripe: Mapped[bool] = mapped_column(default=False)

    customer: Mapped["Customer"] = relationship(back_populates="usage_aggregates")

    __table_args__ = (
        UniqueConstraint(
            "organization_id", "customer_id", "event_name", "period_start",
            name="uq_usage_agg_org_cust_event_period",
        ),
        Index("ix_usage_agg_org_period", "organization_id", "period_start"),
    )
EOF

# --- models/ai_cost.py ---
cat > server/metrify/models/ai_cost.py << 'EOF'
import uuid
from datetime import date
from sqlalchemy import String, ForeignKey, BigInteger, Integer, Date, Index
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from metrify.models.base import Base, IDMixin, TimestampMixin


class AICost(Base, IDMixin, TimestampMixin):
    __tablename__ = "ai_costs"

    organization_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("organizations.id"), nullable=False
    )
    customer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("customers.id"), nullable=False
    )
    provider: Mapped[str] = mapped_column(String(50), nullable=False)
    model: Mapped[str] = mapped_column(String(100), nullable=False)
    cost_date: Mapped[date] = mapped_column(Date, nullable=False)
    input_tokens: Mapped[int] = mapped_column(BigInteger, default=0)
    output_tokens: Mapped[int] = mapped_column(BigInteger, default=0)
    total_tokens: Mapped[int] = mapped_column(BigInteger, default=0)
    cost_microdollars: Mapped[int] = mapped_column(BigInteger, default=0)
    cost_cents: Mapped[int] = mapped_column(Integer, default=0)
    attribution_method: Mapped[str] = mapped_column(String(50), default="proportional")

    customer: Mapped["Customer"] = relationship(back_populates="ai_costs")

    __table_args__ = (
        Index("ix_ai_costs_org_date", "organization_id", "cost_date"),
        Index("ix_ai_costs_customer_date", "customer_id", "cost_date"),
    )
EOF

# --- models/vat_config.py ---
cat > server/metrify/models/vat_config.py << 'EOF'
from sqlalchemy import String, Integer, Boolean
from sqlalchemy.orm import Mapped, mapped_column
from metrify.models.base import Base, IDMixin


class EUVATRate(Base, IDMixin):
    __tablename__ = "eu_vat_rates"

    country_code: Mapped[str] = mapped_column(String(2), unique=True, nullable=False)
    country_name: Mapped[str] = mapped_column(String(100), nullable=False)
    standard_rate: Mapped[int] = mapped_column(Integer, nullable=False)
    reduced_rate: Mapped[int | None] = mapped_column(Integer)
    digital_services_rate: Mapped[int] = mapped_column(Integer, nullable=False)
    has_oss: Mapped[bool] = mapped_column(Boolean, default=True)
EOF

# --- models/__init__.py ---
cat > server/metrify/models/__init__.py << 'EOF'
from metrify.models.base import Base
from metrify.models.organization import Organization
from metrify.models.project import Project
from metrify.models.customer import Customer
from metrify.models.event import Event
from metrify.models.usage_aggregate import UsageAggregate
from metrify.models.ai_cost import AICost
from metrify.models.vat_config import EUVATRate

__all__ = [
    "Base", "Organization", "Project", "Customer",
    "Event", "UsageAggregate", "AICost", "EUVATRate",
]
EOF

# --- schemas/event.py ---
cat > server/metrify/schemas/event.py << 'EOF'
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
EOF

# --- schemas/billing.py ---
cat > server/metrify/schemas/billing.py << 'EOF'
import uuid
from datetime import date
from pydantic import BaseModel


class UsageAggregateResponse(BaseModel):
    customer_id: uuid.UUID
    customer_external_id: str
    event_name: str
    period_start: date
    period_end: date
    total_units: int
    billable_units: int
    amount_cents: int
    synced_to_stripe: bool
    model_config = {"from_attributes": True}


class BillingSyncRequest(BaseModel):
    period_start: date
    period_end: date
    dry_run: bool = True


class BillingSyncResult(BaseModel):
    customers_synced: int
    total_amount_cents: int
    stripe_invoice_items_created: int
    dry_run: bool
    details: list[dict]
EOF

# --- schemas/margin.py ---
cat > server/metrify/schemas/margin.py << 'EOF'
import uuid
from datetime import date
from pydantic import BaseModel, computed_field


class CustomerMargin(BaseModel):
    customer_id: uuid.UUID
    customer_external_id: str
    customer_name: str | None
    period_start: date
    period_end: date
    revenue_cents: int
    ai_cost_cents: int

    @computed_field
    @property
    def gross_profit_cents(self) -> int:
        return self.revenue_cents - self.ai_cost_cents

    @computed_field
    @property
    def margin_percent(self) -> float:
        if self.revenue_cents == 0:
            return 0.0
        return round((self.gross_profit_cents / self.revenue_cents) * 100, 2)


class MarginSummary(BaseModel):
    period_start: date
    period_end: date
    total_revenue_cents: int
    total_ai_cost_cents: int
    total_gross_profit_cents: int
    overall_margin_percent: float
    customer_count: int
    customers: list[CustomerMargin]
    unprofitable_customers: list[CustomerMargin]
EOF

# --- schemas/vat.py ---
cat > server/metrify/schemas/vat.py << 'EOF'
from pydantic import BaseModel


class VATCalculationRequest(BaseModel):
    seller_country: str
    buyer_country: str
    buyer_vat_number: str | None = None
    amount_cents: int
    is_digital_service: bool = True


class VATCalculationResponse(BaseModel):
    net_amount_cents: int
    vat_amount_cents: int
    gross_amount_cents: int
    vat_rate_bps: int
    vat_rate_percent: float
    treatment: str
    buyer_country: str
    seller_country: str
    notes: str


class OSSThresholdStatus(BaseModel):
    current_year_eu_sales_cents: int
    oss_threshold_cents: int
    threshold_reached: bool
    threshold_percent: float
    countries_sold_to: list[str]
    recommendation: str
EOF

# --- schemas/__init__.py ---
touch server/metrify/schemas/__init__.py

# --- repositories/base.py ---
cat > server/metrify/repositories/base.py << 'EOF'
import uuid
from typing import TypeVar, Generic, Type
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from metrify.models.base import Base

ModelType = TypeVar("ModelType", bound=Base)


class BaseRepository(Generic[ModelType]):
    def __init__(self, session: AsyncSession, model: Type[ModelType]):
        self.session = session
        self.model = model

    async def get_by_id(self, id: uuid.UUID) -> ModelType | None:
        return await self.session.get(self.model, id)

    async def create(self, obj: ModelType) -> ModelType:
        self.session.add(obj)
        await self.session.flush()
        return obj

    async def create_many(self, objects: list[ModelType]) -> list[ModelType]:
        self.session.add_all(objects)
        await self.session.flush()
        return objects

    async def count(self, **filters) -> int:
        stmt = select(func.count()).select_from(self.model)
        for key, value in filters.items():
            stmt = stmt.where(getattr(self.model, key) == value)
        result = await self.session.execute(stmt)
        return result.scalar_one()
EOF

# --- repositories/event.py ---
cat > server/metrify/repositories/event.py << 'EOF'
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
EOF

# --- repositories/customer.py ---
cat > server/metrify/repositories/customer.py << 'EOF'
import uuid
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from metrify.models.customer import Customer
from metrify.repositories.base import BaseRepository


class CustomerRepository(BaseRepository[Customer]):
    def __init__(self, session: AsyncSession):
        super().__init__(session, Customer)

    async def get_by_external_id(
        self, organization_id: uuid.UUID, external_id: str
    ) -> Customer | None:
        stmt = select(Customer).where(
            Customer.organization_id == organization_id,
            Customer.external_id == external_id,
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_or_create(
        self, organization_id: uuid.UUID, external_id: str
    ) -> Customer:
        customer = await self.get_by_external_id(organization_id, external_id)
        if customer:
            return customer
        customer = Customer(
            organization_id=organization_id,
            external_id=external_id,
        )
        return await self.create(customer)

    async def list_by_organization(self, organization_id: uuid.UUID) -> list[Customer]:
        stmt = (
            select(Customer)
            .where(Customer.organization_id == organization_id)
            .order_by(Customer.created_at.desc())
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())
EOF

# --- repositories/ai_cost.py ---
cat > server/metrify/repositories/ai_cost.py << 'EOF'
import uuid
from datetime import date
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from metrify.models.ai_cost import AICost
from metrify.repositories.base import BaseRepository


class AICostRepository(BaseRepository[AICost]):
    def __init__(self, session: AsyncSession):
        super().__init__(session, AICost)

    async def get_costs_by_customer(
        self, organization_id: uuid.UUID, start_date: date, end_date: date,
    ) -> list[dict]:
        stmt = (
            select(
                AICost.customer_id,
                func.sum(AICost.cost_cents).label("total_cost_cents"),
                func.sum(AICost.input_tokens).label("total_input_tokens"),
                func.sum(AICost.output_tokens).label("total_output_tokens"),
            )
            .where(
                AICost.organization_id == organization_id,
                AICost.cost_date >= start_date,
                AICost.cost_date <= end_date,
            )
            .group_by(AICost.customer_id)
        )
        result = await self.session.execute(stmt)
        return [dict(row._mapping) for row in result.all()]
EOF

# --- repositories/__init__.py ---
touch server/metrify/repositories/__init__.py

# --- services/event_ingestion.py ---
cat > server/metrify/services/event_ingestion.py << 'EOF'
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
EOF

# --- services/usage_aggregation.py ---
cat > server/metrify/services/usage_aggregation.py << 'EOF'
import uuid
import structlog
from datetime import date, datetime, timezone
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.dialects.postgresql import insert

from metrify.models.usage_aggregate import UsageAggregate
from metrify.models.customer import Customer
from metrify.repositories.event import EventRepository

logger = structlog.get_logger()


class UsageAggregationService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.event_repo = EventRepository(session)

    async def aggregate_period(
        self, organization_id: uuid.UUID, period_start: date, period_end: date,
    ) -> list[UsageAggregate]:
        start_dt = datetime.combine(period_start, datetime.min.time(), tzinfo=timezone.utc)
        end_dt = datetime.combine(period_end, datetime.min.time(), tzinfo=timezone.utc)

        usage_data = await self.event_repo.get_usage_by_customer_and_event(
            organization_id, start_dt, end_dt
        )

        aggregates = []
        for row in usage_data:
            customer = await self.session.get(Customer, row["customer_id"])
            if not customer:
                continue

            total_units = row["total_units"]
            billable = max(0, total_units - customer.included_units)
            amount_cents = billable * customer.overage_price_cents

            stmt = (
                insert(UsageAggregate)
                .values(
                    organization_id=organization_id,
                    customer_id=row["customer_id"],
                    event_name=row["event_name"],
                    period_start=period_start,
                    period_end=period_end,
                    total_units=total_units,
                    billable_units=billable,
                    amount_cents=amount_cents,
                )
                .on_conflict_do_update(
                    constraint="uq_usage_agg_org_cust_event_period",
                    set_={"total_units": total_units, "billable_units": billable, "amount_cents": amount_cents},
                )
                .returning(UsageAggregate)
            )
            result = await self.session.execute(stmt)
            aggregates.append(result.scalar_one())

        logger.info("usage_aggregated", org=str(organization_id), count=len(aggregates))
        return aggregates
EOF

# --- services/billing_sync.py ---
cat > server/metrify/services/billing_sync.py << 'EOF'
import uuid
import stripe
import structlog
from datetime import date
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from metrify.models.usage_aggregate import UsageAggregate
from metrify.models.customer import Customer
from metrify.schemas.billing import BillingSyncResult
from metrify.config import get_settings

logger = structlog.get_logger()
settings = get_settings()


class BillingSyncService:
    def __init__(self, session: AsyncSession):
        self.session = session
        stripe.api_key = settings.stripe_secret_key

    async def sync_to_stripe(
        self, organization_id: uuid.UUID, period_start: date, period_end: date, dry_run: bool = True,
    ) -> BillingSyncResult:
        stmt = (
            select(UsageAggregate)
            .join(Customer)
            .where(
                UsageAggregate.organization_id == organization_id,
                UsageAggregate.period_start == period_start,
                UsageAggregate.period_end == period_end,
                UsageAggregate.synced_to_stripe == False,
                UsageAggregate.billable_units > 0,
                Customer.stripe_customer_id.isnot(None),
            )
        )
        result = await self.session.execute(stmt)
        aggregates = list(result.scalars().all())

        details = []
        items_created = 0
        total_amount = 0

        for agg in aggregates:
            customer = await self.session.get(Customer, agg.customer_id)
            if not customer or not customer.stripe_customer_id:
                continue

            detail = {
                "customer": customer.external_id,
                "event": agg.event_name,
                "units": agg.billable_units,
                "amount": agg.amount_cents,
            }

            if not dry_run:
                try:
                    item = stripe.InvoiceItem.create(
                        customer=customer.stripe_customer_id,
                        amount=agg.amount_cents,
                        currency="eur",
                        description=f"Usage: {agg.event_name} - {agg.billable_units} units ({period_start} to {period_end})",
                    )
                    agg.stripe_invoice_item_id = item.id
                    agg.synced_to_stripe = True
                    items_created += 1
                    detail["stripe_id"] = item.id
                except stripe.StripeError as e:
                    detail["error"] = str(e)

            total_amount += agg.amount_cents
            details.append(detail)

        return BillingSyncResult(
            customers_synced=len(details),
            total_amount_cents=total_amount,
            stripe_invoice_items_created=items_created,
            dry_run=dry_run,
            details=details,
        )
EOF

# --- services/cost_puller.py ---
cat > server/metrify/services/cost_puller.py << 'EOF'
import uuid
import structlog
from datetime import date, datetime, timedelta, timezone
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from metrify.models.organization import Organization
from metrify.models.event import Event
from metrify.models.ai_cost import AICost

logger = structlog.get_logger()

OPENAI_PRICING = {
    "gpt-4o": {"input": 2.50, "output": 10.00},
    "gpt-4o-mini": {"input": 0.15, "output": 0.60},
    "gpt-4-turbo": {"input": 10.00, "output": 30.00},
    "o1": {"input": 15.00, "output": 60.00},
    "o1-mini": {"input": 3.00, "output": 12.00},
    "o3-mini": {"input": 1.10, "output": 4.40},
}

ANTHROPIC_PRICING = {
    "claude-sonnet-4-20250514": {"input": 3.00, "output": 15.00},
    "claude-3-5-sonnet-20241022": {"input": 3.00, "output": 15.00},
    "claude-3-5-haiku-20241022": {"input": 0.80, "output": 4.00},
    "claude-3-opus-20240229": {"input": 15.00, "output": 75.00},
}


class CostPullerService:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def pull_and_attribute(
        self, organization: Organization, cost_date: date | None = None,
    ) -> list[AICost]:
        if cost_date is None:
            cost_date = date.today() - timedelta(days=1)

        start = datetime.combine(cost_date, datetime.min.time(), tzinfo=timezone.utc)
        end = datetime.combine(cost_date + timedelta(days=1), datetime.min.time(), tzinfo=timezone.utc)

        stmt = (
            select(Event.customer_id, Event.properties)
            .where(
                Event.organization_id == organization.id,
                Event.timestamp >= start,
                Event.timestamp < end,
                Event.event_name.in_(["ai_tokens", "ai_completion", "llm_call"]),
                Event.properties.isnot(None),
            )
        )
        result = await self.session.execute(stmt)
        events = result.all()

        cost_map: dict[tuple[uuid.UUID, str, str], dict] = {}

        for row in events:
            props = row.properties or {}
            model = props.get("model", "unknown")
            provider = self._detect_provider(model)
            input_tokens = props.get("input_tokens", 0)
            output_tokens = props.get("output_tokens", 0)
            cost_micro = self._calculate_cost(provider, model, input_tokens, output_tokens)

            key = (row.customer_id, provider, model)
            if key not in cost_map:
                cost_map[key] = {"input_tokens": 0, "output_tokens": 0, "cost_microdollars": 0}
            cost_map[key]["input_tokens"] += input_tokens
            cost_map[key]["output_tokens"] += output_tokens
            cost_map[key]["cost_microdollars"] += cost_micro

        ai_costs = []
        for (customer_id, provider, model), data in cost_map.items():
            ai_cost = AICost(
                organization_id=organization.id,
                customer_id=customer_id,
                provider=provider,
                model=model,
                cost_date=cost_date,
                input_tokens=data["input_tokens"],
                output_tokens=data["output_tokens"],
                total_tokens=data["input_tokens"] + data["output_tokens"],
                cost_microdollars=data["cost_microdollars"],
                cost_cents=data["cost_microdollars"] // 10_000,
                attribution_method="direct",
            )
            self.session.add(ai_cost)
            ai_costs.append(ai_cost)

        await self.session.flush()
        logger.info("costs_attributed", org=str(organization.id), records=len(ai_costs))
        return ai_costs

    def _detect_provider(self, model: str) -> str:
        if model.startswith("claude"):
            return "anthropic"
        if model.startswith(("gpt", "o1", "o3")):
            return "openai"
        return "unknown"

    def _calculate_cost(self, provider: str, model: str, input_tokens: int, output_tokens: int) -> int:
        pricing = {}
        if provider == "openai":
            pricing = OPENAI_PRICING.get(model, {})
        elif provider == "anthropic":
            pricing = ANTHROPIC_PRICING.get(model, {})
        if not pricing:
            return 0
        input_cost = (input_tokens * pricing.get("input", 0)) / 1_000_000 * 1_000_000
        output_cost = (output_tokens * pricing.get("output", 0)) / 1_000_000 * 1_000_000
        return int(input_cost + output_cost)
EOF

# --- services/margin_calculator.py ---
cat > server/metrify/services/margin_calculator.py << 'EOF'
import uuid
import structlog
from datetime import date
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from metrify.models.usage_aggregate import UsageAggregate
from metrify.models.ai_cost import AICost
from metrify.models.customer import Customer
from metrify.schemas.margin import CustomerMargin, MarginSummary

logger = structlog.get_logger()


class MarginCalculatorService:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def calculate_margins(
        self, organization_id: uuid.UUID, period_start: date, period_end: date,
    ) -> MarginSummary:
        rev_stmt = (
            select(UsageAggregate.customer_id, func.sum(UsageAggregate.amount_cents).label("revenue_cents"))
            .where(
                UsageAggregate.organization_id == organization_id,
                UsageAggregate.period_start >= period_start,
                UsageAggregate.period_end <= period_end,
            )
            .group_by(UsageAggregate.customer_id)
        )
        rev_result = await self.session.execute(rev_stmt)
        revenue_map = {r.customer_id: r.revenue_cents for r in rev_result.all()}

        cost_stmt = (
            select(AICost.customer_id, func.sum(AICost.cost_cents).label("cost_cents"))
            .where(
                AICost.organization_id == organization_id,
                AICost.cost_date >= period_start,
                AICost.cost_date <= period_end,
            )
            .group_by(AICost.customer_id)
        )
        cost_result = await self.session.execute(cost_stmt)
        cost_map = {r.customer_id: r.cost_cents for r in cost_result.all()}

        all_ids = set(revenue_map.keys()) | set(cost_map.keys())
        customers_data = []

        for cid in all_ids:
            customer = await self.session.get(Customer, cid)
            if not customer:
                continue
            customers_data.append(CustomerMargin(
                customer_id=cid,
                customer_external_id=customer.external_id,
                customer_name=customer.name,
                period_start=period_start,
                period_end=period_end,
                revenue_cents=revenue_map.get(cid, 0),
                ai_cost_cents=cost_map.get(cid, 0),
            ))

        customers_data.sort(key=lambda c: c.margin_percent)
        unprofitable = [c for c in customers_data if c.gross_profit_cents < 0]

        total_rev = sum(c.revenue_cents for c in customers_data)
        total_cost = sum(c.ai_cost_cents for c in customers_data)
        total_profit = total_rev - total_cost
        margin = round((total_profit / total_rev) * 100, 2) if total_rev > 0 else 0.0

        return MarginSummary(
            period_start=period_start,
            period_end=period_end,
            total_revenue_cents=total_rev,
            total_ai_cost_cents=total_cost,
            total_gross_profit_cents=total_profit,
            overall_margin_percent=margin,
            customer_count=len(customers_data),
            customers=sorted(customers_data, key=lambda c: c.revenue_cents, reverse=True),
            unprofitable_customers=unprofitable,
        )
EOF

# --- services/vat_engine.py ---
cat > server/metrify/services/vat_engine.py << 'EOF'
import structlog
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from metrify.models.vat_config import EUVATRate
from metrify.schemas.vat import VATCalculationRequest, VATCalculationResponse, OSSThresholdStatus

logger = structlog.get_logger()

EU_COUNTRIES = {
    "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR",
    "DE", "GR", "HU", "IE", "IT", "LV", "LT", "LU", "MT", "NL",
    "PL", "PT", "RO", "SK", "SI", "ES", "SE",
}

DEFAULT_DIGITAL_VAT_RATES = {
    "AT": 2000, "BE": 2100, "BG": 2000, "HR": 2500, "CY": 1900,
    "CZ": 2100, "DK": 2500, "EE": 2200, "FI": 2550, "FR": 2000,
    "DE": 1900, "GR": 2400, "HU": 2700, "IE": 2300, "IT": 2200,
    "LV": 2100, "LT": 2100, "LU": 1700, "MT": 1800, "NL": 2100,
    "PL": 2300, "PT": 2300, "RO": 1900, "SK": 2000, "SI": 2200,
    "ES": 2100, "SE": 2500,
}


class VATEngine:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def calculate(self, request: VATCalculationRequest) -> VATCalculationResponse:
        seller_eu = request.seller_country in EU_COUNTRIES
        buyer_eu = request.buyer_country in EU_COUNTRIES

        if not seller_eu:
            return VATCalculationResponse(
                net_amount_cents=request.amount_cents, vat_amount_cents=0,
                gross_amount_cents=request.amount_cents, vat_rate_bps=0,
                vat_rate_percent=0.0, treatment="non_eu_seller",
                buyer_country=request.buyer_country, seller_country=request.seller_country,
                notes="Seller is outside the EU. No EU VAT applies.",
            )

        if request.seller_country == request.buyer_country:
            rate = await self._get_rate(request.buyer_country)
            vat = (request.amount_cents * rate) // 10000
            return VATCalculationResponse(
                net_amount_cents=request.amount_cents, vat_amount_cents=vat,
                gross_amount_cents=request.amount_cents + vat, vat_rate_bps=rate,
                vat_rate_percent=rate / 100, treatment="domestic",
                buyer_country=request.buyer_country, seller_country=request.seller_country,
                notes=f"Domestic sale. {request.seller_country} VAT applies.",
            )

        if buyer_eu and request.buyer_vat_number:
            return VATCalculationResponse(
                net_amount_cents=request.amount_cents, vat_amount_cents=0,
                gross_amount_cents=request.amount_cents, vat_rate_bps=0,
                vat_rate_percent=0.0, treatment="eu_reverse_charge",
                buyer_country=request.buyer_country, seller_country=request.seller_country,
                notes=f"EU B2B reverse charge. Buyer VAT: {request.buyer_vat_number}.",
            )

        if buyer_eu:
            rate = await self._get_rate(request.buyer_country)
            vat = (request.amount_cents * rate) // 10000
            return VATCalculationResponse(
                net_amount_cents=request.amount_cents, vat_amount_cents=vat,
                gross_amount_cents=request.amount_cents + vat, vat_rate_bps=rate,
                vat_rate_percent=rate / 100, treatment="eu_oss",
                buyer_country=request.buyer_country, seller_country=request.seller_country,
                notes=f"EU B2C via OSS. {request.buyer_country} VAT rate applies.",
            )

        return VATCalculationResponse(
            net_amount_cents=request.amount_cents, vat_amount_cents=0,
            gross_amount_cents=request.amount_cents, vat_rate_bps=0,
            vat_rate_percent=0.0, treatment="export_zero_rated",
            buyer_country=request.buyer_country, seller_country=request.seller_country,
            notes="Export to non-EU country. Zero-rated.",
        )

    async def _get_rate(self, country_code: str) -> int:
        stmt = select(EUVATRate).where(EUVATRate.country_code == country_code)
        result = await self.session.execute(stmt)
        rate = result.scalar_one_or_none()
        if rate:
            return rate.digital_services_rate
        return DEFAULT_DIGITAL_VAT_RATES.get(country_code, 0)

    async def check_oss_threshold(
        self, organization_id, current_year_eu_sales_cents: int, countries_sold_to: list[str],
    ) -> OSSThresholdStatus:
        threshold = 1_000_000
        reached = current_year_eu_sales_cents >= threshold
        pct = round((current_year_eu_sales_cents / threshold) * 100, 1) if threshold > 0 else 0
        if reached:
            rec = "You have exceeded the EUR10,000 OSS threshold. You MUST register for OSS."
        elif pct >= 80:
            rec = f"You are at {pct}% of the OSS threshold. Consider registering proactively."
        else:
            rec = f"You are at {pct}% of the OSS threshold."
        return OSSThresholdStatus(
            current_year_eu_sales_cents=current_year_eu_sales_cents,
            oss_threshold_cents=threshold, threshold_reached=reached,
            threshold_percent=pct, countries_sold_to=countries_sold_to, recommendation=rec,
        )
EOF

# --- services/__init__.py ---
touch server/metrify/services/__init__.py

# --- api/deps.py ---
cat > server/metrify/api/deps.py << 'EOF'
import hashlib
from fastapi import Depends, HTTPException, Security, status
from fastapi.security import APIKeyHeader
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from metrify.database import get_db_session
from metrify.models.organization import Organization
from metrify.config import get_settings

settings = get_settings()
api_key_header = APIKeyHeader(name=settings.api_key_header, auto_error=False)


async def get_current_organization(
    api_key: str = Security(api_key_header),
    session: AsyncSession = Depends(get_db_session),
) -> Organization:
    if not api_key:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing API key")

    prefix = api_key[:8]
    key_hash = hashlib.sha256(api_key.encode()).hexdigest()

    stmt = select(Organization).where(
        Organization.api_key_prefix == prefix,
        Organization.api_key_hash == key_hash,
    )
    result = await session.execute(stmt)
    org = result.scalar_one_or_none()

    if not org:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid API key")
    return org
EOF

# --- api/__init__.py ---
touch server/metrify/api/__init__.py
touch server/metrify/api/v1/__init__.py

# --- api/v1/events.py ---
cat > server/metrify/api/v1/events.py << 'EOF'
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
EOF

# --- api/v1/billing.py ---
cat > server/metrify/api/v1/billing.py << 'EOF'
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from metrify.database import get_db_session
from metrify.api.deps import get_current_organization
from metrify.models.organization import Organization
from metrify.schemas.billing import BillingSyncRequest, BillingSyncResult
from metrify.services.usage_aggregation import UsageAggregationService
from metrify.services.billing_sync import BillingSyncService

router = APIRouter(prefix="/billing", tags=["Billing"])


@router.post("/aggregate")
async def aggregate_usage(
    request: BillingSyncRequest,
    organization: Organization = Depends(get_current_organization),
    session: AsyncSession = Depends(get_db_session),
):
    service = UsageAggregationService(session)
    aggregates = await service.aggregate_period(organization.id, request.period_start, request.period_end)
    return {"aggregated": len(aggregates)}


@router.post("/sync", response_model=BillingSyncResult)
async def sync_billing_to_stripe(
    request: BillingSyncRequest,
    organization: Organization = Depends(get_current_organization),
    session: AsyncSession = Depends(get_db_session),
):
    service = BillingSyncService(session)
    return await service.sync_to_stripe(organization.id, request.period_start, request.period_end, dry_run=request.dry_run)
EOF

# --- api/v1/margins.py ---
cat > server/metrify/api/v1/margins.py << 'EOF'
from datetime import date
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from metrify.database import get_db_session
from metrify.api.deps import get_current_organization
from metrify.models.organization import Organization
from metrify.schemas.margin import MarginSummary
from metrify.services.margin_calculator import MarginCalculatorService

router = APIRouter(prefix="/margins", tags=["Margins"])


@router.get("/", response_model=MarginSummary)
async def get_margins(
    period_start: date = Query(...),
    period_end: date = Query(...),
    organization: Organization = Depends(get_current_organization),
    session: AsyncSession = Depends(get_db_session),
):
    service = MarginCalculatorService(session)
    return await service.calculate_margins(organization.id, period_start, period_end)
EOF

# --- api/v1/vat.py ---
cat > server/metrify/api/v1/vat.py << 'EOF'
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from metrify.database import get_db_session
from metrify.api.deps import get_current_organization
from metrify.models.organization import Organization
from metrify.schemas.vat import VATCalculationRequest, VATCalculationResponse
from metrify.services.vat_engine import VATEngine

router = APIRouter(prefix="/vat", tags=["VAT"])


@router.post("/calculate", response_model=VATCalculationResponse)
async def calculate_vat(
    request: VATCalculationRequest,
    organization: Organization = Depends(get_current_organization),
    session: AsyncSession = Depends(get_db_session),
):
    engine = VATEngine(session)
    return await engine.calculate(request)
EOF

# --- api/v1/router.py ---
cat > server/metrify/api/v1/router.py << 'EOF'
from fastapi import APIRouter
from metrify.api.v1.events import router as events_router
from metrify.api.v1.billing import router as billing_router
from metrify.api.v1.margins import router as margins_router
from metrify.api.v1.vat import router as vat_router

api_v1_router = APIRouter(prefix="/v1")
api_v1_router.include_router(events_router)
api_v1_router.include_router(billing_router)
api_v1_router.include_router(margins_router)
api_v1_router.include_router(vat_router)
EOF

# --- app.py ---
cat > server/metrify/app.py << 'EOF'
import sentry_sdk
import structlog
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from metrify.config import get_settings
from metrify.api.v1.router import api_v1_router

settings = get_settings()

if settings.sentry_dsn:
    sentry_sdk.init(dsn=settings.sentry_dsn, traces_sample_rate=0.1)

structlog.configure(
    processors=[
        structlog.contextvars.merge_contextvars,
        structlog.processors.add_log_level,
        structlog.processors.StackInfoRenderer(),
        structlog.dev.set_exc_info,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.dev.ConsoleRenderer() if settings.debug else structlog.processors.JSONRenderer(),
    ],
    wrapper_class=structlog.make_filtering_bound_logger(20),
    context_class=dict,
    logger_factory=structlog.PrintLoggerFactory(),
    cache_logger_on_first_use=True,
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    structlog.get_logger().info("metrify_starting", debug=settings.debug)
    yield
    structlog.get_logger().info("metrify_stopping")


app = FastAPI(
    title="Metrify",
    description="Usage-based billing middleware + cost intelligence for AI startups",
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "https://*.metrify.dev"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_v1_router)


@app.get("/health")
async def health():
    return {"status": "ok", "service": "metrify"}
EOF

# --- __init__.py files ---
touch server/metrify/__init__.py
touch server/metrify/utils/__init__.py

# --- tasks/broker.py ---
cat > server/metrify/tasks/__init__.py << 'EOF'
EOF

cat > server/metrify/tasks/broker.py << 'EOF'
import dramatiq
from dramatiq.brokers.redis import RedisBroker
from metrify.config import get_settings

settings = get_settings()
redis_broker = RedisBroker(url=settings.redis_url)
dramatiq.set_broker(redis_broker)
EOF

# --- tasks/aggregate_usage.py ---
cat > server/metrify/tasks/aggregate_usage.py << 'EOF'
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
EOF

# --- tasks/pull_costs.py ---
cat > server/metrify/tasks/pull_costs.py << 'EOF'
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
EOF

# --- tasks/sync_billing.py ---
cat > server/metrify/tasks/sync_billing.py << 'EOF'
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
EOF

# --- tasks/scheduled.py ---
cat > server/metrify/tasks/scheduled.py << 'EOF'
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
EOF

# ============================================
# ALEMBIC
# ============================================
cat > server/alembic.ini << 'EOF'
[alembic]
script_location = alembic
sqlalchemy.url = postgresql+asyncpg://metrify:metrify@localhost:5432/metrify

[loggers]
keys = root,sqlalchemy,alembic

[handlers]
keys = console

[formatters]
keys = generic

[logger_root]
level = WARN
handlers = console

[logger_sqlalchemy]
level = WARN
handlers =
qualname = sqlalchemy.engine

[logger_alembic]
level = INFO
handlers =
qualname = alembic

[handler_console]
class = StreamHandler
args = (sys.stderr,)
level = NOTSET
formatter = generic

[formatter_generic]
format = %(levelname)-5.5s [%(name)s] %(message)s
EOF

cat > server/alembic/env.py << 'EOF'
import asyncio
from logging.config import fileConfig
from sqlalchemy import pool
from sqlalchemy.ext.asyncio import async_engine_from_config
from alembic import context

from metrify.models import Base
from metrify.config import get_settings

config = context.config
settings = get_settings()

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata
config.set_main_option("sqlalchemy.url", settings.database_url)


def run_migrations_offline():
    url = config.get_main_option("sqlalchemy.url")
    context.configure(url=url, target_metadata=target_metadata, literal_binds=True)
    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection):
    context.configure(connection=connection, target_metadata=target_metadata)
    with context.begin_transaction():
        context.run_migrations()


async def run_async_migrations():
    connectable = async_engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)
    await connectable.dispose()


def run_migrations_online():
    asyncio.run(run_async_migrations())


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
EOF

cat > server/alembic/versions/001_initial.py << 'MIGRATION'
"""Initial migration

Revision ID: 001
Revises:
Create Date: 2025-01-01 00:00:00.000000
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "organizations",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("slug", sa.String(255), unique=True, nullable=False),
        sa.Column("stripe_account_id", sa.String(255)),
        sa.Column("api_key_hash", sa.String(255), nullable=False),
        sa.Column("api_key_prefix", sa.String(12), nullable=False),
        sa.Column("country", sa.String(2), server_default="DE"),
        sa.Column("vat_number", sa.String(20)),
        sa.Column("oss_registered", sa.Boolean, server_default="false"),
        sa.Column("openai_api_key_encrypted", sa.String(500)),
        sa.Column("anthropic_api_key_encrypted", sa.String(500)),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    op.create_table(
        "projects",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("organization_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("organizations.id"), nullable=False),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("slug", sa.String(255), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    op.create_table(
        "customers",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("organization_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("organizations.id"), nullable=False),
        sa.Column("external_id", sa.String(255), nullable=False),
        sa.Column("name", sa.String(255)),
        sa.Column("email", sa.String(255)),
        sa.Column("stripe_customer_id", sa.String(255)),
        sa.Column("stripe_subscription_id", sa.String(255)),
        sa.Column("country", sa.String(2)),
        sa.Column("vat_number", sa.String(20)),
        sa.Column("vat_verified", sa.Boolean, server_default="false"),
        sa.Column("plan_name", sa.String(100)),
        sa.Column("included_units", sa.Integer, server_default="0"),
        sa.Column("overage_price_cents", sa.Integer, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    op.create_table(
        "events",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("organization_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("organizations.id"), nullable=False),
        sa.Column("project_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("projects.id")),
        sa.Column("customer_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("customers.id"), nullable=False),
        sa.Column("event_name", sa.String(255), nullable=False),
        sa.Column("units", sa.BigInteger, server_default="1"),
        sa.Column("properties", postgresql.JSONB),
        sa.Column("timestamp", sa.DateTime(timezone=True), nullable=False),
        sa.Column("ingested_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("idempotency_key", sa.String(255)),
    )
    op.create_index("ix_events_org_customer_name_ts", "events", ["organization_id", "customer_id", "event_name", "timestamp"])
    op.create_index("ix_events_org_ts", "events", ["organization_id", "timestamp"])
    op.create_index("ix_events_idempotency", "events", ["organization_id", "idempotency_key"], unique=True)

    op.create_table(
        "usage_aggregates",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("organization_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("organizations.id"), nullable=False),
        sa.Column("customer_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("customers.id"), nullable=False),
        sa.Column("event_name", sa.String(255), nullable=False),
        sa.Column("period_start", sa.Date, nullable=False),
        sa.Column("period_end", sa.Date, nullable=False),
        sa.Column("total_units", sa.BigInteger, server_default="0"),
        sa.Column("billable_units", sa.BigInteger, server_default="0"),
        sa.Column("amount_cents", sa.BigInteger, server_default="0"),
        sa.Column("stripe_invoice_item_id", sa.String(255)),
        sa.Column("synced_to_stripe", sa.Boolean, server_default="false"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_unique_constraint("uq_usage_agg_org_cust_event_period", "usage_aggregates", ["organization_id", "customer_id", "event_name", "period_start"])
    op.create_index("ix_usage_agg_org_period", "usage_aggregates", ["organization_id", "period_start"])

    op.create_table(
        "ai_costs",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("organization_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("organizations.id"), nullable=False),
        sa.Column("customer_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("customers.id"), nullable=False),
        sa.Column("provider", sa.String(50), nullable=False),
        sa.Column("model", sa.String(100), nullable=False),
        sa.Column("cost_date", sa.Date, nullable=False),
        sa.Column("input_tokens", sa.BigInteger, server_default="0"),
        sa.Column("output_tokens", sa.BigInteger, server_default="0"),
        sa.Column("total_tokens", sa.BigInteger, server_default="0"),
        sa.Column("cost_microdollars", sa.BigInteger, server_default="0"),
        sa.Column("cost_cents", sa.Integer, server_default="0"),
        sa.Column("attribution_method", sa.String(50), server_default="'proportional'"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_ai_costs_org_date", "ai_costs", ["organization_id", "cost_date"])
    op.create_index("ix_ai_costs_customer_date", "ai_costs", ["customer_id", "cost_date"])

    op.create_table(
        "eu_vat_rates",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("country_code", sa.String(2), unique=True, nullable=False),
        sa.Column("country_name", sa.String(100), nullable=False),
        sa.Column("standard_rate", sa.Integer, nullable=False),
        sa.Column("reduced_rate", sa.Integer),
        sa.Column("digital_services_rate", sa.Integer, nullable=False),
        sa.Column("has_oss", sa.Boolean, server_default="true"),
    )

    op.execute("""
        INSERT INTO eu_vat_rates (id, country_code, country_name, standard_rate, digital_services_rate) VALUES
        (gen_random_uuid(), 'AT', 'Austria', 2000, 2000),
        (gen_random_uuid(), 'BE', 'Belgium', 2100, 2100),
        (gen_random_uuid(), 'BG', 'Bulgaria', 2000, 2000),
        (gen_random_uuid(), 'HR', 'Croatia', 2500, 2500),
        (gen_random_uuid(), 'CY', 'Cyprus', 1900, 1900),
        (gen_random_uuid(), 'CZ', 'Czech Republic', 2100, 2100),
        (gen_random_uuid(), 'DK', 'Denmark', 2500, 2500),
        (gen_random_uuid(), 'EE', 'Estonia', 2200, 2200),
        (gen_random_uuid(), 'FI', 'Finland', 2550, 2550),
        (gen_random_uuid(), 'FR', 'France', 2000, 2000),
        (gen_random_uuid(), 'DE', 'Germany', 1900, 1900),
        (gen_random_uuid(), 'GR', 'Greece', 2400, 2400),
        (gen_random_uuid(), 'HU', 'Hungary', 2700, 2700),
        (gen_random_uuid(), 'IE', 'Ireland', 2300, 2300),
        (gen_random_uuid(), 'IT', 'Italy', 2200, 2200),
        (gen_random_uuid(), 'LV', 'Latvia', 2100, 2100),
        (gen_random_uuid(), 'LT', 'Lithuania', 2100, 2100),
        (gen_random_uuid(), 'LU', 'Luxembourg', 1700, 1700),
        (gen_random_uuid(), 'MT', 'Malta', 1800, 1800),
        (gen_random_uuid(), 'NL', 'Netherlands', 2100, 2100),
        (gen_random_uuid(), 'PL', 'Poland', 2300, 2300),
        (gen_random_uuid(), 'PT', 'Portugal', 2300, 2300),
        (gen_random_uuid(), 'RO', 'Romania', 1900, 1900),
        (gen_random_uuid(), 'SK', 'Slovakia', 2000, 2000),
        (gen_random_uuid(), 'SI', 'Slovenia', 2200, 2200),
        (gen_random_uuid(), 'ES', 'Spain', 2100, 2100),
        (gen_random_uuid(), 'SE', 'Sweden', 2500, 2500)
    """)


def downgrade() -> None:
    op.drop_table("eu_vat_rates")
    op.drop_table("ai_costs")
    op.drop_table("usage_aggregates")
    op.drop_table("events")
    op.drop_table("customers")
    op.drop_table("projects")
    op.drop_table("organizations")
MIGRATION

# ============================================
# TESTS
# ============================================
cat > server/tests/__init__.py << 'EOF'
EOF

cat > server/tests/conftest.py << 'EOF'
import asyncio
import pytest
import uuid
import hashlib
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from metrify.models import Base
from metrify.models.organization import Organization


@pytest.fixture(scope="session")
def event_loop():
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest.fixture
async def db_session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    async with factory() as session:
        yield session
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await engine.dispose()


@pytest.fixture
async def organization(db_session: AsyncSession) -> Organization:
    api_key = "mtfy_test_key_12345678"
    org = Organization(
        id=uuid.uuid4(),
        name="Test Org",
        slug="test-org",
        api_key_hash=hashlib.sha256(api_key.encode()).hexdigest(),
        api_key_prefix=api_key[:8],
        country="DE",
    )
    db_session.add(org)
    await db_session.flush()
    return org
EOF

cat > server/tests/test_vat_engine.py << 'EOF'
import pytest
from metrify.services.vat_engine import VATEngine
from metrify.schemas.vat import VATCalculationRequest


@pytest.mark.asyncio
async def test_domestic_sale(db_session):
    engine = VATEngine(db_session)
    result = await engine.calculate(VATCalculationRequest(
        seller_country="DE", buyer_country="DE", amount_cents=10000,
    ))
    assert result.treatment == "domestic"
    assert result.vat_rate_bps == 1900
    assert result.vat_amount_cents == 1900


@pytest.mark.asyncio
async def test_eu_reverse_charge(db_session):
    engine = VATEngine(db_session)
    result = await engine.calculate(VATCalculationRequest(
        seller_country="DE", buyer_country="FR",
        buyer_vat_number="FR12345678901", amount_cents=10000,
    ))
    assert result.treatment == "eu_reverse_charge"
    assert result.vat_amount_cents == 0


@pytest.mark.asyncio
async def test_eu_b2c_oss(db_session):
    engine = VATEngine(db_session)
    result = await engine.calculate(VATCalculationRequest(
        seller_country="DE", buyer_country="FR", amount_cents=10000,
    ))
    assert result.treatment == "eu_oss"
    assert result.vat_rate_bps == 2000


@pytest.mark.asyncio
async def test_export_zero_rated(db_session):
    engine = VATEngine(db_session)
    result = await engine.calculate(VATCalculationRequest(
        seller_country="DE", buyer_country="US", amount_cents=10000,
    ))
    assert result.treatment == "export_zero_rated"
    assert result.vat_amount_cents == 0
EOF

cat > server/tests/test_margin_calculator.py << 'EOF'
import pytest
import uuid
from datetime import date
from metrify.models.customer import Customer
from metrify.models.usage_aggregate import UsageAggregate
from metrify.models.ai_cost import AICost
from metrify.services.margin_calculator import MarginCalculatorService


@pytest.mark.asyncio
async def test_margin_calculation(db_session, organization):
    customer = Customer(
        id=uuid.uuid4(), organization_id=organization.id,
        external_id="cust_1", name="Acme Corp",
    )
    db_session.add(customer)

    agg = UsageAggregate(
        id=uuid.uuid4(), organization_id=organization.id,
        customer_id=customer.id, event_name="ai_tokens",
        period_start=date(2025, 1, 1), period_end=date(2025, 1, 31),
        total_units=100000, billable_units=90000, amount_cents=9000,
    )
    db_session.add(agg)

    cost = AICost(
        id=uuid.uuid4(), organization_id=organization.id,
        customer_id=customer.id, provider="openai", model="gpt-4o",
        cost_date=date(2025, 1, 15), input_tokens=50000, output_tokens=50000,
        total_tokens=100000, cost_cents=3000,
    )
    db_session.add(cost)
    await db_session.flush()

    service = MarginCalculatorService(db_session)
    summary = await service.calculate_margins(organization.id, date(2025, 1, 1), date(2025, 1, 31))

    assert summary.total_revenue_cents == 9000
    assert summary.total_ai_cost_cents == 3000
    assert summary.overall_margin_percent == 66.67
    assert len(summary.unprofitable_customers) == 0
EOF

# ============================================
# SDK - PYTHON
# ============================================
mkdir -p sdk/python/metrify

cat > sdk/python/pyproject.toml << 'EOF'
[project]
name = "metrify"
version = "0.1.0"
description = "Metrify SDK - usage-based billing for AI startups"
requires-python = ">=3.10"
dependencies = ["httpx>=0.27.0"]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"
EOF

cat > sdk/python/metrify/__init__.py << 'EOF'
from metrify.client import Metrify

__all__ = ["Metrify"]
EOF

cat > sdk/python/metrify/client.py << 'EOF'
import time
import uuid
import threading
import logging
from datetime import datetime, timezone
from typing import Any
import httpx

logger = logging.getLogger("metrify")


class Metrify:
    def __init__(
        self, api_key: str, base_url: str = "https://api.metrify.dev",
        flush_interval: float = 5.0, flush_size: int = 100, timeout: float = 10.0,
    ):
        self.api_key = api_key
        self.base_url = base_url.rstrip("/")
        self.flush_interval = flush_interval
        self.flush_size = flush_size
        self._buffer: list[dict] = []
        self._lock = threading.Lock()
        self._client = httpx.Client(
            base_url=self.base_url,
            headers={"X-Metrify-Key": self.api_key},
            timeout=timeout,
        )
        self._running = True
        self._flush_thread = threading.Thread(target=self._flush_loop, daemon=True)
        self._flush_thread.start()

    def track(
        self, event_name: str, customer_id: str, units: int = 1,
        properties: dict[str, Any] | None = None, timestamp: datetime | None = None,
        idempotency_key: str | None = None,
    ) -> None:
        event = {
            "event_name": event_name, "customer_id": customer_id, "units": units,
            "properties": properties,
            "timestamp": (timestamp or datetime.now(timezone.utc)).isoformat(),
            "idempotency_key": idempotency_key or str(uuid.uuid4()),
        }
        with self._lock:
            self._buffer.append(event)
            if len(self._buffer) >= self.flush_size:
                self._flush()

    def flush(self) -> None:
        with self._lock:
            self._flush()

    def _flush(self) -> None:
        if not self._buffer:
            return
        events = self._buffer.copy()
        self._buffer.clear()
        try:
            resp = self._client.post("/v1/events/batch", json={"events": events})
            resp.raise_for_status()
        except Exception as e:
            logger.error(f"Flush failed: {e}")
            self._buffer = events + self._buffer

    def _flush_loop(self) -> None:
        while self._running:
            time.sleep(self.flush_interval)
            with self._lock:
                self._flush()

    def shutdown(self) -> None:
        self._running = False
        self.flush()
        self._client.close()
EOF

# ============================================
# SDK - TYPESCRIPT
# ============================================
mkdir -p sdk/typescript/src

cat > sdk/typescript/package.json << 'EOF'
{
  "name": "@metrify/sdk",
  "version": "0.1.0",
  "description": "Metrify SDK - usage-based billing for AI startups",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "scripts": { "build": "tsc", "dev": "tsc --watch" },
  "devDependencies": { "typescript": "^5.6.0" },
  "files": ["dist"],
  "license": "MIT"
}
EOF

cat > sdk/typescript/src/index.ts << 'SDKTS'
interface MetrifyConfig {
  apiKey: string;
  baseUrl?: string;
  flushInterval?: number;
  flushSize?: number;
}

interface TrackOptions {
  customerId: string;
  units?: number;
  properties?: Record<string, unknown>;
  timestamp?: Date;
  idempotencyKey?: string;
}

interface EventPayload {
  event_name: string;
  customer_id: string;
  units: number;
  properties?: Record<string, unknown>;
  timestamp: string;
  idempotency_key: string;
}

export class Metrify {
  private apiKey: string;
  private baseUrl: string;
  private flushInterval: number;
  private flushSize: number;
  private buffer: EventPayload[] = [];
  private timer: ReturnType<typeof setInterval> | null = null;

  constructor(config: MetrifyConfig) {
    this.apiKey = config.apiKey;
    this.baseUrl = (config.baseUrl || "https://api.metrify.dev").replace(/\/$/, "");
    this.flushInterval = config.flushInterval || 5000;
    this.flushSize = config.flushSize || 100;
    this.timer = setInterval(() => this.flush(), this.flushInterval);
    if (typeof process !== "undefined" && process.on) {
      process.on("beforeExit", () => this.flush());
    }
  }

  track(eventName: string, options: TrackOptions): void {
    this.buffer.push({
      event_name: eventName,
      customer_id: options.customerId,
      units: options.units ?? 1,
      properties: options.properties,
      timestamp: (options.timestamp || new Date()).toISOString(),
      idempotency_key: options.idempotencyKey || crypto.randomUUID(),
    });
    if (this.buffer.length >= this.flushSize) this.flush();
  }

  async flush(): Promise<void> {
    if (this.buffer.length === 0) return;
    const events = [...this.buffer];
    this.buffer = [];
    try {
      const res = await fetch(`${this.baseUrl}/v1/events/batch`, {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-Metrify-Key": this.apiKey },
        body: JSON.stringify({ events }),
      });
      if (!res.ok) this.buffer = [...events, ...this.buffer];
    } catch {
      this.buffer = [...events, ...this.buffer];
    }
  }

  shutdown(): void {
    if (this.timer) { clearInterval(this.timer); this.timer = null; }
    this.flush();
  }
}

export default Metrify;
SDKTS

# ============================================
# WEB (Next.js)
# ============================================
mkdir -p web/src/{app/{dashboard,},components/{ui,charts,tables,billing},hooks,lib}

cat > web/package.json << 'EOF'
{
  "name": "@metrify/web",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint"
  },
  "dependencies": {
    "next": "^15.1.0",
    "react": "^19.0.0",
    "react-dom": "^19.0.0",
    "@tanstack/react-query": "^5.60.0",
    "@radix-ui/react-dialog": "^1.1.0",
    "@radix-ui/react-dropdown-menu": "^2.1.0",
    "@radix-ui/react-tabs": "^1.1.0",
    "@radix-ui/react-tooltip": "^1.1.0",
    "@radix-ui/react-slot": "^1.1.0",
    "class-variance-authority": "^0.7.0",
    "clsx": "^2.1.0",
    "tailwind-merge": "^2.5.0",
    "framer-motion": "^11.11.0",
    "recharts": "^2.13.0",
    "lucide-react": "^0.460.0",
    "date-fns": "^4.1.0"
  },
  "devDependencies": {
    "typescript": "^5.6.0",
    "@types/react": "^19.0.0",
    "@types/node": "^22.0.0",
    "tailwindcss": "^3.4.0",
    "postcss": "^8.4.0",
    "autoprefixer": "^10.4.0"
  }
}
EOF

cat > web/next.config.js << 'EOF'
/** @type {import('next').NextConfig} */
const nextConfig = {
  output: "standalone",
};
module.exports = nextConfig;
EOF

cat > web/tailwind.config.ts << 'EOF'
import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./src/**/*.{js,ts,jsx,tsx,mdx}"],
  darkMode: "class",
  theme: { extend: {} },
  plugins: [],
};
export default config;
EOF

cat > web/tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "target": "ES2017",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": { "@/*": ["./src/*"] }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
EOF

cat > web/src/lib/api-client.ts << 'EOF'
const API_BASE = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";

interface ApiOptions {
  method?: string;
  body?: unknown;
  token?: string;
}

export async function api<T>(path: string, options: ApiOptions = {}): Promise<T> {
  const { method = "GET", body, token } = options;
  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (token) headers["Authorization"] = `Bearer ${token}`;

  const response = await fetch(`${API_BASE}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });

  if (!response.ok) {
    const error = await response.json().catch(() => ({ detail: "Unknown error" }));
    throw new Error(error.detail || `API error: ${response.status}`);
  }
  return response.json();
}
EOF

cat > web/src/lib/utils.ts << 'EOF'
import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatCents(cents: number): string {
  return new Intl.NumberFormat("de-DE", { style: "currency", currency: "EUR" }).format(cents / 100);
}

export function formatPercent(value: number): string {
  return `${value.toFixed(1)}%`;
}

export function formatNumber(value: number): string {
  return new Intl.NumberFormat("de-DE").format(value);
}
EOF

cat > web/src/hooks/use-margins.ts << 'EOF'
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api-client";

interface CustomerMargin {
  customer_id: string;
  customer_external_id: string;
  customer_name: string | null;
  period_start: string;
  period_end: string;
  revenue_cents: number;
  ai_cost_cents: number;
  gross_profit_cents: number;
  margin_percent: number;
}

interface MarginSummary {
  period_start: string;
  period_end: string;
  total_revenue_cents: number;
  total_ai_cost_cents: number;
  total_gross_profit_cents: number;
  overall_margin_percent: number;
  customer_count: number;
  customers: CustomerMargin[];
  unprofitable_customers: CustomerMargin[];
}

export function useMargins(periodStart: string, periodEnd: string) {
  return useQuery<MarginSummary>({
    queryKey: ["margins", periodStart, periodEnd],
    queryFn: () => api(`/v1/margins/?period_start=${periodStart}&period_end=${periodEnd}`),
    staleTime: 30_000,
  });
}
EOF

cat > web/src/hooks/use-usage.ts << 'EOF'
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api-client";

interface UsageAggregate {
  customer_id: string;
  customer_external_id: string;
  event_name: string;
  total_units: number;
  billable_units: number;
  amount_cents: number;
  synced_to_stripe: boolean;
}

export function useUsage(periodStart: string, periodEnd: string) {
  return useQuery<UsageAggregate[]>({
    queryKey: ["usage", periodStart, periodEnd],
    queryFn: () => api(`/v1/billing/usage?period_start=${periodStart}&period_end=${periodEnd}`),
    staleTime: 30_000,
  });
}
EOF

cat > web/src/app/globals.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;
EOF

cat > web/src/app/providers.tsx << 'EOF'
"use client";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { useState } from "react";

export function Providers({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(
    () => new QueryClient({ defaultOptions: { queries: { staleTime: 60 * 1000, retry: 1 } } })
  );
  return <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>;
}
EOF

cat > web/src/app/layout.tsx << 'EOF'
import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import { Providers } from "./providers";

const inter = Inter({ subsets: ["latin"] });

export const metadata: Metadata = {
  title: "Metrify - Usage Billing + Cost Intelligence",
  description: "Add usage-based pricing to any SaaS in one afternoon",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className="dark">
      <body className={inter.className}>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
EOF

cat > web/src/app/page.tsx << 'EOF'
import Link from "next/link";

export default function Home() {
  return (
    <div className="min-h-screen bg-zinc-950 text-white flex items-center justify-center">
      <div className="text-center space-y-6">
        <h1 className="text-5xl font-bold">
          <span className="text-blue-400">metrify</span>
        </h1>
        <p className="text-xl text-zinc-400">
          Usage-based billing + cost intelligence for AI startups
        </p>
        <Link
          href="/dashboard"
          className="inline-block px-6 py-3 bg-blue-600 hover:bg-blue-500 rounded-lg font-medium transition-colors"
        >
          Open Dashboard
        </Link>
      </div>
    </div>
  );
}
EOF

cat > web/src/app/dashboard/layout.tsx << 'DASHLAY'
"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";

const nav = [
  { href: "/dashboard", label: "Overview" },
  { href: "/dashboard/margins", label: "Margins" },
  { href: "/dashboard/usage", label: "Usage" },
  { href: "/dashboard/billing", label: "Billing" },
  { href: "/dashboard/vat", label: "VAT" },
];

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  return (
    <div className="min-h-screen bg-zinc-950 text-white flex">
      <aside className="w-64 border-r border-zinc-800 p-6 flex flex-col">
        <div className="mb-8">
          <h1 className="text-xl font-bold"><span className="text-blue-400">metrify</span></h1>
          <p className="text-xs text-zinc-500 mt-1">billing + cost intelligence</p>
        </div>
        <nav className="space-y-1 flex-1">
          {nav.map((item) => (
            <Link key={item.href} href={item.href}
              className={cn(
                "flex items-center gap-3 px-3 py-2 rounded-lg text-sm transition-colors",
                pathname === item.href ? "bg-zinc-800 text-white" : "text-zinc-400 hover:text-white hover:bg-zinc-800/50"
              )}>
              {item.label}
            </Link>
          ))}
        </nav>
      </aside>
      <main className="flex-1 p-8 overflow-auto">{children}</main>
    </div>
  );
}
DASHLAY

cat > web/src/app/dashboard/page.tsx << 'DASHPAGE'
"use client";

import { useMargins } from "@/hooks/use-margins";
import { formatCents, formatPercent, formatNumber } from "@/lib/utils";

const now = new Date();
const periodStart = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-01`;
const periodEnd = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate()).padStart(2, "0")}`;

export default function DashboardPage() {
  const { data: margins, isLoading } = useMargins(periodStart, periodEnd);

  if (isLoading) {
    return <div className="flex items-center justify-center h-96"><div className="animate-spin rounded-full h-8 w-8 border-b-2 border-white" /></div>;
  }
  if (!margins) return null;

  const cards = [
    { title: "Revenue", value: formatCents(margins.total_revenue_cents), color: "text-green-400" },
    { title: "AI Costs", value: formatCents(margins.total_ai_cost_cents), color: "text-red-400" },
    { title: "Gross Margin", value: formatPercent(margins.overall_margin_percent), color: margins.overall_margin_percent >= 50 ? "text-green-400" : "text-yellow-400" },
    { title: "Customers", value: formatNumber(margins.customer_count), color: "text-blue-400" },
  ];

  return (
    <div className="space-y-8">
      <div><h1 className="text-3xl font-bold">Dashboard</h1><p className="text-zinc-400 mt-1">{periodStart} to {periodEnd}</p></div>
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        {cards.map((card) => (
          <div key={card.title} className="bg-zinc-900 border border-zinc-800 rounded-xl p-6">
            <p className="text-sm text-zinc-400">{card.title}</p>
            <p className={`text-2xl font-bold mt-2 ${card.color}`}>{card.value}</p>
          </div>
        ))}
      </div>
      {margins.unprofitable_customers.length > 0 && (
        <div className="bg-red-950/30 border border-red-900/50 rounded-xl p-6">
          <h2 className="text-lg font-semibold text-red-400 mb-4">{margins.unprofitable_customers.length} Unprofitable Customers</h2>
          {margins.unprofitable_customers.map((c) => (
            <div key={c.customer_id} className="flex justify-between text-sm py-1">
              <span>{c.customer_name || c.customer_external_id}</span>
              <span className="text-red-400 font-mono">{formatPercent(c.margin_percent)}</span>
            </div>
          ))}
        </div>
      )}
      <div className="bg-zinc-900 border border-zinc-800 rounded-xl overflow-hidden">
        <div className="p-6 border-b border-zinc-800"><h2 className="text-lg font-semibold">Customer Margins</h2></div>
        <table className="w-full text-sm">
          <thead><tr className="border-b border-zinc-800 text-zinc-400">
            <th className="text-left p-4">Customer</th><th className="text-right p-4">Revenue</th>
            <th className="text-right p-4">AI Cost</th><th className="text-right p-4">Profit</th>
            <th className="text-right p-4">Margin</th>
          </tr></thead>
          <tbody>
            {margins.customers.map((c) => (
              <tr key={c.customer_id} className="border-b border-zinc-800/50 hover:bg-zinc-800/30">
                <td className="p-4 font-medium">{c.customer_name || c.customer_external_id}</td>
                <td className="p-4 text-right text-green-400">{formatCents(c.revenue_cents)}</td>
                <td className="p-4 text-right text-red-400">{formatCents(c.ai_cost_cents)}</td>
                <td className={`p-4 text-right ${c.gross_profit_cents >= 0 ? "text-green-400" : "text-red-400"}`}>{formatCents(c.gross_profit_cents)}</td>
                <td className="p-4 text-right">
                  <span className={`px-2 py-1 rounded-full text-xs font-mono ${c.margin_percent >= 60 ? "bg-green-900/30 text-green-400" : c.margin_percent >= 30 ? "bg-yellow-900/30 text-yellow-400" : "bg-red-900/30 text-red-400"}`}>
                    {formatPercent(c.margin_percent)}
                  </span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
DASHPAGE

# Placeholder pages
# Placeholder pages
mkdir -p web/src/app/dashboard/margins
cat > web/src/app/dashboard/margins/page.tsx << 'EOF'
export default function MarginsPage() {
  return <div><h1 className="text-3xl font-bold">Margins</h1><p className="text-zinc-400 mt-2">Coming soon</p></div>;
}
EOF

mkdir -p web/src/app/dashboard/usage
cat > web/src/app/dashboard/usage/page.tsx << 'EOF'
export default function UsagePage() {
  return <div><h1 className="text-3xl font-bold">Usage</h1><p className="text-zinc-400 mt-2">Coming soon</p></div>;
}
EOF

mkdir -p web/src/app/dashboard/billing
cat > web/src/app/dashboard/billing/page.tsx << 'EOF'
export default function BillingPage() {
  return <div><h1 className="text-3xl font-bold">Billing</h1><p className="text-zinc-400 mt-2">Coming soon</p></div>;
}
EOF

mkdir -p web/src/app/dashboard/vat
cat > web/src/app/dashboard/vat/page.tsx << 'EOF'
export default function VatPage() {
  return <div><h1 className="text-3xl font-bold">VAT</h1><p className="text-zinc-400 mt-2">Coming soon</p></div>;
}
EOF
# ============================================
# DOCKER
# ============================================
cat > docker-compose.yml << 'EOF'
version: "3.9"

services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: metrify
      POSTGRES_PASSWORD: metrify
      POSTGRES_DB: metrify
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U metrify"]
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 5s
      retries: 5

volumes:
  pgdata:
EOF

cat > Dockerfile.server << 'EOF'
FROM python:3.12-slim
WORKDIR /app
RUN pip install --no-cache-dir uv
COPY server/pyproject.toml .
RUN uv pip install --system -e ".[dev]"
COPY server/ .
CMD ["sh", "-c", "alembic upgrade head && uvicorn metrify.app:app --host 0.0.0.0 --port 8000 --workers 4"]
EOF

cat > Dockerfile.worker << 'EOF'
FROM python:3.12-slim
WORKDIR /app
RUN pip install --no-cache-dir uv
COPY server/pyproject.toml .
RUN uv pip install --system -e .
COPY server/ .
CMD ["dramatiq", "metrify.tasks.aggregate_usage", "metrify.tasks.pull_costs", "metrify.tasks.sync_billing", "--processes", "2", "--threads", "4"]
EOF

cat > turbo.json << 'EOF'
{
  "$schema": "https://turbo.build/schema.json",
  "globalDependencies": ["**/.env.*local"],
  "pipeline": {
    "build": { "dependsOn": ["^build"], "outputs": [".next/**", "dist/**"] },
    "dev": { "cache": false, "persistent": true },
    "lint": {}
  }
}
EOF

# --- .env template ---
cat > server/.env << 'EOF'
METRIFY_DEBUG=true
METRIFY_DATABASE_URL=postgresql+asyncpg://metrify:metrify@localhost:5432/metrify
METRIFY_REDIS_URL=redis://localhost:6379/0
METRIFY_STRIPE_SECRET_KEY=sk_test_...
METRIFY_STRIPE_WEBHOOK_SECRET=whsec_...
METRIFY_OPENAI_ADMIN_KEY=
METRIFY_ANTHROPIC_ADMIN_KEY=
METRIFY_SENTRY_DSN=
EOF

# --- .gitignore ---
cat > .gitignore << 'EOF'
__pycache__/
*.pyc
.env
.venv/
node_modules/
.next/
dist/
*.egg-info/
.ruff_cache/
.mypy_cache/
.pytest_cache/
pgdata/
EOF

echo ""
echo "================================================"
echo "  Metrify project created successfully!"
echo "================================================"
echo ""
echo "  cd metrify && code ."
echo ""
echo "  Then follow the Quick Start:"
echo "  1. docker compose up -d postgres redis"
echo "  2. cd server && pip install uv && uv pip install -e '.[dev]'"
echo "  3. alembic upgrade head"
echo "  4. uvicorn metrify.app:app --reload --port 8000"
echo "  5. cd ../web && pnpm install && pnpm dev"
echo ""