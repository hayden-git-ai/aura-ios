/**
 * App Store Connect webhook receiver for release/review notifications.
 *
 * App Store Connect calls this endpoint when build, TestFlight, or App Review
 * status changes happen for Aura. The endpoint verifies Apple's HMAC signature
 * with APP_STORE_CONNECT_WEBHOOK_SECRET, then posts a compact notice into Slack.
 *
 * This endpoint is public (no Supabase JWT). Deploy with verify_jwt OFF.
 */

const APP_STORE_CONNECT_URL = "https://appstoreconnect.apple.com/apps/6809618566";

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method !== "POST") return new Response("POST only", { status: 405 });

  const raw = await request.text();
  if (!(await verifyAppleSignature(request, raw))) {
    return new Response("bad signature", { status: 401 });
  }

  let payload: any;
  try {
    payload = JSON.parse(raw);
  } catch {
    return new Response("bad json", { status: 400 });
  }

  await postToSlack(payload).catch(() => {});
  return new Response("ok", { status: 200 });
});

async function verifyAppleSignature(request: Request, raw: string): Promise<boolean> {
  const secret = Deno.env.get("APP_STORE_CONNECT_WEBHOOK_SECRET");
  const sig = request.headers.get("x-apple-signature");
  if (!secret || !sig) return false;

  const actual = sig.trim().toLowerCase();
  if (!actual.startsWith("hmacsha256=")) return false;

  const enc = new TextEncoder();
  const cryptoKey = await crypto.subtle.importKey(
    "raw", enc.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"],
  );
  const mac = await crypto.subtle.sign("HMAC", cryptoKey, enc.encode(raw));
  const expected = "hmacsha256=" +
    [...new Uint8Array(mac)].map((b) => b.toString(16).padStart(2, "0")).join("");

  return timingSafeEqual(expected, actual);
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

async function postToSlack(payload: any): Promise<void> {
  const token = Deno.env.get("SLACK_BOT_TOKEN");
  const channel = Deno.env.get("SLACK_RELEASES_CHANNEL_ID");
  if (!token || !channel) return;

  const event = summarizeAppleEvent(payload);
  await fetch("https://slack.com/api/chat.postMessage", {
    method: "POST",
    headers: {
      authorization: `Bearer ${token}`,
      "content-type": "application/json; charset=utf-8",
    },
    body: JSON.stringify({
      channel,
      text: event.text,
      unfurl_links: false,
      blocks: [
        {
          type: "section",
          text: { type: "mrkdwn", text: event.text },
        },
        {
          type: "context",
          elements: [
            { type: "mrkdwn", text: `<${APP_STORE_CONNECT_URL}|Open Aura in App Store Connect>` },
          ],
        },
      ],
    }),
    signal: AbortSignal.timeout(5_000),
  });
}

function summarizeAppleEvent(payload: any): { text: string } {
  const data = payload?.data ?? {};
  const attrs = data?.attributes ?? {};
  const eventType = attrs.eventType || data.eventType || data.type || "App Store Connect event";
  const prettyType = prettify(eventType);

  const oldState =
    attrs.oldValue || attrs.oldState || attrs.oldExternalBuildState || attrs.previousState || "";
  const newState =
    attrs.newValue || attrs.newState || attrs.newExternalBuildState || attrs.currentState || "";
  const timestamp = attrs.timestamp || attrs.createdDate || "";

  const pieces = [`*Aura App Store Connect:* ${prettyType}`];
  if (oldState || newState) {
    pieces.push(`Status: ${oldState ? `\`${oldState}\`` : "unknown"} -> ${
      newState ? `\`${newState}\`` : "unknown"
    }`);
  }
  if (timestamp) pieces.push(`Time: ${timestamp}`);

  return { text: pieces.join("\n") };
}

function prettify(value: string): string {
  return value
    .replace(/([a-z0-9])([A-Z])/g, "$1 $2")
    .replace(/[_-]+/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .replace(/\b\w/g, (m) => m.toUpperCase());
}
