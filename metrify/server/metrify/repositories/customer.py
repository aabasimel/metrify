import uuid
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from metrify.models.customer import Customer
from metrify.repositories.base import BaseRepository


class CustomerRepository(BaseRepository[Customer]):
    def __init__(self, session: AsyncSession):
        super().__init__(session, Customer)

    async def get_by_external_id(
        self, organization_id: uuid.UUID, external_id: str
    ) -> Customer | None:
        stmt = select(Customer).where(
            Customer.organization_id == organization_id,
            Customer.external_id == external_id,
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_or_create(
        self, organization_id: uuid.UUID, external_id: str
    ) -> Customer:
        customer = await self.get_by_external_id(organization_id, external_id)
        if customer:
            return customer
        customer = Customer(
            organization_id=organization_id,
            external_id=external_id,
        )
        return await self.create(customer)

    async def list_by_organization(self, organization_id: uuid.UUID) -> list[Customer]:
        stmt = (
            select(Customer)
            .where(Customer.organization_id == organization_id)
            .order_by(Customer.created_at.desc())
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())
