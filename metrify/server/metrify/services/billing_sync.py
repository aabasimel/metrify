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
