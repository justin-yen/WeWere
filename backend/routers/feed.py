import random
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status

from middleware.auth import get_current_user
from models.schemas import PhotoResponse, ProfileResponse
from services.storage import get_signed_urls
from services.supabase import get_client

router = APIRouter(prefix="/feed", tags=["feed"])


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


@router.get("/random-photos", response_model=list[dict])
async def get_random_photos(
    count: int = 8,
    auth_id: str = Depends(get_current_user),
):
    """Get random photos from all developed events the user is part of.

    Returns photos with signed URLs, event name, and photographer name in a single call.
    Much faster than fetching photos per-event.
    """
    client = get_client()
    user_id = _get_internal_user_id(client, auth_id)

    # Get all events where user has developed
    memberships = (
        client.table("event_members")
        .select("event_id")
        .eq("user_id", user_id)
        .eq("has_developed", True)
        .execute()
    )

    if not memberships.data:
        return []

    event_ids = [m["event_id"] for m in memberships.data]

    # Fetch all photos from those events in one query
    photos_result = (
        client.table("photos")
        .select("id, event_id, user_id, storage_path, created_at, users(id, first_name, last_name, display_name)")
        .in_("event_id", event_ids)
        .execute()
    )

    if not photos_result.data:
        return []

    # Fetch event names
    events_result = (
        client.table("events")
        .select("id, name")
        .in_("id", event_ids)
        .execute()
    )
    event_names = {e["id"]: e["name"] for e in (events_result.data or [])}

    # Pick random photos
    all_photos = photos_result.data
    selected = random.sample(all_photos, min(count, len(all_photos)))

    # Batch generate signed URLs (one call instead of N)
    storage_paths = [p["storage_path"] for p in selected]
    signed_url_map = get_signed_urls(storage_paths, expires_in=3600)

    # Build response
    result = []
    for p in selected:
        user_data = p.get("users") or {}
        photographer_name = (
            user_data.get("display_name")
            or f"{user_data.get('first_name', '')} {user_data.get('last_name', '')}".strip()
            or "Unknown"
        )

        result.append({
            "id": p["id"],
            "photo_id": p["id"],
            "event_id": p["event_id"],
            "event_name": event_names.get(p["event_id"], "Unknown Event"),
            "photographer_name": photographer_name,
            "signed_url": signed_url_map.get(p["storage_path"], ""),
            "created_at": p["created_at"],
        })

    return result
