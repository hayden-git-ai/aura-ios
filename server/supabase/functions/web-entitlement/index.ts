type WebEntitlementResponse = {
  active: boolean;
  store: string | null;
  expiresAt: string | null;
  error?: string;
};

const WEB2WAVE_SUBSCRIPTIONS_URL = "https://api.web2wave.com/api/user/subscriptions";
const ACTIVE_STATUSES = new Set(["active", "trialing", "past_due"]);

const corsHeaders = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
};

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return json({ active: false, store: null, expiresAt: null, error: "POST only" }, 405);
  }

  const bearer = request.headers.get("authorization") ?? "";
  const jwt = bearer.startsWith("Bearer ") ? bearer.slice(7) : null;
  if (!jwt) return json({ error: "unauthorized" }, 401);

  const user = await verifyUser(jwt);
  if (!user) return json({ error: "unauthorized" }, 401);

  const web2waveKey = Deno.env.get("WEB2WAVE_API_KEY");
  if (!web2waveKey) return inactiveWithError("server_misconfigured");

  try {
    const url = new URL(WEB2WAVE_SUBSCRIPTIONS_URL);
    url.searchParams.set("user", user.id);

    const upstream = await fetch(url, {
      headers: { api_key: web2waveKey },
      signal: AbortSignal.timeout(6_000),
    });

    if (upstream.status === 404) return json(inactive(), 200);
    if (!upstream.ok) return inactiveWithError(`web2wave_http_${upstream.status}`);

    const payload = await upstream.json().catch(() => null);
    if (!payload || typeof payload !== "object") return inactiveWithError("web2wave_bad_json");

    return json(resolveEntitlement(payload), 200);
  } catch (error) {
    const reason = error instanceof DOMException && error.name === "TimeoutError"
      ? "web2wave_timeout"
      : "web2wave_fetch_failed";
    return inactiveWithError(reason);
  }
});

async function verifyUser(jwt: string): Promise<{ id: string; email: string | null } | null> {
  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !anon) return null;

  try {
    const response = await fetch(`${url}/auth/v1/user`, {
      headers: { authorization: `Bearer ${jwt}`, apikey: anon },
      signal: AbortSignal.timeout(3_000),
    });
    if (!response.ok) return null;

    const user = await response.json();
    return typeof user?.id === "string"
      ? { id: user.id, email: typeof user?.email === "string" ? user.email : null }
      : null;
  } catch {
    return null;
  }
}

function resolveEntitlement(payload: Record<string, unknown>): WebEntitlementResponse {
  const subscriptions = Array.isArray(payload.subscription)
    ? payload.subscription
    : Array.isArray(payload.subscriptions)
      ? payload.subscriptions
      : [];

  const allowTestPayments = Deno.env.get("WEB2WAVE_ALLOW_TEST_PAYMENTS") === "1";
  const active = subscriptions
    .map(normalizeSubscription)
    .filter((subscription): subscription is NormalizedSubscription =>
      subscription &&
      ACTIVE_STATUSES.has(subscription.status) &&
      (allowTestPayments || subscription.realPayment !== false)
    )
    .sort((a, b) => compareExpiresAtDesc(a.expiresAt, b.expiresAt))[0];

  return active
    ? { active: true, store: active.store, expiresAt: active.expiresAt }
    : inactive();
}

type NormalizedSubscription = {
  status: string;
  store: string | null;
  expiresAt: string | null;
  realPayment: boolean;
};

function normalizeSubscription(value: unknown): NormalizedSubscription | null {
  if (!value || typeof value !== "object") return null;
  const subscription = value as Record<string, unknown>;
  const plan = subscription.plan && typeof subscription.plan === "object"
    ? subscription.plan as Record<string, unknown>
    : {};

  const status = typeof subscription.status === "string"
    ? subscription.status.toLowerCase()
    : "";
  const store = normalizeStore(
    stringOrNull(subscription.payment_system_label) ?? stringOrNull(plan.payment_system),
  );
  const expiresAt = normalizeDate(stringOrNull(subscription.next_charge_date));
  const realPayment = subscription.real_payment !== 0;

  return { status, store, expiresAt, realPayment };
}

function normalizeStore(value: string | null): string | null {
  if (!value) return null;
  const lowered = value.trim().toLowerCase();
  if (lowered.includes("paddle")) return "paddle";
  if (lowered.includes("stripe")) return "stripe";
  return lowered || null;
}

function normalizeDate(value: string | null): string | null {
  if (!value) return null;
  const normalized = value.includes("T") ? value : value.replace(" ", "T") + "Z";
  const date = new Date(normalized);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

function compareExpiresAtDesc(left: string | null, right: string | null): number {
  const leftTime = left ? new Date(left).getTime() : 0;
  const rightTime = right ? new Date(right).getTime() : 0;
  return rightTime - leftTime;
}

function stringOrNull(value: unknown): string | null {
  return typeof value === "string" ? value : null;
}

function inactive(): WebEntitlementResponse {
  return { active: false, store: null, expiresAt: null };
}

function inactiveWithError(error: string): Response {
  return json({ ...inactive(), error }, 200);
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
}
