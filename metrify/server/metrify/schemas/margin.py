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
