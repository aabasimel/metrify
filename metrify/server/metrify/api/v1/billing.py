from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from metrify.database import get_db_session
from metrify.api.deps import get_current_organization
from metrify.models.organization import Organization
from metrify.schemas.billing import BillingSyncRequest, BillingSyncResult
from metrify.services.usage_aggregation import UsageAggregationService
from metrify.services.billing_sync import BillingSyncService

router = APIRouter(prefix="/billing", tags=["Billing"])


@router.post("/aggregate")
async def aggregate_usage(
    request: BillingSyncRequest,
    organization: Organization = Depends(get_current_organization),
    session: AsyncSession = Depends(get_db_session),
):
    service = UsageAggregationService(session)
    aggregates = await service.aggregate_period(organization.id, request.period_start, request.period_end)
    return {"aggregated": len(aggregates)}


@router.post("/sync", response_model=BillingSyncResult)
async def sync_billing_to_stripe(
    request: BillingSyncRequest,
    organization: Organization = Depends(get_current_organization),
    session: AsyncSession = Depends(get_db_session),
):
    service = BillingSyncService(session)
    return await service.sync_to_stripe(organization.id, request.period_start, request.period_end, dry_run=request.dry_run)
