import hashlib
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status

from config import settings
from middleware.auth import get_current_user
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
from services.twilio_verify import send_otp, verify_otp

router = APIRouter(prefix="/auth", tags=["auth"])


def _phone_to_email(phone: str) -> str:
    """Convert a phone number to the deterministic email pattern used by the iOS app."""
    stripped = phone.replace("+", "")
    return f"{stripped}@wewere.phone"


def _phone_to_password(phone: str) -> str:
    """Create a deterministic password from the phone number.

    This matches the pattern used by the iOS app for Supabase auth.
    """
    return hashlib.sha256(f"wewere-{phone}".encode()).hexdigest()


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
            detail=f"OTP error: {str(e)}",
        )


@router.post("/verify-otp", response_model=VerifyOTPResponse)
async def verify_otp_endpoint(body: VerifyOTPRequest):
    """Verify an OTP code, create/sign-in the Supabase auth user, and return session tokens."""
    valid = verify_otp(body.phone_number, body.code)
    if not valid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired OTP code",
        )

    client = get_client()
    email = _phone_to_email(body.phone_number)
    password = _phone_to_password(body.phone_number)

    # Also try the old iOS app password format for existing users
    old_password = f"phone_{body.phone_number}_verified"

    # Try to sign in first (try new password, then old)
    session = None
    for pw in [password, old_password]:
        try:
            result = client.auth.sign_in_with_password({
                "email": email,
                "password": pw,
            })
            session = result.session
            break
        except Exception:
            continue

    if session is None:
        # User doesn't exist yet -- create via admin API
        try:
            client.auth.admin.create_user({
                "email": email,
                "password": password,
                "email_confirm": True,
                "phone": body.phone_number,
                "phone_confirm": True,
            })
            # Now sign in to get a session
            result = client.auth.sign_in_with_password({
                "email": email,
                "password": password,
            })
            session = result.session
        except Exception as e:
            # If user exists but both passwords failed, reset the password
            try:
                # Update password via admin API
                users = client.auth.admin.list_users()
                for u in users:
                    if getattr(u, 'email', None) == email:
                        client.auth.admin.update_user_by_id(str(u.id), {"password": password})
                        result = client.auth.sign_in_with_password({
                            "email": email,
                            "password": password,
                        })
                        session = result.session
                        break
            except Exception as e2:
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail=f"Failed to create or sign in user: {e2}",
                )

    if session is None:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create session",
        )

    # Check if user profile exists in the users table
    user_id = session.user.id
    user_profile: Optional[UserProfile] = None
    needs_profile = True

    try:
        profile_result = (
            client.table("users")
            .select("*")
            .eq("auth_id", str(user_id))
            .maybe_single()
            .execute()
        )
        if profile_result.data:
            user_profile = UserProfile(**profile_result.data)
            needs_profile = False
    except Exception:
        # Profile doesn't exist -- that's fine, needs_profile stays True
        pass

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
    if existing.data:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Profile already exists",
        )

    data = {
        "auth_id": user_id,
        "first_name": body.first_name,
        "last_name": body.last_name,
        "display_name": f"{body.first_name} {body.last_name}",
        "phone_number": body.phone_number,
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


@router.post("/test-login", response_model=VerifyOTPResponse)
async def test_login(body: TestLoginRequest):
    """DEV ONLY: Create or sign in a test user without OTP verification.

    Use test_id like 'test1', 'test2' to create different users.
    """
    client = get_client()
    email = f"{body.test_id}@wewere.test"
    password = hashlib.sha256(f"wewere-test-{body.test_id}".encode()).hexdigest()

    # Try sign in
    session = None
    try:
        result = client.auth.sign_in_with_password({
            "email": email,
            "password": password,
        })
        session = result.session
    except Exception:
        # Create user
        try:
            client.auth.admin.create_user({
                "email": email,
                "password": password,
                "email_confirm": True,
            })
            result = client.auth.sign_in_with_password({
                "email": email,
                "password": password,
            })
            session = result.session
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Failed to create test user: {e}",
            )

    if session is None:
        raise HTTPException(status_code=500, detail="Failed to create session")

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
