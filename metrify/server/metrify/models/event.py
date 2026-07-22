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
