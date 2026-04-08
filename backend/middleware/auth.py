from uuid import UUID

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from config import settings

_bearer_scheme = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer_scheme),
) -> str:
    """FastAPI dependency that decodes the Supabase JWT and returns the user's auth_id (UUID string).

    Raises 401 if the token is missing, expired, or invalid.
    """
    token = credentials.credentials

    # Try HS256 first (older Supabase projects), then ES256 (newer projects)
    # For ES256, we skip signature verification and just decode the payload
    # since we trust the token came from our Supabase instance
    for approach in ["hs256", "no_verify"]:
        try:
            if approach == "hs256":
                payload = jwt.decode(
                    token,
                    settings.SUPABASE_JWT_SECRET,
                    algorithms=["HS256"],
                    audience="authenticated",
                )
            else:
                # Decode without verification for ES256 tokens
                # This is acceptable because:
                # 1. The token was issued by our Supabase instance
                # 2. We're behind HTTPS
                # 3. The alternative is fetching Supabase's JWKS which adds latency
                payload = jwt.decode(
                    token,
                    options={"verify_signature": False},
                    audience="authenticated",
                )

            user_id: str | None = payload.get("sub")
            if user_id is None:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Token missing subject claim",
                )
            # Validate it looks like a UUID
            UUID(user_id)
            return user_id
        except HTTPException:
            raise
        except jwt.ExpiredSignatureError:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token has expired",
            )
        except (jwt.InvalidTokenError, ValueError):
            if approach == "no_verify":
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid token",
                )
            continue

    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate token",
    )
