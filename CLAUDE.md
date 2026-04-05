# WeWere

Disposable-camera-style iOS app for event photography. Attendees take photos during an event but can't see them until the host ends the event and each user "develops" their film.

## Quick Reference

- **PRD**: `PRD.md` — product requirements and feature specs
- **TDD**: `TDD.md` — technical design, architecture, data models
- **Xcode project**: generated via XcodeGen from `project.yml`

## Tech Stack

- **iOS**: Swift 5.9, SwiftUI, iOS 17+, iPhone only, dark mode only
- **Backend**: Supabase (Auth, Postgres with RLS, Storage, Edge Functions, Realtime)
- **Auth**: Phone number + SMS OTP via Twilio Verify → Supabase Auth session
- **Camera**: AVFoundation
- **Photo filter**: CoreImage client-side (Kodak Gold 200 aesthetic), plus server-side edge function
- **Offline queue**: SwiftData for upload retries
- **Dependencies**: `supabase-swift` 2.0+ (sole SPM dependency)

## Project Structure

```
WeWere/
├── WeWere/              # iOS app source
│   ├── App/             # Entry point, AppState, AppDelegate, RootView
│   ├── Design/          # Theme.swift (colors, fonts, spacing), reusable components
│   ├── Features/        # Feature modules, each with View + ViewModel
│   │   ├── Auth/        # Phone OTP sign-in, profile setup
│   │   ├── Home/        # Event list (live + past sections)
│   │   ├── Camera/      # Photo capture with AVFoundation
│   │   ├── CreateEvent/ # Event creation form
│   │   ├── JoinEvent/   # Join via share code
│   │   ├── EventDetail/ # Event info, attendee list, end controls
│   │   ├── DevelopFilm/ # "Develop your film" reveal flow
│   │   ├── Album/       # Photo grid gallery
│   │   ├── PhotoDetail/ # Full-screen photo, reactions, save
│   │   └── Profile/     # User profile
│   ├── Models/          # Codable data models (Event, Photo, User, etc.)
│   ├── Services/        # Backend integration (AuthService, EventService, PhotoService, etc.)
│   ├── Repositories/    # UploadQueue (SwiftData offline queue)
│   └── Utilities/       # RetroFilter, ImageCompressor, HapticManager
├── supabase/
│   ├── migrations/      # Postgres schema migrations (001–003)
│   ├── functions/       # Edge functions (apply-retro-filter, auto-end-events, send-push)
│   └── config.toml
├── project.yml          # XcodeGen project definition
├── PRD.md
└── TDD.md
```

## Architecture

- **MVVM**: Each feature has a SwiftUI View paired with an `@Observable` ViewModel
- **Services**: Singletons that wrap Supabase client calls (AuthService, EventService, PhotoService, ReactionService)
- **SupabaseManager**: Shared singleton at `Services/SupabaseManager.swift` — holds the configured `SupabaseClient`
- **AppState**: Global state for auth status and navigation routing

## Key Patterns

- ViewModels are `@MainActor` and `@Observable`
- Supabase queries use typed Codable models for insert/select
- Date encoding/decoding uses ISO8601 with fractional seconds
- Photos upload as HEIC to Supabase Storage, edge function converts to filtered JPEG
- Event joining uses a 6-character alphanumeric share code (not the event ID)
- Realtime subscriptions for live photo counts and event status changes

## Database Tables

- `users` — profile info, push token, auth_id
- `events` — name, description, location, start/end time (end nullable), status, share_code
- `event_members` — links users to events with role (host/attendee), has_developed flag
- `photos` — storage paths for original + filtered, dimensions
- `reactions` — emoji reactions on photos (unique per user+photo+emoji)

## Build & Run

```bash
# Regenerate Xcode project after changing project.yml
xcodegen generate

# Run Supabase locally
supabase start

# Deploy edge functions
supabase functions deploy apply-retro-filter
supabase functions deploy auto-end-events
supabase functions deploy send-push
```

## Design System

- Dark-only theme — all colors defined in `Theme.swift` via hex values
- Typography: Plus Jakarta Sans (body), Space Grotesk (headings), Clash Display (display)
- Custom components: FilmGrainOverlay, BrushedChromeButton, DarkroomGlow, NoirDivider, TabBar
- Retro/darkroom aesthetic throughout

## Current Status

Core flows are implemented: auth → create/join event → camera capture → filter → develop → album → reactions. See PRD.md "Open Questions" for unresolved decisions.
