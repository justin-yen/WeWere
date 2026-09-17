# Stage 1: authentication and session recovery

Implemented locally and validated against staging Supabase and Railway. The staging simulator completed the WEW-16 session recovery journeys documented in `WEW16_FINAL_VALIDATION.md`. Real SMS delivery, edge-function job validation, password retirement, and production rollout remain open.

## Recovery behavior

| Scenario | Implementation |
| --- | --- |
| Access token expires | One shared refresh operation serves concurrent API and Supabase callers. The rotated token pair is written to Keychain together. |
| Authenticated API returns 401 | Refresh, then replay the original request once. A second 401 surfaces an error. |
| Network outage, timeout, rate limit, server error | Keep credentials. Retry on a later request, foreground activation, or explicit session recovery. Do not automatically replay writes after ambiguous failures. |
| Refresh session explicitly revoked/expired | Remove credentials and cached profile, retain the last account ID, and request sign-in. This code does not delete pending work. |
| Sign-out/account switch during refresh or API request | Generation checks reject late completions; they cannot reinstall the old session. Shared photo caches are cleared and late cache writes are guarded. |
| Keychain unavailable during migration | Keep the UserDefaults tokens until a Keychain write succeeds. Retry recovery later. |
| Keychain write fails after server rotates a token | Retain the new token in memory and retry persistence before the next authenticated request. Process death before persistence can still require sign-in. |
| Profile service unavailable after OTP success | Save the valid session, then recover the profile separately. An outage does not imply a new account. |
| Relaunch during profile setup | A confirmed profile 404 resumes onboarding. The backend uses the verified identity's phone number. |

`SessionCoordinator` owns credentials for both APIClient and Supabase. The Supabase SDK's independent automatic refresh is disabled. Keychain uses `AfterFirstUnlockThisDeviceOnly`; tokens are no longer written to UserDefaults. Token payload decoding on iOS is for scheduling only, not authorization.

Backend authorization verifies signature, expiry, issued-at, issuer, audience, and UUID subject. It supports the configured legacy HS256 secret and project JWKS ES256/RS256 keys. JWKS connection failure returns 503 rather than invalidating a session.

Twilio-verified sign-in uses a server-generated one-time Supabase link exchange through a separate anonymous client. The privileged admin client cannot be mutated by user sign-in. Existing synthetic email identities and auth UUIDs are preserved. Predictable passwords are replaced with random secrets once, tracked in admin-controlled app metadata.

## Local validation

- `./scripts/test-session-reliability.sh`: compiles the production session coordinator, API client, and user model with fake configuration; runs 13 checks covering refresh coordination, outages, invalidation, account races, migration failures, persistence failures, and retry limits. Numeric Supabase error codes are covered alongside string machine-readable codes.
- `python -m pytest backend/tests -q` in an environment installed from `backend/requirements.txt` plus pytest: signature/claim validation, disabled developer routes, internal credentials, OTP exchange isolation, and provider outage behavior.
- `./scripts/run.sh --build-only`: simulator compilation of the complete app.

Tests use fake identities and mocked network providers. They do not validate real SMS delivery, Supabase project settings, physical-device Keychain behavior, or deployed edge functions. Deno is not installed in the local environment, so edge runtime execution remains a staging check.

## Rollout order

1. Validate on a staging Supabase project with the same auth configuration as production. Confirm new and existing Twilio-verified users receive usable access/refresh tokens through `generate_link` + `verify_otp`; check email auth is enabled. Confirm an existing user's UUID, profile, memberships, and photos remain unchanged, including after password rotation. Verify refresh after restarting the app and after an outage.
2. Configure the backend's matching `SUPABASE_URL`, anonymous key, service role key, and (if HS256 tokens remain active) `SUPABASE_JWT_SECRET`. Production must use `APP_ENV=production` and `ENABLE_TEST_ENDPOINTS=false`. Development test routes require both `APP_ENV=development` and `ENABLE_TEST_ENDPOINTS=true`.
3. Generate a strong server-only `INTERNAL_API_KEY`. Configure it in both backend and Supabase function secrets. Configure cron jobs/webhooks/server callers to send `x-internal-api-key`, alongside any existing gateway Authorization header. The affected functions are `send-push`, `auto-end-events`, and `apply-retro-filter`; backend `/push/send` also requires it. Never include this key in the iOS app. Missing configuration intentionally rejects calls.
4. Deploy the passwordless backend and protected functions, coordinating caller header configuration so scheduled work is not interrupted. Smoke-test valid OTP login, invalid OTP rejection, authenticated profile access, blocked test routes, and each internal job.
5. Run `python backend/scripts/retire_legacy_passwords.py` to preview the count of legacy identities. After reviewing against the intended environment, run with `--apply`. This preserves UUIDs and profile links; it may require users to authenticate again. Rerun the dry-run and expect zero remaining candidates. **Dormant accounts retain predictable passwords until this migration runs.** The script has not been run against a live project by this implementation.
6. Release the iOS update after staging recovery checks. Verify migration from a previous app installation, airplane-mode launch, expired access token, revoked refresh token, sign-out during refresh, and switching accounts. Confirm cron/push/filter jobs continue succeeding.

Do not roll back to the old predictable-password login implementation after password migration. Roll forward or retain the passwordless exchange when reverting unrelated changes. Never print tokens or one-time link hashes during diagnosis.

## Boundaries for later stages

This stage establishes session recovery. Durable photo/upload queues, mutation idempotency keys, reconciliation of uncertain writes, persistent account-scoped pending work, comprehensive offline caches, and server job retries remain separate roadmap work. A request already accepted by the server may finish after local sign-out; generation checks only prevent its late result from changing the new local session. Best-effort server logout cannot guarantee immediate revocation while offline.
