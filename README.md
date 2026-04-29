# WeWere

A disposable film camera app for iOS. Create events, invite friends, and take photos — but nobody sees them until the event ends and each person "develops their film." Photos get a retro filter applied automatically, and the full album becomes a shared keepsake.

## Tech Stack

- **iOS**: Swift 5.9, SwiftUI, iOS 17+
- **Backend**: Python/FastAPI, hosted on Railway
- **Database**: Supabase (Postgres + Storage + Realtime + Edge Functions)
- **Auth**: Phone OTP via Twilio Verify

## Getting Started

### Prerequisites

- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- Python 3.11+ (for backend)
- Supabase CLI (for local development)

### iOS App

```bash
# Generate the Xcode project
xcodegen generate --spec project.yml

# Copy secrets template and fill in your values
cp WeWere/Secrets.template.swift WeWere/Secrets.swift

# Open in Xcode and build
open WeWere.xcodeproj
```

> **Note**: Run `xcodegen generate --spec project.yml` after adding or removing Swift files.

### Backend

```bash
cd backend

# Install dependencies
pip install -r requirements.txt

# Copy .env and fill in values (Supabase, Twilio, Unsplash keys)
cp .env.example .env

# Run locally
uvicorn main:app --reload --port 8000

# Deploy to Railway
railway up
```

### Database

Run SQL migrations in order via Supabase Dashboard > SQL Editor:

```
supabase/migrations/001_initial_schema.sql
supabase/migrations/002_user_profile_fields.sql
supabase/migrations/003_event_location.sql
supabase/migrations/004_update_reaction_emojis.sql
supabase/migrations/005_event_cover_photo.sql
supabase/migrations/006_nullable_auth_id.sql
```

## Project Structure

```
WeWere/
├── WeWere/              # iOS app
│   ├── App/             # Entry point, AppState, RootView
│   ├── Design/          # Theme, reusable components
│   ├── Features/        # Feature modules (Home, Camera, Album, etc.)
│   ├── Models/          # Data models
│   ├── Services/        # API client, auth, events, photos
│   ├── Repositories/    # Offline upload queue
│   └── Utilities/       # RetroFilter, image utils
├── backend/             # FastAPI backend
│   ├── routers/         # API endpoints
│   ├── middleware/       # JWT auth
│   ├── models/          # Pydantic schemas
│   └── services/        # Supabase, Twilio, storage
├── supabase/            # Database migrations & edge functions
└── project.yml          # XcodeGen project definition
```
