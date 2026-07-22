import hashlib
from fastapi import Depends, HTTPException, Security, status
from fastapi.security import APIKeyHeader
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from metrify.database import get_db_session
from metrify.models.organization import Organization
from metrify.config import get_settings

settings = get_settings()
api_key_header = APIKeyHeader(name=settings.api_key_header, auto_error=False)


async def get_current_organization(
    api_key: str = Security(api_key_header),
    session: AsyncSession = Depends(get_db_session),
) -> Organization:
    if not api_key:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing API key")

    prefix = api_key[:8]
    key_hash = hashlib.sha256(api_key.encode()).hexdigest()

    stmt = select(Organization).where(
        Organization.api_key_prefix == prefix,
        Organization.api_key_hash == key_hash,
    )
    result = await session.execute(stmt)
    org = result.scalar_one_or_none()

    if not org:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid API key")
    return org
