from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status

from middleware.auth import get_current_user
from models.schemas import ReactionResponse, AddReactionRequest, MyReactionsResponse, SuccessResponse
from services.supabase import get_client

router = APIRouter(prefix="/photos/{photo_id}/reactions", tags=["reactions"])


def _get_user_row(client, auth_id: str) -> dict:
    result = (
        client.table("users")
        .select("id")
        .eq("auth_id", auth_id)
        .maybe_single()
        .execute()
    )
    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User profile not found",
        )
    return result.data


@router.post("", response_model=ReactionResponse, status_code=status.HTTP_201_CREATED)
async def add_reaction(
    photo_id: UUID,
    body: AddReactionRequest,
    auth_id: str = Depends(get_current_user),
):
    """Add an emoji reaction to a photo."""
    client = get_client()
    user = _get_user_row(client, auth_id)

    # Check photo exists
    photo = (
        client.table("photos")
        .select("id")
        .eq("id", str(photo_id))
        .maybe_single()
        .execute()
    )
    if not photo.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Photo not found",
        )

    # Upsert to handle duplicate gracefully
    result = (
        client.table("reactions")
        .upsert(
            {
                "photo_id": str(photo_id),
                "user_id": user["id"],
                "emoji": body.emoji,
            },
            on_conflict="photo_id,user_id,emoji",
        )
        .execute()
    )

    if not result.data:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to add reaction",
        )

    return ReactionResponse(**result.data[0])


@router.delete("/{emoji}", response_model=SuccessResponse)
async def remove_reaction(
    photo_id: UUID,
    emoji: str,
    auth_id: str = Depends(get_current_user),
):
    """Remove an emoji reaction from a photo."""
    client = get_client()
    user = _get_user_row(client, auth_id)

    client.table("reactions").delete().eq(
        "photo_id", str(photo_id)
    ).eq("user_id", user["id"]).eq("emoji", emoji).execute()

    return SuccessResponse()


@router.get("", response_model=list[ReactionResponse])
async def list_reactions(
    photo_id: UUID,
    auth_id: str = Depends(get_current_user),
):
    """List all reactions on a photo with user info."""
    client = get_client()

    result = (
        client.table("reactions")
        .select("*, users(id, first_name, last_name, display_name)")
        .eq("photo_id", str(photo_id))
        .execute()
    )

    reactions = []
    for r in result.data or []:
        user_data = r.pop("users", None)
        if user_data:
            r["user"] = user_data
        reactions.append(ReactionResponse(**r))

    return reactions


@router.get("/me", response_model=MyReactionsResponse)
async def get_my_reactions(
    photo_id: UUID,
    auth_id: str = Depends(get_current_user),
):
    """Get the current user's reactions on a photo."""
    client = get_client()
    user = _get_user_row(client, auth_id)

    result = (
        client.table("reactions")
        .select("emoji")
        .eq("photo_id", str(photo_id))
        .eq("user_id", user["id"])
        .execute()
    )

    emojis = [r["emoji"] for r in (result.data or [])]
    return MyReactionsResponse(emojis=emojis)
