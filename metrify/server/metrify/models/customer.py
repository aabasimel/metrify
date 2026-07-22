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
