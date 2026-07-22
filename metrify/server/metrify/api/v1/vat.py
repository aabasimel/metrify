from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from metrify.database import get_db_session
from metrify.api.deps import get_current_organization
from metrify.models.organization import Organization
from metrify.schemas.vat import VATCalculationRequest, VATCalculationResponse
from metrify.services.vat_engine import VATEngine

router = APIRouter(prefix="/vat", tags=["VAT"])


@router.post("/calculate", response_model=VATCalculationResponse)
async def calculate_vat(
    request: VATCalculationRequest,
    organization: Organization = Depends(get_current_organization),
    session: AsyncSession = Depends(get_db_session),
):
    engine = VATEngine(session)
    return await engine.calculate(request)
