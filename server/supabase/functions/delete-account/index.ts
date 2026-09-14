/**
 * Account deletion.
 *
 * Apple guideline 5.1.1(v) requires an in-app way to delete the account, not
 * just deactivate it. The client cannot delete its own auth.users row (that
 * needs the service role), so it calls this. This verifies who is asking from
 * their JWT, wipes their Storage folder, then deletes the auth user, which
 * cascades every owned row (profiles, progress) via ON DELETE CASCADE.
 *
 * Only ever deletes the caller's own account: the id comes from the verified
 * token, never from the request body, so nobody can delete someone else.
 */

import { checkedArrayPages, checkedFetch, checkedFetchChunks } from "../_shared/checked-fetch.ts";

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method !== "POST") {
    return json({ error: "POST only" }, 405);
  }

  // The caller must be a real signed-in user. The id is taken from the verified
  // token so it cannot be spoofed to target another account.
  const bearer = request.headers.get("authorization") ?? "";
  const uid = bearer.startsWith("Bearer ")
    ? await verifyUser(bearer.slice(7))
    : null;
  if (!uid) return json({ error: "unauthorized" }, 401);

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) return json({ error: "server misconfigured" }, 500);

  try {
    // 1. Storage does not cascade from auth.users, so clear the user's folder
    //    first. A list/delete failure must block auth deletion; otherwise the
    //    function would report success while retaining the user's media.
    await deleteUserMedia(url, serviceKey, uid);

    // 2. Delete the auth user. profiles + progress cascade from this.
    const del = await fetch(`${url}/auth/v1/admin/users/${uid}`, {
      method: "DELETE",
      headers: { apikey: serviceKey, authorization: `Bearer ${serviceKey}` },
      signal: AbortSignal.timeout(8_000),
    });
    if (!del.ok && del.status !== 404) {
      return json({ error: "delete failed", status: del.status }, 502);
    }
  } catch (_e) {
    return json({ error: "delete failed" }, 502);
  }

  return json({ deleted: true }, 200);
});

/**
 * Resolves the JWT to a user id, or null if it is missing, expired, or forged.
 * Same check the proof endpoint uses.
 */
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

/**
 * Removes every object under the user's `<uid>/` prefix in the user-media
 * bucket (Wall-of-Wins photos + avatar). Lists recursively because wins live in
 * a `wins/` subfolder, then deletes the collected paths in bounded calls.
 */
async function deleteUserMedia(url: string, key: string, uid: string): Promise<void> {
  const paths = await listAll(url, key, "user-media", `${uid}/`);
  if (paths.length === 0) return;
  await checkedFetchChunks("user media delete", paths, 1000, (chunk) => ({
    input: `${url}/storage/v1/object/user-media`,
    init: {
      method: "DELETE",
      headers: {
        apikey: key,
        authorization: `Bearer ${key}`,
        "content-type": "application/json",
      },
      signal: AbortSignal.timeout(8_000),
      body: JSON.stringify({ prefixes: chunk }),
    },
  }));
}

/** Recursively lists every file path under a prefix. Folders have a null id. */
async function listAll(url: string, key: string, bucket: string, prefix: string): Promise<string[]> {
  const out: string[] = [];
  const pageSize = 1000;
  const items = await checkedArrayPages<Record<string, unknown>>(
    "user media list",
    pageSize,
    (offset) => ({
      input: `${url}/storage/v1/object/list/${bucket}`,
      init: {
        method: "POST",
        headers: {
          apikey: key,
          authorization: `Bearer ${key}`,
          "content-type": "application/json",
        },
        signal: AbortSignal.timeout(5_000),
        body: JSON.stringify({ prefix, limit: pageSize, offset }),
      },
    }),
  );
  for (const item of items) {
    if (typeof item.name !== "string" || item.name.length === 0) {
      throw new Error("user media list returned invalid data");
    }
    const name = `${prefix}${item.name}`;
    if (item.id == null) {
      // A folder placeholder: recurse into it.
      out.push(...await listAll(url, key, bucket, `${name}/`));
    } else {
      out.push(name);
    }
  }
  return out;
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}
