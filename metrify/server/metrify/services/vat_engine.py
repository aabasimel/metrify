import structlog
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from metrify.models.vat_config import EUVATRate
from metrify.schemas.vat import VATCalculationRequest, VATCalculationResponse, OSSThresholdStatus

logger = structlog.get_logger()

EU_COUNTRIES = {
    "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR",
    "DE", "GR", "HU", "IE", "IT", "LV", "LT", "LU", "MT", "NL",
    "PL", "PT", "RO", "SK", "SI", "ES", "SE",
}

DEFAULT_DIGITAL_VAT_RATES = {
    "AT": 2000, "BE": 2100, "BG": 2000, "HR": 2500, "CY": 1900,
    "CZ": 2100, "DK": 2500, "EE": 2200, "FI": 2550, "FR": 2000,
    "DE": 1900, "GR": 2400, "HU": 2700, "IE": 2300, "IT": 2200,
    "LV": 2100, "LT": 2100, "LU": 1700, "MT": 1800, "NL": 2100,
    "PL": 2300, "PT": 2300, "RO": 1900, "SK": 2000, "SI": 2200,
    "ES": 2100, "SE": 2500,
}


class VATEngine:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def calculate(self, request: VATCalculationRequest) -> VATCalculationResponse:
        seller_eu = request.seller_country in EU_COUNTRIES
        buyer_eu = request.buyer_country in EU_COUNTRIES

        if not seller_eu:
            return VATCalculationResponse(
                net_amount_cents=request.amount_cents, vat_amount_cents=0,
                gross_amount_cents=request.amount_cents, vat_rate_bps=0,
                vat_rate_percent=0.0, treatment="non_eu_seller",
                buyer_country=request.buyer_country, seller_country=request.seller_country,
                notes="Seller is outside the EU. No EU VAT applies.",
            )

        if request.seller_country == request.buyer_country:
            rate = await self._get_rate(request.buyer_country)
            vat = (request.amount_cents * rate) // 10000
            return VATCalculationResponse(
                net_amount_cents=request.amount_cents, vat_amount_cents=vat,
                gross_amount_cents=request.amount_cents + vat, vat_rate_bps=rate,
                vat_rate_percent=rate / 100, treatment="domestic",
                buyer_country=request.buyer_country, seller_country=request.seller_country,
                notes=f"Domestic sale. {request.seller_country} VAT applies.",
            )

        if buyer_eu and request.buyer_vat_number:
            return VATCalculationResponse(
                net_amount_cents=request.amount_cents, vat_amount_cents=0,
                gross_amount_cents=request.amount_cents, vat_rate_bps=0,
                vat_rate_percent=0.0, treatment="eu_reverse_charge",
                buyer_country=request.buyer_country, seller_country=request.seller_country,
                notes=f"EU B2B reverse charge. Buyer VAT: {request.buyer_vat_number}.",
            )

        if buyer_eu:
            rate = await self._get_rate(request.buyer_country)
            vat = (request.amount_cents * rate) // 10000
            return VATCalculationResponse(
                net_amount_cents=request.amount_cents, vat_amount_cents=vat,
                gross_amount_cents=request.amount_cents + vat, vat_rate_bps=rate,
                vat_rate_percent=rate / 100, treatment="eu_oss",
                buyer_country=request.buyer_country, seller_country=request.seller_country,
                notes=f"EU B2C via OSS. {request.buyer_country} VAT rate applies.",
            )

        return VATCalculationResponse(
            net_amount_cents=request.amount_cents, vat_amount_cents=0,
            gross_amount_cents=request.amount_cents, vat_rate_bps=0,
            vat_rate_percent=0.0, treatment="export_zero_rated",
            buyer_country=request.buyer_country, seller_country=request.seller_country,
            notes="Export to non-EU country. Zero-rated.",
        )

    async def _get_rate(self, country_code: str) -> int:
        stmt = select(EUVATRate).where(EUVATRate.country_code == country_code)
        result = await self.session.execute(stmt)
        rate = result.scalar_one_or_none()
        if rate:
            return rate.digital_services_rate
        return DEFAULT_DIGITAL_VAT_RATES.get(country_code, 0)

    async def check_oss_threshold(
        self, organization_id, current_year_eu_sales_cents: int, countries_sold_to: list[str],
    ) -> OSSThresholdStatus:
        threshold = 1_000_000
        reached = current_year_eu_sales_cents >= threshold
        pct = round((current_year_eu_sales_cents / threshold) * 100, 1) if threshold > 0 else 0
        if reached:
            rec = "You have exceeded the EUR10,000 OSS threshold. You MUST register for OSS."
        elif pct >= 80:
            rec = f"You are at {pct}% of the OSS threshold. Consider registering proactively."
        else:
            rec = f"You are at {pct}% of the OSS threshold."
        return OSSThresholdStatus(
            current_year_eu_sales_cents=current_year_eu_sales_cents,
            oss_threshold_cents=threshold, threshold_reached=reached,
            threshold_percent=pct, countries_sold_to=countries_sold_to, recommendation=rec,
        )
