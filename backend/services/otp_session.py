"""Exchange verified Twilio ownership for a Supabase session without shared passwords."""
import secrets

from services.supabase import get_auth_client

PASSWORD_MIGRATION = 'wewere_password_v2'


def retire_legacy_password(client, user):
    """Preserve the auth UUID/profile links; replace predictable passwords once."""
    metadata = dict(user.app_metadata or {})
    if metadata.get(PASSWORD_MIGRATION):
        return False
    metadata[PASSWORD_MIGRATION] = True
    client.auth.admin.update_user_by_id(str(user.id), {
        'password': secrets.token_urlsafe(48), 'app_metadata': metadata,
    })
    return True


def session_for_verified_email(client, email: str, phone: str | None = None):
    # generate_link resolves an existing identity or creates one. Nothing is emailed.
    link = client.auth.admin.generate_link({'type': 'magiclink', 'email': email})
    password_changed = retire_legacy_password(client, link.user)
    if phone is not None:
        client.auth.admin.update_user_by_id(str(link.user.id), {
            'phone': phone, 'phone_confirm': True,
        })
    # Auth identity updates can invalidate the link minted above. Mint the
    # exchange token only after those updates have completed.
    if password_changed or phone is not None:
        link = client.auth.admin.generate_link({'type': 'magiclink', 'email': email})
    result = get_auth_client().auth.verify_otp({
        'token_hash': link.properties.hashed_token,
        'type': link.properties.verification_type,
    })
    if result.session is None:
        raise RuntimeError('Session exchange did not return a session')
    return result.session
