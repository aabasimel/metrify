import uuid
import hashlib
import secrets
import random
from datetime import datetime, timezone, timedelta
from pydantic import BaseModel, field_validator
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, String, Boolean, DateTime
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
    email_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    verification_code: Mapped[str | None] = mapped_column(String(10), nullable=True)
    verification_expires: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


# ============================================
# Schemas
# ============================================
class SignupRequest(BaseModel):
    email: str
    password: str
    name: str
    company_name: str

    @field_validator("email")
    @classmethod
    def validate_email(cls, v: str) -> str:
        v = v.lower().strip()
        if "@" not in v or "." not in v.split("@")[-1]:
            raise ValueError("Invalid email address")
        # Block obviously fake domains
        domain = v.split("@")[1]
        blocked = ["test.com", "fake.com", "example.com", "asdf.com", "abc.com"]
        if domain in blocked:
            raise ValueError(f"Please use a real email address")
        if len(domain) < 4:
            raise ValueError("Invalid email domain")
        return v

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        return v

    @field_validator("name")
    @classmethod
    def validate_name(cls, v: str) -> str:
        v = v.strip()
        if len(v) < 2:
            raise ValueError("Name is required")
        return v

    @field_validator("company_name")
    @classmethod
    def validate_company(cls, v: str) -> str:
        v = v.strip()
        if len(v) < 2:
            raise ValueError("Company name is required")
        return v


class LoginRequest(BaseModel):
    email: str
    password: str


class VerifyEmailRequest(BaseModel):
    email: str
    code: str


class ResendCodeRequest(BaseModel):
    email: str


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
    emailVerified: bool = False
    requiresVerification: bool = False


# ============================================
# Helpers
# ============================================
def hash_password(password: str) -> str:
    salt = "metrify_salt_v1"
    return hashlib.sha256(f"{salt}:{password}".encode()).hexdigest()


def generate_api_key() -> str:
    return f"mtfy_live_sk_{secrets.token_hex(20)}"


def generate_verification_code() -> str:
    return str(random.randint(100000, 999999))


def make_slug(name: str) -> str:
    slug = name.lower().strip()
    for char in [" ", ".", ",", "&", "'", '"', "/", "\\", "(", ")"]:
        slug = slug.replace(char, "-")
    while "--" in slug:
        slug = slug.replace("--", "-")
    return slug.strip("-") or "org"


async def send_verification_email(email: str, code: str, name: str):
    """
    Send verification code via email.
    Uses SMTP — configure with Gmail, SendGrid, Resend, etc.
    For development, just prints the code.
    """
    import os

    smtp_host = os.environ.get("SMTP_HOST", "")
    smtp_user = os.environ.get("SMTP_USER", "")
    smtp_pass = os.environ.get("SMTP_PASS", "")

    if not smtp_host:
        # Development mode — print code to console
        print(f"\n{'='*50}")
        print(f"  VERIFICATION CODE for {email}")
        print(f"  Code: {code}")
        print(f"{'='*50}\n")
        return

    # Production — send real email
    import aiosmtplib
    from email.mime.text import MIMEText
    from email.mime.multipart import MIMEMultipart

    msg = MIMEMultipart("alternative")
    msg["Subject"] = f"Metrify — Your verification code is {code}"
    msg["From"] = smtp_user
    msg["To"] = email

    html = f"""
    <div style="font-family: -apple-system, sans-serif; max-width: 400px; margin: 0 auto; padding: 40px 20px;">
        <div style="text-align: center; margin-bottom: 30px;">
            <div style="display: inline-block; width: 40px; height: 40px; background: linear-gradient(135deg, #6366f1, #4338ca); border-radius: 10px; line-height: 40px; color: white; font-weight: bold; font-size: 18px;">M</div>
        </div>
        <h2 style="text-align: center; color: #18181b; margin-bottom: 10px;">Verify your email</h2>
        <p style="text-align: center; color: #71717a; font-size: 14px;">Hi {name}, enter this code to verify your account:</p>
        <div style="text-align: center; margin: 30px 0;">
            <span style="font-size: 32px; font-weight: bold; letter-spacing: 8px; color: #18181b; font-family: monospace;">{code}</span>
        </div>
        <p style="text-align: center; color: #a1a1aa; font-size: 12px;">This code expires in 10 minutes.</p>
        <p style="text-align: center; color: #a1a1aa; font-size: 12px; margin-top: 30px;">If you didn't sign up for Metrify, ignore this email.</p>
    </div>
    """

    msg.attach(MIMEText(html, "html"))

    try:
        await aiosmtplib.send(
            msg,
            hostname=smtp_host,
            port=587,
            username=smtp_user,
            password=smtp_pass,
            use_tls=True,
        )
    except Exception as e:
        print(f"Failed to send email: {e}")
        # Don't block signup if email fails
        print(f"VERIFICATION CODE for {email}: {code}")


async def create_org_and_user(
    session: AsyncSession,
    email: str,
    password_hash: str,
    name: str,
    company_name: str,
    auth_provider: str = "email",
    email_verified: bool = False,
) -> tuple[User, Organization, str]:
    base_slug = make_slug(company_name)
    slug = base_slug
    for _ in range(10):
        result = await session.execute(
            select(Organization).where(Organization.slug == slug)
        )
        if not result.scalar_one_or_none():
            break
        slug = f"{base_slug}-{secrets.token_hex(3)}"

    api_key = generate_api_key()
    api_key_hash = hashlib.sha256(api_key.encode()).hexdigest()

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

    code = generate_verification_code()
    user_id = uuid.uuid4()
    user = User(
        id=user_id,
        email=email,
        password_hash=password_hash,
        name=name,
        organization_id=org_id,
        auth_provider=auth_provider,
        email_verified=email_verified,
        verification_code=code if not email_verified else None,
        verification_expires=datetime.now(timezone.utc) + timedelta(minutes=10) if not email_verified else None,
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
        emailVerified=user.email_verified,
        requiresVerification=not user.email_verified and user.auth_provider == "email",
    )


# ============================================
# Endpoints
# ============================================
@router.post("/signup", response_model=AuthResponse)
async def signup(
    request: SignupRequest,
    session: AsyncSession = Depends(get_db_session),
):
    email = request.email.lower().strip()

    result = await session.execute(
        select(User).where(User.email == email)
    )
    existing = result.scalar_one_or_none()

    if existing:
        if existing.email_verified:
            raise HTTPException(status_code=400, detail="Email already registered. Try logging in.")
        else:
            # Resend verification code
            code = generate_verification_code()
            existing.verification_code = code
            existing.verification_expires = datetime.now(timezone.utc) + timedelta(minutes=10)
            await session.flush()
            await send_verification_email(email, code, existing.name)

            org = await session.get(Organization, existing.organization_id)
            api_key = generate_api_key()
            org.api_key_hash = hashlib.sha256(api_key.encode()).hexdigest()
            org.api_key_prefix = api_key[:8]
            await session.flush()

            return make_auth_response(existing, org, api_key)

    user, org, api_key = await create_org_and_user(
        session=session,
        email=email,
        password_hash=hash_password(request.password),
        name=request.name.strip(),
        company_name=request.company_name.strip(),
        auth_provider="email",
        email_verified=False,
    )

    await send_verification_email(email, user.verification_code, user.name)

    return make_auth_response(user, org, api_key)


@router.post("/verify-email", response_model=AuthResponse)
async def verify_email(
    request: VerifyEmailRequest,
    session: AsyncSession = Depends(get_db_session),
):
    email = request.email.lower().strip()

    result = await session.execute(
        select(User).where(User.email == email)
    )
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=400, detail="Account not found")

    if user.email_verified:
        raise HTTPException(status_code=400, detail="Email already verified")

    if not user.verification_code or not user.verification_expires:
        raise HTTPException(status_code=400, detail="No verification code. Request a new one.")

    if datetime.now(timezone.utc) > user.verification_expires:
        raise HTTPException(status_code=400, detail="Code expired. Request a new one.")

    if user.verification_code != request.code.strip():
        raise HTTPException(status_code=400, detail="Invalid code")

    user.email_verified = True
    user.verification_code = None
    user.verification_expires = None
    await session.flush()

    org = await session.get(Organization, user.organization_id)
    api_key = generate_api_key()
    org.api_key_hash = hashlib.sha256(api_key.encode()).hexdigest()
    org.api_key_prefix = api_key[:8]
    await session.flush()

    return make_auth_response(user, org, api_key)


@router.post("/resend-code")
async def resend_code(
    request: ResendCodeRequest,
    session: AsyncSession = Depends(get_db_session),
):
    email = request.email.lower().strip()

    result = await session.execute(
        select(User).where(User.email == email)
    )
    user = result.scalar_one_or_none()

    if not user:
        return {"message": "If that email exists, a new code has been sent."}

    if user.email_verified:
        return {"message": "Email already verified. You can log in."}

    code = generate_verification_code()
    user.verification_code = code
    user.verification_expires = datetime.now(timezone.utc) + timedelta(minutes=10)
    await session.flush()

    await send_verification_email(email, code, user.name)

    return {"message": "Verification code sent."}


@router.post("/login", response_model=AuthResponse)
async def login(
    request: LoginRequest,
    session: AsyncSession = Depends(get_db_session),
):
    email = request.email.lower().strip()

    if email == "demo@metrify.dev" and request.password == "demo":
        result = await session.execute(
            select(Organization).where(Organization.slug == "demo-gmbh")
        )
        org = result.scalar_one_or_none()
        if not org:
            api_key = "mtfy_live_sk_a1b2c3d4e5f6g7h8i9j0"
            org = Organization(
                id=uuid.uuid4(), name="Demo GmbH", slug="demo-gmbh",
                api_key_hash=hashlib.sha256(api_key.encode()).hexdigest(),
                api_key_prefix=api_key[:8], country="DE",
            )
            session.add(org)
            await session.flush()

        return AuthResponse(
            id="demo", email="demo@metrify.dev", name="Demo User",
            orgId=str(org.id), orgName=org.name,
            apiKey="mtfy_live_sk_a1b2c3d4e5f6g7h8i9j0",
            emailVerified=True, requiresVerification=False,
        )

    result = await session.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=401, detail="Invalid email or password")

    if user.auth_provider == "google":
        raise HTTPException(status_code=401, detail="This account uses Google login. Click 'Continue with Google'.")

    if user.password_hash != hash_password(request.password):
        raise HTTPException(status_code=401, detail="Invalid email or password")

    if not user.email_verified:
        code = generate_verification_code()
        user.verification_code = code
        user.verification_expires = datetime.now(timezone.utc) + timedelta(minutes=10)
        await session.flush()
        await send_verification_email(email, code, user.name)

        org = await session.get(Organization, user.organization_id)
        api_key = generate_api_key()
        org.api_key_hash = hashlib.sha256(api_key.encode()).hexdigest()
        org.api_key_prefix = api_key[:8]
        await session.flush()

        return make_auth_response(user, org, api_key)

    org = await session.get(Organization, user.organization_id)
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
    google_email = (request.email or f"google-{secrets.token_hex(4)}@gmail.com").lower()
    google_name = request.name or "Google User"

    result = await session.execute(select(User).where(User.email == google_email))
    existing_user = result.scalar_one_or_none()

    if existing_user:
        org = await session.get(Organization, existing_user.organization_id)
        api_key = generate_api_key()
        org.api_key_hash = hashlib.sha256(api_key.encode()).hexdigest()
        org.api_key_prefix = api_key[:8]
        await session.flush()
        avatar = f"https://ui-avatars.com/api/?name={google_name.replace(' ', '+')}&background=4f46e5&color=fff&size=64"
        return make_auth_response(existing_user, org, api_key, avatar=avatar)

    user, org, api_key = await create_org_and_user(
        session=session, email=google_email,
        password_hash=hash_password(secrets.token_hex(32)),
        name=google_name, company_name=f"{google_name}'s Startup",
        auth_provider="google", email_verified=True,
    )
    avatar = f"https://ui-avatars.com/api/?name={google_name.replace(' ', '+')}&background=4f46e5&color=fff&size=64"
    return make_auth_response(user, org, api_key, avatar=avatar)


@router.post("/google/callback", response_model=AuthResponse)
async def google_callback(
    request: GoogleAuthRequest,
    session: AsyncSession = Depends(get_db_session),
):
    return await google_auth(request, session)