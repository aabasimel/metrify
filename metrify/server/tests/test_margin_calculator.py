import pytest
import uuid
from datetime import date
from metrify.models.customer import Customer
from metrify.models.usage_aggregate import UsageAggregate
from metrify.models.ai_cost import AICost
from metrify.services.margin_calculator import MarginCalculatorService


@pytest.mark.asyncio
async def test_margin_calculation(db_session, organization):
    customer = Customer(
        id=uuid.uuid4(), organization_id=organization.id,
        external_id="cust_1", name="Acme Corp",
    )
    db_session.add(customer)

    agg = UsageAggregate(
        id=uuid.uuid4(), organization_id=organization.id,
        customer_id=customer.id, event_name="ai_tokens",
        period_start=date(2025, 1, 1), period_end=date(2025, 1, 31),
        total_units=100000, billable_units=90000, amount_cents=9000,
    )
    db_session.add(agg)

    cost = AICost(
        id=uuid.uuid4(), organization_id=organization.id,
        customer_id=customer.id, provider="openai", model="gpt-4o",
        cost_date=date(2025, 1, 15), input_tokens=50000, output_tokens=50000,
        total_tokens=100000, cost_cents=3000,
    )
    db_session.add(cost)
    await db_session.flush()

    service = MarginCalculatorService(db_session)
    summary = await service.calculate_margins(organization.id, date(2025, 1, 1), date(2025, 1, 31))

    assert summary.total_revenue_cents == 9000
    assert summary.total_ai_cost_cents == 3000
    assert summary.overall_margin_percent == 66.67
    assert len(summary.unprofitable_customers) == 0
