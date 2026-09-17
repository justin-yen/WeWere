from functools import lru_cache
from secrets import compare_digest
from uuid import UUID

import jwt
from fastapi import Depends, Header, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from starlette.concurrency import run_in_threadpool

from config import settings

_bearer_scheme = HTTPBearer(auto_error=False)


@lru_cache(maxsize=4)
def _jwks_client(url: str) -> jwt.PyJWKClient:
    return jwt.PyJWKClient(url, cache_jwk_set=True, lifespan=300, timeout=5)


def _verify_token(token: str) -> str:
    issuer = settings.SUPABASE_URL.rstrip('/') + '/auth/v1'
    algorithm = jwt.get_unverified_header(token).get('alg')
    if algorithm == 'HS256':
        if not settings.SUPABASE_JWT_SECRET:
            raise HTTPException(503, 'Authentication temporarily unavailable')
        key = settings.SUPABASE_JWT_SECRET
    elif algorithm in ('ES256', 'RS256'):
        key = _jwks_client(issuer + '/.well-known/jwks.json').get_signing_key_from_jwt(token).key
    else:
        raise jwt.InvalidAlgorithmError('Unsupported signing algorithm')
    payload = jwt.decode(
        token, key, algorithms=[algorithm], audience='authenticated', issuer=issuer,
        options={'require': ['exp', 'iat', 'sub', 'iss', 'aud']},
    )
    return str(UUID(payload['sub']))


async def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer_scheme),
) -> str:
    if credentials is None or credentials.scheme.lower() != 'bearer':
        raise HTTPException(401, 'Authentication required', headers={'WWW-Authenticate': 'Bearer'})
    try:
        return await run_in_threadpool(_verify_token, credentials.credentials)
    except jwt.PyJWKClientConnectionError:
        # A key-service outage is not evidence that the user's session is invalid.
        raise HTTPException(503, 'Authentication temporarily unavailable') from None
    except (jwt.PyJWTError, ValueError, TypeError, KeyError):
        raise HTTPException(401, 'Invalid or expired token', headers={'WWW-Authenticate': 'Bearer'}) from None


def require_development():
    if settings.APP_ENV != 'development' or not settings.ENABLE_TEST_ENDPOINTS:
        raise HTTPException(404, 'Not found')


def require_internal_key(x_internal_api_key: str | None = Header(default=None)):
    if not settings.INTERNAL_API_KEY or not x_internal_api_key or not compare_digest(
        x_internal_api_key, settings.INTERNAL_API_KEY
    ):
        raise HTTPException(403, 'Forbidden')
