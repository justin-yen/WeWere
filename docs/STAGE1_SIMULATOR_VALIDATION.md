# Stage 1 simulator validation — September 12, 2026

Environment: iPhone 17 Pro Max, iOS 26.5 simulator; local Debug iOS build; existing deployed Railway API and Supabase project. Backend changes were not deployed during this run. No real SMS was sent and no bulk password migration was executed.

## Observed journeys

| Journey | Result | Evidence |
| --- | --- | --- |
| Start app with saved credentials | Fixed, then passed | Initial Keychain access failed with OSStatus -34018. Simulator builds disabled signing. Ad-hoc simulator signing removed this failure. |
| Recover an unusable refresh token | Fixed, then passed | Supabase returned HTTP 400 with numeric `code` and string `error_code=refresh_token_already_used`. Decoder previously rejected the whole error object. After the fix, the app returned to phone entry instead of looping on retry. |
| Sign in as existing TEST1 | Passed | Clicked TEST1; Home loaded three live events. Profile showed Test User TEST1. |
| Restore signed-in session after process termination | Passed | Terminated and relaunched without clearing app data. Home loaded; Profile still showed TEST1. |
| Sign out | Passed | Confirmed Profile → Sign Out; app returned to phone entry. |
| Remain signed out after process termination | Passed | Relaunch stayed at phone entry; old account did not return. |
| Switch from TEST1 to TEST2 | Blocked by deployed backend | TEST2 returned HTTP 500: `Session from session_id claim in JWT does not exist`. The deployed test-login error uses the old implementation, not the new local passwordless helper. |
| Real SMS, wrong code, resend, new-user onboarding | Pending | Requires a designated test phone number and verification code. |
| Outage and concurrent-refresh races | Automated coverage only | The standalone checks simulate transport errors and races. No device-wide network outage or concurrent-refresh race was manually induced in the simulator. |

## Changes made during validation

- `scripts/run.sh` now ad-hoc signs simulator builds so Keychain access works.
- Refresh error parsing tolerates a numeric `code` while reading `error_code`. Regression coverage uses Supabase's observed response shape.
- The session recovery screen has an explicit “Sign out and sign in again” action. It leaves ordinary retries nondestructive. The new exit itself remains to be exercised under an induced transient outage.
- Explicit sign-out before restoration now retires legacy UserDefaults tokens and marks the coordinator restored. A regression check covers this case.
- Session recovery logs contain only error domains/status codes, not tokens or provider response bodies.

## Automated results

- 13 standalone Swift session/API checks passed.
- 26 backend checks passed.
- Full simulator build/install/launch passed with ad-hoc signing.

## Remaining validation

Deploy the Stage 1 backend to a designated test environment following `STAGE1_RELIABILITY.md`, then repeat switching between test accounts and validate Twilio-to-Supabase login. Use a designated phone for OTP/onboarding. Still exercise temporary outages, the explicit recovery exit, and device Keychain behavior before treating Stage 1 as release-validated.
