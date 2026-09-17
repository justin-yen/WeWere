-- Update allowed emoji values for reactions
-- New set: heart, fire, sparkles, film, moon (replacing laugh, wow, cry)

-- Remove old check constraint
ALTER TABLE reactions DROP CONSTRAINT IF EXISTS reactions_emoji_check;

-- Migrate any existing reactions with old emoji values
UPDATE reactions SET emoji = 'sparkles' WHERE emoji = 'laugh';
UPDATE reactions SET emoji = 'film' WHERE emoji = 'wow';
UPDATE reactions SET emoji = 'moon' WHERE emoji = 'cry';

-- Add new check constraint with updated values
ALTER TABLE reactions ADD CONSTRAINT reactions_emoji_check
    CHECK (emoji IN ('heart', 'fire', 'sparkles', 'film', 'moon'));
