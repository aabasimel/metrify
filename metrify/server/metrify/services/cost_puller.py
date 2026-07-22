import uuid
import structlog
from datetime import date, datetime, timedelta, timezone
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from metrify.models.organization import Organization
from metrify.models.event import Event
from metrify.models.ai_cost import AICost

logger = structlog.get_logger()

OPENAI_PRICING = {
    "gpt-4o": {"input": 2.50, "output": 10.00},
    "gpt-4o-mini": {"input": 0.15, "output": 0.60},
    "gpt-4-turbo": {"input": 10.00, "output": 30.00},
    "o1": {"input": 15.00, "output": 60.00},
    "o1-mini": {"input": 3.00, "output": 12.00},
    "o3-mini": {"input": 1.10, "output": 4.40},
}

ANTHROPIC_PRICING = {
    "claude-sonnet-4-20250514": {"input": 3.00, "output": 15.00},
    "claude-3-5-sonnet-20241022": {"input": 3.00, "output": 15.00},
    "claude-3-5-haiku-20241022": {"input": 0.80, "output": 4.00},
    "claude-3-opus-20240229": {"input": 15.00, "output": 75.00},
}


class CostPullerService:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def pull_and_attribute(
        self, organization: Organization, cost_date: date | None = None,
    ) -> list[AICost]:
        if cost_date is None:
            cost_date = date.today() - timedelta(days=1)

        start = datetime.combine(cost_date, datetime.min.time(), tzinfo=timezone.utc)
        end = datetime.combine(cost_date + timedelta(days=1), datetime.min.time(), tzinfo=timezone.utc)

        stmt = (
            select(Event.customer_id, Event.properties)
            .where(
                Event.organization_id == organization.id,
                Event.timestamp >= start,
                Event.timestamp < end,
                Event.event_name.in_(["ai_tokens", "ai_completion", "llm_call"]),
                Event.properties.isnot(None),
            )
        )
        result = await self.session.execute(stmt)
        events = result.all()

        cost_map: dict[tuple[uuid.UUID, str, str], dict] = {}

        for row in events:
            props = row.properties or {}
            model = props.get("model", "unknown")
            provider = self._detect_provider(model)
            input_tokens = props.get("input_tokens", 0)
            output_tokens = props.get("output_tokens", 0)
            cost_micro = self._calculate_cost(provider, model, input_tokens, output_tokens)

            key = (row.customer_id, provider, model)
            if key not in cost_map:
                cost_map[key] = {"input_tokens": 0, "output_tokens": 0, "cost_microdollars": 0}
            cost_map[key]["input_tokens"] += input_tokens
            cost_map[key]["output_tokens"] += output_tokens
            cost_map[key]["cost_microdollars"] += cost_micro

        ai_costs = []
        for (customer_id, provider, model), data in cost_map.items():
            ai_cost = AICost(
                organization_id=organization.id,
                customer_id=customer_id,
                provider=provider,
                model=model,
                cost_date=cost_date,
                input_tokens=data["input_tokens"],
                output_tokens=data["output_tokens"],
                total_tokens=data["input_tokens"] + data["output_tokens"],
                cost_microdollars=data["cost_microdollars"],
                cost_cents=data["cost_microdollars"] // 10_000,
                attribution_method="direct",
            )
            self.session.add(ai_cost)
            ai_costs.append(ai_cost)

        await self.session.flush()
        logger.info("costs_attributed", org=str(organization.id), records=len(ai_costs))
        return ai_costs

    def _detect_provider(self, model: str) -> str:
        if model.startswith("claude"):
            return "anthropic"
        if model.startswith(("gpt", "o1", "o3")):
            return "openai"
        return "unknown"

    def _calculate_cost(self, provider: str, model: str, input_tokens: int, output_tokens: int) -> int:
        pricing = {}
        if provider == "openai":
            pricing = OPENAI_PRICING.get(model, {})
        elif provider == "anthropic":
            pricing = ANTHROPIC_PRICING.get(model, {})
        if not pricing:
            return 0
        input_cost = (input_tokens * pricing.get("input", 0)) / 1_000_000 * 1_000_000
        output_cost = (output_tokens * pricing.get("output", 0)) / 1_000_000 * 1_000_000
        return int(input_cost + output_cost)
