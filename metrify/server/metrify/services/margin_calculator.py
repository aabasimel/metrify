import uuid
import structlog
from datetime import date
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from metrify.models.usage_aggregate import UsageAggregate
from metrify.models.ai_cost import AICost
from metrify.models.customer import Customer
from metrify.schemas.margin import CustomerMargin, MarginSummary

logger = structlog.get_logger()


class MarginCalculatorService:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def calculate_margins(
        self, organization_id: uuid.UUID, period_start: date, period_end: date,
    ) -> MarginSummary:
        rev_stmt = (
            select(UsageAggregate.customer_id, func.sum(UsageAggregate.amount_cents).label("revenue_cents"))
            .where(
                UsageAggregate.organization_id == organization_id,
                UsageAggregate.period_start >= period_start,
                UsageAggregate.period_end <= period_end,
            )
            .group_by(UsageAggregate.customer_id)
        )
        rev_result = await self.session.execute(rev_stmt)
        revenue_map = {r.customer_id: r.revenue_cents for r in rev_result.all()}

        cost_stmt = (
            select(AICost.customer_id, func.sum(AICost.cost_cents).label("cost_cents"))
            .where(
                AICost.organization_id == organization_id,
                AICost.cost_date >= period_start,
                AICost.cost_date <= period_end,
            )
            .group_by(AICost.customer_id)
        )
        cost_result = await self.session.execute(cost_stmt)
        cost_map = {r.customer_id: r.cost_cents for r in cost_result.all()}

        all_ids = set(revenue_map.keys()) | set(cost_map.keys())
        customers_data = []

        for cid in all_ids:
            customer = await self.session.get(Customer, cid)
            if not customer:
                continue
            customers_data.append(CustomerMargin(
                customer_id=cid,
                customer_external_id=customer.external_id,
                customer_name=customer.name,
                period_start=period_start,
                period_end=period_end,
                revenue_cents=revenue_map.get(cid, 0),
                ai_cost_cents=cost_map.get(cid, 0),
            ))

        customers_data.sort(key=lambda c: c.margin_percent)
        unprofitable = [c for c in customers_data if c.gross_profit_cents < 0]

        total_rev = sum(c.revenue_cents for c in customers_data)
        total_cost = sum(c.ai_cost_cents for c in customers_data)
        total_profit = total_rev - total_cost
        margin = round((total_profit / total_rev) * 100, 2) if total_rev > 0 else 0.0

        return MarginSummary(
            period_start=period_start,
            period_end=period_end,
            total_revenue_cents=total_rev,
            total_ai_cost_cents=total_cost,
            total_gross_profit_cents=total_profit,
            overall_margin_percent=margin,
            customer_count=len(customers_data),
            customers=sorted(customers_data, key=lambda c: c.revenue_cents, reverse=True),
            unprofitable_customers=unprofitable,
        )
