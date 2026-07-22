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
