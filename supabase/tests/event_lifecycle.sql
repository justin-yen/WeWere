BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
SET LOCAL search_path = public, extensions;
SELECT plan(5);
INSERT INTO public.users (id, display_name)
VALUES ('00000000-0000-0000-0000-000000000001', 'Migration test host');
SELECT lives_ok($$
    INSERT INTO public.events (host_id, name, start_time, end_time, share_code)
    VALUES ('00000000-0000-0000-0000-000000000001', 'Open ended', now(), NULL, 'migration-open')
$$, 'An event can be created without an end time');
INSERT INTO public.events (host_id, name, start_time, end_time, share_code)
VALUES
('00000000-0000-0000-0000-000000000001', 'Expired', now() - interval '2 hours', now() - interval '1 hour', 'migration-expired'),
('00000000-0000-0000-0000-000000000001', 'Future', now(), now() + interval '1 hour', 'migration-future');
SELECT is((SELECT count(*)::integer FROM public.events
           WHERE status = 'live' AND end_time <= now() AND share_code LIKE 'migration-%'),
          1, 'Only expired scheduled events qualify for automatic ending');
UPDATE public.events SET status = 'ended', end_time = now() WHERE share_code = 'migration-open';
SELECT is((SELECT status FROM public.events WHERE share_code = 'migration-open'), 'ended',
          'The host can end an open-ended event');
SELECT ok((SELECT end_time IS NOT NULL FROM public.events WHERE share_code = 'migration-open'),
          'Manual ending records the actual end time');
SELECT has_column('public', 'events', 'location_lat', 'The baseline includes the old backend migration');
SELECT * FROM finish();
ROLLBACK;
