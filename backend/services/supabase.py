from supabase import create_client, Client

from config import settings

_client: Client | None = None


def get_client() -> Client:
    """Return a singleton Supabase client using the service role key."""
    global _client
    if _client is None:
        _client = create_client(
            settings.SUPABASE_URL,
            settings.SUPABASE_SERVICE_ROLE_KEY,
        )
    return _client
