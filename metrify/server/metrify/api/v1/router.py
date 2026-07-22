from fastapi import APIRouter
from metrify.api.v1.events import router as events_router
from metrify.api.v1.billing import router as billing_router
from metrify.api.v1.margins import router as margins_router
from metrify.api.v1.vat import router as vat_router
from metrify.api.v1.dashboard import router as dashboard_router
from metrify.api.v1.auth import router as auth_router

api_v1_router = APIRouter(prefix="/v1")
api_v1_router.include_router(auth_router)
api_v1_router.include_router(events_router)
api_v1_router.include_router(billing_router)
api_v1_router.include_router(margins_router)
api_v1_router.include_router(vat_router)
api_v1_router.include_router(dashboard_router)