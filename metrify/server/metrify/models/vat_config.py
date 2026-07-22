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
