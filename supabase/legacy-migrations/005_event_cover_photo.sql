-- Rename cover_image_url to cover_photo_url for consistency
ALTER TABLE events RENAME COLUMN cover_image_url TO cover_photo_url;

-- Add attribution column
ALTER TABLE events ADD COLUMN IF NOT EXISTS cover_photo_attribution TEXT;
