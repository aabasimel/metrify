import uuid
import hashlib
import secrets
from pydantic import BaseModel
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, String
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.dialects.postgresql import UUID as PG_UUID

from metrify.database import get_db_session
from metrify.models.base import Base, IDMixin, TimestampMixin
from metrify.models.organization import Organization

router = APIRouter(prefix="/auth", tags=["Auth"])


# ============================================
# User model
# ============================================
class User(Base, IDMixin, TimestampMixin):
    __tablename__ = "users"
    __table_args__ = {"extend_existing": True}

    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    organization_id: Mapped[uuid.UUID] = mapped_column(PG_UUID(as_uuid=True), nullable=False)
    auth_provider: Mapped[str] = mapped_column(String(50), default="email")


# ============================================
# Request/Response schemas
# ============================================
class SignupRequest(BaseModel):
    email: str
    password: str
    name: str
    company_name: str


class LoginRequest(BaseModel):
    email: str
    password: str


class GoogleAuthRequest(BaseModel):
    credential: str | None = None
    code: str | None = None
    email: str | None = None
    name: str | None = None


class AuthResponse(BaseModel):
    id: str
    email: str
    name: str
    orgId: str
    orgName: str
    apiKey: str
    avatar: str | None = None


# ============================================
# Helpers
# ============================================
def hash_password(password: str) -> str:
    salt = "metrify_salt_v1"
    return hashlib.sha256(f"{salt}:{password}".encode()).hexdigest()


def generate_api_key() -> str:
    return f"mtfy_live_sk_{secrets.token_hex(20)}"


def make_slug(name: str) -> str:
    slug = name.lower().strip()
    for char in [" ", ".", ",", "&", "'", '"', "/", "\\", "(", ")"]:
        slug = slug.replace(char, "-")
    # Remove double dashes
    while "--" in slug:
        slug = slug.replace("--", "-")
    slug = slug.strip("-")
    return slug or "org"


async def create_org_and_user(
    session: AsyncSession,
    email: str,
    password_hash: str,
    name: str,
    company_name: str,
    auth_provider: str = "email",
) -> tuple[User, Organization, str]:
    """Create organization + user + API key. Returns (user, org, api_key)."""

    # Generate unique slug
    base_slug = make_slug(company_name)
    slug = base_slug
    for attempt in range(10):
        result = await session.execute(
            select(Organization).where(Organization.slug == slug)
        )
        if not result.scalar_one_or_none():
            break
        slug = f"{base_slug}-{secrets.token_hex(3)}"

    # Generate API key
    api_key = generate_api_key()
    api_key_hash = hashlib.sha256(api_key.encode()).hexdigest()

    # Create organization
    org_id = uuid.uuid4()
    org = Organization(
        id=org_id,
        name=company_name,
        slug=slug,
        api_key_hash=api_key_hash,
        api_key_prefix=api_key[:8],
        country="DE",
    )
    session.add(org)
    await session.flush()

    # Create user
    user_id = uuid.uuid4()
    user = User(
        id=user_id,
        email=email,
        password_hash=password_hash,
        name=name,
        organization_id=org_id,
        auth_provider=auth_provider,
    )
    session.add(user)
    await session.flush()

    return user, org, api_key


def make_auth_response(user: User, org: Organization, api_key: str, avatar: str | None = None) -> AuthResponse:
    return AuthResponse(
        id=str(user.id),
        email=user.email,
        name=user.name,
        orgId=str(org.id),
        orgName=org.name,
        apiKey=api_key,
        avatar=avatar,
    )


# ============================================
# Endpoints
# ============================================
@router.post("/signup", response_model=AuthResponse)
async def signup(
    request: SignupRequest,
    session: AsyncSession = Depends(get_db_session),
):
    # Validate
    if not request.email or "@" not in request.email:
        raise HTTPException(status_code=400, detail="Invalid email address")
    if len(request.password) < 6:
        raise HTTPException(status_code=400, detail="Password must be at least 6 characters")
    if not request.name.strip():
        raise HTTPException(status_code=400, detail="Name is required")
    if not request.company_name.strip():
        raise HTTPException(status_code=400, detail="Company name is required")

    # Check if email exists
    result = await session.execute(
        select(User).where(User.email == request.email.lower().strip())
    )
    if result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Email already registered. Try logging in.")

    # Create everything
    user, org, api_key = await create_org_and_user(
        session=session,
        email=request.email.lower().strip(),
        password_hash=hash_password(request.password),
        name=request.name.strip(),
        company_name=request.company_name.strip(),
        auth_provider="email",
    )

    return make_auth_response(user, org, api_key)


@router.post("/login", response_model=AuthResponse)
async def login(
    request: LoginRequest,
    session: AsyncSession = Depends(get_db_session),
):
    email = request.email.lower().strip()

    # Demo login
    if email == "demo@metrify.dev" and request.password == "demo":
        # Find or create demo org
        result = await session.execute(
            select(Organization).where(Organization.slug == "demo-gmbh")
        )
        org = result.scalar_one_or_none()

        if not org:
            api_key = "mtfy_live_sk_a1b2c3d4e5f6g7h8i9j0"
            org = Organization(
                id=uuid.uuid4(),
                name="Demo GmbH",
                slug="demo-gmbh",
                api_key_hash=hashlib.sha256(api_key.encode()).hexdigest(),
                api_key_prefix=api_key[:8],
                country="DE",
            )
            session.add(org)
            await session.flush()

        return AuthResponse(
            id="demo",
            email="demo@metrify.dev",
            name="Demo User",
            orgId=str(org.id),
            orgName=org.name,
            apiKey="mtfy_live_sk_a1b2c3d4e5f6g7h8i9j0",
        )

    # Find user
    result = await session.execute(
        select(User).where(User.email == email)
    )
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=401, detail="Invalid email or password")

    # Check password
    if user.auth_provider == "google":
        raise HTTPException(
            status_code=401,
            detail="This account uses Google login. Click 'Continue with Google' instead."
        )

    if user.password_hash != hash_password(request.password):
        raise HTTPException(status_code=401, detail="Invalid email or password")

    # Get organization
    org = await session.get(Organization, user.organization_id)
    if not org:
        raise HTTPException(status_code=500, detail="Organization not found")

    # Regenerate API key on login (so user always has a working key)
    api_key = generate_api_key()
    org.api_key_hash = hashlib.sha256(api_key.encode()).hexdigest()
    org.api_key_prefix = api_key[:8]
    await session.flush()

    return make_auth_response(user, org, api_key)


@router.post("/google", response_model=AuthResponse)
async def google_auth(
    request: GoogleAuthRequest,
    session: AsyncSession = Depends(get_db_session),
):
    """
    Handle Google OAuth.
    In development: creates a mock Google user.
    In production: verify the credential with Google's API.
    """

    # Extract email and name from request or use defaults
    google_email = request.email or f"google-{secrets.token_hex(4)}@gmail.com"
    google_name = request.name or "Google User"

    # TODO: In production, verify the Google credential:
    # from google.oauth2 import id_token
    # from google.auth.transport import requests
    # idinfo = id_token.verify_oauth2_token(request.credential, requests.Request(), GOOGLE_CLIENT_ID)
    # google_email = idinfo['email']
    # google_name = idinfo.get('name', 'User')

    # Check if user already exists (returning Google user)
    result = await session.execute(
        select(User).where(User.email == google_email.lower())
    )
    existing_user = result.scalar_one_or_none()

    if existing_user:
        # Existing user — log them in
        org = await session.get(Organization, existing_user.organization_id)
        if not org:
            raise HTTPException(status_code=500, detail="Organization not found")

        # Regenerate API key
        api_key = generate_api_key()
        org.api_key_hash = hashlib.sha256(api_key.encode()).hexdigest()
        org.api_key_prefix = api_key[:8]
        await session.flush()

        avatar = f"https://ui-avatars.com/api/?name={google_name.replace(' ', '+')}&background=4f46e5&color=fff&size=64"
        return make_auth_response(existing_user, org, api_key, avatar=avatar)

    # New Google user — create account
    company_name = f"{google_name}'s Startup"

    user, org, api_key = await create_org_and_user(
        session=session,
        email=google_email.lower(),
        password_hash=hash_password(secrets.token_hex(32)),  # Random password (they use Google)
        name=google_name,
        company_name=company_name,
        auth_provider="google",
    )

    avatar = f"https://ui-avatars.com/api/?name={google_name.replace(' ', '+')}&background=4f46e5&color=fff&size=64"
    return make_auth_response(user, org, api_key, avatar=avatar)


@router.post("/google/callback", response_model=AuthResponse)
async def google_callback(
    request: GoogleAuthRequest,
    session: AsyncSession = Depends(get_db_session),
):
    """Handle Google OAuth redirect callback."""
    return await google_auth(request, session)