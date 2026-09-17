BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(3);
SELECT is((SELECT name FROM public.events WHERE share_code = 'upgrade-preserved'),
          'Existing event', 'Existing event survives the upgrade');
SELECT is((SELECT end_time FROM public.events WHERE share_code = 'upgrade-preserved'),
          '2026-01-01T16:00:00Z'::timestamptz, 'Existing end times stay unchanged');
SELECT is((SELECT display_name FROM public.users WHERE id = '00000000-0000-0000-0000-000000000099'),
          'Existing host', 'Existing host survives the upgrade');
SELECT * FROM finish();
ROLLBACK;
