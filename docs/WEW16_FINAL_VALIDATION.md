# WEW-16 final validation

Date: September 16, 2026. Scope: session expiry, temporary outages, controlled reauthentication, and refresh/account races.

Dedicated simulator: **WeWere-WEW16-Validation-0916**, iOS 26.5, UDID `4F43E70A-8D0E-44C3-BEB5-4EBAA45ACB9F`. All app launches/restarts targeted this UDID. The Simulator window title was verified before interaction; other tasks' devices were not used.

Backend: `https://api-staging-staging-62e9.up.railway.app`; Supabase: `rmehfwdzxyrsdpvwgozm`. TEST1 and TEST2 were used. No production deployment, production account modification, or real SMS was performed.

## Results

| Scenario | Observed result | Status |
| --- | --- | --- |
| Fresh TEST1 login | Normal developer login button reached staging Home using live services. | Passed |
| Process termination/relaunch | Home restored; validation panel identified TEST1 with credentials saved. | Passed |
| Expired-access scheduling | Set local expiry metadata to the past; one real Supabase refresh and authenticated profile request succeeded. Both in-memory and Keychain credentials remained present. | Passed |
| Concurrent expiry | Ten live profile requests completed for the same account with exactly one real refresh request. | Passed |
| API 503 | Injected a server-error response; cached authenticated state and Keychain credentials survived. | Passed |
| Refresh 503 | Forced expiry while returning 503; credentials remained intact and recoveryError was set. | Passed |
| Offline startup with profile cache | Terminated/relaunched with API/auth transport returning URLError.notConnectedToInternet. Home and saved TEST1 identity remained available. | Passed |
| Reconnect with profile cache | Restored live transport and retried; profile fetch/refresh succeeded and recoveryError cleared. | Passed |
| Offline startup without profile cache | Removed only cached profile, retained credentials, forced expiry, and relaunched offline. Normal recovery screen appeared. Repeated Try again taps did not erase credentials. In-app check confirmed credentials persisted in Keychain. | Passed |
| Normal recovery-screen retry | Restored live transport, dismissed controls, and tapped the app's Try again. It showed Connecting, then returned to Home as TEST1 without another login. | Passed |
| Switch during refresh | Delayed delivery of a live refresh response, signed in as TEST2, awaited the old request and delay. Old request failed with accountChanged; UI and Keychain retained TEST2. | Passed |
| Sign out during refresh | Delayed live refresh, signed out, awaited the late-response window. Old request failed with accountChanged; credentials stayed absent in memory/Keychain. Relaunch stayed at phone entry. | Passed |
| Explicit invalid refresh | Injected Supabase-shaped HTTP 400 with numeric code and error_code=refresh_token_not_found. Credentials cleared in memory/Keychain, authenticated=false, recoveryError=false; normal phone entry appeared. Live reauthentication then succeeded. | Passed |
| Recovery-screen sign-out while offline | Recreated uncached offline startup, tapped Sign out and sign in again. Phone entry appeared; persisted credentials were absent. | Passed |

## Evidence and interpretation

The UI actions used the actual staging app's AuthService, APIClient, SessionCoordinator, and Keychain store. Success responses came from live staging. Failures and response delays were injected inside this app only by `StagingFaultProtocol`; the Mac's network was not disconnected. The local expiry test exercises the normal expiry branch without waiting for the signed token's wall-clock expiry or editing its signature. Invalid-refresh classification uses an injected provider-format response. Those are controlled fault tests, not claims of naturally occurring service outages.

Sanitized timestamped assertions are in `output/validation/wew16/session-validation.txt`. They contain no tokens, phone numbers, or account IDs. UI observations above additionally cover normal sign-in, Home, retry, and sign-out screens.

The 13 standalone session/API regression checks passed, including HTTP 401 retry limits, no mutation replay after 5xx, migration failures, refresh persistence failures, and cross-account rejection. Staging and production builds passed. Binary checks confirmed `StagingFaultProtocol`, `SessionValidationView`, and validation control labels are absent from production.

## Repeating the tests

Create your own uniquely named simulator, then run `./scripts/run.sh --env staging --sim "YOUR-UNIQUE-SIMULATOR"`. Open **Session tests** in the lower-right corner. The panel exists only in Debug staging simulator builds. Start with live mode and TEST1, then run the scenarios above. Network mode persists over relaunch intentionally; return it to **live** after testing.

The session acceptance criteria for WEW-16 are satisfied. This is not full-app or production release certification: camera hardware, photo uploads/library access, event lifecycle behavior, real OTP delivery, and the WEW-21 production security rollout remain separate validation scopes.
