import uuid
from datetime import date
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from metrify.models.ai_cost import AICost
from metrify.repositories.base import BaseRepository


class AICostRepository(BaseRepository[AICost]):
    def __init__(self, session: AsyncSession):
        super().__init__(session, AICost)

    async def get_costs_by_customer(
        self, organization_id: uuid.UUID, start_date: date, end_date: date,
    ) -> list[dict]:
        stmt = (
            select(
                AICost.customer_id,
                func.sum(AICost.cost_cents).label("total_cost_cents"),
                func.sum(AICost.input_tokens).label("total_input_tokens"),
                func.sum(AICost.output_tokens).label("total_output_tokens"),
            )
            .where(
                AICost.organization_id == organization_id,
                AICost.cost_date >= start_date,
                AICost.cost_date <= end_date,
            )
            .group_by(AICost.customer_id)
        )
        result = await self.session.execute(stmt)
        return [dict(row._mapping) for row in result.all()]
