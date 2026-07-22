from datetime import date
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from metrify.database import get_db_session
from metrify.api.deps import get_current_organization
from metrify.models.organization import Organization
from metrify.schemas.margin import MarginSummary
from metrify.services.margin_calculator import MarginCalculatorService

router = APIRouter(prefix="/margins", tags=["Margins"])


@router.get("/", response_model=MarginSummary)
async def get_margins(
    period_start: date = Query(...),
    period_end: date = Query(...),
    organization: Organization = Depends(get_current_organization),
    session: AsyncSession = Depends(get_db_session),
):
    service = MarginCalculatorService(session)
    return await service.calculate_margins(organization.id, period_start, period_end)
