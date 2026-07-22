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
