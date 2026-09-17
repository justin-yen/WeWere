-- Allow auth_id to be null for fake/test users created for populated events
ALTER TABLE users ALTER COLUMN auth_id DROP NOT NULL;
