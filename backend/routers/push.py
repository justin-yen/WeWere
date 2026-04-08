from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status

from middleware.auth import get_current_user
from models.schemas import RegisterPushTokenRequest, SendPushRequest, SuccessResponse
from services.push_service import send_push_to_tokens
from services.supabase import get_client

router = APIRouter(prefix="/push", tags=["push"])


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


@router.post("/register", response_model=SuccessResponse)
async def register_push_token(
    body: RegisterPushTokenRequest,
    auth_id: str = Depends(get_current_user),
):
    """Register or update a device push token for the current user."""
    client = get_client()
    user_id = _get_internal_user_id(client, auth_id)

    client.table("users").update({"push_token": body.token}).eq("id", user_id).execute()

    return SuccessResponse(success=True)


@router.post("/send", response_model=SuccessResponse)
async def send_push(body: SendPushRequest):
    """Send a push notification to all members of an event.

    This is an internal endpoint. In production, protect with an API key.
    """
    client = get_client()

    # Get all members of the event with push tokens
    members = (
        client.table("event_members")
        .select("user_id, users(push_token)")
        .eq("event_id", str(body.event_id))
        .execute()
    )

    tokens: list[str] = []
    for member in members.data or []:
        user_data = member.get("users")
        if user_data and isinstance(user_data, dict):
            token = user_data.get("push_token")
            if token:
                tokens.append(token)

    if not tokens:
        return SuccessResponse(success=True)

    title_map = {
        "event_ended": "Film Ready to Develop!",
        "new_member": "New Member Joined",
        "photo_uploaded": "New Photo Taken",
    }
    title = title_map.get(body.type, "WeWere")

    await send_push_to_tokens(
        tokens=tokens,
        title=title,
        body=body.message,
        data={"event_id": str(body.event_id), "type": body.type},
    )

    return SuccessResponse(success=True)
