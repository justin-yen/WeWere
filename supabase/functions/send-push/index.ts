import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// APNs configuration
const APNS_KEY_ID = Deno.env.get("APNS_KEY_ID") ?? "";
const APNS_TEAM_ID = Deno.env.get("APNS_TEAM_ID") ?? "";
const APNS_BUNDLE_ID = "com.wewere.app";
// Base64-encoded .p8 private key content
const APNS_PRIVATE_KEY_BASE64 = Deno.env.get("APNS_PRIVATE_KEY_BASE64") ?? "";

serve(async (req) => {
  try {
    const { event_id, type = "film_ready" } = await req.json();

    if (!event_id) {
      return new Response(JSON.stringify({ error: "Missing event_id" }), {
        status: 400,
      });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Fetch event details
    const { data: event, error: eventError } = await supabase
      .from("events")
      .select("id, name")
      .eq("id", event_id)
      .single();

    if (eventError || !event) {
      return new Response(JSON.stringify({ error: "Event not found" }), {
        status: 404,
      });
    }

    // Fetch all members' push tokens
    const { data: members, error: membersError } = await supabase
      .from("event_members")
      .select("user_id, users(push_token, display_name)")
      .eq("event_id", event_id);

    if (membersError) {
      return new Response(
        JSON.stringify({ error: "Failed to fetch members" }),
        { status: 500 }
      );
    }

    // Build notification payload based on type
    let alert: { title: string; body: string };
    let sound = "default";

    switch (type) {
      case "film_ready":
        alert = {
          title: "Film Ready!",
          body: `Your film from ${event.name} is ready to develop!`,
        };
        sound = "shutter.caf";
        break;
      case "reaction":
        const { reactor_name, emoji } = await req.json();
        alert = {
          title: `${reactor_name} reacted`,
          body: `${reactor_name} reacted ${emoji} to your photo`,
        };
        break;
      default:
        alert = {
          title: "WeWere",
          body: `Something happened in ${event.name}`,
        };
    }

    const apnsPayload = {
      aps: {
        alert,
        sound,
        "mutable-content": 1,
      },
      event_id: event.id,
      type,
    };

    // Send push to each member with a valid token
    let sent = 0;
    let failed = 0;

    for (const member of members ?? []) {
      const user = member.users as any;
      const pushToken = user?.push_token;

      if (!pushToken) continue;

      try {
        await sendAPNS(pushToken, apnsPayload);
        sent++;
      } catch (err) {
        console.error(
          `Failed to send push to ${user?.display_name}:`,
          err
        );
        failed++;
      }
    }

    console.log(
      `Push sent for event ${event.name}: ${sent} delivered, ${failed} failed`
    );

    return new Response(
      JSON.stringify({ success: true, sent, failed }),
      { status: 200 }
    );
  } catch (err) {
    console.error("Unexpected error:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
    });
  }
});

/**
 * Send a push notification via APNs HTTP/2 API.
 *
 * For production, you need:
 * 1. An Apple Developer account
 * 2. An APNs key (.p8 file) from Certificates, Identifiers & Profiles
 * 3. Set these as Supabase Edge Function secrets:
 *    - APNS_KEY_ID
 *    - APNS_TEAM_ID
 *    - APNS_PRIVATE_KEY_BASE64
 *
 * To set secrets:
 *   supabase secrets set APNS_KEY_ID=ABC123DEFG
 *   supabase secrets set APNS_TEAM_ID=YOUR_TEAM_ID
 *   supabase secrets set APNS_PRIVATE_KEY_BASE64=$(base64 -i AuthKey_ABC123DEFG.p8)
 */
async function sendAPNS(
  deviceToken: string,
  payload: Record<string, unknown>
): Promise<void> {
  // Use sandbox for development, production for release
  const isProduction = Deno.env.get("APNS_PRODUCTION") === "true";
  const host = isProduction
    ? "api.push.apple.com"
    : "api.sandbox.push.apple.com";

  const jwt = await generateAPNSJWT();

  const response = await fetch(
    `https://${host}/3/device/${deviceToken}`,
    {
      method: "POST",
      headers: {
        authorization: `bearer ${jwt}`,
        "apns-topic": APNS_BUNDLE_ID,
        "apns-push-type": "alert",
        "apns-priority": "10",
        "apns-expiration": "0",
        "content-type": "application/json",
      },
      body: JSON.stringify(payload),
    }
  );

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`APNs error ${response.status}: ${body}`);
  }
}

/**
 * Generate a short-lived JWT for APNs authentication.
 * Uses ES256 algorithm with the .p8 key.
 */
async function generateAPNSJWT(): Promise<string> {
  const header = btoa(
    JSON.stringify({ alg: "ES256", kid: APNS_KEY_ID })
  )
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");

  const now = Math.floor(Date.now() / 1000);
  const claims = btoa(
    JSON.stringify({ iss: APNS_TEAM_ID, iat: now })
  )
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");

  const unsignedToken = `${header}.${claims}`;

  // Decode the base64 .p8 key
  const keyData = Uint8Array.from(atob(APNS_PRIVATE_KEY_BASE64), (c) =>
    c.charCodeAt(0)
  );

  // Strip PEM headers if present
  const pemString = new TextDecoder().decode(keyData);
  const pemBody = pemString
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const keyBytes = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));

  // Import the key for signing
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    keyBytes,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );

  // Sign
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    cryptoKey,
    new TextEncoder().encode(unsignedToken)
  );

  const signatureBase64 = btoa(
    String.fromCharCode(...new Uint8Array(signature))
  )
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");

  return `${unsignedToken}.${signatureBase64}`;
}
