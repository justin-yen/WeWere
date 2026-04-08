import httpx
from fastapi import APIRouter, Depends, HTTPException, status

from config import settings
from middleware.auth import get_current_user

router = APIRouter(prefix="/places", tags=["places"])

AUTOCOMPLETE_URL = "https://maps.googleapis.com/maps/api/place/autocomplete/json"
DETAILS_URL = "https://maps.googleapis.com/maps/api/place/details/json"


@router.get("/autocomplete")
async def autocomplete(query: str, auth_id: str = Depends(get_current_user)):
    """Proxy Google Places Autocomplete API. Returns location suggestions."""
    if not settings.GOOGLE_PLACES_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Google Places API key not configured",
        )

    async with httpx.AsyncClient() as client:
        resp = await client.get(
            AUTOCOMPLETE_URL,
            params={
                "input": query,
                "key": settings.GOOGLE_PLACES_API_KEY,
            },
        )

    data = resp.json()
    if data.get("status") not in ("OK", "ZERO_RESULTS"):
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Google Places API error: {data.get('status')}",
        )

    predictions = data.get("predictions", [])
    return [
        {
            "place_id": p["place_id"],
            "description": p["description"],
            "structured_formatting": {
                "main_text": p.get("structured_formatting", {}).get("main_text", ""),
                "secondary_text": p.get("structured_formatting", {}).get("secondary_text", ""),
            },
        }
        for p in predictions
    ]


@router.get("/details/{place_id}")
async def place_details(place_id: str, auth_id: str = Depends(get_current_user)):
    """Get detailed place info including lat/lng."""
    if not settings.GOOGLE_PLACES_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Google Places API key not configured",
        )

    async with httpx.AsyncClient() as client:
        resp = await client.get(
            DETAILS_URL,
            params={
                "place_id": place_id,
                "key": settings.GOOGLE_PLACES_API_KEY,
                "fields": "geometry,formatted_address,name",
            },
        )

    data = resp.json()
    if data.get("status") != "OK":
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Google Places API error: {data.get('status')}",
        )

    result = data["result"]
    location = result.get("geometry", {}).get("location", {})

    return {
        "name": result.get("name", ""),
        "address": result.get("formatted_address", ""),
        "latitude": location.get("lat"),
        "longitude": location.get("lng"),
    }
