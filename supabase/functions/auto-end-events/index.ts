import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

/**
 * Auto-end events that have passed their scheduled end time.
 *
 * This function should be called on a cron schedule (every minute).
 *
 * Setup via Supabase Dashboard:
 *   1. Go to Database > Extensions > Enable pg_cron and pg_net
 *   2. Go to SQL Editor and run:
 *
 *   SELECT cron.schedule(
 *     'auto-end-events',
 *     '* * * * *',
 *     $$
 *     SELECT net.http_post(
 *       url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/auto-end-events',
 *       headers := jsonb_build_object(
 *         'Authorization', 'Bearer YOUR_SUPABASE_ANON_KEY',
 *         'Content-Type', 'application/json'
 *       ),
 *       body := '{}'::jsonb
 *     );
 *     $$
 *   );
 *
 * Alternatively, you can use Supabase's built-in cron from the Dashboard:
 *   Database > Cron Jobs > Create
 */
serve(async (req) => {
  try {
    // Verify this is called with a valid key (service role or anon with RLS bypass)
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
      });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Find all live events that should have ended
    const now = new Date().toISOString();
    const { data: expiredEvents, error: fetchError } = await supabase
      .from("events")
      .select("id, name")
      .eq("status", "live")
      .lte("end_time", now);

    if (fetchError) {
      console.error("Failed to fetch expired events:", fetchError);
      return new Response(
        JSON.stringify({ error: "Failed to fetch events" }),
        { status: 500 }
      );
    }

    if (!expiredEvents || expiredEvents.length === 0) {
      return new Response(
        JSON.stringify({ message: "No events to end", ended: 0 }),
        { status: 200 }
      );
    }

    console.log(`Found ${expiredEvents.length} events to auto-end`);

    let ended = 0;
    let pushErrors = 0;

    for (const event of expiredEvents) {
      // Update event status to 'ended'
      const { error: updateError } = await supabase
        .from("events")
        .update({ status: "ended" })
        .eq("id", event.id);

      if (updateError) {
        console.error(`Failed to end event ${event.name}:`, updateError);
        continue;
      }

      ended++;
      console.log(`Ended event: ${event.name} (${event.id})`);

      // Trigger push notifications via the send-push function
      try {
        const pushUrl = `${SUPABASE_URL}/functions/v1/send-push`;
        const pushResponse = await fetch(pushUrl, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            event_id: event.id,
            type: "film_ready",
          }),
        });

        if (!pushResponse.ok) {
          const errBody = await pushResponse.text();
          console.error(`Push failed for ${event.name}: ${errBody}`);
          pushErrors++;
        }
      } catch (pushErr) {
        console.error(`Push error for ${event.name}:`, pushErr);
        pushErrors++;
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        ended,
        push_errors: pushErrors,
        checked_at: now,
      }),
      { status: 200 }
    );
  } catch (err) {
    console.error("Unexpected error:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
    });
  }
});
