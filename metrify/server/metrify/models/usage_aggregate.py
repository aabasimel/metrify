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
