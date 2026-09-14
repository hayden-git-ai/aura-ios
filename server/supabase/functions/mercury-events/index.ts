/**
 * Mercury webhook receiver for Aura finance alerts.
 *
 * Mercury calls this on transaction and balance events. The endpoint verifies
 * Mercury's HMAC signature with MERCURY_WEBHOOK_SECRET, optionally enriches
 * transaction events with the Mercury API, then posts a readable notice into
 * Slack #mercury-transactions.
 *
 * This endpoint is public (no Supabase JWT). Deploy with verify_jwt OFF.
 */

const MERCURY_API = "https://api.mercury.com/api/v1";
const MERCURY_DASHBOARD_URL = "https://app.mercury.com/transactions";
const DEFAULT_CHANNEL = "C0C0CMZAVPD"; // #mercury-transactions
const MAX_SIGNATURE_AGE_SECONDS = 5 * 60;

interface MercuryEvent {
  id?: string;
  resourceType?: string;
  resourceId?: string;
  operationType?: string;
  resourceVersion?: number;
  occurredAt?: string;
  changedPaths?: string[];
  mergePatch?: Record<string, unknown>;
  previousValues?: Record<string, unknown> | null;
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method !== "POST") return new Response("POST only", { status: 405 });

  const raw = await request.text();
  if (!(await verifyMercurySignature(request, raw))) {
    return new Response("bad signature", { status: 401 });
  }

  let event: MercuryEvent;
  try {
    event = JSON.parse(raw);
  } catch {
    return new Response("bad json", { status: 400 });
  }

  // The Mercury dashboard may subscribe this endpoint to all events. Keep the
  // Slack channel focused on transaction events only; deposits and card/checking
  // spends are all represented as transactions.
  if (event.resourceType === "transaction") {
    await postToSlack(event).catch(() => {});
  }
  return new Response("ok", { status: 200 });
});

async function verifyMercurySignature(request: Request, raw: string): Promise<boolean> {
  const secret = Deno.env.get("MERCURY_WEBHOOK_SECRET");
  const header = request.headers.get("mercury-signature");
  if (!secret || !header) return false;

  const parts = Object.fromEntries(
    header.split(",").map((part) => {
      const [key, ...rest] = part.trim().split("=");
      return [key, rest.join("=")];
    }),
  );
  const timestamp = parts.t;
  const signature = parts.v1?.toLowerCase();
  if (!timestamp || !signature) return false;

  const sentAt = Number(timestamp);
  if (!Number.isFinite(sentAt)) return false;
  if (Math.abs(Date.now() / 1000 - sentAt) > MAX_SIGNATURE_AGE_SECONDS) return false;

  const enc = new TextEncoder();
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    enc.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = await crypto.subtle.sign("HMAC", cryptoKey, enc.encode(`${timestamp}.${raw}`));
  const expected = [...new Uint8Array(mac)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");

  return timingSafeEqual(expected, signature);
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

async function postToSlack(event: MercuryEvent): Promise<void> {
  const token = Deno.env.get("SLACK_BOT_TOKEN");
  const channel = Deno.env.get("SLACK_MERCURY_TRANSACTIONS_CHANNEL_ID") || DEFAULT_CHANNEL;
  if (!token || !channel) return;

  const transaction = event.resourceType === "transaction"
    ? await fetchTransaction(event.resourceId || "").catch(() => null)
    : null;

  const alert = summarizeMercuryEvent(event, transaction);
  await fetch("https://slack.com/api/chat.postMessage", {
    method: "POST",
    headers: {
      authorization: `Bearer ${token}`,
      "content-type": "application/json; charset=utf-8",
    },
    signal: AbortSignal.timeout(5_000),
    body: JSON.stringify({
      channel,
      text: alert.text,
      unfurl_links: false,
      blocks: [
        {
          type: "section",
          text: { type: "mrkdwn", text: alert.text },
        },
        {
          type: "context",
          elements: [
            { type: "mrkdwn", text: `<${MERCURY_DASHBOARD_URL}|Open Mercury transactions>` },
          ],
        },
      ],
    }),
  });
}

async function fetchTransaction(transactionId: string): Promise<Record<string, unknown> | null> {
  const token = Deno.env.get("MERCURY_API_TOKEN");
  if (!token || !transactionId) return null;

  const res = await fetch(`${MERCURY_API}/transaction/${transactionId}`, {
    headers: {
      authorization: `Bearer ${token}`,
      accept: "application/json",
    },
    signal: AbortSignal.timeout(5_000),
  });
  if (!res.ok) return null;

  const body = await res.json();
  return (body?.data && typeof body.data === "object") ? body.data : body;
}

function summarizeMercuryEvent(
  event: MercuryEvent,
  transaction: Record<string, unknown> | null,
): { text: string } {
  if (event.resourceType === "transaction") {
    return summarizeTransaction(event, transaction);
  }

  const resource = prettify(event.resourceType || "Mercury resource");
  const amount = firstString(
    event.mergePatch?.availableBalance,
    event.mergePatch?.currentBalance,
    event.mergePatch?.inFlightBalance,
  );
  const lines = [
    `*Mercury ${resource} update*`,
    event.operationType ? `Type: \`${event.operationType}\`` : "",
    event.occurredAt ? `Time: ${formatTime(event.occurredAt)}` : "",
    amount ? `Balance: ${formatMoney(amount)}` : "",
    event.changedPaths?.length ? `Changed: ${event.changedPaths.join(", ")}` : "",
  ];
  return { text: lines.filter(Boolean).join("\n") };
}

function summarizeTransaction(
  event: MercuryEvent,
  tx: Record<string, unknown> | null,
): { text: string } {
  const amountValue = firstString(
    tx?.amount,
    event.mergePatch?.amount,
    event.previousValues?.amount,
  );
  const amountNumber = toNumber(amountValue);
  const isDeposit = amountNumber !== null && amountNumber > 0;
  const title = isDeposit
    ? "*Mercury deposit received*"
    : amountNumber !== null && amountNumber < 0
    ? "*Mercury spend recorded*"
    : "*Mercury transaction update*";

  const description = firstString(
    tx?.bankDescription,
    tx?.externalMemo,
    tx?.note,
    event.mergePatch?.bankDescription,
    event.mergePatch?.externalMemo,
    event.mergePatch?.note,
  );
  const status = firstString(tx?.status, event.mergePatch?.status);
  const occurredAt = firstString(
    tx?.postedAt,
    tx?.createdAt,
    tx?.occurredAt,
    event.mergePatch?.postedAt,
    event.occurredAt,
  );
  const cardOrAccount = summarizeCardOrAccount(tx);
  const category = categoryName(tx?.categoryData);

  const lines = [
    title,
    amountValue !== "" ? `Amount: *${formatMoney(amountValue)}*` : "",
    description ? `Vendor/description: ${escapeSlack(description)}` : "",
    cardOrAccount ? `Card/account: ${escapeSlack(cardOrAccount)}` : "",
    status ? `Status: \`${escapeSlack(status)}\`` : "",
    category ? `Category: ${escapeSlack(category)}` : "",
    occurredAt ? `Time: ${formatTime(occurredAt)}` : "",
    event.changedPaths?.length ? `Changed: ${event.changedPaths.join(", ")}` : "",
  ];

  return { text: lines.filter(Boolean).join("\n") };
}

function summarizeCardOrAccount(tx: Record<string, unknown> | null): string {
  if (!tx) return "";
  const card = objectValue(tx.card);
  const account = objectValue(tx.account);

  const cardName = firstString(card?.name, card?.nickname, card?.label);
  const cardLast4 = firstString(card?.lastFour, card?.last4, card?.lastFourDigits);
  if (cardName || cardLast4) {
    return [cardName || "Card", cardLast4 ? `...${cardLast4}` : ""].filter(Boolean).join(" ");
  }

  const accountName = firstString(account?.name, account?.nickname, tx.accountName);
  const accountLast4 = firstString(account?.lastFour, account?.last4, tx.accountLast4);
  if (accountName || accountLast4) {
    return [accountName || "Account", accountLast4 ? `...${accountLast4}` : ""]
      .filter(Boolean)
      .join(" ");
  }

  return "";
}

function categoryName(value: unknown): string {
  const category = objectValue(value);
  const custom = objectValue(category?.customCategory);
  const mercury = objectValue(category?.mercuryCategory);
  return firstString(custom?.name, mercury?.name, mercury);
}

function objectValue(value: unknown): Record<string, unknown> | null {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

function firstString(...values: unknown[]): string {
  for (const value of values) {
    if (value === null || value === undefined) continue;
    if (typeof value === "number" && Number.isFinite(value)) return String(value);
    if (typeof value === "string" && value.trim()) return value.trim();
  }
  return "";
}

function toNumber(value: string): number | null {
  if (!value) return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function formatMoney(value: string): string {
  const amount = toNumber(value);
  if (amount === null) return escapeSlack(value);
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
  }).format(amount);
}

function formatTime(value: string): string {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return escapeSlack(value);
  return new Intl.DateTimeFormat("en-US", {
    timeZone: "America/New_York",
    month: "short",
    day: "numeric",
    year: "numeric",
    hour: "numeric",
    minute: "2-digit",
    timeZoneName: "short",
  }).format(date);
}

function prettify(value: string): string {
  return value
    .replace(/([a-z0-9])([A-Z])/g, "$1 $2")
    .replace(/[_-]+/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .replace(/\b\w/g, (m) => m.toUpperCase());
}

function escapeSlack(value: string): string {
  return value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}
