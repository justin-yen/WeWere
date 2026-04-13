from uuid import UUID

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status

from middleware.auth import get_current_user
from models.schemas import ProfileResponse, UpdateProfileRequest
from services.storage import get_signed_url, upload_avatar
from services.supabase import get_client

router = APIRouter(prefix="/profiles", tags=["profiles"])


@router.get("/me", response_model=ProfileResponse)
async def get_my_profile(user_id: str = Depends(get_current_user)):
    """Get the current user's profile."""
    client = get_client()
    result = (
        client.table("users")
        .select("*")
        .eq("auth_id", user_id)
        .maybe_single()
        .execute()
    )
    if result is None or not result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Profile not found",
        )
    return ProfileResponse(**result.data)


@router.put("/me", response_model=ProfileResponse)
async def update_my_profile(
    body: UpdateProfileRequest,
    user_id: str = Depends(get_current_user),
):
    """Update the current user's profile."""
    client = get_client()

    update_data = body.model_dump(exclude_none=True)
    if not update_data:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No fields to update",
        )

    result = (
        client.table("users")
        .update(update_data)
        .eq("auth_id", user_id)
        .execute()
    )

    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Profile not found",
        )

    return ProfileResponse(**result.data[0])


@router.get("/me/stats")
async def get_my_stats(user_id: str = Depends(get_current_user)):
    """Get the current user's event and photo counts."""
    client = get_client()

    # Resolve auth_id to internal user id
    user_result = (
        client.table("users")
        .select("id")
        .eq("auth_id", user_id)
        .maybe_single()
        .execute()
    )
    if not user_result or not user_result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Profile not found",
        )
    internal_id = user_result.data["id"]

    events_result = (
        client.table("event_members")
        .select("id", count="exact")
        .eq("user_id", internal_id)
        .execute()
    )

    photos_result = (
        client.table("photos")
        .select("id", count="exact")
        .eq("user_id", internal_id)
        .execute()
    )

    return {
        "events_attended": events_result.count or 0,
        "photos_taken": photos_result.count or 0,
    }


@router.post("/me/avatar", response_model=ProfileResponse)
async def upload_avatar_endpoint(
    file: UploadFile = File(...),
    user_id: str = Depends(get_current_user),
):
    """Upload a profile picture. The image is stored in Supabase storage."""
    content_type = file.content_type or "image/jpeg"
    if not content_type.startswith("image/"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File must be an image",
        )

    file_bytes = await file.read()
    if len(file_bytes) > 10 * 1024 * 1024:  # 10MB limit
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File too large (max 10MB)",
        )

    # Attempt to resize to 256x256 if Pillow is available
    try:
        from io import BytesIO

        from PIL import Image

        img = Image.open(BytesIO(file_bytes))
        img = img.convert("RGB")
        img = img.resize((256, 256), Image.LANCZOS)
        buffer = BytesIO()
        img.save(buffer, format="JPEG", quality=85)
        file_bytes = buffer.getvalue()
        content_type = "image/jpeg"
    except ImportError:
        # Pillow not installed -- upload original
        pass

    storage_path = upload_avatar(user_id, file_bytes, content_type)
    avatar_url = get_signed_url(storage_path, expires_in=86400 * 365)  # 1 year

    client = get_client()
    result = (
        client.table("users")
        .update({"avatar_url": avatar_url})
        .eq("auth_id", user_id)
        .execute()
    )

    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Profile not found",
        )

    return ProfileResponse(**result.data[0])


@router.get("/{target_user_id}", response_model=ProfileResponse)
async def get_user_profile(
    target_user_id: UUID,
    user_id: str = Depends(get_current_user),
):
    """Get another user's public profile."""
    client = get_client()
    result = (
        client.table("users")
        .select("*")
        .eq("id", str(target_user_id))
        .maybe_single()
        .execute()
    )
    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )
    return ProfileResponse(**result.data)
