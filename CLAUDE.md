# WeWere

## What is WeWere?
WeWere is a disposable film camera iOS app. Users create events, invite friends via deep links, and take photos during the event -- but nobody can see the photos until the event ends and they "develop the film." Photos get a Portra 400 retro filter applied client-side before upload. After developing, users browse a shared gallery with emoji reactions, comments, and a polaroid-style "Past Moments" photo stack on the home screen.

## Architecture

### iOS App (Swift/SwiftUI, iOS 17+)
- **Location:** `/WeWere/`
- **Pattern:** MVVM with shared view models across tabs
- **Key files:**
  - `App/RootView.swift` -- Tab-based root with NavigationStack per tab
  - `App/AppState.swift` -- Global navigation state, Route enum, deep link handling
  - `Services/APIClient.swift` -- Centralized HTTP client pointing to Railway backend
  - `Services/AuthService.swift` -- Phone OTP auth via backend (Twilio Verify)
  - `Services/EventService.swift` -- Event CRUD, returns EventWithCounts from backend
  - `Features/Home/SharedEventsViewModel.swift` -- Shared across Home and Events tabs
  - `Features/Home/PhotoStackView.swift` -- Swipeable polaroid card stack
  - `Utilities/RetroFilter.swift` -- Portra 400 Core Image filter pipeline
  - `Design/Theme.swift` -- All color tokens, fonts (ClashDisplay, PlusJakartaSans, SpaceGrotesk), spacing

### Python Backend (FastAPI)
- **Location:** `/backend/`
- **Deployed:** Railway at `https://api-production-77f0.up.railway.app`
- **Key files:**
  - `routers/auth.py` -- Phone OTP via Twilio Verify, passwordless Supabase session exchange; development-only test login
  - `routers/events.py` -- CRUD, join, end, develop. Uses `auth_id` → `_get_internal_user_id()` for all queries
  - `routers/photos.py` -- Upload, list with signed URLs, count, peak time, comments
  - `routers/feed.py` -- `/feed/random-photos` endpoint for the home photo stack (single call, batch signed URLs)
  - `routers/places.py` -- Google Places Autocomplete proxy for location search
  - `routers/reactions.py` -- Emoji reactions with user info for long-press display
  - `middleware/auth.py` -- Verified HS256 or JWKS-backed ES256/RS256 JWT authentication

### Supabase
- **Project:** `xsvscfqnzybdxptijmqs`
- **Tables:** users, events, event_members, photos, reactions, comments
- **Storage:** `event-photos` bucket (private, signed URLs)
- **Key pattern:** `users.id` is internal UUID, `users.auth_id` links to Supabase auth. All backend queries resolve `auth_id` → internal `id` via `_get_internal_user_id()`.
- **RLS:** Uses `public.current_user_id()` SECURITY DEFINER function to avoid recursive policy lookups on the users table.

## Common Gotchas
- **`auth_id` vs `id`:** The Supabase auth user UUID (`sub` claim in JWT) is NOT the same as `users.id`. Every backend endpoint must call `_get_internal_user_id(client, auth_id)` first.
- **Date decoding:** Supabase returns ISO 8601 strings. The SupabaseManager configures a custom decoder. The APIClient also has its own ISO 8601 decoder.
- **Entitlements:** Personal dev team doesn't support Associated Domains or Push Notifications. The `project.yml` has no entitlements section. Don't add one or xcodegen will break builds.
- **xcodegen:** Run `xcodegen generate --spec project.yml` after adding/removing Swift files. The `.xcodeproj` is gitignored.
- **Secrets:** iOS production secrets are in `WeWere/Secrets.swift`, staging secrets in `WeWere/StagingSecrets.swift` (both gitignored). Backend secrets are in `.env` and Railway environment variables.
- **Twilio:** Uses Verify (not raw SMS). Existing synthetic email identities follow `{digits}@wewere.phone`. Sessions use a one-time Supabase link exchange; predictable legacy passwords must be retired using `backend/scripts/retire_legacy_passwords.py` after reviewing the target environment.
- **Signed URLs:** Photos in Supabase Storage are private. The backend generates signed URLs (1hr expiry) via `get_signed_urls()` batch call.
- **Photo orientation:** Camera captures are normalized via `RetroFilter.normalizeOrientation()` before filter application. `videoRotationAngle = 90` is set on the capture connection.

## Design System
- **Theme:** Dark only. Surface `#131313`, on-surface `#e2e2e2`.
- **Fonts:** ClashDisplay-Semibold (brand/headers), PlusJakartaSans (body), SpaceGrotesk (labels/metadata)
- **Buttons:** "Brushed chrome" = LinearGradient white→#d4d4d4, text in #1a1c1c
- **No borders:** Use tonal layering (surface container hierarchy) for depth
- **Stitch project ID:** `10757421569687931481` (Google Stitch, has all screen designs)

## Deploy
- **Simulator ownership:** Every task using a simulator creates and boots its own uniquely named device. Record its name and UDID, pass its name with `scripts/run.sh --sim`, and target the explicit UDID for all `simctl` commands. Never use another task's device.
- **Backend:** `cd backend && railway up`
- **iOS:** Use `./scripts/run.sh --env staging --sim "YOUR-DEVICE"` for staging or `--env production` for production. See `docs/APP_ENVIRONMENTS.md`.
- **DB migrations:** Paste SQL in Supabase Dashboard > SQL Editor
