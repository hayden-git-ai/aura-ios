/**
 * Scheduled cleanup of orphaned support attachments.
 *
 * The app uploads a support image to `user-media/<uid>/support/<uuid>.jpg`, then
 * calls `support-send` to record a `support_messages` row whose `media_url` points
 * at it. If that second step never lands (app killed, network drop), the file is
 * left with no message referencing it. This sweep deletes support files older than
 * a grace window that no `support_messages` row points to.
 *
 * Only touches user support attachment paths — wins and avatars are the user's own data
 * and are handled by account deletion, not here. Best-effort per file.
 *
 * Auth: not user-facing. Deploy with `--no-verify-jwt` and call it only from the
 * scheduler with the shared `CLEANUP_KEY` header. Idempotent.
 */

const GRACE_HOURS = 24;
const PAGE = 1000;

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method !== "POST") return json({ error: "POST only" }, 405);

  const key = Deno.env.get("CLEANUP_KEY");
  if (!key || request.headers.get("x-cleanup-key") !== key) {
    return json({ error: "unauthorized" }, 401);
  }

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) return json({ error: "server misconfigured" }, 500);

  const cutoff = new Date(Date.now() - GRACE_HOURS * 3_600_000).toISOString();

  let checked = 0;
  let deleted = 0;
  let offset = 0;
  // Page through candidate objects until a short page signals the end.
  for (;;) {
    const paths = await listSupportObjects(url, serviceKey, cutoff, offset);
    if (paths.length === 0) break;
    for (const path of paths) {
      checked++;
      if (!(await isReferenced(url, serviceKey, path))) {
        if (await deleteObject(url, serviceKey, path)) deleted++;
      }
    }
    if (paths.length < PAGE) break;
    offset += PAGE;
  }

  return json({ checked, deleted, cutoff }, 200);
});

/** Support-prefix objects older than the grace window (via the `storage` schema). */
async function listSupportObjects(
  url: string, serviceKey: string, cutoff: string, offset: number,
): Promise<string[]> {
  const query = new URLSearchParams({
    bucket_id: "eq.user-media",
    name: "like.*/support/*",
    created_at: `lt.${cutoff}`,
    select: "name",
    order: "name.asc",
    limit: String(PAGE),
    offset: String(offset),
  });
  const res = await fetch(`${url}/rest/v1/objects?${query}`, {
    headers: {
      authorization: `Bearer ${serviceKey}`,
      apikey: serviceKey,
      // storage.objects lives in the `storage` schema, not `public`.
      "accept-profile": "storage",
    },
  });
  if (!res.ok) return [];
  const rows = await res.json().catch(() => []);
  return Array.isArray(rows)
    ? rows.map((r) => (typeof r?.name === "string" ? r.name : "")).filter(Boolean)
    : [];
}

/** True if any support_messages row's media_url points at this object path. */
async function isReferenced(url: string, serviceKey: string, path: string): Promise<boolean> {
  const query = new URLSearchParams({
    media_url: `like.*${path}*`,
    select: "id",
    limit: "1",
  });
  const res = await fetch(`${url}/rest/v1/support_messages?${query}`, {
    headers: { authorization: `Bearer ${serviceKey}`, apikey: serviceKey },
  });
  if (!res.ok) return true; // On a query failure, keep the file (never delete blindly).
  const rows = await res.json().catch(() => null);
  return !Array.isArray(rows) || rows.length > 0;
}

async function deleteObject(url: string, serviceKey: string, path: string): Promise<boolean> {
  const res = await fetch(`${url}/storage/v1/object/user-media/${path}`, {
    method: "DELETE",
    headers: { authorization: `Bearer ${serviceKey}`, apikey: serviceKey },
  });
  return res.ok;
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}
