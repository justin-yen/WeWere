CREATE TABLE IF NOT EXISTS comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    photo_id UUID NOT NULL REFERENCES photos(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    text TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_comments_photo_id ON comments(photo_id);

ALTER TABLE comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can read comments" ON comments FOR SELECT USING (true);
CREATE POLICY "Auth users can add comments" ON comments FOR INSERT WITH CHECK (true);
CREATE POLICY "Users can delete own comments" ON comments FOR DELETE USING (
    user_id = (SELECT id FROM public.users WHERE auth_id = auth.uid())
);

ALTER PUBLICATION supabase_realtime ADD TABLE comments;
