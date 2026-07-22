"""
Seed the database with test data for development.
Run: python -m scripts.seed
"""
import asyncio
import uuid
import hashlib
import random
from datetime import datetime, date, timedelta, timezone

from metrify.database import async_session_factory, engine
from metrify.models import Base
from metrify.models.organization import Organization
from metrify.models.customer import Customer
from metrify.models.event import Event
from metrify.models.usage_aggregate import UsageAggregate
from metrify.models.ai_cost import AICost


API_KEY = "mtfy_live_sk_a1b2c3d4e5f6g7h8i9j0"

CUSTOMERS = [
    {"ext": "acme_corp", "name": "Acme Corp", "country": "DE", "vat": "DE123456789", "stripe": "cus_acme", "plan": "growth", "included": 500000, "overage": 1},
    {"ext": "globex", "name": "Globex Inc", "country": "DE", "vat": "DE987654321", "stripe": "cus_globex", "plan": "growth", "included": 500000, "overage": 1},
    {"ext": "initech", "name": "Initech GmbH", "country": "DE", "vat": "DE456789123", "stripe": "cus_initech", "plan": "pro", "included": 1000000, "overage": 1},
    {"ext": "hooli", "name": "Hooli AG", "country": "AT", "vat": "ATU12345678", "stripe": "cus_hooli", "plan": "growth", "included": 500000, "overage": 1},
    {"ext": "piedpiper", "name": "Pied Piper", "country": "NL", "vat": "NL123456789B01", "stripe": "cus_pied", "plan": "starter", "included": 100000, "overage": 1},
    {"ext": "wayne", "name": "Wayne Enterprises", "country": "FR", "vat": None, "stripe": "cus_wayne", "plan": "growth", "included": 500000, "overage": 1},
    {"ext": "stark", "name": "Stark Industries", "country": "ES", "vat": None, "stripe": "cus_stark", "plan": "starter", "included": 100000, "overage": 1},
    {"ext": "umbrella", "name": "Umbrella Corp", "country": "US", "vat": None, "stripe": "cus_umbrella", "plan": "starter", "included": 100000, "overage": 1},
    {"ext": "cyberdyne", "name": "Cyberdyne Systems", "country": "US", "vat": None, "stripe": "cus_cyberdyne", "plan": "starter", "included": 100000, "overage": 1},
    {"ext": "weyland", "name": "Weyland-Yutani", "country": "IE", "vat": "IE1234567T", "stripe": "cus_weyland", "plan": "starter", "included": 100000, "overage": 1},
    {"ext": "skynet", "name": "Skynet AI", "country": "SE", "vat": None, "stripe": "cus_skynet", "plan": "starter", "included": 100000, "overage": 2},
    {"ext": "trial", "name": "Trial User", "country": "DE", "vat": None, "stripe": None, "plan": "free", "included": 50000, "overage": 0},
]

MODELS = [
    ("openai", "gpt-4o", 2.50, 10.00),
    ("openai", "gpt-4o-mini", 0.15, 0.60),
    ("anthropic", "claude-3-5-sonnet", 3.00, 15.00),
    ("openai", "o1-mini", 3.00, 12.00),
    ("anthropic", "claude-3-5-haiku", 0.80, 4.00),
]

EVENT_TYPES = ["ai_tokens", "api_calls", "document_processed", "image_generated"]


async def seed():
    # Create tables
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with async_session_factory() as session:
        # Check if already seeded
        from sqlalchemy import select, func
        count = await session.scalar(select(func.count()).select_from(Organization))
        if count and count > 0:
            print("Database already seeded. Drop tables first if you want to re-seed.")
            print("  psql -U metrify -c 'DROP SCHEMA public CASCADE; CREATE SCHEMA public;'")
            return

        # Organization
        org_id = uuid.uuid4()
        org = Organization(
            id=org_id,
            name="Demo GmbH",
            slug="demo-gmbh",
            api_key_hash=hashlib.sha256(API_KEY.encode()).hexdigest(),
            api_key_prefix=API_KEY[:8],
            country="DE",
            vat_number="DE123456789",
            oss_registered=True,
        )
        session.add(org)
        print(f"Created org: {org.name} (API key: {API_KEY})")

        # Customers
        customer_map: dict[str, Customer] = {}
        for c in CUSTOMERS:
            customer = Customer(
                id=uuid.uuid4(),
                organization_id=org_id,
                external_id=c["ext"],
                name=c["name"],
                country=c["country"],
                vat_number=c["vat"],
                stripe_customer_id=c["stripe"],
                plan_name=c["plan"],
                included_units=c["included"],
                overage_price_cents=c["overage"],
                vat_verified=c["vat"] is not None,
            )
            session.add(customer)
            customer_map[c["ext"]] = customer
            print(f"  Customer: {c['name']} ({c['country']})")

        await session.flush()

        # Generate events for January 2025
        print("\nGenerating events...")
        period_start = date(2025, 1, 1)
        period_end = date(2025, 1, 31)

        # Revenue weights per customer (higher = more usage)
        weights = {
            "acme_corp": 12, "globex": 9, "initech": 7.5, "hooli": 6.2,
            "piedpiper": 4.5, "wayne": 3.8, "stark": 2.9, "umbrella": 1.2,
            "cyberdyne": 0.85, "weyland": 0.45, "skynet": 0.15, "trial": 0.05,
        }

        event_count = 0
        for day_offset in range(31):
            current_date = period_start + timedelta(days=day_offset)
            is_weekend = current_date.weekday() >= 5
            day_multiplier = 0.55 if is_weekend else 1.0

            for ext_id, customer in customer_map.items():
                weight = weights.get(ext_id, 1.0)

                for event_type in EVENT_TYPES:
                    # Not all customers use all event types
                    if event_type == "image_generated" and ext_id not in ["acme_corp", "globex", "hooli", "wayne", "stark", "skynet"]:
                        continue
                    if event_type == "document_processed" and ext_id in ["trial", "skynet"]:
                        continue

                    # Calculate units
                    if event_type == "ai_tokens":
                        base_units = int(weight * 30000 * day_multiplier * (0.8 + random.random() * 0.4))
                    elif event_type == "api_calls":
                        base_units = int(weight * 1000 * day_multiplier * (0.7 + random.random() * 0.6))
                    elif event_type == "document_processed":
                        base_units = int(weight * 50 * day_multiplier * (0.5 + random.random() * 1.0))
                    else:  # image_generated
                        base_units = int(weight * 15 * day_multiplier * (0.3 + random.random() * 1.4))

                    if base_units <= 0:
                        continue

                    # Pick a model for AI events
                    model_idx = random.choices(range(len(MODELS)), weights=[40, 30, 15, 10, 5])[0]
                    provider, model, input_price, output_price = MODELS[model_idx]
                    input_tokens = int(base_units * 0.6)
                    output_tokens = base_units - input_tokens

                    props = {
                        "model": model,
                        "input_tokens": input_tokens,
                        "output_tokens": output_tokens,
                    } if event_type == "ai_tokens" else None

                    event = Event(
                        id=uuid.uuid4(),
                        organization_id=org_id,
                        customer_id=customer.id,
                        event_name=event_type,
                        units=base_units,
                        properties=props,
                        timestamp=datetime.combine(
                            current_date,
                            datetime.min.time(),
                            tzinfo=timezone.utc
                        ) + timedelta(hours=random.randint(8, 20), minutes=random.randint(0, 59)),
                        idempotency_key=f"seed-{ext_id}-{event_type}-{current_date.isoformat()}-{random.randint(0, 9999)}",
                    )
                    session.add(event)
                    event_count += 1

        print(f"  Created {event_count} events")

        # Generate usage aggregates
        print("\nAggregating usage...")
        from sqlalchemy import select, func as sqlfunc

        stmt = (
            select(
                Event.customer_id,
                Event.event_name,
                sqlfunc.sum(Event.units).label("total_units"),
            )
            .where(
                Event.organization_id == org_id,
                Event.timestamp >= datetime.combine(period_start, datetime.min.time(), tzinfo=timezone.utc),
                Event.timestamp < datetime.combine(period_end + timedelta(days=1), datetime.min.time(), tzinfo=timezone.utc),
            )
            .group_by(Event.customer_id, Event.event_name)
        )
        await session.flush()
        result = await session.execute(stmt)
        rows = result.all()

        agg_count = 0
        for row in rows:
            customer = await session.get(Customer, row.customer_id)
            if not customer:
                continue

            total = row.total_units
            billable = max(0, total - customer.included_units)
            amount = billable * customer.overage_price_cents

            agg = UsageAggregate(
                id=uuid.uuid4(),
                organization_id=org_id,
                customer_id=row.customer_id,
                event_name=row.event_name,
                period_start=period_start,
                period_end=period_end,
                total_units=total,
                billable_units=billable,
                amount_cents=amount,
            )
            session.add(agg)
            agg_count += 1

        print(f"  Created {agg_count} usage aggregates")

        # Generate AI costs
        print("\nAttributing AI costs...")
        cost_count = 0
        for day_offset in range(31):
            current_date = period_start + timedelta(days=day_offset)

            for ext_id, customer in customer_map.items():
                weight = weights.get(ext_id, 1.0)
                is_weekend = current_date.weekday() >= 5
                day_mult = 0.55 if is_weekend else 1.0

                for provider, model, input_price, output_price in MODELS:
                    # Not all customers use all models
                    model_chance = random.random()
                    if model == "gpt-4o" and model_chance > 0.7:
                        continue
                    if model == "gpt-4o-mini" and model_chance > 0.6:
                        continue
                    if model.startswith("claude") and model_chance > 0.4:
                        continue
                    if model == "o1-mini" and model_chance > 0.3:
                        continue

                    input_tokens = int(weight * 5000 * day_mult * (0.5 + random.random()))
                    output_tokens = int(input_tokens * (0.3 + random.random() * 0.4))

                    if input_tokens <= 0:
                        continue

                    # Cost in microdollars
                    input_cost = (input_tokens * input_price) / 1_000_000 * 1_000_000
                    output_cost = (output_tokens * output_price) / 1_000_000 * 1_000_000
                    total_cost_micro = int(input_cost + output_cost)
                    cost_cents = total_cost_micro // 10_000

                    if cost_cents <= 0:
                        continue

                    ai_cost = AICost(
                        id=uuid.uuid4(),
                        organization_id=org_id,
                        customer_id=customer.id,
                        provider=provider,
                        model=model,
                        cost_date=current_date,
                        input_tokens=input_tokens,
                        output_tokens=output_tokens,
                        total_tokens=input_tokens + output_tokens,
                        cost_microdollars=total_cost_micro,
                        cost_cents=cost_cents,
                        attribution_method="direct",
                    )
                    session.add(ai_cost)
                    cost_count += 1

        print(f"  Created {cost_count} AI cost records")

        await session.commit()
        print(f"\n✅ Seed complete!")
        print(f"   API Key: {API_KEY}")
        print(f"   Org: Demo GmbH")
        print(f"   Customers: {len(CUSTOMERS)}")
        print(f"   Events: {event_count}")
        print(f"   Aggregates: {agg_count}")
        print(f"   Cost records: {cost_count}")


if __name__ == "__main__":
    asyncio.run(seed())