import asyncio
import pytest
import uuid
import hashlib
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from metrify.models import Base
from metrify.models.organization import Organization


@pytest.fixture(scope="session")
def event_loop():
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest.fixture
async def db_session():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    async with factory() as session:
        yield session
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await engine.dispose()


@pytest.fixture
async def organization(db_session: AsyncSession) -> Organization:
    api_key = "mtfy_test_key_12345678"
    org = Organization(
        id=uuid.uuid4(),
        name="Test Org",
        slug="test-org",
        api_key_hash=hashlib.sha256(api_key.encode()).hexdigest(),
        api_key_prefix=api_key[:8],
        country="DE",
    )
    db_session.add(org)
    await db_session.flush()
    return org
