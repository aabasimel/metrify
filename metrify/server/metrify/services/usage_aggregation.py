import uuid
import structlog
from datetime import date, datetime, timezone
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.dialects.postgresql import insert

from metrify.models.usage_aggregate import UsageAggregate
from metrify.models.customer import Customer
from metrify.repositories.event import EventRepository

logger = structlog.get_logger()


class UsageAggregationService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.event_repo = EventRepository(session)

    async def aggregate_period(
        self, organization_id: uuid.UUID, period_start: date, period_end: date,
    ) -> list[UsageAggregate]:
        start_dt = datetime.combine(period_start, datetime.min.time(), tzinfo=timezone.utc)
        end_dt = datetime.combine(period_end, datetime.min.time(), tzinfo=timezone.utc)

        usage_data = await self.event_repo.get_usage_by_customer_and_event(
            organization_id, start_dt, end_dt
        )

        aggregates = []
        for row in usage_data:
            customer = await self.session.get(Customer, row["customer_id"])
            if not customer:
                continue

            total_units = row["total_units"]
            billable = max(0, total_units - customer.included_units)
            amount_cents = billable * customer.overage_price_cents

            stmt = (
                insert(UsageAggregate)
                .values(
                    organization_id=organization_id,
                    customer_id=row["customer_id"],
                    event_name=row["event_name"],
                    period_start=period_start,
                    period_end=period_end,
                    total_units=total_units,
                    billable_units=billable,
                    amount_cents=amount_cents,
                )
                .on_conflict_do_update(
                    constraint="uq_usage_agg_org_cust_event_period",
                    set_={"total_units": total_units, "billable_units": billable, "amount_cents": amount_cents},
                )
                .returning(UsageAggregate)
            )
            result = await self.session.execute(stmt)
            aggregates.append(result.scalar_one())

        logger.info("usage_aggregated", org=str(organization_id), count=len(aggregates))
        return aggregates
