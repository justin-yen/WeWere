import re
from fastapi import APIRouter, Depends, HTTPException, Query, status
import httpx

from config import settings
from middleware.auth import get_current_user

router = APIRouter(prefix="/unsplash", tags=["unsplash"])

# Common English stopwords to strip from queries
_STOPWORDS = frozenset(
    "a an the at in on of to for and or but is are was were my our your his her "
    "its their this that these those with from by".split()
)


def _build_query(name: str, description: str | None = None) -> str:
    """Extract up to 4 keywords from the event name + description."""
    text = name
    if description:
        text += " " + description

    # Remove possessives and special chars
    text = re.sub(r"'s\b", "", text)
    words = re.findall(r"[a-zA-Z]+", text.lower())
    keywords = [w for w in words if w not in _STOPWORDS and len(w) > 2]

    # Deduplicate while preserving order
    seen: set[str] = set()
    unique: list[str] = []
    for w in keywords:
        if w not in seen:
            seen.add(w)
            unique.append(w)

    return " ".join(unique[:4]) if unique else "celebration"


@router.get("/search")
async def search_photos(
    event_name: str = Query(..., min_length=1),
    event_description: str = Query(None),
    _auth_id: str = Depends(get_current_user),
):
    """Search Unsplash for cover photo suggestions based on event name."""
    api_key = settings.UNSPLASH_ACCESS_KEY
    if not api_key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Unsplash integration not configured",
        )

    query = _build_query(event_name, event_description)

    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(
                "https://api.unsplash.com/search/photos",
                params={
                    "query": query,
                    "per_page": 30,
                    "orientation": "landscape",
                },
                headers={"Authorization": f"Client-ID {api_key}"},
                timeout=10.0,
            )
            response.raise_for_status()
        except httpx.HTTPStatusError:
            # Fallback query on no results or error
            try:
                response = await client.get(
                    "https://api.unsplash.com/search/photos",
                    params={
                        "query": "social gathering",
                        "per_page": 30,
                        "orientation": "landscape",
                    },
                    headers={"Authorization": f"Client-ID {api_key}"},
                    timeout=10.0,
                )
                response.raise_for_status()
            except Exception:
                return {"photos": [], "query": query}
        except Exception:
            return {"photos": [], "query": query}

    data = response.json()
    results = data.get("results", [])

    # If no results, try fallback query
    if not results and query != "social gathering":
        try:
            async with httpx.AsyncClient() as fallback_client:
                fb_response = await fallback_client.get(
                    "https://api.unsplash.com/search/photos",
                    params={
                        "query": "celebration",
                        "per_page": 30,
                        "orientation": "landscape",
                    },
                    headers={"Authorization": f"Client-ID {api_key}"},
                    timeout=10.0,
                )
                fb_response.raise_for_status()
                data = fb_response.json()
                results = data.get("results", [])
        except Exception:
            pass

    photos = []
    for r in results:
        urls = r.get("urls", {})
        user = r.get("user", {})
        photos.append({
            "id": r.get("id"),
            "url_small": urls.get("small"),
            "url_regular": urls.get("regular"),
            "url_full": urls.get("full"),
            "photographer": user.get("name", "Unknown"),
            "photographer_url": user.get("links", {}).get("html", ""),
            "color": r.get("color"),
            "width": r.get("width"),
            "height": r.get("height"),
        })

    return {"photos": photos, "query": query}
