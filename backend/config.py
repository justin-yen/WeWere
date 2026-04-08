import os
from dotenv import load_dotenv

load_dotenv()


class Settings:
    """Application settings loaded from environment variables."""

    SUPABASE_URL: str = os.getenv("SUPABASE_URL", "")
    SUPABASE_SERVICE_ROLE_KEY: str = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
    SUPABASE_ANON_KEY: str = os.getenv("SUPABASE_ANON_KEY", "")
    SUPABASE_JWT_SECRET: str = os.getenv("SUPABASE_JWT_SECRET", "")

    TWILIO_ACCOUNT_SID: str = os.getenv("TWILIO_ACCOUNT_SID", "")
    TWILIO_AUTH_TOKEN: str = os.getenv("TWILIO_AUTH_TOKEN", "")
    TWILIO_VERIFY_SID: str = os.getenv("TWILIO_VERIFY_SID", "")

    APNS_KEY_ID: str = os.getenv("APNS_KEY_ID", "")
    APNS_TEAM_ID: str = os.getenv("APNS_TEAM_ID", "")
    APNS_KEY_PATH: str = os.getenv("APNS_KEY_PATH", "")
    APP_BUNDLE_ID: str = os.getenv("APP_BUNDLE_ID", "com.wewere.app")

    GOOGLE_PLACES_API_KEY: str = os.getenv("GOOGLE_PLACES_API_KEY", "")


settings = Settings()
