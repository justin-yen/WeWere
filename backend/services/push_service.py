import json
import time
from typing import Optional

import httpx
import jwt

from config import settings


def _build_apns_token() -> str:
    """Build a short-lived JWT for APNs authentication."""
    with open(settings.APNS_KEY_PATH, "r") as f:
        private_key = f.read()

    headers = {
        "alg": "ES256",
        "kid": settings.APNS_KEY_ID,
    }
    payload = {
        "iss": settings.APNS_TEAM_ID,
        "iat": int(time.time()),
    }
    return jwt.encode(payload, private_key, algorithm="ES256", headers=headers)


async def send_push_notification(
    device_token: str,
    title: str,
    body: str,
    data: Optional[dict] = None,
    badge: Optional[int] = None,
) -> bool:
    """Send a push notification via APNs HTTP/2.

    Returns True if the notification was accepted.
    """
    try:
        apns_token = _build_apns_token()

        apns_payload: dict = {
            "aps": {
                "alert": {
                    "title": title,
                    "body": body,
                },
                "sound": "default",
            }
        }
        if badge is not None:
            apns_payload["aps"]["badge"] = badge
        if data:
            apns_payload["data"] = data

        # Use production APNs endpoint
        url = f"https://api.push.apple.com/3/device/{device_token}"

        headers = {
            "authorization": f"bearer {apns_token}",
            "apns-topic": settings.APP_BUNDLE_ID,
            "apns-push-type": "alert",
            "apns-priority": "10",
        }

        async with httpx.AsyncClient(http2=True) as client:
            response = await client.post(
                url,
                headers=headers,
                content=json.dumps(apns_payload),
            )
            return response.status_code == 200
    except Exception:
        return False


async def send_push_to_tokens(
    tokens: list[str],
    title: str,
    body: str,
    data: Optional[dict] = None,
) -> int:
    """Send push notifications to multiple device tokens.

    Returns the number of successful sends.
    """
    success_count = 0
    for token in tokens:
        if await send_push_notification(token, title, body, data):
            success_count += 1
    return success_count
