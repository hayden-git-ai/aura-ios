/**
 * Slack Events receiver: the founder's side of the two-way support chat.
 *
 * Slack calls this whenever a message is posted in a public channel the bot is
 * in. When that message is a reply inside a #support thread (a founder answering
 * a user), we match the thread back to the user via `support_threads` and write
 * a `team` row into `support_messages`. The app reads that row and shows the
 * reply.
 *
 * This endpoint is public (no Supabase JWT). It authenticates every request by
 * verifying Slack's signature against SLACK_SIGNING_SECRET, so only real Slack
 * calls are accepted. Deploy with verify_jwt OFF.
 *
 * Loop safety: the bot's own posts (the user's relayed messages and the thread
 * headers) carry a bot_id and are ignored, so relaying never echoes back.
 */

const SUPPORT_CHANNEL = "C0C0BCMJNUB";

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method !== "POST") return new Response("POST only", { status: 405 });

  // Slack signs the RAW body, so read it as text before parsing.
  const raw = await request.text();
  if (!(await verifySlackSignature(request, raw))) {
    return new Response("bad signature", { status: 401 });
  }

  let event: any;
  try {
    event = JSON.parse(raw);
  } catch {
    return new Response("bad json", { status: 400 });
  }

  // First-time endpoint handshake.
  if (event?.type === "url_verification") {
    return new Response(JSON.stringify({ challenge: event.challenge }), {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  }

  // Everything else must return 200 fast so Slack does not retry; do the work
  // then answer. The work is a single quick insert.
  if (event?.type === "event_callback") {
    await handleMessage(event.event).catch(() => {});
  }
  return new Response("ok", { status: 200 });
});

async function handleMessage(ev: any): Promise<void> {
  if (!ev || ev.type !== "message") return;
  // Only plain human messages: skip the bot's own posts, edits, joins, and
  // other subtypes.
  if (ev.bot_id || ev.subtype) return;
  if (ev.channel !== SUPPORT_CHANNEL) return;
  // Must be a reply inside a thread (the founder answering a user). A top-level
  // message in #support belongs to no user thread.
  const threadTs = ev.thread_ts;
  if (!threadTs || threadTs === ev.ts) return;
  const text = typeof ev.text === "string" ? ev.text.trim() : "";
  if (!text) return;

  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return;

  // Which user owns this Slack thread?
  const thread = await restSelectOne(
    url, key, `support_threads?slack_ts=eq.${threadTs}&select=user_id`,
  );
  const uid = thread?.user_id as string | undefined;
  if (!uid) return;

  await restInsert(url, key, "support_messages", {
    user_id: uid,
    sender: "team",
    text: cleanSlackText(text),
  });
}

/**
 * Verifies the Slack request signature (v0 HMAC-SHA256 over `v0:ts:body`) and
 * rejects stale timestamps to blunt replays.
 */
async function verifySlackSignature(request: Request, raw: string): Promise<boolean> {
  const secret = Deno.env.get("SLACK_SIGNING_SECRET");
  const ts = request.headers.get("x-slack-request-timestamp");
  const sig = request.headers.get("x-slack-signature");
  if (!secret || !ts || !sig) return false;

  const skew = Math.abs(Date.now() / 1000 - Number(ts));
  if (!Number.isFinite(skew) || skew > 300) return false;

  const enc = new TextEncoder();
  const cryptoKey = await crypto.subtle.importKey(
    "raw", enc.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"],
  );
  const mac = await crypto.subtle.sign("HMAC", cryptoKey, enc.encode(`v0:${ts}:${raw}`));
  const expected = "v0=" +
    [...new Uint8Array(mac)].map((b) => b.toString(16).padStart(2, "0")).join("");
  return timingSafeEqual(expected, sig);
}

/** Constant-time string compare, to avoid leaking the signature via timing. */
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/**
 * Turns the bits of Slack markup a founder might type into plain text: user
 * mentions and links. Enough to keep replies readable in the app.
 */
function cleanSlackText(text: string): string {
  return text
    .replace(/<@[^>]+>/g, "")               // drop @mentions
    .replace(/<([^|>]+)\|([^>]+)>/g, "$2")  // <url|label> -> label
    .replace(/<([^>]+)>/g, "$1")            // <url> -> url
    .trim();
}

async function restInsert(
  url: string, key: string, table: string, row: Record<string, unknown>,
): Promise<void> {
  await fetch(`${url}/rest/v1/${table}`, {
    method: "POST",
    headers: {
      apikey: key,
      authorization: `Bearer ${key}`,
      "content-type": "application/json",
      prefer: "return=minimal",
    },
    signal: AbortSignal.timeout(5_000),
    body: JSON.stringify(row),
  });
}

async function restSelectOne(
  url: string, key: string, query: string,
): Promise<Record<string, unknown> | null> {
  const r = await fetch(`${url}/rest/v1/${query}`, {
    headers: {
      apikey: key,
      authorization: `Bearer ${key}`,
      accept: "application/json",
    },
    signal: AbortSignal.timeout(5_000),
  });
  if (!r.ok) return null;
  const rows = await r.json();
  return Array.isArray(rows) && rows.length > 0 ? rows[0] : null;
}
