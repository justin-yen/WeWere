from collections import defaultdict
from datetime import datetime, timedelta, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status

from middleware.auth import get_current_user
from models.schemas import (
    AddCommentRequest,
    CommentResponse,
    PeakTimeResponse,
    PhotoCountResponse,
    PhotoResponse,
    ProfileResponse,
)
from services.storage import get_signed_urls, upload_photo
from services.supabase import get_client

router = APIRouter(prefix="/events/{event_id}/photos", tags=["photos"])


def _get_internal_user_id(client, auth_id: str) -> str:
    result = (
        client.table("users")
        .select("id")
        .eq("auth_id", auth_id)
        .maybe_single()
        .execute()
    )
    if not result or not result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User profile not found",
        )
    return result.data["id"]


def _assert_member(client, event_id: str, user_id: str) -> dict:
    result = (
        client.table("event_members")
        .select("*")
        .eq("event_id", event_id)
        .eq("user_id", user_id)
        .maybe_single()
        .execute()
    )
    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not a member of this event",
        )
    return result.data


def _get_event_or_404(client, event_id: str) -> dict:
    result = (
        client.table("events")
        .select("*")
        .eq("id", event_id)
        .maybe_single()
        .execute()
    )
    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Event not found",
        )
    return result.data


@router.post("", response_model=PhotoResponse, status_code=status.HTTP_201_CREATED)
async def upload_event_photo(
    event_id: UUID,
    file: UploadFile = File(...),
    auth_id: str = Depends(get_current_user),
):
    """Upload a photo to an event. Event must be live and user must be a member."""
    client = get_client()
    user_id = _get_internal_user_id(client, auth_id)
    event = _get_event_or_404(client, str(event_id))
    _assert_member(client, str(event_id), user_id)

    if event.get("status") == "ended":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot upload photos to an ended event",
        )

    # Validate file type
    content_type = file.content_type or "image/jpeg"
    if not content_type.startswith("image/"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File must be an image",
        )

    file_bytes = await file.read()
    if len(file_bytes) > 20 * 1024 * 1024:  # 20MB limit
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File too large (max 20MB)",
        )

    storage_path = upload_photo(str(event_id), user_id, file_bytes, content_type)

    # Create record in photos table
    result = (
        client.table("photos")
        .insert({
            "event_id": str(event_id),
            "user_id": user_id,
            "storage_path": storage_path,
        })
        .execute()
    )

    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to save photo record",
        )

    return PhotoResponse(**result.data[0])


@router.get("", response_model=list[PhotoResponse])
async def list_photos(
    event_id: UUID,
    auth_id: str = Depends(get_current_user),
):
    """List all photos for an event with signed URLs. User must have developed."""
    client = get_client()
    user_id = _get_internal_user_id(client, auth_id)
    membership = _assert_member(client, str(event_id), user_id)

    if not membership.get("has_developed"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You must develop your film before viewing photos",
        )

    # Fetch photos with user info
    photos_result = (
        client.table("photos")
        .select("*, users(*)")
        .eq("event_id", str(event_id))
        .order("created_at", desc=False)
        .execute()
    )

    photos = photos_result.data or []
    if not photos:
        return []

    # Generate signed URLs for all photos
    storage_paths = [p["storage_path"] for p in photos if p.get("storage_path")]
    url_map = get_signed_urls(storage_paths) if storage_paths else {}

    result = []
    for p in photos:
        user_data = p.pop("users", None)
        if user_data:
            p["user"] = user_data
        p["signed_url"] = url_map.get(p.get("storage_path", ""), "")
        result.append(PhotoResponse(**p))

    return result


@router.get("/count", response_model=PhotoCountResponse)
async def get_photo_count(
    event_id: UUID,
    auth_id: str = Depends(get_current_user),
):
    """Get the number of photos in an event."""
    client = get_client()
    user_id = _get_internal_user_id(client, auth_id)
    _assert_member(client, str(event_id), user_id)

    result = (
        client.table("photos")
        .select("id", count="exact")
        .eq("event_id", str(event_id))
        .execute()
    )

    return PhotoCountResponse(count=result.count or 0)


@router.get("/peak-time", response_model=PeakTimeResponse)
async def get_peak_time(
    event_id: UUID,
    auth_id: str = Depends(get_current_user),
):
    """Calculate the peak photo-taking time using a 15-minute sliding window."""
    client = get_client()
    user_id = _get_internal_user_id(client, auth_id)
    _assert_member(client, str(event_id), user_id)

    photos_result = (
        client.table("photos")
        .select("created_at")
        .eq("event_id", str(event_id))
        .order("created_at", desc=False)
        .execute()
    )

    photos = photos_result.data or []
    if not photos:
        return PeakTimeResponse(peak_start=None, peak_end=None, photo_count=0)

    # Parse timestamps
    timestamps: list[datetime] = []
    for p in photos:
        ts_str = p.get("created_at", "")
        if ts_str:
            try:
                ts = datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
                timestamps.append(ts)
            except ValueError:
                continue

    if not timestamps:
        return PeakTimeResponse(peak_start=None, peak_end=None, photo_count=0)

    timestamps.sort()
    window_duration = timedelta(minutes=15)

    best_start = timestamps[0]
    best_count = 0

    # Sliding window
    for i, start in enumerate(timestamps):
        window_end = start + window_duration
        count = 0
        for ts in timestamps[i:]:
            if ts <= window_end:
                count += 1
            else:
                break
        if count > best_count:
            best_count = count
            best_start = start

    return PeakTimeResponse(
        peak_start=best_start,
        peak_end=best_start + window_duration,
        photo_count=best_count,
    )


# ─── Comments ───────────────────────────────────────────────────────


@router.get("/{photo_id}/comments", response_model=list[CommentResponse])
async def list_comments(
    event_id: UUID,
    photo_id: UUID,
    auth_id: str = Depends(get_current_user),
):
    """List comments for a photo, ordered by created_at ascending."""
    client = get_client()
    user_id = _get_internal_user_id(client, auth_id)
    _assert_member(client, str(event_id), user_id)

    result = (
        client.table("comments")
        .select("*, users(id, first_name, last_name, instagram_handle, phone_number, avatar_url, created_at)")
        .eq("photo_id", str(photo_id))
        .order("created_at", desc=False)
        .execute()
    )

    comments = result.data or []
    response = []
    for c in comments:
        user_data = c.pop("users", None)
        if user_data:
            c["user"] = user_data
        response.append(CommentResponse(**c))

    return response


@router.post(
    "/{photo_id}/comments",
    response_model=CommentResponse,
    status_code=status.HTTP_201_CREATED,
)
async def add_comment(
    event_id: UUID,
    photo_id: UUID,
    body: AddCommentRequest,
    auth_id: str = Depends(get_current_user),
):
    """Add a comment to a photo."""
    client = get_client()
    user_id = _get_internal_user_id(client, auth_id)
    _assert_member(client, str(event_id), user_id)

    result = (
        client.table("comments")
        .insert({
            "photo_id": str(photo_id),
            "user_id": user_id,
            "text": body.text,
        })
        .execute()
    )

    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to save comment",
        )

    comment = result.data[0]

    # Fetch user info to include in response
    user_result = (
        client.table("users")
        .select("id, first_name, last_name, instagram_handle, phone_number, avatar_url, created_at")
        .eq("id", user_id)
        .maybe_single()
        .execute()
    )
    if user_result.data:
        comment["user"] = user_result.data

    return CommentResponse(**comment)
