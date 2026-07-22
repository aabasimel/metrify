"""Initial migration

Revision ID: 001
Revises:
Create Date: 2025-01-01 00:00:00.000000
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "organizations",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("slug", sa.String(255), unique=True, nullable=False),
        sa.Column("stripe_account_id", sa.String(255)),
        sa.Column("api_key_hash", sa.String(255), nullable=False),
        sa.Column("api_key_prefix", sa.String(12), nullable=False),
        sa.Column("country", sa.String(2), server_default="DE"),
        sa.Column("vat_number", sa.String(20)),
        sa.Column("oss_registered", sa.Boolean, server_default="false"),
        sa.Column("openai_api_key_encrypted", sa.String(500)),
        sa.Column("anthropic_api_key_encrypted", sa.String(500)),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    op.create_table(
        "projects",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("organization_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("organizations.id"), nullable=False),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("slug", sa.String(255), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    op.create_table(
        "customers",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("organization_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("organizations.id"), nullable=False),
        sa.Column("external_id", sa.String(255), nullable=False),
        sa.Column("name", sa.String(255)),
        sa.Column("email", sa.String(255)),
        sa.Column("stripe_customer_id", sa.String(255)),
        sa.Column("stripe_subscription_id", sa.String(255)),
        sa.Column("country", sa.String(2)),
        sa.Column("vat_number", sa.String(20)),
        sa.Column("vat_verified", sa.Boolean, server_default="false"),
        sa.Column("plan_name", sa.String(100)),
        sa.Column("included_units", sa.Integer, server_default="0"),
        sa.Column("overage_price_cents", sa.Integer, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    op.create_table(
        "events",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("organization_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("organizations.id"), nullable=False),
        sa.Column("project_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("projects.id")),
        sa.Column("customer_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("customers.id"), nullable=False),
        sa.Column("event_name", sa.String(255), nullable=False),
        sa.Column("units", sa.BigInteger, server_default="1"),
        sa.Column("properties", postgresql.JSONB),
        sa.Column("timestamp", sa.DateTime(timezone=True), nullable=False),
        sa.Column("ingested_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("idempotency_key", sa.String(255)),
    )
    op.create_index("ix_events_org_customer_name_ts", "events", ["organization_id", "customer_id", "event_name", "timestamp"])
    op.create_index("ix_events_org_ts", "events", ["organization_id", "timestamp"])
    op.create_index("ix_events_idempotency", "events", ["organization_id", "idempotency_key"], unique=True)

    op.create_table(
        "usage_aggregates",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("organization_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("organizations.id"), nullable=False),
        sa.Column("customer_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("customers.id"), nullable=False),
        sa.Column("event_name", sa.String(255), nullable=False),
        sa.Column("period_start", sa.Date, nullable=False),
        sa.Column("period_end", sa.Date, nullable=False),
        sa.Column("total_units", sa.BigInteger, server_default="0"),
        sa.Column("billable_units", sa.BigInteger, server_default="0"),
        sa.Column("amount_cents", sa.BigInteger, server_default="0"),
        sa.Column("stripe_invoice_item_id", sa.String(255)),
        sa.Column("synced_to_stripe", sa.Boolean, server_default="false"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_unique_constraint("uq_usage_agg_org_cust_event_period", "usage_aggregates", ["organization_id", "customer_id", "event_name", "period_start"])
    op.create_index("ix_usage_agg_org_period", "usage_aggregates", ["organization_id", "period_start"])

    op.create_table(
        "ai_costs",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("organization_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("organizations.id"), nullable=False),
        sa.Column("customer_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("customers.id"), nullable=False),
        sa.Column("provider", sa.String(50), nullable=False),
        sa.Column("model", sa.String(100), nullable=False),
        sa.Column("cost_date", sa.Date, nullable=False),
        sa.Column("input_tokens", sa.BigInteger, server_default="0"),
        sa.Column("output_tokens", sa.BigInteger, server_default="0"),
        sa.Column("total_tokens", sa.BigInteger, server_default="0"),
        sa.Column("cost_microdollars", sa.BigInteger, server_default="0"),
        sa.Column("cost_cents", sa.Integer, server_default="0"),
        sa.Column("attribution_method", sa.String(50), server_default="'proportional'"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_ai_costs_org_date", "ai_costs", ["organization_id", "cost_date"])
    op.create_index("ix_ai_costs_customer_date", "ai_costs", ["customer_id", "cost_date"])

    op.create_table(
        "eu_vat_rates",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("country_code", sa.String(2), unique=True, nullable=False),
        sa.Column("country_name", sa.String(100), nullable=False),
        sa.Column("standard_rate", sa.Integer, nullable=False),
        sa.Column("reduced_rate", sa.Integer),
        sa.Column("digital_services_rate", sa.Integer, nullable=False),
        sa.Column("has_oss", sa.Boolean, server_default="true"),
    )

    op.execute("""
        INSERT INTO eu_vat_rates (id, country_code, country_name, standard_rate, digital_services_rate) VALUES
        (gen_random_uuid(), 'AT', 'Austria', 2000, 2000),
        (gen_random_uuid(), 'BE', 'Belgium', 2100, 2100),
        (gen_random_uuid(), 'BG', 'Bulgaria', 2000, 2000),
        (gen_random_uuid(), 'HR', 'Croatia', 2500, 2500),
        (gen_random_uuid(), 'CY', 'Cyprus', 1900, 1900),
        (gen_random_uuid(), 'CZ', 'Czech Republic', 2100, 2100),
        (gen_random_uuid(), 'DK', 'Denmark', 2500, 2500),
        (gen_random_uuid(), 'EE', 'Estonia', 2200, 2200),
        (gen_random_uuid(), 'FI', 'Finland', 2550, 2550),
        (gen_random_uuid(), 'FR', 'France', 2000, 2000),
        (gen_random_uuid(), 'DE', 'Germany', 1900, 1900),
        (gen_random_uuid(), 'GR', 'Greece', 2400, 2400),
        (gen_random_uuid(), 'HU', 'Hungary', 2700, 2700),
        (gen_random_uuid(), 'IE', 'Ireland', 2300, 2300),
        (gen_random_uuid(), 'IT', 'Italy', 2200, 2200),
        (gen_random_uuid(), 'LV', 'Latvia', 2100, 2100),
        (gen_random_uuid(), 'LT', 'Lithuania', 2100, 2100),
        (gen_random_uuid(), 'LU', 'Luxembourg', 1700, 1700),
        (gen_random_uuid(), 'MT', 'Malta', 1800, 1800),
        (gen_random_uuid(), 'NL', 'Netherlands', 2100, 2100),
        (gen_random_uuid(), 'PL', 'Poland', 2300, 2300),
        (gen_random_uuid(), 'PT', 'Portugal', 2300, 2300),
        (gen_random_uuid(), 'RO', 'Romania', 1900, 1900),
        (gen_random_uuid(), 'SK', 'Slovakia', 2000, 2000),
        (gen_random_uuid(), 'SI', 'Slovenia', 2200, 2200),
        (gen_random_uuid(), 'ES', 'Spain', 2100, 2100),
        (gen_random_uuid(), 'SE', 'Sweden', 2500, 2500)
    """)


def downgrade() -> None:
    op.drop_table("eu_vat_rates")
    op.drop_table("ai_costs")
    op.drop_table("usage_aggregates")
    op.drop_table("events")
    op.drop_table("customers")
    op.drop_table("projects")
    op.drop_table("organizations")
