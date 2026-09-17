-- Open-ended events remain live until the host ends them manually.
-- The auto-end job's end_time <= now filter already excludes NULL values.
ALTER TABLE public.events ALTER COLUMN end_time DROP NOT NULL;
