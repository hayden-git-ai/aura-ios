/**
 * Support message send + Crisp relay (+ Slack heads-up).
 *
 * The app calls this when a user sends a message in the in-app support chat.
 * It does three things, in order:
 *   1. Persists the message to `support_messages` (the source of truth the app
 *      reads back, on this device and any other).
 *   2. Relays it into Crisp so a founder sees it in a real per-user inbox. Each
 *      user maps to one Crisp conversation: the first message creates the
 *      conversation (and records its id in `crisp_sessions`, stamped with the
 *      user's name/email), and every message posts into it as `from: "user"`.
 *   3. Posts a lightweight heads-up to Slack `#support` so a new message is not
 *      missed. This is a NOTIFICATION only; the founder replies in Crisp, and the
 *      reply travels back via the `crisp-events` function.
 *
 * Auth: the user id comes from the verified JWT, never the body, so a caller can
 * only ever write to their own thread. Runs with verify_jwt ON.
 */

import { Image } from "https://deno.land/x/imagescript@1.2.17/mod.ts";
import { checkedFetch } from "../_shared/checked-fetch.ts";
import {
  createFreshSignedSupportURL,
  fetchTrustedSupportMedia,
  rasterWithinPixelBudget,
  trustedSupportMedia,
} from "../_shared/support-media.ts";

const CRISP_API = "https://api.crisp.chat/v1";
// The Slack channel used only as a heads-up feed (non-secret channel id).
const SLACK_SUPPORT_CHANNEL = "C0C0BCMJNUB";
const MAX_LEN = 4000;
// Server-side image caps for the founder-facing support path (defence in depth,
// on top of the client's ImageSanitizer): a modified client can't push a raw or
// metadata-bearing image into Crisp.
const IMAGE_MAX_DIM = 2048;
const IMAGE_JPEG_QUALITY = 82;

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method !== "POST") return json({ error: "POST only" }, 405);

  const bearer = request.headers.get("authorization") ?? "";
  const uid = bearer.startsWith("Bearer ")
    ? await verifyUser(bearer.slice(7))
    : null;
  if (!uid) return json({ error: "unauthorized" }, 401);

  let text = "";
  let mediaUrl = "", mediaMime = "", mediaName = "";
  try {
    const body = await request.json();
    text = typeof body?.text === "string" ? body.text.trim() : "";
    mediaUrl = typeof body?.media_url === "string" ? body.media_url : "";
    mediaMime = typeof body?.media_mime === "string" ? body.media_mime : "";
    mediaName = typeof body?.media_name === "string" ? body.media_name : "";
  } catch {
    return json({ error: "bad request" }, 400);
  }
  if (!text && !mediaUrl) return json({ error: "empty" }, 400);
  if (text.length > MAX_LEN) text = text.slice(0, MAX_LEN);
  if (!mediaUrl) { mediaMime = ""; mediaName = ""; }

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) return json({ error: "server misconfigured" }, 500);

  // 0. Every attachment must be this user's exact private Storage object and a
  //    decodable image. Caller-provided MIME is never a trust signal.
  if (mediaUrl) {
    const sanitizedURL = await sanitizeStoredImage(url, serviceKey, mediaUrl, uid);
    if (!sanitizedURL) return json({ error: "invalid attachment" }, 400);
    mediaUrl = sanitizedURL;
    mediaMime = "image/jpeg";
    mediaName = mediaName.replace(/\.[^.]+$/, "") + ".jpg";
  }

  // 1. Persist the user's message. This is the source of truth the app reads.
  try {
    await restInsert(url, serviceKey, "support_messages", {
      user_id: uid,
      sender: "user",
      text,
      media_url: mediaUrl || null,
      media_mime: mediaMime || null,
      media_name: mediaName || null,
    });
  } catch {
    return json({ error: "message persistence failed" }, 502);
  }

  // Who is this? Fetched once and reused by the Crisp meta and the Slack ping.
  const profile = await restSelectOne(
    url, serviceKey, `profiles?user_id=eq.${uid}&select=display_name,email`,
  );
  const name = (profile?.display_name as string) || "Aura user";
  const email = (profile?.email as string) || "";

  // 2. Relay to Crisp. Best-effort: a Crisp hiccup must not fail the send.
  const crisp = crispCreds();
  if (crisp) {
    try {
      const session = await ensureCrispSession(url, serviceKey, crisp, uid, name, email);
      if (session) {
        await crispSendUserMessage(crisp, session, { text, mediaUrl, mediaMime, mediaName }, name);
      }
    } catch (_e) { /* persisted; next send retries */ }
  }

  // 3. Slack heads-up (notification only). Best-effort.
  const slackToken = Deno.env.get("SLACK_BOT_TOKEN");
  if (slackToken) {
    try {
      await slackNotify(slackToken, name, text || "📎 sent an attachment");
    } catch (_e) { /* a missed ping is harmless; Crisp still has the message */ }
  }

  return json({ ok: true }, 200);
});

/**
 * Downloads the authenticated user's object through a trusted Storage API URL,
 * re-encodes it to a capped
 * JPEG (dropping any EXIF/GPS and enforcing a max dimension), and overwrites the
 * same object in place. Returns false on any validation, download, decode, or
 * overwrite failure; the caller then rejects the message before persistence.
 */
async function sanitizeStoredImage(
  url: string, serviceKey: string, signedUrl: string, uid: string,
): Promise<string | null> {
  try {
    const media = trustedSupportMedia(url, signedUrl, uid);
    if (!media) return null;
    const original = await fetchTrustedSupportMedia(media, serviceKey);
    if (!rasterWithinPixelBudget(original)) return null;

    const clean = await reencodeJpeg(original);
    if (!clean) return null;

    // Overwrite in place (same path) with the service role.
    await checkedFetch("support media sanitize", media.uploadURL, {
      method: "PUT",
      headers: {
        authorization: `Bearer ${serviceKey}`,
        apikey: serviceKey,
        "content-type": "image/jpeg",
        "x-upsert": "true",
      },
      body: clean,
      redirect: "error",
      signal: AbortSignal.timeout(5_000),
    });
    return await createFreshSignedSupportURL(media, serviceKey);
  } catch {
    return null;
  }
}

/** Decodes, downscales to `IMAGE_MAX_DIM`, and re-encodes as JPEG. */
async function reencodeJpeg(bytes: Uint8Array): Promise<Uint8Array | null> {
  try {
    const image = await Image.decode(bytes);
    const longest = Math.max(image.width, image.height);
    const scaled = longest > IMAGE_MAX_DIM
      ? (image.width >= image.height
          ? image.resize(IMAGE_MAX_DIM, Image.RESIZE_AUTO)
          : image.resize(Image.RESIZE_AUTO, IMAGE_MAX_DIM))
      : image;
    return await scaled.encodeJPEG(IMAGE_JPEG_QUALITY);
  } catch {
    return null;
  }
}

interface CrispCreds { identifier: string; key: string; websiteId: string }

function crispCreds(): CrispCreds | null {
  const identifier = Deno.env.get("CRISP_IDENTIFIER");
  const key = Deno.env.get("CRISP_KEY");
  const websiteId = Deno.env.get("CRISP_WEBSITE_ID");
  if (!identifier || !key || !websiteId) return null;
  return { identifier, key, websiteId };
}

function crispHeaders(c: CrispCreds): HeadersInit {
  return {
    authorization: `Basic ${btoa(`${c.identifier}:${c.key}`)}`,
    "content-type": "application/json",
    "X-Crisp-Tier": "plugin",
  };
}

/**
 * Returns the user's Crisp conversation id, creating (and recording) one the first
 * time. On create it stamps the conversation with the user's name/email.
 */
async function ensureCrispSession(
  url: string, key: string, c: CrispCreds, uid: string, name: string, email: string,
): Promise<string | null> {
  const existing = await restSelectOne(
    url, key, `crisp_sessions?user_id=eq.${uid}&select=session_id`,
  );
  if (existing?.session_id) return existing.session_id as string;

  const created = await fetch(`${CRISP_API}/website/${c.websiteId}/conversation`, {
    method: "POST",
    headers: crispHeaders(c),
    signal: AbortSignal.timeout(5_000),
  });
  const createdBody = await created.json().catch(() => null);
  const sessionId = createdBody?.data?.session_id as string | undefined;
  if (!sessionId) return null;

  // Put the email in the display name, NOT the Crisp email field. Setting the
  // email field makes Crisp treat the person as reachable by email, and since our
  // app visitor is always "offline" to Crisp, it would email your reply to them.
  // We want replies to go only through the app (via the webhook), so the email is
  // kept as context in the name instead.
  const meta: Record<string, unknown> = {
    nickname: email ? `${name} (${email})` : name,
  };
  await fetch(`${CRISP_API}/website/${c.websiteId}/conversation/${sessionId}/meta`, {
    method: "PATCH",
    headers: crispHeaders(c),
    body: JSON.stringify(meta),
    signal: AbortSignal.timeout(5_000),
  }).catch(() => {});

  await restInsert(url, key, "crisp_sessions", { user_id: uid, session_id: sessionId });
  return sessionId;
}

interface OutMessage { text: string; mediaUrl: string; mediaMime: string; mediaName: string }

/**
 * Posts the user's message into their Crisp conversation as an incoming message.
 * Media is sent as a Crisp `file` message (Crisp previews images inline and shows
 * other files as downloads); plain text is sent as a `text` message.
 */
async function crispSendUserMessage(
  c: CrispCreds, sessionId: string, msg: OutMessage, name: string,
): Promise<void> {
  const base = { from: "user", origin: "chat", user: { nickname: name } };
  const payload = msg.mediaUrl
    ? {
        ...base,
        type: "file",
        content: {
          name: msg.mediaName || "attachment",
          url: msg.mediaUrl,
          type: msg.mediaMime || "application/octet-stream",
        },
      }
    : { ...base, type: "text", content: msg.text };
  const r = await fetch(`${CRISP_API}/website/${c.websiteId}/conversation/${sessionId}/message`, {
    method: "POST",
    headers: crispHeaders(c),
    body: JSON.stringify(payload),
    signal: AbortSignal.timeout(5_000),
  });
  if (msg.mediaUrl) {
    const rb = await r.json().catch(() => null);
    console.log("[crisp] file msg status", r.status, "body", JSON.stringify(rb));
  }
}

/** A simple "new message" line in Slack #support. Reply happens in Crisp. */
async function slackNotify(token: string, name: string, text: string): Promise<void> {
  await fetch("https://slack.com/api/chat.postMessage", {
    method: "POST",
    headers: {
      authorization: `Bearer ${token}`,
      "content-type": "application/json; charset=utf-8",
    },
    body: JSON.stringify({
      channel: SLACK_SUPPORT_CHANNEL,
      text: `:speech_balloon: *New support message from ${name}*\n${text}\n_Reply in Crisp._`,
    }),
    signal: AbortSignal.timeout(5_000),
  });
}

/** Resolves the JWT to a user id, or null. Matches the other functions. */
async function verifyUser(jwt: string): Promise<string | null> {
  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !anon) return null;
  try {
    const r = await fetch(`${url}/auth/v1/user`, {
      headers: { authorization: `Bearer ${jwt}`, apikey: anon },
      signal: AbortSignal.timeout(3_000),
    });
    if (!r.ok) return null;
    const user = await r.json();
    return typeof user?.id === "string" ? user.id : null;
  } catch {
    return null;
  }
}

async function restInsert(
  url: string, key: string, table: string, row: Record<string, unknown>,
): Promise<void> {
  await checkedFetch("support message insert", `${url}/rest/v1/${table}`, {
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

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}
