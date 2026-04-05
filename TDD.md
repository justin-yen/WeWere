# WeWere - Technical Design Document

## 1. Architecture Overview

### 1.1 System Diagram

```
+---------------------+       +------------------------+
|   iOS App (SwiftUI) |       |       Supabase         |
|   iOS 17+ / Swift   |<----->|  (Backend-as-a-Service)|
+---------------------+       +------------------------+
         |                        |    |    |    |
         |                        |    |    |    +-- Auth (Anonymous + Apple)
         |                        |    |    +------ Postgres (RLS)
         |                        |    +----------- Storage (Photos)
         |                        +---------------- Edge Functions
         |                                          - Photo filter pipeline
         |                                          - Cron: auto-end events
         |                                          - Push notification dispatch
         |
         +--- AVFoundation (Camera)
         +--- APNs (Push Notifications)
         +--- Universal Links (Deep Linking)
```

### 1.2 Tech Stack

| Layer | Technology |
|-------|-----------|
| Platform | iOS 17+, iPhone only |
| Language | Swift 5.9+ |
| UI Framework | SwiftUI |
| Architecture | MVVM + Repository pattern |
| Networking | Supabase Swift SDK (`supabase-swift`) |
| Camera | AVFoundation (`AVCaptureSession`) |
| Image Processing | Core Image (client-side preview), Supabase Edge Functions (server-side filter) |
| Push Notifications | APNs via Supabase Edge Functions |
| Deep Linking | Universal Links (`applinks:wewere.app`) |
| Local Persistence | SwiftData (offline upload queue) |
| Dependency Management | Swift Package Manager |

### 1.3 Project Structure

```
WeWere/
├── App/
│   ├── WeWereApp.swift              # App entry point, scene config
│   ├── AppState.swift               # Global app state (auth, navigation)
│   └── AppDelegate.swift            # Push notification registration
├── Design/
│   ├── Theme.swift                  # Colors, typography, spacing tokens
│   ├── Fonts/                       # Plus Jakarta Sans, Space Grotesk, Clash Display
│   └── Components/
│       ├── FilmGrainOverlay.swift   # Grain texture view modifier
│       ├── BrushedChromeButton.swift # Gradient CTA buttons
│       ├── DarkroomGlow.swift       # Radial glow background effect
│       ├── NoirDivider.swift        # Radial gradient divider
│       └── TabBar.swift             # Custom bottom tab bar
├── Features/
│   ├── Home/
│   │   ├── HomeView.swift           # Event list (live + past)
│   │   ├── HomeViewModel.swift
│   │   ├── LiveEventCard.swift      # Hero card with cover image
│   │   └── PastEventRow.swift       # Compact row for past events
│   ├── EventDetail/
│   │   ├── EventDetailView.swift    # Live event info, attendees, stats
│   │   ├── EventDetailViewModel.swift
│   │   └── AttendeeRow.swift
│   ├── Camera/
│   │   ├── CameraView.swift         # Full-screen viewfinder
│   │   ├── CameraViewModel.swift
│   │   ├── CameraService.swift      # AVCaptureSession wrapper
│   │   └── ShutterButton.swift      # Custom shutter with animation
│   ├── DevelopFilm/
│   │   ├── DevelopFilmView.swift    # "Event is over" + develop CTA
│   │   ├── DevelopingAnimationView.swift # Processing animation
│   │   └── DevelopFilmViewModel.swift
│   ├── Album/
│   │   ├── AlbumView.swift          # Photo grid with filter tabs
│   │   ├── AlbumViewModel.swift
│   │   └── PhotoGridItem.swift      # Single photo cell
│   ├── PhotoDetail/
│   │   ├── PhotoDetailView.swift    # Full-screen photo + reactions
│   │   ├── PhotoDetailViewModel.swift
│   │   └── ReactionBar.swift        # Emoji reaction picker
│   ├── JoinEvent/
│   │   ├── JoinEventView.swift      # Invitation-style join screen
│   │   └── JoinEventViewModel.swift
│   ├── CreateEvent/
│   │   ├── CreateEventView.swift    # Event creation form
│   │   └── CreateEventViewModel.swift
│   └── Profile/
│       ├── ProfileView.swift
│       └── ProfileViewModel.swift
├── Services/
│   ├── AuthService.swift            # Supabase Auth (anon + Apple Sign-In)
│   ├── EventService.swift           # Event CRUD, realtime subscriptions
│   ├── PhotoService.swift           # Upload, download, queue management
│   ├── ReactionService.swift        # Emoji reactions CRUD
│   ├── PushNotificationService.swift # APNs token registration
│   └── DeepLinkService.swift        # Universal Link routing
├── Models/
│   ├── User.swift
│   ├── Event.swift
│   ├── EventMember.swift
│   ├── Photo.swift
│   └── Reaction.swift
├── Repositories/
│   ├── EventRepository.swift        # Supabase ↔ local data bridge
│   ├── PhotoRepository.swift
│   └── UploadQueue.swift            # SwiftData-backed offline queue
└── Utilities/
    ├── ImageCompressor.swift        # Pre-upload HEIC/JPEG compression
    └── HapticManager.swift          # Tactile feedback for shutter, develop
```

---

## 2. Design System Implementation

### 2.1 Color Tokens

All colors derived from the Stitch design system. The app uses a **dark-only theme** -- no light mode.

```swift
// Theme.swift
extension Color {
    // Surfaces
    static let surface          = Color(hex: "#131313")
    static let surfaceBright    = Color(hex: "#393939")
    static let surfaceContainer = Color(hex: "#1e1e1e")
    static let surfaceContainerLow  = Color(hex: "#191919")
    static let surfaceContainerHigh = Color(hex: "#282828")
    static let surfaceContainerHighest = Color(hex: "#353535")
    static let surfaceContainerLowest  = Color(hex: "#0e0e0e")

    // Primary
    static let onSurface        = Color(hex: "#e2e2e2")
    static let onSurfaceVariant = Color(hex: "#c7c6c6")
    static let primary          = Color.white
    static let onPrimary        = Color(hex: "#1a1c1c")

    // Secondary
    static let secondary          = Color(hex: "#c7c6c6")
    static let secondaryContainer = Color(hex: "#464747")

    // Tertiary
    static let tertiary          = Color(hex: "#e2e2e2")
    static let tertiaryContainer = Color(hex: "#909191")

    // Utility
    static let outline        = Color(hex: "#919191")
    static let outlineVariant = Color(hex: "#474747")
    static let error          = Color(hex: "#ffb4ab")
    static let errorContainer = Color(hex: "#93000a")
}
```

### 2.2 Typography

Three font families mapped to SwiftUI:

| Role | Font | Usage |
|------|------|-------|
| **Brand / Logo** | Clash Display (Semibold 600) | "WEWERE" wordmark, section headers |
| **Headlines / Body** | Plus Jakarta Sans (400, 700) | Event titles, body text, buttons |
| **Labels / Metadata** | Space Grotesk (400, 500) | ISO, timestamps, photo counts, technical data |

```swift
// Font scale (mapped from Stitch HTML)
enum AppFont {
    static func clashDisplay(_ size: CGFloat) -> Font {
        .custom("ClashDisplay-Semibold", size: size)
    }
    static func jakartaSans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(weight == .bold ? "PlusJakartaSans-Bold" : "PlusJakartaSans-Regular", size: size)
    }
    static func spaceGrotesk(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(weight == .medium ? "SpaceGrotesk-Medium" : "SpaceGrotesk-Regular", size: size)
    }
}
```

**Type Scale** (derived from Stitch screens):

| Token | Font | Size | Weight | Usage |
|-------|------|------|--------|-------|
| `display-lg` | Clash Display | 36pt | 600 | Event titles on hero cards |
| `headline-md` | Plus Jakarta Sans | 24pt | 700 | Section headers ("LIVE EVENTS") |
| `title-lg` | Plus Jakarta Sans | 20pt | 600 | Event names in lists |
| `title-sm` | Plus Jakarta Sans | 14pt | 600 | Button labels |
| `body-lg` | Plus Jakarta Sans | 16pt | 400 | Descriptions, body text |
| `body-md` | Plus Jakarta Sans | 14pt | 400 | Secondary text |
| `label-lg` | Space Grotesk | 14pt | 500 | Photo counts, metadata |
| `label-md` | Space Grotesk | 12pt | 400 | ISO, shutter speed, timestamps |
| `label-sm` | Space Grotesk | 10pt | 400 | Fine-print metadata |

### 2.3 Corner Radius

```swift
enum Radius {
    static let sm: CGFloat   = 2    // 0.125rem - inputs, subtle elements
    static let md: CGFloat   = 4    // 0.25rem  - default cards
    static let lg: CGFloat   = 8    // 0.5rem   - larger cards
    static let xl: CGFloat   = 12   // 0.75rem  - prominent containers
    static let full: CGFloat = 9999 // pill shapes - chips, badges
}
```

### 2.4 Visual Effects

Extracted from Stitch HTML/CSS:

| Effect | Implementation | Usage |
|--------|---------------|-------|
| **Film Grain** | `UIImage` noise texture at 3% opacity, overlaid via `.overlay()` modifier with sepia(20%), contrast(110%), saturation(90%), brightness(95%) filters | Applied globally to backgrounds |
| **Brushed Chrome** | `LinearGradient(colors: [.white, Color(hex: "#d4d4d4")], startPoint: .topLeading, endPoint: .bottomTrailing)` | Primary CTA buttons ("DEVELOP FILM", "JOIN EVENT") |
| **Darkroom Glow** | `RadialGradient` from `white.opacity(0.05)` at center to `clear` | Background ambiance on develop/camera screens |
| **Noir Divider** | 1px height `RadialGradient` from `outlineVariant` to `clear` | Section separators (replaces hairline dividers) |
| **Viewfinder Mask** | `inset box-shadow: 0 0 150px rgba(0,0,0,0.8)` -> SwiftUI radial gradient vignette | Camera view edge darkening |
| **Glass Effect** | `.ultraThinMaterial` + `opacity(0.6)` with 20px blur | Floating overlays on camera view |

---

## 3. Data Models

### 3.1 Supabase Postgres Schema

```sql
-- Users
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    auth_id UUID UNIQUE NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT NOT NULL,
    avatar_url TEXT,
    push_token TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Events
CREATE TABLE events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    host_id UUID NOT NULL REFERENCES users(id),
    name TEXT NOT NULL,
    description TEXT,
    cover_image_url TEXT,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL DEFAULT 'live' CHECK (status IN ('live', 'ended')),
    share_code TEXT UNIQUE NOT NULL DEFAULT encode(gen_random_bytes(6), 'hex'),
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Event Members
CREATE TABLE event_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    role TEXT NOT NULL DEFAULT 'attendee' CHECK (role IN ('host', 'attendee')),
    has_developed BOOLEAN DEFAULT false,
    developed_at TIMESTAMPTZ,
    joined_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(event_id, user_id)
);

-- Photos
CREATE TABLE photos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    storage_path TEXT NOT NULL,
    filtered_storage_path TEXT,
    width INT,
    height INT,
    filter_applied BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Reactions
CREATE TABLE reactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    photo_id UUID NOT NULL REFERENCES photos(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    emoji TEXT NOT NULL CHECK (emoji IN ('fire', 'heart', 'laugh', 'wow', 'cry')),
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(photo_id, user_id, emoji)
);

-- Indexes
CREATE INDEX idx_photos_event_id ON photos(event_id);
CREATE INDEX idx_event_members_event_id ON event_members(event_id);
CREATE INDEX idx_event_members_user_id ON event_members(user_id);
CREATE INDEX idx_reactions_photo_id ON reactions(photo_id);
CREATE INDEX idx_events_status ON events(status);
CREATE INDEX idx_events_share_code ON events(share_code);
```

### 3.2 Row Level Security Policies

```sql
-- Users: can read own profile, update own profile
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own" ON users FOR SELECT USING (auth_id = auth.uid());
CREATE POLICY "Users can read co-attendees" ON users FOR SELECT USING (
    id IN (
        SELECT em2.user_id FROM event_members em1
        JOIN event_members em2 ON em1.event_id = em2.event_id
        WHERE em1.user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
    )
);
CREATE POLICY "Users can update own" ON users FOR UPDATE USING (auth_id = auth.uid());
CREATE POLICY "Users can insert own" ON users FOR INSERT WITH CHECK (auth_id = auth.uid());

-- Events: members can read, host can update
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Members can read events" ON events FOR SELECT USING (
    id IN (SELECT event_id FROM event_members WHERE user_id = (SELECT id FROM users WHERE auth_id = auth.uid()))
);
CREATE POLICY "Anyone can read by share_code" ON events FOR SELECT USING (true);
CREATE POLICY "Auth users can create" ON events FOR INSERT WITH CHECK (
    host_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);
CREATE POLICY "Host can update" ON events FOR UPDATE USING (
    host_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);

-- Photos: only visible after user has developed
ALTER TABLE photos ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Photos visible after develop" ON photos FOR SELECT USING (
    event_id IN (
        SELECT event_id FROM event_members
        WHERE user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
        AND has_developed = true
    )
);
CREATE POLICY "Members can insert during live event" ON photos FOR INSERT WITH CHECK (
    user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
    AND event_id IN (
        SELECT id FROM events WHERE status = 'live'
    )
    AND event_id IN (
        SELECT event_id FROM event_members
        WHERE user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
    )
);

-- Reactions: only on developed photos
ALTER TABLE reactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Reactions readable by event members" ON reactions FOR SELECT USING (
    photo_id IN (
        SELECT p.id FROM photos p
        JOIN event_members em ON em.event_id = p.event_id
        WHERE em.user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
        AND em.has_developed = true
    )
);
CREATE POLICY "Members can react" ON reactions FOR INSERT WITH CHECK (
    user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);
CREATE POLICY "Users can remove own reactions" ON reactions FOR DELETE USING (
    user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
);
```

### 3.3 Swift Models

```swift
struct AppUser: Codable, Identifiable {
    let id: UUID
    let authId: UUID
    var displayName: String
    var avatarUrl: String?
    var pushToken: String?
    let createdAt: Date
}

struct Event: Codable, Identifiable {
    let id: UUID
    let hostId: UUID
    var name: String
    var description: String?
    var coverImageUrl: String?
    let startTime: Date
    let endTime: Date
    var status: EventStatus
    let shareCode: String
    let createdAt: Date

    enum EventStatus: String, Codable {
        case live, ended
    }
}

struct EventMember: Codable, Identifiable {
    let id: UUID
    let eventId: UUID
    let userId: UUID
    let role: MemberRole
    var hasDeveloped: Bool
    var developedAt: Date?
    let joinedAt: Date

    enum MemberRole: String, Codable {
        case host, attendee
    }
}

struct Photo: Codable, Identifiable {
    let id: UUID
    let eventId: UUID
    let userId: UUID
    let storagePath: String
    var filteredStoragePath: String?
    var width: Int?
    var height: Int?
    var filterApplied: Bool
    let createdAt: Date
}

struct Reaction: Codable, Identifiable {
    let id: UUID
    let photoId: UUID
    let userId: UUID
    let emoji: ReactionEmoji
    let createdAt: Date

    enum ReactionEmoji: String, Codable, CaseIterable {
        case fire, heart, laugh, wow, cry
    }
}
```

### 3.4 Supabase Storage Buckets

```
event-photos/
├── {event_id}/
│   ├── originals/
│   │   └── {photo_id}.heic      # Original upload (HEIC for size efficiency)
│   └── filtered/
│       └── {photo_id}.jpg       # Retro-filtered version (JPEG for compatibility)
```

**Bucket Policies:**
- `event-photos` bucket: private, authenticated access only
- Upload: allowed for event members during live events
- Download (filtered/): allowed only for members who have developed
- Download (originals/): denied to all clients (server-side only)

---

## 4. Screen Specifications

### 4.1 Home / Event List

**Route:** Root tab (index 0)

**Layout** (from Stitch "Home / Event List V7"):
- Header: "WEWERE" wordmark (Clash Display, white) left-aligned, notification bell icon right-aligned
- **Live Events Section:**
  - Section label: "LIVE EVENTS" (Space Grotesk, label-lg, `onSurfaceVariant`) with count badge
  - Horizontally paged hero cards, full-width with 16px horizontal padding
  - Each card: cover image background, event name (Clash Display, display-lg), photo count + attendee count (Space Grotesk, label-md), gradient overlay bottom
- **Past Events Section:**
  - Section label: "PAST EVENTS"
  - Sub-labels: "READY TO DEVELOP" / "DEVELOPED"
  - Compact rows: thumbnail left, event name (Plus Jakarta Sans, title-lg), date + photo count right
  - "Ready to develop" rows have a subtle amber/gold accent indicator
- **Bottom Tab Bar:** 4 tabs - Home (grid_view), Search, Notifications, Profile

**Data Flow:**
```
HomeViewModel
├── eventRepository.getMyEvents() -> [Event]
├── eventRepository.subscribeToLiveEvents() -> AsyncStream<[Event]>
└── Computed:
    ├── liveEvents: [Event]  (status == .live)
    ├── readyToDevelop: [(Event, EventMember)]  (ended, !hasDeveloped)
    └── developed: [(Event, EventMember)]  (ended, hasDeveloped)
```

### 4.2 Camera View

**Route:** Presented modally from Event Detail "Open Camera" button

**Layout** (from Stitch "Camera View V4"):
- Full-screen `AVCaptureVideoPreviewLayer` with viewfinder vignette mask
- Top bar (glass material): back arrow, flash toggle, flip camera
- Center: large photo counter ("042") in Plus Jakarta Sans bold, 64pt
- Metadata strip: "ISO 400 | 1/125 | 35mm" in Space Grotesk label-sm
- Bottom: custom shutter button (brushed chrome circle, 72pt diameter) with haptic feedback
- Bottom labels: "HOME" / "CAMERA" / "PROFILE" tab indicators

**Camera Service (`CameraService.swift`):**
```swift
class CameraService: NSObject, ObservableObject {
    @Published var isSessionRunning = false
    @Published var photoCount: Int = 0

    private let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var device: AVCaptureDevice?

    func configure() async throws { ... }
    func capturePhoto() { ... }
    func toggleFlash() { ... }
    func switchCamera() { ... }
}
```

**Capture Flow:**
1. User taps shutter -> haptic impact (`.heavy`)
2. White flash overlay animation (100ms fade in, 200ms fade out)
3. `AVCapturePhotoOutput.capturePhoto()` fires
4. Photo data received in delegate -> compress to HEIC (quality 0.8)
5. Enqueue to `UploadQueue` (SwiftData) -> increment counter
6. No preview shown. Viewfinder remains active.

**Upload Queue (`UploadQueue.swift`):**
```swift
@Model
class QueuedUpload {
    var id: UUID
    var eventId: UUID
    var imageData: Data
    var status: UploadStatus  // .pending, .uploading, .completed, .failed
    var retryCount: Int
    var createdAt: Date
}
```
- Background URLSession for uploads
- Retry with exponential backoff (max 5 retries)
- Monitor via `NWPathMonitor` for connectivity changes
- Resume pending uploads on app foreground

### 4.3 Event Detail

**Route:** Push from Home -> event card tap

**Layout** (from Stitch "Event Detail V7"):
- Header image with cinematic gradient overlay (bottom fade)
- Status badge: "LIVE NOW" (green pulse dot + pill badge)
- Event name: Clash Display, display-lg, white
- Countdown timer: "02:44:12" (Space Grotesk, headline-md, monospaced)
- Photo count: "1,248" with camera icon (Space Grotesk, headline-md)
- "Open Camera" CTA (brushed chrome button, full width)
- **Attendees section:** list of member rows with avatar, name, photo count per user
- **Location:** map thumbnail + address text
- **Stats:** engagement percentage, peak upload time
- Bottom tab bar

**Realtime Subscription:**
```swift
// Subscribe to live photo count
supabase.channel("event-\(eventId)")
    .on("postgres_changes", filter: .init(
        event: .insert,
        schema: "public",
        table: "photos",
        filter: "event_id=eq.\(eventId)"
    )) { payload in
        self.photoCount += 1
    }
    .subscribe()
```

### 4.4 Develop Film

**Route:** Push from Home -> "Ready to Develop" event tap

**Layout** (from Stitch "Develop Film V4"):
- Background: dark with darkroom glow effect (radial gradient)
- Header: "WEWERE" + notification bell
- Label: "ARCHIVE SERIES // 004" (Space Grotesk, label-md)
- Headline: "THE EVENT IS OVER" (Clash Display, display-lg, white, tracking wide)
- Sub-label: "36 EXPOSURES READY" (Space Grotesk, label-lg)
- Film canister icon / film strip visual (centered)
- "REC" indicator with red dot
- **"DEVELOP FILM" button:** brushed chrome gradient, full-width, Plus Jakarta Sans title-sm
- Note: "CHEMICAL PROCESS WILL TAKE APPROXIMATELY 24 HOURS." (Space Grotesk, label-sm, `onSurfaceVariant`)
- Metadata footer: "ISO 400" badge, Location, Expired timestamp
- Bottom tab bar: HOME / FILM / PROFILE

**Develop Action:**
```swift
func developFilm(eventId: UUID) async throws {
    // 1. Update event_members.has_developed = true
    try await supabase.from("event_members")
        .update(["has_developed": true, "developed_at": ISO8601DateFormatter().string(from: Date())])
        .eq("event_id", value: eventId)
        .eq("user_id", value: currentUserId)
        .execute()

    // 2. Navigate to developing animation
    // 3. After animation, navigate to album
}
```

### 4.5 Developing Animation

**Route:** Presented after "Develop Film" tap, auto-transitions to Album

**Layout** (from Stitch "Developing Animation V4"):
- Background: solid `surface` (#131313)
- Processing label: "Processing Node AXON-B_v04" + "Roll ID #MN-90882-X" (Space Grotesk, label-sm)
- Polaroid frame: white border (12px padding), photo inside with blur/reveal animation
- "DEVELOPING..." text overlay on photo (Plus Jakarta Sans, body-lg, animated opacity pulse)
- Timestamp + exposure metadata below frame
- Headline: "Developing your midnight vision." (Plus Jakarta Sans, headline-md, white)
- Technical metadata row: Latency 42ms | Phase Rendering/03 | ISO 3200 | Shutter 1/250 | Aperture f/1.8

**Animation Sequence** (3-5 seconds total):
1. Polaroid frame slides up from bottom with spring animation
2. Photo inside starts fully blurred (Gaussian blur radius 30)
3. "DEVELOPING..." text pulses opacity 0.3 -> 1.0 (0.8s loop)
4. Blur reduces progressively: 30 -> 20 -> 10 -> 5 -> 0 over 3 seconds
5. At blur = 0, "DEVELOPING..." fades out
6. Brief pause (0.5s), then auto-navigate to Album with matched geometry transition

### 4.6 Event Album

**Route:** Push after developing animation completes, or from Home -> developed event tap

**Layout** (from Stitch "Event Album V4"):
- Header: "WEWERE" + notification bell
- Event title: "MIDNIGHT VOYAGE 2024" (Clash Display, display-lg)
- Sub-label: "428 HIGH-RESOLUTION PHOTOGRAPHS" (Space Grotesk, label-md)
- Action bar: "DOWNLOAD ALL" button + filter icon
- **Filter tabs:** horizontal scroll of pill chips - ALL PHOTOS, PORTRAITS, CANDID, BACKSTAGE, ATMOSPHERE (Space Grotesk, label-md, `secondaryContainer` when selected)
- **Photo grid:** 2-column masonry layout with asymmetric spacing (16px left, 24px right per design system)
  - Photos displayed with retro film filter applied
  - Lazy loading with progressive JPEG decode
  - Tap navigates to Photo Detail
- Feature callout: "THE PEAK MOMENT -- 23:45" label on highlighted photo
- Floating "+" button (bottom right) -- re-share album link
- Bottom tab bar

**Photo Grid Implementation:**
```swift
// Masonry layout using LazyVGrid with adaptive columns
let columns = [
    GridItem(.flexible(), spacing: 4),
    GridItem(.flexible(), spacing: 4)
]

LazyVGrid(columns: columns, spacing: 4) {
    ForEach(photos) { photo in
        AsyncImage(url: photo.filteredUrl)
            .aspectRatio(
                CGFloat(photo.width ?? 3) / CGFloat(photo.height ?? 4),
                contentMode: .fill
            )
    }
}
```

### 4.7 Photo Detail

**Route:** Push from Album -> photo tap

**Layout** (from Stitch "Photo Detail V5"):
- Full-screen photo (filtered version), pinch-to-zoom enabled
- Top-left: close (X) button
- Top metadata: photographer name (Plus Jakarta Sans, title-sm) + date/time (Space Grotesk, label-md)
- Top-right: "WEWERE" wordmark + time
- **"SAVE TO CAMERA ROLL"** button (brushed chrome, full width, with download icon)
- **Reaction bar** (bottom): horizontal row of emoji buttons
  - Available: fire, heart, laugh, wow, cry
  - Each shows count if > 0
  - Tap toggles own reaction (with scale animation)
- Metadata strip: ISO, aperture, shutter speed, focal length (Space Grotesk, label-sm)
- Photo grain overlay applied to image

**Save to Camera Roll:**
```swift
func savePhoto(url: URL) async throws {
    let (data, _) = try await URLSession.shared.data(from: url)
    guard let image = UIImage(data: data) else { return }
    try await PHPhotoLibrary.shared().performChanges {
        PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
    }
}
```

### 4.8 Join Event

**Route:** Universal Link `wewere.app/event/{share_code}` or in-app link

**Layout** (from Stitch "Join Event V5"):
- Background: `surface` with subtle darkroom glow
- Top: hamburger menu + "WEWERE" wordmark + notification bell
- Label: "INVITATION NO. 882-01 | 2024 ED." (Space Grotesk, label-md, `onSurfaceVariant`)
- Event banner image (full width, 200pt height, rounded xl corners)
- Event name: "AFTER HOURS: THE MONOLITH" (Clash Display, headline-md)
- Location + time: "SECRET LOCATION * MIDNIGHT CST" (Space Grotesk, label-md)
- **Identity section:**
  - Label: "IDENTITY" (Space Grotesk, label-md)
  - Text field: "ENTER YOUR NAME" placeholder (Space Grotesk, label-md in `surfaceContainerLow` well)
- **"JOIN EVENT" button:** brushed chrome, full width, with right arrow icon
- Terms note: small print (Space Grotesk, label-sm, `outlineVariant`)
- Metadata footer: Date + Capacity ("LIMITED / 50")

**Join Flow:**
1. Deep link parsed -> extract `share_code`
2. Fetch event by share_code (public read policy)
3. If no auth session -> create anonymous Supabase auth session
4. Prompt for display name
5. Insert into `event_members` (role: attendee)
6. Navigate to Event Detail

---

## 5. Backend Services

### 5.1 Supabase Edge Functions

#### `apply-retro-filter`
**Trigger:** Supabase Storage webhook on file upload to `event-photos/{event_id}/originals/`

```typescript
// supabase/functions/apply-retro-filter/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

serve(async (req) => {
    const { record } = await req.json()
    const storagePath = record.storage_path
    const photoId = record.id

    // 1. Download original from storage
    // 2. Apply retro filter (warm color grade, grain, vignette, light leak)
    //    - Color temperature shift: +15% warm (Kodak Gold emulation)
    //    - Grain: Gaussian noise, sigma=12, opacity=8%
    //    - Vignette: radial gradient, 40% darkening at edges
    //    - Contrast: +10%, Saturation: -15%
    //    - Optional: random subtle light leak (orange/amber gradient)
    // 3. Save filtered version to filtered/ path
    // 4. Update photos table: filtered_storage_path, filter_applied = true

    return new Response(JSON.stringify({ success: true }))
})
```

#### `auto-end-events`
**Trigger:** pg_cron, runs every minute

```sql
SELECT cron.schedule(
    'auto-end-events',
    '* * * * *',
    $$
    UPDATE events
    SET status = 'ended'
    WHERE status = 'live'
    AND end_time <= now();
    $$
);
```

After status update, a Postgres trigger invokes the push notification function:

```sql
CREATE OR REPLACE FUNCTION notify_event_ended()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'ended' AND OLD.status = 'live' THEN
        PERFORM net.http_post(
            url := 'https://<project>.supabase.co/functions/v1/send-push',
            body := json_build_object('event_id', NEW.id)::text
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_event_ended
AFTER UPDATE ON events
FOR EACH ROW
WHEN (NEW.status = 'ended' AND OLD.status = 'live')
EXECUTE FUNCTION notify_event_ended();
```

#### `send-push`
**Trigger:** HTTP POST from `notify_event_ended` trigger or direct invocation

```typescript
// Sends APNs push to all event members
// Payload: { "aps": { "alert": { "title": "Film Ready!", "body": "Your film from {event_name} is ready to develop!" }, "sound": "shutter.caf" } }
```

### 5.2 Realtime Channels

| Channel | Table | Event | Purpose |
|---------|-------|-------|---------|
| `event-{id}-photos` | `photos` | INSERT | Live photo count during event |
| `event-{id}-members` | `event_members` | INSERT | Live attendee count during event |
| `event-{id}-status` | `events` | UPDATE | Detect event end in real-time |

---

## 6. Key User Flows

### 6.1 Event Creation Flow

```
CreateEventView
    ├── Enter event name
    ├── Set start date/time (DatePicker)
    ├── Set end date/time (DatePicker)
    ├── Optional: add description
    ├── Tap "Create Event"
    │   ├── eventService.createEvent(name, description, startTime, endTime)
    │   │   ├── INSERT into events (host_id = current user)
    │   │   └── INSERT into event_members (role = 'host')
    │   └── Generate share link: wewere.app/event/{share_code}
    └── Show share sheet with link
```

### 6.2 Photo Capture Flow

```
EventDetail -> "Open Camera"
    ├── CameraView presented (modal, fullscreen)
    ├── AVCaptureSession starts
    ├── User taps shutter
    │   ├── Haptic: .impact(.heavy)
    │   ├── Flash overlay animation
    │   ├── AVCapturePhotoOutput captures HEIC
    │   ├── Compress (quality 0.8, max 2048px long edge)
    │   ├── Save to UploadQueue (SwiftData)
    │   ├── Increment local counter
    │   └── Background upload starts:
    │       ├── Upload to Supabase Storage: event-photos/{event_id}/originals/{photo_id}.heic
    │       ├── INSERT into photos table
    │       └── Edge Function auto-triggers filter
    └── No preview shown -- viewfinder stays active
```

### 6.3 Film Development Flow

```
Home -> "Ready to Develop" event
    ├── DevelopFilmView
    │   ├── Shows exposure count, event metadata
    │   └── Tap "DEVELOP FILM"
    │       ├── UPDATE event_members SET has_developed = true
    │       └── Navigate to DevelopingAnimationView
    ├── DevelopingAnimationView (3-5 seconds)
    │   ├── Polaroid frame slides up
    │   ├── Photo blur reveal animation
    │   └── Auto-navigate to AlbumView
    └── AlbumView
        ├── Fetch all photos for event (now accessible via RLS)
        ├── Display in masonry grid with retro filter
        └── Tap photo -> PhotoDetailView
```

### 6.4 Deep Link Join Flow

```
User taps wewere.app/event/{share_code}
    ├── iOS routes to app via Universal Links
    ├── AppDelegate/SceneDelegate receives URL
    ├── DeepLinkService.parse(url) -> .joinEvent(shareCode)
    ├── Fetch event by share_code
    ├── If no auth session:
    │   └── Create anonymous Supabase session
    ├── JoinEventView
    │   ├── Show event info (name, date, cover image)
    │   ├── Prompt for display name
    │   └── Tap "JOIN EVENT"
    │       ├── Upsert user (display_name)
    │       ├── INSERT event_members (role: attendee)
    │       └── Navigate to EventDetailView
    └── If app not installed:
        └── Redirect to App Store (handled by AASA file on wewere.app)
```

---

## 7. Navigation Architecture

```swift
// Tab-based root with NavigationStack per tab
enum Tab: Int, CaseIterable {
    case home       // grid_view icon
    case search     // search icon
    case notifications // notifications icon
    case profile    // person icon
}

enum Route: Hashable {
    case eventDetail(Event)
    case camera(Event)
    case developFilm(Event)
    case developingAnimation(Event)
    case album(Event)
    case photoDetail(Photo)
    case joinEvent(shareCode: String)
    case createEvent
}

// AppState manages navigation
@Observable
class AppState {
    var selectedTab: Tab = .home
    var navigationPath = NavigationPath()
    var presentedSheet: Route?
    var pendingDeepLink: Route?
}
```

---

## 8. Authentication Strategy

### 8.1 Anonymous-First Auth

```swift
class AuthService: ObservableObject {
    @Published var currentUser: AppUser?
    @Published var isAuthenticated = false

    private let supabase: SupabaseClient

    // Anonymous sign-in on first launch -- zero friction
    func signInAnonymously() async throws {
        let session = try await supabase.auth.signInAnonymously()
        // User record created via trigger or client-side insert
    }

    // Upgrade to persistent account (optional)
    func linkAppleAccount(idToken: String, nonce: String) async throws {
        try await supabase.auth.updateUser(
            UserAttributes(data: ["provider": "apple"]),
            // Link Apple credential to existing anonymous session
        )
    }
}
```

### 8.2 Auth Flow

1. **First launch:** auto sign-in anonymously -> create `users` record with placeholder name
2. **Join event:** prompt for display name -> update `users.display_name`
3. **Optional upgrade:** Settings -> "Save your account" -> Apple Sign-In links to existing session
4. **Token refresh:** handled automatically by Supabase Swift SDK

---

## 9. Push Notifications

### 9.1 Registration

```swift
// AppDelegate.swift
func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    Task {
        try await supabase.from("users")
            .update(["push_token": token])
            .eq("auth_id", value: supabase.auth.currentUser?.id)
            .execute()
    }
}
```

### 9.2 Notification Types

| Notification | Trigger | Title | Body |
|-------------|---------|-------|------|
| Film Ready | Event status -> ended | "Film Ready!" | "Your film from {name} is ready to develop!" |
| New Reaction | Reaction inserted on user's photo | "{user} reacted" | "{user} reacted {emoji} to your photo" |

---

## 10. Universal Links & Deep Linking

### 10.1 Apple App Site Association (AASA)

Hosted at `https://wewere.app/.well-known/apple-app-site-association`:

```json
{
    "applinks": {
        "apps": [],
        "details": [
            {
                "appID": "TEAMID.com.wewere.app",
                "paths": ["/event/*"]
            }
        ]
    }
}
```

### 10.2 Link Routing

```swift
// DeepLinkService.swift
enum DeepLink {
    case joinEvent(shareCode: String)
}

func parse(url: URL) -> DeepLink? {
    guard url.host == "wewere.app",
          url.pathComponents.count >= 3,
          url.pathComponents[1] == "event" else { return nil }
    return .joinEvent(shareCode: url.pathComponents[2])
}
```

---

## 11. Performance Considerations

| Concern | Strategy |
|---------|----------|
| Photo upload reliability | SwiftData-backed queue with background URLSession, NWPathMonitor for connectivity |
| Large album loading | Paginated fetch (50 photos per page), progressive JPEG, thumbnail generation |
| Camera startup | Pre-warm AVCaptureSession on event detail appearance |
| Memory | Lazy image loading, `AsyncImage` with disk cache, limit in-memory photo buffer to 10 |
| Battery | Batch uploads (max 3 concurrent), throttle realtime updates to 1/sec |
| Offline | Queue captures locally, sync on reconnect, show pending upload count |

---

## 12. Build Phases & Milestones

### Phase 1: Foundation
- [ ] Xcode project setup, SPM dependencies (supabase-swift)
- [ ] Design system: Theme.swift, custom fonts, visual effects
- [ ] Supabase project setup: tables, RLS, storage buckets
- [ ] Auth service: anonymous sign-in, user record creation
- [ ] Navigation skeleton: tab bar, NavigationStack routing

### Phase 2: Core Event Flow
- [ ] Home screen: event list (live + past sections)
- [ ] Create Event screen + Supabase insert
- [ ] Event Detail screen with realtime photo count
- [ ] Share link generation + copy to clipboard

### Phase 3: Camera & Upload
- [ ] Camera service (AVFoundation)
- [ ] Camera UI: viewfinder, shutter button, counter, flash
- [ ] Photo capture + HEIC compression
- [ ] Upload queue (SwiftData) + background upload
- [ ] Supabase Storage upload integration

### Phase 4: Film Development
- [ ] Develop Film screen
- [ ] Developing animation (blur reveal, Polaroid frame)
- [ ] Mark as developed (Supabase update)
- [ ] Edge Function: retro filter pipeline

### Phase 5: Album & Social
- [ ] Album view: masonry grid, filter tabs
- [ ] Photo detail: full-screen, metadata
- [ ] Emoji reactions (CRUD)
- [ ] Save to camera roll
- [ ] Download all photos

### Phase 6: Distribution & Polish
- [ ] Deep linking: Universal Links, AASA, join flow
- [ ] Push notifications: APNs registration, event-ended push
- [ ] Auto-end events (pg_cron)
- [ ] Event end detection via realtime
- [ ] Haptics, transitions, animation polish
- [ ] App Store assets & submission
