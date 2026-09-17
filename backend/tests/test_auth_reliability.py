import asyncio
import time
from types import SimpleNamespace as NS
from unittest.mock import Mock
from uuid import uuid4

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import ec, rsa
from fastapi.testclient import TestClient
from main import app
from middleware import auth
from services import otp_session
from routers import auth as routes

client = TestClient(app)
SUBJECT = str(uuid4())


def claims(**overrides):
    return dict(sub=SUBJECT, iss=auth.settings.SUPABASE_URL + '/auth/v1', aud='authenticated', iat=int(time.time()), exp=int(time.time()) + 3600, **overrides)


def token(payload=None, key='test-signing-secret', algorithm='HS256'):
    return jwt.encode(payload or claims(), key, algorithm=algorithm)


def check(value):
    from fastapi.security import HTTPAuthorizationCredentials
    return asyncio.run(auth.get_current_user(HTTPAuthorizationCredentials(scheme='Bearer', credentials=value)))


def test_valid_legacy_token():
    assert check(token()) == SUBJECT


@pytest.mark.parametrize('field,value', [('exp', 1), ('iss', 'https://wrong.example/auth/v1'), ('aud', 'anon'), ('sub', 'not-a-uuid'), ('iat', int(time.time())+99999)])
def test_invalid_claims_rejected(field, value):
    payload = claims(); payload[field] = value
    with pytest.raises(auth.HTTPException) as exc: check(token(payload))
    assert exc.value.status_code == 401


@pytest.mark.parametrize('field', ['exp', 'iat', 'iss', 'aud', 'sub'])
def test_required_claims(field):
    payload = claims(); del payload[field]
    with pytest.raises(auth.HTTPException) as exc: check(token(payload))
    assert exc.value.status_code == 401


@pytest.mark.parametrize('value', [token(key='attacker'), jwt.encode(claims(), '', algorithm='none'), 'broken'])
def test_forged_and_malformed_tokens_rejected(value):
    with pytest.raises(auth.HTTPException) as exc: check(value)
    assert exc.value.status_code == 401


@pytest.mark.parametrize('algorithm', ['ES256', 'RS256'])
def test_asymmetric_signatures_are_verified(monkeypatch, algorithm):
    key = ec.generate_private_key(ec.SECP256R1()) if algorithm == 'ES256' else rsa.generate_private_key(public_exponent=65537, key_size=2048)
    monkeypatch.setattr(auth, '_jwks_client', lambda _: NS(get_signing_key_from_jwt=lambda _: NS(key=key.public_key())))
    assert check(token(key=key, algorithm=algorithm)) == SUBJECT
    other = ec.generate_private_key(ec.SECP256R1()) if algorithm == 'ES256' else rsa.generate_private_key(public_exponent=65537, key_size=2048)
    with pytest.raises(auth.HTTPException) as exc: check(token(key=other, algorithm=algorithm))
    assert exc.value.status_code == 401


def test_jwks_outage_is_recoverable_503(monkeypatch):
    def unavailable(_): raise jwt.PyJWKClientConnectionError('offline')
    monkeypatch.setattr(auth, '_jwks_client', lambda _: NS(get_signing_key_from_jwt=unavailable))
    key = ec.generate_private_key(ec.SECP256R1())
    with pytest.raises(auth.HTTPException) as exc: check(token(key=key, algorithm='ES256'))
    assert exc.value.status_code == 503


def test_missing_auth_returns_401():
    assert client.get('/profiles/me').status_code == 401


def test_development_routes_fail_closed(monkeypatch):
    assert client.post('/auth/test-login', json={'test_id': 'test1'}).status_code == 404
    assert client.post(f'/test/events/{uuid4()}/populate-attendees').status_code == 404
    monkeypatch.setattr(auth.settings, 'ENABLE_TEST_ENDPOINTS', True)
    assert client.post('/auth/test-login', json={'test_id': 'test1'}).status_code == 404
    monkeypatch.setattr(auth.settings, 'APP_ENV', 'development')
    auth.require_development()


def test_push_requires_server_secret(monkeypatch):
    body = {'event_id': str(uuid4()), 'type': 'event_ended', 'message': 'test'}
    assert client.post('/push/send', json=body).status_code == 403
    monkeypatch.setattr(auth.settings, 'INTERNAL_API_KEY', 'server-only')
    assert client.post('/push/send', json=body, headers={'x-internal-api-key': 'wrong'}).status_code == 403
    auth.require_internal_key('server-only')


def test_passwordless_exchange_preserves_identity_and_isolates_clients(monkeypatch):
    admin = Mock(); public = Mock()
    user = NS(id=SUBJECT, app_metadata={'existing': True})
    admin.auth.admin.generate_link.return_value = NS(user=user, properties=NS(hashed_token='one-time-hash', verification_type='magiclink'))
    public.auth.verify_otp.return_value = NS(session=NS(user=user))
    monkeypatch.setattr(otp_session, 'get_auth_client', lambda: public)
    result = otp_session.session_for_verified_email(admin, '15550000000@wewere.phone', '+15550000000')
    assert result.user.id == SUBJECT
    admin.auth.verify_otp.assert_not_called()
    admin.auth.sign_in_with_password.assert_not_called()
    public.auth.verify_otp.assert_called_once_with({'token_hash': 'one-time-hash', 'type': 'magiclink'})
    args = admin.auth.admin.update_user_by_id.call_args_list[0].args
    assert args[0] == SUBJECT and len(args[1]['password']) >= 48
    assert args[1]['app_metadata']['existing']


def test_password_migration_is_repeatable():
    admin = Mock()
    user = NS(id=SUBJECT, app_metadata={otp_session.PASSWORD_MIGRATION: True})
    assert not otp_session.retire_legacy_password(admin, user)
    admin.auth.admin.update_user_by_id.assert_not_called()


def test_identity_update_uses_fresh_exchange_link(monkeypatch):
    admin = Mock(); public = Mock()
    user = NS(id=SUBJECT, app_metadata={})
    admin.auth.admin.generate_link.side_effect = [
        NS(user=user, properties=NS(hashed_token='invalidated', verification_type='magiclink')),
        NS(user=user, properties=NS(hashed_token='fresh', verification_type='magiclink')),
    ]
    monkeypatch.setattr(otp_session, 'get_auth_client', lambda: public)
    otp_session.session_for_verified_email(admin, 'new@wewere.test')
    public.auth.verify_otp.assert_called_once_with({'token_hash': 'fresh', 'type': 'magiclink'})


def test_invalid_twilio_code_never_exchanges_session(monkeypatch):
    exchange = Mock()
    monkeypatch.setattr(routes, 'verify_otp', lambda *args: False)
    monkeypatch.setattr(routes, 'session_for_verified_email', exchange)
    response = client.post('/auth/verify-otp', json={'phone_number': '+15550000000', 'code': '123456'})
    assert response.status_code == 401
    exchange.assert_not_called()


def test_profile_outage_returns_session_for_recovery(monkeypatch):
    db = Mock(); db.table.side_effect = RuntimeError('database unavailable')
    monkeypatch.setattr(routes, 'verify_otp', lambda *args: True)
    monkeypatch.setattr(routes, 'get_client', lambda: db)
    monkeypatch.setattr(routes, 'session_for_verified_email', lambda *args: NS(access_token='access', refresh_token='refresh', user=NS(id=SUBJECT)))
    response = client.post('/auth/verify-otp', json={'phone_number': '+15550000000', 'code': '123456'})
    assert response.status_code == 200
    assert response.json()['needs_profile'] is False
    assert response.json()['refresh_token'] == 'refresh'


def test_twilio_outage_is_503_without_provider_details(monkeypatch):
    def unavailable(*args):
        raise RuntimeError('private provider diagnostics')
    monkeypatch.setattr(routes, 'verify_otp', unavailable)
    response = client.post('/auth/verify-otp', json={'phone_number': '+15550000000', 'code': '123456'})
    assert response.status_code == 503
    assert 'private provider' not in response.text


def test_verify_rejects_noncanonical_phone():
    response = client.post('/auth/verify-otp', json={'phone_number': '555-000-0000', 'code': '123456'})
    assert response.status_code == 422
