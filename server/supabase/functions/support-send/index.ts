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
  trustedSupportMedia,
} from "../_shared/support-media.ts";

import { supportAttachmentKind } from "../_shared/support-attachment.ts";

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
  let clientMessageId = "";
  let mediaUrl = "", mediaMime = "", mediaName = "";
  try {
    const body = await request.json();
    clientMessageId = typeof body?.client_message_id === "string"
      ? body.client_message_id.toLowerCase()
      : "";
    text = typeof body?.text === "string" ? body.text.trim() : "";
    mediaUrl = typeof body?.media_url === "string" ? body.media_url : "";
    mediaMime = typeof body?.media_mime === "string" ? body.media_mime : "";
    mediaName = typeof body?.media_name === "string" ? body.media_name : "";
  } catch {
    return json({ error: "bad request" }, 400);
  }
  if (!text && !mediaUrl) return json({ error: "empty" }, 400);
  const retryableClient = isUUID(clientMessageId);
  if (!retryableClient) clientMessageId = crypto.randomUUID();
  if (text.length > MAX_LEN) text = text.slice(0, MAX_LEN);
  if (!mediaUrl) { mediaMime = ""; mediaName = ""; }

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) return json({ error: "server misconfigured" }, 500);

  // 0. Every attachment must be this user's exact private Storage object and a
  //    supported image, document or audio file. Caller MIME is not trusted.
  if (mediaUrl) {
    const attachment = await sanitizeStoredAttachment(url, serviceKey, mediaUrl, uid);
    if (!attachment) return json({ error: "invalid attachment" }, 400);
    mediaUrl = attachment.url;
    mediaMime = attachment.mime;
    mediaName = mediaName.replace(/[\x00-\x1f\x7f/\\]/g, "").slice(0, 160) || "attachment";
    if (attachment.image) mediaName = mediaName.replace(/\.[^.]+$/, "") + ".jpg";
  }

  // 1. Persist the user's message. This is the source of truth the app reads.
  try {
    await restInsert(url, serviceKey, "support_messages", {
      id: clientMessageId,
      user_id: uid,
      sender: "user",
      text,
      media_url: mediaUrl || null,
      media_mime: mediaMime || null,
      media_name: mediaName || null,
    }, true);
  } catch {
    return json({ error: "message persistence failed" }, 502);
  }

  // Who is this? Fetched once and reused by the Crisp meta and the Slack ping.
  const profile = await restSelectOne(
    url, serviceKey, `profiles?user_id=eq.${uid}&select=display_name,email`,
  );
  const name = (profile?.display_name as string) || "Aura user";
  const email = (profile?.email as string) || "";

  // A retry with the same client UUID keeps one database row. If the earlier
  // attempt reached Crisp, return success without posting it twice.
  const persisted = await restSelectOne(
    url, serviceKey,
    `support_messages?id=eq.${clientMessageId}&user_id=eq.${uid}&select=crisp_relayed_at`,
  ).catch(() => null);
  if (!persisted) return json({ error: "message lookup failed" }, 502);
  if (persisted.crisp_relayed_at) return json({ ok: true }, 200);

  // 2. Relay to Crisp. New clients receive a failure and expose their existing
  // retry button; the same UUID prevents that retry from duplicating the row.
  const crisp = crispCreds();
  if (!crisp) return json({ error: "support relay unavailable" }, 502);
  try {
    const session = await ensureCrispSession(url, serviceKey, crisp, uid, name, email);
    if (!session) throw new Error("Crisp session unavailable");
    await crispSendUserMessage(crisp, session, { text, mediaUrl, mediaMime, mediaName }, name);
    await restMarkCrispRelayed(url, serviceKey, clientMessageId, uid);
  } catch (_e) {
    // Old clients did not send a stable UUID, so returning a retryable error to
    // them would create duplicates. New clients are safe to retry.
    if (retryableClient) return json({ error: "support relay failed" }, 502);
    return json({ ok: true, relay_pending: true }, 200);
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
 * validates its format, and re-encodes images as capped metadata-free JPEGs.
 * Supported documents/audio retain their bytes. The trusted content type is
 * written back before signing/relay; any failure rejects before persistence.
 */
async function sanitizeStoredAttachment(
  url: string, serviceKey: string, signedUrl: string, uid: string,
): Promise<{ url: string; mime: string; image: boolean } | null> {
  try {
    const media = trustedSupportMedia(url, signedUrl, uid);
    if (!media) return null;
    const original = await fetchTrustedSupportMedia(media, serviceKey);
    const kind = supportAttachmentKind(original, media.objectPath);
    if (!kind) return null;
    const clean = kind.image ? await reencodeJpeg(original) : original;
    if (!clean) return null;

    // Overwrite in place (same path) with the service role.
    await checkedFetch("support media sanitize", media.uploadURL, {
      method: "PUT",
      headers: {
        authorization: `Bearer ${serviceKey}`,
        apikey: serviceKey,
        "content-type": kind.mime,
        "x-upsert": "true",
      },
      body: clean,
      redirect: "error",
      signal: AbortSignal.timeout(5_000),
    });
    return { url: await createFreshSignedSupportURL(media, serviceKey), ...kind };
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

  const created = await checkedFetch(
    "Crisp conversation create",
    `${CRISP_API}/website/${c.websiteId}/conversation`, {
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
  const r = await checkedFetch(
    "Crisp message relay",
    `${CRISP_API}/website/${c.websiteId}/conversation/${sessionId}/message`, {
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
  ignoreDuplicates = false,
): Promise<void> {
  await checkedFetch("support message insert", `${url}/rest/v1/${table}`, {
    method: "POST",
    headers: {
      apikey: key,
      authorization: `Bearer ${key}`,
      "content-type": "application/json",
      prefer: ignoreDuplicates ? "resolution=ignore-duplicates,return=minimal" : "return=minimal",
    },
    signal: AbortSignal.timeout(5_000),
    body: JSON.stringify(row),
  });
}

async function restSelectOne(
  url: string, key: string, query: string,
): Promise<Record<string, unknown> | null> {
  const r = await checkedFetch("support row select", `${url}/rest/v1/${query}`, {
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

async function restMarkCrispRelayed(
  url: string, key: string, messageId: string, uid: string,
): Promise<void> {
  await checkedFetch(
    "support relay marker update",
    `${url}/rest/v1/support_messages?id=eq.${messageId}&user_id=eq.${uid}`, {
      method: "PATCH",
      headers: {
        apikey: key,
        authorization: `Bearer ${key}`,
        "content-type": "application/json",
        prefer: "return=minimal",
      },
      signal: AbortSignal.timeout(5_000),
      body: JSON.stringify({ crisp_relayed_at: new Date().toISOString() }),
    },
  );
}

function isUUID(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(value);
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}
