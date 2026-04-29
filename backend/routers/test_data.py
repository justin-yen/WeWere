import random
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status

from middleware.auth import get_current_user
from services.supabase import get_client

router = APIRouter(prefix="/test", tags=["test"])


_FIRST_NAMES = [
    "Alex", "Jordan", "Taylor", "Morgan", "Casey", "Riley", "Avery", "Quinn",
    "Harper", "Emery", "Rowan", "Parker", "Sage", "Reese", "Logan", "Hayden",
    "Peyton", "Dakota", "Skyler", "Finley", "Emma", "Liam", "Olivia", "Noah",
    "Ava", "Elijah", "Sophia", "Mason", "Isabella", "Lucas", "Mia", "Ethan",
    "Amelia", "Oliver", "Charlotte", "Aiden", "Evelyn", "James", "Abigail",
    "Benjamin", "Harper", "Sebastian", "Emily", "Jack", "Madison", "Owen",
    "Scarlett", "Theodore", "Luna", "Wyatt", "Grace", "Julian", "Chloe",
    "Leo", "Penelope", "Grayson", "Layla", "Levi", "Riley", "Asher",
]

_LAST_NAMES = [
    "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller",
    "Davis", "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez",
    "Wilson", "Anderson", "Thomas", "Taylor", "Moore", "Jackson", "Martin",
    "Lee", "Perez", "Thompson", "White", "Harris", "Sanchez", "Clark",
    "Ramirez", "Lewis", "Robinson", "Walker", "Young", "Allen", "King",
    "Wright", "Scott", "Torres", "Nguyen", "Hill", "Flores", "Green",
    "Adams", "Nelson", "Baker", "Hall", "Rivera", "Campbell", "Mitchell",
    "Carter", "Roberts", "Gomez", "Phillips", "Evans", "Turner", "Diaz",
    "Parker", "Cruz", "Edwards", "Collins",
]

_HANDLES = [
    "sunset", "moon", "star", "wave", "cosmic", "neon", "analog", "dusk",
    "midnight", "aurora", "ember", "echo", "orbit", "pixel", "solstice",
    "twilight", "vapor", "velvet", "wildflower", "zenith",
]


def _generate_fake_user() -> dict:
    first = random.choice(_FIRST_NAMES)
    last = random.choice(_LAST_NAMES)
    handle = f"{random.choice(_HANDLES)}_{random.randint(100, 999)}"
    return {
        "first_name": first,
        "last_name": last,
        "display_name": f"{first} {last}",
        "instagram_handle": handle,
        "auth_id": None,
    }


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


@router.post("/events/{event_id}/populate-attendees")
async def populate_test_attendees(
    event_id: UUID,
    count: int = 50,
    auth_id: str = Depends(get_current_user),
):
    """Create fake user profiles and add them as attendees. Dev/test only."""
    if count < 1 or count > 200:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Count must be between 1 and 200",
        )

    client = get_client()
    user_id = _get_internal_user_id(client, auth_id)

    # Verify event exists and requester is a member (host or attendee)
    event = (
        client.table("events")
        .select("id, host_id")
        .eq("id", str(event_id))
        .maybe_single()
        .execute()
    )
    if not event or not event.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Event not found",
        )

    membership = (
        client.table("event_members")
        .select("id")
        .eq("event_id", str(event_id))
        .eq("user_id", user_id)
        .maybe_single()
        .execute()
    )
    if not membership or not membership.data:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not a member of this event",
        )

    # Generate and insert fake users
    fake_users = [_generate_fake_user() for _ in range(count)]
    users_result = client.table("users").insert(fake_users).execute()

    if not users_result.data:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create fake users",
        )

    # Add as event members
    members = [
        {
            "event_id": str(event_id),
            "user_id": u["id"],
            "role": "attendee",
            "has_developed": False,
        }
        for u in users_result.data
    ]
    client.table("event_members").insert(members).execute()

    return {"count": len(members)}
