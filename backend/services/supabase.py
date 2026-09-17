from supabase import create_client, Client, ClientOptions

from config import settings

_client: Client | None = None


def get_client() -> Client:
    """Return a singleton Supabase client using the service role key."""
    global _client
    if _client is None:
        _client = create_client(
            settings.SUPABASE_URL,
            settings.SUPABASE_SERVICE_ROLE_KEY,
            options=ClientOptions(persist_session=False, auto_refresh_token=False),
        )
    return _client


def get_auth_client() -> Client:
    """Request-local client: signing in must never change the admin client's bearer token."""
    return create_client(
        settings.SUPABASE_URL, settings.SUPABASE_ANON_KEY,
        options=ClientOptions(persist_session=False, auto_refresh_token=False),
    )
