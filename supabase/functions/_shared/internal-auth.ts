/** Internal jobs and database webhooks require a server-only secret, not a user JWT. */
export async function requireInternalKey(req: Request): Promise<Response | null> {
  const expected = Deno.env.get("INTERNAL_API_KEY");
  const supplied = req.headers.get("x-internal-api-key");
  if (!expected || !supplied) return new Response("Forbidden", { status: 403 });
  const encoder = new TextEncoder();
  const [left, right] = await Promise.all([
    crypto.subtle.digest("SHA-256", encoder.encode(expected)),
    crypto.subtle.digest("SHA-256", encoder.encode(supplied)),
  ]);
  const a = new Uint8Array(left), b = new Uint8Array(right);
  let difference = 0;
  for (let i = 0; i < a.length; i++) difference |= a[i] ^ b[i];
  return difference === 0 ? null : new Response("Forbidden", { status: 403 });
}
