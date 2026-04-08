import uuid
from datetime import timedelta

from services.supabase import get_client


PHOTO_BUCKET = "event-photos"
AVATAR_BUCKET = "event-photos"  # avatars stored in same bucket under avatars/ prefix


def upload_photo(event_id: str, user_id: str, file_bytes: bytes, content_type: str) -> str:
    """Upload a photo to Supabase storage and return the storage path."""
    client = get_client()
    file_ext = "jpg" if "jpeg" in content_type or "jpg" in content_type else "png"
    file_name = f"{uuid.uuid4().hex}.{file_ext}"
    storage_path = f"events/{event_id}/{file_name}"

    client.storage.from_(PHOTO_BUCKET).upload(
        path=storage_path,
        file=file_bytes,
        file_options={"content-type": content_type},
    )
    return storage_path


def upload_avatar(user_id: str, file_bytes: bytes, content_type: str) -> str:
    """Upload an avatar image to Supabase storage and return the storage path."""
    client = get_client()
    file_ext = "jpg" if "jpeg" in content_type or "jpg" in content_type else "png"
    storage_path = f"avatars/{user_id}.{file_ext}"

    # Upsert: try to remove old avatar first (ignore errors)
    try:
        client.storage.from_(PHOTO_BUCKET).remove([storage_path])
    except Exception:
        pass

    client.storage.from_(PHOTO_BUCKET).upload(
        path=storage_path,
        file=file_bytes,
        file_options={"content-type": content_type, "upsert": "true"},
    )
    return storage_path


def get_signed_url(storage_path: str, expires_in: int = 3600) -> str:
    """Generate a signed URL for a storage object."""
    client = get_client()
    result = client.storage.from_(PHOTO_BUCKET).create_signed_url(
        path=storage_path,
        expires_in=expires_in,
    )
    return result.get("signedURL", "") if isinstance(result, dict) else ""


def get_signed_urls(storage_paths: list[str], expires_in: int = 3600) -> dict[str, str]:
    """Generate signed URLs for multiple storage objects."""
    if not storage_paths:
        return {}
    client = get_client()
    results = client.storage.from_(PHOTO_BUCKET).create_signed_urls(
        paths=storage_paths,
        expires_in=expires_in,
    )
    url_map: dict[str, str] = {}
    if isinstance(results, list):
        for item in results:
            path = item.get("path", "")
            url = item.get("signedURL", "")
            if path and url:
                url_map[path] = url
    return url_map
