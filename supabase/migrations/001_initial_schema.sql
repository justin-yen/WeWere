-- WeWere Database Schema
-- Run this in Supabase SQL Editor to set up the database

-- ============================================
-- TABLES
-- ============================================

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    auth_id UUID UNIQUE NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT NOT NULL DEFAULT 'Anonymous',
    avatar_url TEXT,
    push_token TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS events (
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

CREATE TABLE IF NOT EXISTS event_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    role TEXT NOT NULL DEFAULT 'attendee' CHECK (role IN ('host', 'attendee')),
    has_developed BOOLEAN DEFAULT false,
    developed_at TIMESTAMPTZ,
    joined_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(event_id, user_id)
);

CREATE TABLE IF NOT EXISTS photos (
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

CREATE TABLE IF NOT EXISTS reactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    photo_id UUID NOT NULL REFERENCES photos(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    emoji TEXT NOT NULL CHECK (emoji IN ('fire', 'heart', 'laugh', 'wow', 'cry')),
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(photo_id, user_id, emoji)
);

-- ============================================
-- INDEXES
-- ============================================

CREATE INDEX IF NOT EXISTS idx_photos_event_id ON photos(event_id);
CREATE INDEX IF NOT EXISTS idx_event_members_event_id ON event_members(event_id);
CREATE INDEX IF NOT EXISTS idx_event_members_user_id ON event_members(user_id);
CREATE INDEX IF NOT EXISTS idx_reactions_photo_id ON reactions(photo_id);
CREATE INDEX IF NOT EXISTS idx_events_status ON events(status);
CREATE INDEX IF NOT EXISTS idx_events_share_code ON events(share_code);

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================

-- Users
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own profile"
    ON users FOR SELECT
    USING (auth_id = auth.uid());

CREATE POLICY "Users can read co-attendees"
    ON users FOR SELECT
    USING (
        id IN (
            SELECT em2.user_id FROM event_members em1
            JOIN event_members em2 ON em1.event_id = em2.event_id
            WHERE em1.user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
        )
    );

CREATE POLICY "Users can insert own"
    ON users FOR INSERT
    WITH CHECK (auth_id = auth.uid());

CREATE POLICY "Users can update own"
    ON users FOR UPDATE
    USING (auth_id = auth.uid());

-- Events
ALTER TABLE events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read events by share_code"
    ON events FOR SELECT
    USING (true);

CREATE POLICY "Auth users can create events"
    ON events FOR INSERT
    WITH CHECK (
        host_id = (SELECT id FROM users WHERE auth_id = auth.uid())
    );

CREATE POLICY "Host can update event"
    ON events FOR UPDATE
    USING (
        host_id = (SELECT id FROM users WHERE auth_id = auth.uid())
    );

-- Event Members
ALTER TABLE event_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can read event members"
    ON event_members FOR SELECT
    USING (
        event_id IN (
            SELECT event_id FROM event_members
            WHERE user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
        )
    );

CREATE POLICY "Auth users can join events"
    ON event_members FOR INSERT
    WITH CHECK (
        user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
    );

CREATE POLICY "Members can update own membership"
    ON event_members FOR UPDATE
    USING (
        user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
    );

-- Photos (only visible after developing)
ALTER TABLE photos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Photos visible after develop"
    ON photos FOR SELECT
    USING (
        event_id IN (
            SELECT event_id FROM event_members
            WHERE user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
            AND has_developed = true
        )
    );

CREATE POLICY "Members can count photos during live event"
    ON photos FOR SELECT
    USING (
        event_id IN (
            SELECT event_id FROM event_members
            WHERE user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
        )
    );

CREATE POLICY "Members can insert photos during live event"
    ON photos FOR INSERT
    WITH CHECK (
        user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
        AND event_id IN (SELECT id FROM events WHERE status = 'live')
        AND event_id IN (
            SELECT event_id FROM event_members
            WHERE user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
        )
    );

-- Reactions
ALTER TABLE reactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Reactions readable by developed members"
    ON reactions FOR SELECT
    USING (
        photo_id IN (
            SELECT p.id FROM photos p
            JOIN event_members em ON em.event_id = p.event_id
            WHERE em.user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
            AND em.has_developed = true
        )
    );

CREATE POLICY "Members can add reactions"
    ON reactions FOR INSERT
    WITH CHECK (
        user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
    );

CREATE POLICY "Users can remove own reactions"
    ON reactions FOR DELETE
    USING (
        user_id = (SELECT id FROM users WHERE auth_id = auth.uid())
    );

-- ============================================
-- ENABLE REALTIME
-- ============================================

ALTER PUBLICATION supabase_realtime ADD TABLE photos;
ALTER PUBLICATION supabase_realtime ADD TABLE events;
ALTER PUBLICATION supabase_realtime ADD TABLE event_members;

-- ============================================
-- STORAGE BUCKET
-- ============================================
-- Note: Create the "event-photos" bucket via Supabase Dashboard > Storage
-- Set it to PRIVATE. The RLS policies above + storage policies handle access.

-- ============================================
-- DATABASE WEBHOOK (for photo filter)
-- ============================================
-- Set up via Supabase Dashboard > Database > Webhooks:
--   Table: photos
--   Events: INSERT
--   URL: https://YOUR_PROJECT_REF.supabase.co/functions/v1/apply-retro-filter
--   Headers: Authorization: Bearer YOUR_SERVICE_ROLE_KEY
