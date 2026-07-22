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
