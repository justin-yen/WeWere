-- Fake data in the local disposable database only. No production data is copied.
WITH host AS (
    INSERT INTO public.users (id, display_name)
    VALUES ('00000000-0000-0000-0000-000000000099', 'Existing host')
    RETURNING id
)
INSERT INTO public.events (host_id, name, start_time, end_time, share_code)
SELECT id, 'Existing event', '2026-01-01T12:00:00Z', '2026-01-01T16:00:00Z', 'upgrade-preserved'
FROM host;
