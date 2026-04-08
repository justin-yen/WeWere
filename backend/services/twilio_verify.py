from twilio.rest import Client

from config import settings


def _get_client() -> Client:
    return Client(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)


def send_otp(phone_number: str) -> bool:
    """Send an OTP to the given phone number via Twilio Verify.

    Returns True if the verification was successfully created.
    """
    try:
        client = _get_client()
        verification = client.verify.v2.services(
            settings.TWILIO_VERIFY_SID
        ).verifications.create(to=phone_number, channel="sms")
        return verification.status == "pending"
    except Exception as e:
        print(f"Twilio send_otp error: {e}")
        raise


def verify_otp(phone_number: str, code: str) -> bool:
    """Verify an OTP code for the given phone number.

    Returns True if the code is valid.
    """
    try:
        client = _get_client()
        verification_check = client.verify.v2.services(
            settings.TWILIO_VERIFY_SID
        ).verification_checks.create(to=phone_number, code=code)
        return verification_check.status == "approved"
    except Exception:
        return False
