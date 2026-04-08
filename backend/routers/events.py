import secrets
import string
from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status

from middleware.auth import get_current_user
from models.schemas import (
    CreateEventRequest,
    EventDetailResponse,
    EventResponse,
    MemberResponse,
    ProfileResponse,
    SuccessResponse,
)
from services.supabase import get_client

router = APIRouter(prefix="/events", tags=["events"])


def _get_internal_user_id(client, auth_id: str) -> str:
    """Resolve a Supabase auth UUID to the internal users table UUID."""
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


def _generate_share_code(length: int = 8) -> str:
    """Generate a random alphanumeric share code."""
    alphabet = string.ascii_uppercase + string.digits
    return "".join(secrets.choice(alphabet) for _ in range(length))


def _assert_member(client, event_id: str, user_id: str) -> dict:
    """Assert the user is a member of the event. Returns the membership record."""
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
    """Get an event by ID or raise 404."""
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


@router.get("", response_model=list[EventResponse])
async def list_events(auth_id: str = Depends(get_current_user)):
    """List all events the current user is a member of."""
    client = get_client()
    user_id = _get_internal_user_id(client, auth_id)

    # Get event IDs the user is a member of
    memberships = (
        client.table("event_members")
        .select("event_id, role, has_developed, developed_at")
        .eq("user_id", user_id)
        .execute()
    )

    if not memberships.data:
        return []

    event_ids = [m["event_id"] for m in memberships.data]

    events = (
        client.table("events")
        .select("*")
        .in_("id", event_ids)
        .order("created_at", desc=True)
        .execute()
    )

    # Enrich with counts
    result = []
    for event in events.data or []:
        # Photo count
        photo_count_res = (
            client.table("photos")
            .select("id", count="exact")
            .eq("event_id", event["id"])
            .execute()
        )
        # Member count
        member_count_res = (
            client.table("event_members")
            .select("id", count="exact")
            .eq("event_id", event["id"])
            .execute()
        )
        event["photo_count"] = photo_count_res.count or 0
        event["member_count"] = member_count_res.count or 0

        # Add current user's membership info
        user_membership = next(
            (m for m in memberships.data if m["event_id"] == event["id"]),
            None
        )
        if user_membership:
            event["membership"] = {
                "has_developed": user_membership.get("has_developed", False),
                "developed_at": user_membership.get("developed_at"),
                "role": user_membership.get("role"),
            }

        result.append(EventResponse(**event))

    return result


@router.post("", response_model=EventResponse, status_code=status.HTTP_201_CREATED)
async def create_event(
    body: CreateEventRequest,
    auth_id: str = Depends(get_current_user),
):
    """Create a new event and add the creator as host."""
    client = get_client()
    user_id = _get_internal_user_id(client, auth_id)
    share_code = _generate_share_code()

    event_data = {
        "name": body.name,
        "host_id": user_id,
        "share_code": share_code,
        "start_time": body.start_time.isoformat(),
        "status": "live",
    }
    if body.description:
        event_data["description"] = body.description
    if body.location:
        event_data["location"] = body.location
    if body.location_name:
        event_data["location_name"] = body.location_name
    if body.location_address:
        event_data["location_address"] = body.location_address
    if body.location_lat is not None:
        event_data["location_lat"] = body.location_lat
    if body.location_lng is not None:
        event_data["location_lng"] = body.location_lng
    if body.end_time:
        event_data["end_time"] = body.end_time.isoformat()

    result = client.table("events").insert(event_data).execute()
    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create event",
        )

    event = result.data[0]

    # Add creator as host member
    client.table("event_members").insert({
        "event_id": event["id"],
        "user_id": user_id,
        "role": "host",
        "has_developed": False,
    }).execute()

    event["photo_count"] = 0
    event["member_count"] = 1
    return EventResponse(**event)


@router.get("/join/{share_code}", response_model=EventResponse)
async def get_event_by_share_code(share_code: str):
    """Get event info by share code. Public endpoint -- no auth required."""
    client = get_client()
    result = (
        client.table("events")
        .select("*")
        .eq("share_code", share_code)
        .maybe_single()
        .execute()
    )
    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Event not found",
        )
    event = result.data
    return EventResponse(**event)


@router.get("/{event_id}", response_model=EventDetailResponse)
async def get_event(
    event_id: UUID,
    auth_id: str = Depends(get_current_user),
):
    """Get detailed event info. Requires membership."""
    client = get_client()
    user_id = _get_internal_user_id(client, auth_id)
    event = _get_event_or_404(client, str(event_id))
    membership = _assert_member(client, str(event_id), user_id)

    # Get members with user info
    members_result = (
        client.table("event_members")
        .select("*, users(*)")
        .eq("event_id", str(event_id))
        .execute()
    )

    members = []
    for m in members_result.data or []:
        user_data = m.pop("users", None)
        if user_data:
            m["user"] = user_data
        members.append(m)

    # Counts
    photo_count_res = (
        client.table("photos")
        .select("id", count="exact")
        .eq("event_id", str(event_id))
        .execute()
    )
    member_count_res = (
        client.table("event_members")
        .select("id", count="exact")
        .eq("event_id", str(event_id))
        .execute()
    )

    event["photo_count"] = photo_count_res.count or 0
    event["member_count"] = member_count_res.count or 0
    event["members"] = members
    event["has_developed"] = membership.get("has_developed", False)

    return EventDetailResponse(**event)


@router.post("/{event_id}/end", response_model=EventResponse)
async def end_event(
    event_id: UUID,
    auth_id: str = Depends(get_current_user),
):
    """End an event. Only the host can do this."""
    client = get_client()
    user_id = _get_internal_user_id(client, auth_id)
    event = _get_event_or_404(client, str(event_id))

    if event["host_id"] != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the host can end the event",
        )

    if event.get("status") == "ended":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Event is already ended",
        )

    result = (
        client.table("events")
        .update({
            "status": "ended",
            "end_time": datetime.now(timezone.utc).isoformat(),
        })
        .eq("id", str(event_id))
        .execute()
    )

    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to end event",
        )

    updated = result.data[0]
    return EventResponse(**updated)


@router.get("/{event_id}/members", response_model=list[MemberResponse])
async def list_members(
    event_id: UUID,
    auth_id: str = Depends(get_current_user),
):
    """List event members with user info."""
    client = get_client()
    user_id = _get_internal_user_id(client, auth_id)
    _assert_member(client, str(event_id), user_id)

    members_result = (
        client.table("event_members")
        .select("*, users(*)")
        .eq("event_id", str(event_id))
        .execute()
    )

    members = []
    for m in members_result.data or []:
        user_data = m.pop("users", None)
        if user_data:
            m["user"] = user_data
        members.append(MemberResponse(**m))

    return members


@router.post("/{event_id}/join", response_model=SuccessResponse)
async def join_event(
    event_id: UUID,
    auth_id: str = Depends(get_current_user),
):
    """Join an event. The event_id in the URL must match."""
    client = get_client()
    user_id = _get_internal_user_id(client, auth_id)
    event = _get_event_or_404(client, str(event_id))

    if event.get("status") == "ended":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot join an ended event",
        )

    # Check if already a member
    existing = (
        client.table("event_members")
        .select("id")
        .eq("event_id", str(event_id))
        .eq("user_id", user_id)
        .maybe_single()
        .execute()
    )
    if existing and existing.data:
        return SuccessResponse(success=True)  # Already joined, idempotent

    client.table("event_members").insert({
        "event_id": str(event_id),
        "user_id": user_id,
        "role": "attendee",
        "has_developed": False,
    }).execute()

    return SuccessResponse(success=True)


@router.post("/{event_id}/develop", response_model=SuccessResponse)
async def develop_event(
    event_id: UUID,
    auth_id: str = Depends(get_current_user),
):
    """Mark the current user's film as developed for this event."""
    client = get_client()
    user_id = _get_internal_user_id(client, auth_id)
    membership = _assert_member(client, str(event_id), user_id)

    if membership.get("has_developed"):
        return SuccessResponse(success=True)  # Already developed

    client.table("event_members").update({
        "has_developed": True,
        "developed_at": datetime.now(timezone.utc).isoformat(),
    }).eq("event_id", str(event_id)).eq("user_id", user_id).execute()

    return SuccessResponse(success=True)
