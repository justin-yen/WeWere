from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status

from config import settings
from middleware.auth import get_current_user, require_development
from pydantic import BaseModel, Field

from models.schemas import (
    CreateProfileRequest,
    ProfileResponse,
    SendOTPRequest,
    SuccessResponse,
    VerifyOTPRequest,
    VerifyOTPResponse,
    UserProfile,
)
from services.supabase import get_client
from services.otp_session import session_for_verified_email
from services.twilio_verify import send_otp, verify_otp

router = APIRouter(prefix="/auth", tags=["auth"])


def _phone_to_email(phone: str) -> str:
    """Convert a phone number to the deterministic email pattern used by the iOS app."""
    stripped = phone.replace("+", "")
    return f"{stripped}@wewere.phone"


@router.post("/send-otp", response_model=SuccessResponse)
async def send_otp_endpoint(body: SendOTPRequest):
    """Send an OTP code to the given phone number."""
    try:
        success = send_otp(body.phone_number)
        if not success:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to send OTP",
            )
        return SuccessResponse(success=True)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Verification service temporarily unavailable",
        )


@router.post("/verify-otp", response_model=VerifyOTPResponse)
async def verify_otp_endpoint(body: VerifyOTPRequest):
    """Verify an OTP code, create/sign-in the Supabase auth user, and return session tokens."""
    try:
        valid = verify_otp(body.phone_number, body.code)
    except Exception:
        raise HTTPException(503, "Verification service temporarily unavailable") from None
    if not valid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired OTP code",
        )

    client = get_client()
    email = _phone_to_email(body.phone_number)
    try:
        session = session_for_verified_email(client, email, body.phone_number)
    except Exception:
        raise HTTPException(503, "Sign-in temporarily unavailable. Please request a new code.") from None

    # Check if user profile exists in the users table
    user_id = session.user.id
    user_profile: Optional[UserProfile] = None
    needs_profile = True

    # A database outage must not masquerade as a missing profile. Return the
    # valid session and let the client recover the profile fetch separately.
    try:
        profile_result = client.table("users").select("*").eq("auth_id", str(user_id)).maybe_single().execute()
        if profile_result and profile_result.data:
            user_profile = UserProfile(**profile_result.data)
            needs_profile = False
    except Exception:
        needs_profile = False

    return VerifyOTPResponse(
        access_token=session.access_token,
        refresh_token=session.refresh_token,
        user=user_profile,
        needs_profile=needs_profile,
    )


@router.post("/create-profile", response_model=ProfileResponse)
async def create_profile(
    body: CreateProfileRequest,
    user_id: str = Depends(get_current_user),
):
    """Create a user profile in the users table after initial auth."""
    client = get_client()

    # Check profile doesn't already exist
    existing = (
        client.table("users")
        .select("id")
        .eq("auth_id", user_id)
        .maybe_single()
        .execute()
    )
    if existing and existing.data:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Profile already exists",
        )

    identity = client.auth.admin.get_user_by_id(user_id).user
    verified_phone = identity.phone if identity else None
    if not verified_phone:
        raise HTTPException(400, "Phone number does not match verified identity")

    data = {
        "auth_id": user_id,
        "first_name": body.first_name,
        "last_name": body.last_name,
        "display_name": f"{body.first_name} {body.last_name}",
        "phone_number": verified_phone,
    }
    if body.instagram_handle:
        data["instagram_handle"] = body.instagram_handle

    result = client.table("users").insert(data).execute()

    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create profile",
        )

    return ProfileResponse(**result.data[0])


# ---------- Test Login (dev only) ----------

class TestLoginRequest(BaseModel):
    """Login as a test user without OTP. Creates the user if needed."""
    test_id: str = Field(..., description="A short identifier like 'test1', 'test2'")
    first_name: str = "Test"
    last_name: str = "User"


@router.post("/test-login", response_model=VerifyOTPResponse, dependencies=[Depends(require_development)])
async def test_login(body: TestLoginRequest):
    """DEV ONLY: Create or sign in a test user without OTP verification.

    Use test_id like 'test1', 'test2' to create different users.
    """
    client = get_client()
    email = f"{body.test_id}@wewere.test"
    try:
        session = session_for_verified_email(client, email)
    except Exception:
        raise HTTPException(503, "Test sign-in temporarily unavailable") from None

    # Check/create profile
    user_id = str(session.user.id)
    user_profile = None
    needs_profile = True

    profile_result = (
        client.table("users")
        .select("*")
        .eq("auth_id", user_id)
        .maybe_single()
        .execute()
    )
    if profile_result and profile_result.data:
        user_profile = UserProfile(**profile_result.data)
        needs_profile = False
    else:
        # Auto-create profile for test users
        phone = f"+1555000{body.test_id.replace('test', '').zfill(4)}"
        profile_data = {
            "auth_id": user_id,
            "first_name": body.first_name,
            "last_name": f"{body.last_name} {body.test_id.upper()}",
            "display_name": f"{body.first_name} {body.last_name} {body.test_id.upper()}",
            "phone_number": phone,
        }
        insert_result = client.table("users").insert(profile_data).execute()
        if insert_result.data:
            user_profile = UserProfile(**insert_result.data[0])
            needs_profile = False

    return VerifyOTPResponse(
        access_token=session.access_token,
        refresh_token=session.refresh_token,
        user=user_profile,
        needs_profile=needs_profile,
    )
