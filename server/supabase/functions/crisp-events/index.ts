/**
 * Crisp web hook receiver: the founder's side of the two-way support chat.
 *
 * Crisp calls this on `message:send` (the visitor's own message) and
 * `message:received` (a message the visitor receives, i.e. the founder's reply).
 * We act only on `from: "operator"` messages: we map the conversation back to the
 * user via `crisp_sessions` and write a `team` row into `support_messages`, which
 * the app reads and shows.
 *
 * This endpoint is public (no Supabase JWT). It authenticates every request by
 * verifying Crisp's signature against CRISP_WEBHOOK_SECRET, so only genuine Crisp
 * calls are accepted. Deploy with verify_jwt OFF.
 *
 * Loop safety: the user's own messages (posted by `support-send` as `from:"user"`)
 * also fire this event; they are ignored because only `from:"operator"` is acted
 * on, so relaying never echoes back.
 */

import { checkedFetch } from "../_shared/checked-fetch.ts";

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method !== "POST") return new Response("POST only", { status: 405 });

  // Crisp signs the RAW body, so read it as text before parsing.
  const raw = await request.text();
  if (!(await verifyCrispSignature(request, raw))) {
    return new Response("bad signature", { status: 401 });
  }

  let payload: any;
  try {
    payload = JSON.parse(raw);
  } catch {
    return new Response("bad json", { status: 400 });
  }

  // `message:send` is the visitor's own message (skipped); the founder's reply
  // arrives as `message:received`. We take either and act only on from:"operator".
  if (payload?.event === "message:send" || payload?.event === "message:received") {
    try {
      await handleMessage(payload.data);
    } catch {
      // A non-success response tells Crisp to retry instead of losing a founder
      // reply during a temporary database or configuration failure.
      return new Response("temporary failure", { status: 503 });
    }
  }
  return new Response("ok", { status: 200 });
});

async function handleMessage(d: any): Promise<void> {
  if (!d) return;
  // Only a founder's reply: skip the user's own relayed messages.
  if (d.from !== "operator") return;
  const sessionId = typeof d.session_id === "string" ? d.session_id : "";
  if (!sessionId) return;

  // Text messages carry a string; media messages (file/picture/audio/video/gif)
  // carry an object with a URL. Anything else we can't render, so skip it.
  let text = "", mediaUrl = "", mediaMime = "", mediaName = "";
  if (d.type === "text") {
    text = typeof d.content === "string" ? d.content.trim() : "";
  } else if (d.content && typeof d.content === "object" && typeof d.content.url === "string") {
    mediaUrl = d.content.url;
    mediaName = typeof d.content.name === "string" ? d.content.name : "";
    mediaMime = (typeof d.content.type === "string" && d.content.type)
      ? d.content.type
      : mimeForURL(mediaUrl, mimeForType(d.type));
  }
  if (!text && !mediaUrl) return;

  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) throw new Error("server misconfigured");

  // Which user owns this Crisp conversation?
  const row = await restSelectOne(
    url, key, `crisp_sessions?session_id=eq.${sessionId}&select=user_id`,
  );
  const uid = row?.user_id as string | undefined;
  if (!uid) return;

  await restInsert(url, key, "support_messages", {
    user_id: uid,
    sender: "team",
    text,
    media_url: mediaUrl || null,
    media_mime: mediaMime || null,
    media_name: mediaName || null,
  });
}

/** Best-guess MIME for a Crisp message type when the payload omits one. */
function mimeForType(t: string): string {
  switch (t) {
    case "picture": return "image/jpeg";
    case "animation": return "image/gif";
    case "audio": return "audio/mpeg";
    case "video": return "video/mp4";
    default: return "application/octet-stream";
  }
}

/** Infer only known audio types from the URL when Crisp omits content.type. */
function mimeForURL(rawURL: string, fallback: string): string {
  try {
    const extension = new URL(rawURL).pathname.split(".").pop()?.toLowerCase();
    switch (extension) {
      case "m4a": return "audio/mp4";
      case "aac": return "audio/aac";
      case "mp3": return "audio/mpeg";
      case "wav": return "audio/wav";
      default: return fallback;
    }
  } catch {
    return fallback;
  }
}

/**
 * Verifies the Crisp web hook signature: HMAC-SHA256 over `[timestamp;body]`
 * using the signing secret, compared against the `X-Crisp-Signature` header.
 */
async function verifyCrispSignature(request: Request, raw: string): Promise<boolean> {
  const secret = Deno.env.get("CRISP_WEBHOOK_SECRET");
  const ts = request.headers.get("x-crisp-request-timestamp");
  const sig = request.headers.get("x-crisp-signature");
  if (!secret || !ts || !sig) return false;

  const enc = new TextEncoder();
  const cryptoKey = await crypto.subtle.importKey(
    "raw", enc.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"],
  );
  const mac = await crypto.subtle.sign("HMAC", cryptoKey, enc.encode(`[${ts};${raw}]`));
  const expected = [...new Uint8Array(mac)].map((b) => b.toString(16).padStart(2, "0")).join("");
  return timingSafeEqual(expected, sig);
}

/** Constant-time string compare, to avoid leaking the signature via timing. */
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

async function restInsert(
  url: string, key: string, table: string, row: Record<string, unknown>,
): Promise<void> {
  await checkedFetch("support reply insert", `${url}/rest/v1/${table}`, {
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
  const r = await checkedFetch("support session select", `${url}/rest/v1/${query}`, {
    headers: {
      apikey: key,
      authorization: `Bearer ${key}`,
      accept: "application/json",
    },
    signal: AbortSignal.timeout(5_000),
  });
  const rows = await r.json();
  return Array.isArray(rows) && rows.length > 0 ? rows[0] : null;
}
