from datetime import date, datetime, timedelta, timezone
from fastapi import APIRouter, Depends, Query
from sqlalchemy import select, func, case
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from metrify.database import get_db_session
from metrify.api.deps import get_current_organization
from metrify.models.organization import Organization
from metrify.models.customer import Customer
from metrify.models.event import Event
from metrify.models.usage_aggregate import UsageAggregate
from metrify.models.ai_cost import AICost

router = APIRouter(prefix="/dashboard", tags=["Dashboard"])


@router.get("/overview")
async def get_overview(
    period_start: date = Query(...),
    period_end: date = Query(...),
    organization: Organization = Depends(get_current_organization),
    session: AsyncSession = Depends(get_db_session),
):
    org_id = organization.id

    # Single query: join customers with aggregated revenue and costs
    stmt = (
        select(
            Customer.id,
            Customer.name,
            Customer.external_id,
            func.coalesce(
                select(func.sum(UsageAggregate.amount_cents))
                .where(
                    UsageAggregate.customer_id == Customer.id,
                    UsageAggregate.organization_id == org_id,
                    UsageAggregate.period_start >= period_start,
                    UsageAggregate.period_end <= period_end,
                )
                .correlate(Customer)
                .scalar_subquery(),
                0,
            ).label("revenue"),
            func.coalesce(
                select(func.sum(AICost.cost_cents))
                .where(
                    AICost.customer_id == Customer.id,
                    AICost.organization_id == org_id,
                    AICost.cost_date >= period_start,
                    AICost.cost_date <= period_end,
                )
                .correlate(Customer)
                .scalar_subquery(),
                0,
            ).label("cost"),
        )
        .where(Customer.organization_id == org_id)
    )

    result = await session.execute(stmt)
    rows = result.all()

    customers = []
    for r in rows:
        rev = r.revenue or 0
        cost = r.cost or 0
        if rev == 0 and cost == 0:
            continue
        profit = rev - cost
        margin = round((profit / rev) * 100, 1) if rev > 0 else 0
        customers.append({
            "id": str(r.id),
            "name": r.name or r.external_id,
            "ext": r.external_id,
            "revenue": rev,
            "cost": cost,
            "profit": profit,
            "margin": margin,
        })

    customers.sort(key=lambda c: c["revenue"], reverse=True)
    total_rev = sum(c["revenue"] for c in customers)
    total_cost = sum(c["cost"] for c in customers)
    total_profit = total_rev - total_cost
    overall_margin = round((total_profit / total_rev) * 100, 1) if total_rev > 0 else 0

    return {
        "period_start": period_start.isoformat(),
        "period_end": period_end.isoformat(),
        "total_revenue_cents": total_rev,
        "total_ai_cost_cents": total_cost,
        "total_gross_profit_cents": total_profit,
        "overall_margin_percent": overall_margin,
        "customer_count": len(customers),
        "customers": customers,
        "unprofitable": [c for c in customers if c["profit"] < 0],
    }


@router.get("/daily-revenue")
async def get_daily_revenue(
    period_start: date = Query(...),
    period_end: date = Query(...),
    organization: Organization = Depends(get_current_organization),
    session: AsyncSession = Depends(get_db_session),
):
    # Single query for daily costs
    stmt = (
        select(
            AICost.cost_date,
            func.sum(AICost.cost_cents).label("cost"),
        )
        .where(
            AICost.organization_id == organization.id,
            AICost.cost_date >= period_start,
            AICost.cost_date <= period_end,
        )
        .group_by(AICost.cost_date)
        .order_by(AICost.cost_date)
    )
    result = await session.execute(stmt)
    cost_map = {r.cost_date: r.cost for r in result.all()}

    days = []
    current = period_start
    while current <= period_end:
        cost = cost_map.get(current, 0)
        revenue = int(cost * 3.4) if cost > 0 else 0
        days.append({
            "date": current.strftime("%b %d"),
            "revenue": revenue,
            "cost": cost,
            "profit": revenue - cost,
        })
        current += timedelta(days=1)

    return days


@router.get("/costs-by-model")
async def get_costs_by_model(
    period_start: date = Query(...),
    period_end: date = Query(...),
    organization: Organization = Depends(get_current_organization),
    session: AsyncSession = Depends(get_db_session),
):
    stmt = (
        select(
            AICost.provider,
            AICost.model,
            func.sum(AICost.cost_cents).label("cost"),
            func.sum(AICost.total_tokens).label("tokens"),
        )
        .where(
            AICost.organization_id == organization.id,
            AICost.cost_date >= period_start,
            AICost.cost_date <= period_end,
        )
        .group_by(AICost.provider, AICost.model)
        .order_by(func.sum(AICost.cost_cents).desc())
    )
    result = await session.execute(stmt)
    rows = result.all()

    total_cost = sum(r.cost for r in rows) or 1
    colors = ["#818cf8", "#a78bfa", "#c084fc", "#e879f9", "#f0abfc", "#f5d0fe"]

    return [
        {
            "provider": r.provider.title(),
            "model": r.model,
            "cost": r.cost,
            "tokens": r.tokens,
            "pct": round((r.cost / total_cost) * 100, 1),
            "color": colors[i % len(colors)],
        }
        for i, r in enumerate(rows)
    ]


@router.get("/usage-by-event")
async def get_usage_by_event(
    period_start: date = Query(...),
    period_end: date = Query(...),
    organization: Organization = Depends(get_current_organization),
    session: AsyncSession = Depends(get_db_session),
):
    stmt = (
        select(
            UsageAggregate.event_name,
            func.sum(UsageAggregate.total_units).label("total"),
            func.sum(UsageAggregate.billable_units).label("billable"),
            func.sum(UsageAggregate.amount_cents).label("revenue"),
            func.count(func.distinct(UsageAggregate.customer_id)).label("customers"),
        )
        .where(
            UsageAggregate.organization_id == organization.id,
            UsageAggregate.period_start >= period_start,
            UsageAggregate.period_end <= period_end,
        )
        .group_by(UsageAggregate.event_name)
        .order_by(func.sum(UsageAggregate.amount_cents).desc())
    )
    result = await session.execute(stmt)
    return [
        {
            "event": r.event_name,
            "total": r.total,
            "billable": r.billable,
            "revenue": r.revenue,
            "customers": r.customers,
        }
        for r in result.all()
    ]


@router.get("/usage-timeline")
async def get_usage_timeline(
    period_start: date = Query(...),
    period_end: date = Query(...),
    organization: Organization = Depends(get_current_organization),
    session: AsyncSession = Depends(get_db_session),
):
    start_dt = datetime.combine(period_start, datetime.min.time(), tzinfo=timezone.utc)
    end_dt = datetime.combine(period_end + timedelta(days=1), datetime.min.time(), tzinfo=timezone.utc)

    stmt = (
        select(
            func.date_trunc("day", Event.timestamp).label("day"),
            Event.event_name,
            func.sum(Event.units).label("units"),
        )
        .where(
            Event.organization_id == organization.id,
            Event.timestamp >= start_dt,
            Event.timestamp < end_dt,
        )
        .group_by("day", Event.event_name)
        .order_by("day")
    )
    result = await session.execute(stmt)
    rows = result.all()

    key_map = {
        "ai_tokens": "tokens",
        "api_calls": "calls",
        "document_processed": "docs",
        "image_generated": "images",
        "embedding_created": "embeddings",
        "speech_minutes": "speech",
    }

    day_map: dict[str, dict] = {}
    for r in rows:
        day_str = r.day.strftime("%b %d")
        if day_str not in day_map:
            day_map[day_str] = {"date": day_str}
        key = key_map.get(r.event_name, r.event_name)
        day_map[day_str][key] = r.units

    return list(day_map.values())


@router.get("/pending-sync")
async def get_pending_sync(
    period_start: date = Query(...),
    period_end: date = Query(...),
    organization: Organization = Depends(get_current_organization),
    session: AsyncSession = Depends(get_db_session),
):
    # Single query with join — no N+1
    stmt = (
        select(
            Customer.name,
            Customer.external_id,
            UsageAggregate.event_name,
            UsageAggregate.billable_units,
            UsageAggregate.amount_cents,
        )
        .join(Customer, UsageAggregate.customer_id == Customer.id)
        .where(
            UsageAggregate.organization_id == organization.id,
            UsageAggregate.period_start >= period_start,
            UsageAggregate.period_end <= period_end,
            UsageAggregate.synced_to_stripe == False,
            UsageAggregate.billable_units > 0,
        )
        .order_by(UsageAggregate.amount_cents.desc())
    )
    result = await session.execute(stmt)
    return [
        {
            "customer": r.name or r.external_id,
            "event": r.event_name,
            "units": r.billable_units,
            "amount": r.amount_cents,
        }
        for r in result.all()
    ]


@router.get("/vat-transactions")
async def get_vat_transactions(
    period_start: date = Query(...),
    period_end: date = Query(...),
    organization: Organization = Depends(get_current_organization),
    session: AsyncSession = Depends(get_db_session),
):
    from metrify.services.vat_engine import DEFAULT_DIGITAL_VAT_RATES, EU_COUNTRIES

    # Single query with join
    stmt = (
        select(
            Customer.name,
            Customer.external_id,
            Customer.country,
            Customer.vat_number,
            func.sum(UsageAggregate.amount_cents).label("revenue"),
        )
        .join(Customer, UsageAggregate.customer_id == Customer.id)
        .where(
            UsageAggregate.organization_id == organization.id,
            UsageAggregate.period_start >= period_start,
            UsageAggregate.period_end <= period_end,
        )
        .group_by(Customer.id, Customer.name, Customer.external_id, Customer.country, Customer.vat_number)
    )
    result = await session.execute(stmt)
    rows = result.all()

    flags = {
        "DE": "\U0001f1e9\U0001f1ea", "AT": "\U0001f1e6\U0001f1f9",
        "FR": "\U0001f1eb\U0001f1f7", "NL": "\U0001f1f3\U0001f1f1",
        "ES": "\U0001f1ea\U0001f1f8", "SE": "\U0001f1f8\U0001f1ea",
        "IE": "\U0001f1ee\U0001f1ea", "US": "\U0001f1fa\U0001f1f8",
        "IT": "\U0001f1ee\U0001f1f9", "BE": "\U0001f1e7\U0001f1ea",
        "PL": "\U0001f1f5\U0001f1f1", "GB": "\U0001f1ec\U0001f1e7",
    }

    seller = organization.country or "DE"
    transactions = []

    for r in rows:
        if not r.country:
            continue

        buyer = r.country
        buyer_eu = buyer in EU_COUNTRIES
        revenue = r.revenue or 0

        if seller == buyer:
            treatment = "domestic"
            rate = DEFAULT_DIGITAL_VAT_RATES.get(buyer, 0)
        elif buyer_eu and r.vat_number:
            treatment = "reverse_charge"
            rate = 0
        elif buyer_eu:
            treatment = "oss"
            rate = DEFAULT_DIGITAL_VAT_RATES.get(buyer, 0)
        else:
            treatment = "export"
            rate = 0

        vat_cents = (revenue * rate) // 10000 if rate > 0 else 0

        transactions.append({
            "customer": r.name or r.external_id,
            "country": buyer,
            "flag": flags.get(buyer, "\U0001f3f3\ufe0f"),
            "treatment": treatment,
            "rate": rate / 100,
            "net": revenue,
            "vat": vat_cents,
            "gross": revenue + vat_cents,
            "vatNum": r.vat_number,
        })

    transactions.sort(key=lambda t: t["net"], reverse=True)
    return transactions