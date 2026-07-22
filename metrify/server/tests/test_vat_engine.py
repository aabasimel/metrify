import pytest
from metrify.services.vat_engine import VATEngine
from metrify.schemas.vat import VATCalculationRequest


@pytest.mark.asyncio
async def test_domestic_sale(db_session):
    engine = VATEngine(db_session)
    result = await engine.calculate(VATCalculationRequest(
        seller_country="DE", buyer_country="DE", amount_cents=10000,
    ))
    assert result.treatment == "domestic"
    assert result.vat_rate_bps == 1900
    assert result.vat_amount_cents == 1900


@pytest.mark.asyncio
async def test_eu_reverse_charge(db_session):
    engine = VATEngine(db_session)
    result = await engine.calculate(VATCalculationRequest(
        seller_country="DE", buyer_country="FR",
        buyer_vat_number="FR12345678901", amount_cents=10000,
    ))
    assert result.treatment == "eu_reverse_charge"
    assert result.vat_amount_cents == 0


@pytest.mark.asyncio
async def test_eu_b2c_oss(db_session):
    engine = VATEngine(db_session)
    result = await engine.calculate(VATCalculationRequest(
        seller_country="DE", buyer_country="FR", amount_cents=10000,
    ))
    assert result.treatment == "eu_oss"
    assert result.vat_rate_bps == 2000


@pytest.mark.asyncio
async def test_export_zero_rated(db_session):
    engine = VATEngine(db_session)
    result = await engine.calculate(VATCalculationRequest(
        seller_country="DE", buyer_country="US", amount_cents=10000,
    ))
    assert result.treatment == "export_zero_rated"
    assert result.vat_amount_cents == 0
