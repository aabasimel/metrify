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
