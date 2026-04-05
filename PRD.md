# WeWere - Product Requirements Document

## Overview

**WeWere** is an iOS app that turns event photography into a shared, surprise experience — mimicking the magic of disposable film cameras. Attendees take photos during an event, but nobody sees them until the event ends. When the host marks the event as over, everyone gets notified that their "film" is ready to develop. Photos are revealed with a retro film filter, and the full album becomes a shared keepsake.

## Problem Statement

Modern smartphone photography kills spontaneity at events. People curate, retake, and review every shot — then never look at them again. The best event memories come from candid, in-the-moment photos that you discover later, but there's no product that recreates the anticipation and surprise of getting disposable camera film developed.

## Target Users

- **Hosts**: People organizing social events (parties, dinners, weddings, trips, conferences) who want a fun, communal photo experience for their guests.
- **Attendees**: Event guests who join via a shared link and contribute photos during the event.

A single user can be both a host (for their own events) and an attendee (for events they've been invited to).

---

## Core Concepts

### Event Lifecycle

```
Created → Live → Ended → Revealed (per-user)
```

1. **Created** — Host sets up the event with a name, start/end time, and optional details.
2. **Live** — The event is active. Attendees can take photos. A running photo count is visible to all attendees.
3. **Ended** — The host ends the event (manually, or it auto-ends at the scheduled time). Photos are locked — no more can be taken. All attendees receive a push notification that the event is over and their film is ready to "develop."
4. **Revealed** — Each attendee individually chooses to "develop" their film, triggering the reveal of all event photos for that user.

### The "Disposable Camera" Constraint

- **No preview after capture.** When a user takes a photo, they do not see what the photo looks like. The viewfinder shows the live camera feed, but after tapping the shutter, there is no preview/review. The photo is uploaded directly.
- **No gallery access during event.** No one — not even the host — can view any photos until after the event ends and they choose to develop.
- **Retro filter applied server-side.** Photos are stored as originals and have a retro/film-style filter applied on the server before being served to users. Users only ever see the filtered versions in-app.

---

## Features

### 1. Event Creation (Host)

- **Fields:**
  - Event name (required)
  - Start date/time (required)
  - End date/time (optional) — if omitted, the event stays live until the host ends it manually.
  - Description (optional)
  - Location (optional)
- **Host can end the event** at any time via a manual action.
- **Auto-end:** If an end time is set, the event automatically ends at the scheduled time if the host hasn't ended it manually.
- On creation, a unique shareable link is generated for the event.

### 2. Authentication & Sign-Up

- **Account required.** All users must sign up before using the app. There is no anonymous access.
- **Phone number + SMS OTP.** Users sign up and sign in using their phone number. A one-time passcode is sent via SMS (Twilio Verify) for verification.
- **Profile setup.** After first verification, users complete a profile with first name, last name, and optional Instagram handle.
- **Persistent sessions.** Once authenticated, the session persists across app launches via Supabase Auth.

### 3. Event Joining (Attendee)

- **Join via deep link.** Tapping a WeWere link opens the app directly to the event join flow. If the user doesn't have the app, the link redirects to the App Store.
- **Account required to join.** Users must be signed in to join an event.
- After joining, the event appears in the user's event list.

### 4. Camera & Photo Capture

- **Custom in-app camera.** Full-screen viewfinder. Simple shutter button. No flash controls, no zoom, no filters visible — keep it simple like a disposable camera.
- **No photo preview.** After tapping the shutter, the photo is captured and uploaded in the background. The user sees a brief confirmation animation (e.g., a flash effect) but never sees the actual photo.
- **Photo counter.** All attendees can see a running count of total photos taken for the event (e.g., "47 photos taken").
- **Upload.** Photos are uploaded to cloud storage in the background. Handle offline/poor connectivity gracefully — queue uploads and retry.

### 5. Event End & Notification

- When the event ends (manually by host or auto):
  - Photo capture is disabled for the event.
  - All attendees receive a push notification: *"Your film from [Event Name] is ready to develop!"*
  - The event moves to an "ended" state in each user's event list.

### 6. Film Development & Reveal

- **Individual reveal.** Each user taps a "Develop Film" button to reveal the album for themselves. This is a one-time action — once developed, the album is permanently viewable.
- **Reveal experience.** The development should feel special — consider an animation that mimics film developing (photos fading in, a darkroom aesthetic, etc.).
- **Retro filter.** All photos are displayed with a retro/disposable camera filter applied server-side. Users see only the filtered versions.

### 7. Album & Gallery

- **Post-reveal gallery.** A scrollable gallery of all photos from the event, displayed with the retro filter.
- **Photo count & metadata.** Show who took each photo (display name) and when.
- **Emoji reactions.** Users can leave emoji reactions on individual photos (similar to iMessage reactions — a small set of emoji options).
- **Download.** Users can save individual photos to their camera roll (filtered version).
- **Sharing.** The event album is shareable via the same deep link mechanism. New users who open the link get added to the event and can view the album (after downloading the app if needed).

### 8. User Home / Event List

- **Two sections:**
  - **Live Events** — events currently active where the user can take photos.
  - **Past Events** — ended events, split into "Ready to Develop" and "Developed."
- **Hosting vs. Attending** is not a separate tab — all events appear in one unified list with a subtle host badge where applicable.

---

## Technical Architecture

### Platform
- **iOS only** (Swift/SwiftUI, minimum iOS 17)

### Backend — Supabase
- **Auth:** Supabase Auth with phone number sign-in. SMS OTP verification is handled via Twilio Verify, and the resulting session is created in Supabase Auth. All users must authenticate before accessing any features.
- **Database:** Supabase Postgres
  - `users` — id, display_name, first_name, last_name, instagram_handle, auth_id, avatar_url, push_token, created_at
  - `events` — id, host_id, name, description, location, start_time, end_time (nullable), status (live/ended), share_code, created_at
  - `event_members` — event_id, user_id, role (host/attendee), joined_at, has_developed (boolean)
  - `photos` — id, event_id, user_id, storage_path, filtered_storage_path, created_at
  - `reactions` — id, photo_id, user_id, emoji, created_at
- **Storage:** Supabase Storage for photo uploads (originals and filtered versions).
- **Edge Functions:** Supabase Edge Functions for:
  - Applying the retro filter to uploaded photos (triggered on upload).
  - Ending events on schedule (cron or pg_cron).
- **Realtime:** Supabase Realtime for live photo count updates during events.
- **Push Notifications:** APNs via Supabase Edge Functions or a lightweight push service.

### Deep Linking
- **Universal Links** (Apple) pointing to the app, with an App Store fallback for users without the app installed.
- Link format: `https://wewere.app/event/{event_id}`

### Photo Processing Pipeline
1. User captures photo -> uploaded as original to Supabase Storage.
2. Upload triggers an Edge Function that applies the retro filter.
3. Filtered version is stored alongside the original.
4. On reveal, the client fetches and displays only the filtered version.

---

## Non-Functional Requirements

- **Performance:** Photos should upload in the background without blocking the camera. Queued uploads for offline scenarios.
- **Privacy:** Photos are not accessible to anyone (including the host) until the event ends and the user develops. Row Level Security (RLS) in Supabase enforces this.
- **Scalability:** Design for events with up to ~200 attendees and ~1,000 photos per event as initial targets.
- **Content Moderation:** Basic image moderation (Apple's CSAM/NSFW detection or a third-party service) should be considered for App Store compliance.

---

## Out of Scope (V1)

- Android or web app
- Per-event or per-user photo limits
- Photo deletion (by photographer or host)
- Comments or captions on photos (emoji reactions only)
- Video capture
- Paid features or monetization
- In-app event chat
- Photo editing or filter selection (single fixed retro filter)

---

## Success Metrics

- **Activation:** % of users who join an event via link and take at least 1 photo.
- **Engagement:** Average photos per attendee per event.
- **Retention:** % of users who attend a second event within 30 days.
- **Reveal rate:** % of attendees who develop their film after event ends.
- **Share rate:** % of events where the album link is shared post-reveal.

---

## Open Questions

1. **Filter style:** What specific retro filter aesthetic? (Kodak Gold warm tones, washed-out Fuji, high-grain black & white, etc.) — may want to test a few.
2. **Event size limits:** Should there be a max attendee count per event in V1?
3. **Photo storage costs:** What's the budget for cloud storage? Compression strategy for uploaded photos?
4. **Moderation approach:** Manual review, automated ML-based, or report-based?
