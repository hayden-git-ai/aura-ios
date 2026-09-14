# Handoff 01 — Supabase backend deploys + migrations

**For:** GPT desktop (has terminal + browser + this repo on the same Mac).
**Goal of this task:** get the backend code that is already written but **not yet
deployed** live on the real Supabase project, apply the pending DB migrations, and
verify each piece. No app/Swift changes in this task.

This clears these launch-checklist items (`docs/LAUNCH_CHECKLIST.md`): §8 account
deletion deploy, §10 support-chat final redeploys + media migration, and confirms
§4 is fully live.

---

## Facts you need

- **Supabase project:** name `Aura App`, ref **`xafxoixbxaezijooutlw`**.
- **Project root for the CLI:** `server/` (the `supabase/` config dir lives at
  `server/supabase/`, holding `functions/` and `migrations/`). Run every
  `supabase` command from inside `server/`.
- **CLI is not on PATH.** Install once: `brew install supabase/tap/supabase`,
  then `supabase login`. The folder is already linked (`.temp/linked-project.json`
  has the ref); if a command says it isn't, run
  `supabase link --project-ref xafxoixbxaezijooutlw`.

## Hard guardrails (do not skip)

1. **Never print or paste a secret value** into the chat. Set secrets with
   `supabase secrets set NAME=...` and only ever refer to them by name.
2. **These migrations run against PRODUCTION.** Before pushing, run
   `supabase migration list` and read what is unapplied. The pending ones are all
   **additive** (new tables/columns). **Never** run `supabase db reset` (it wipes
   data).
3. Match each function's existing **`verify_jwt`** setting when redeploying (see
   the function table below). Getting this wrong makes a working endpoint start
   rejecting real users.
4. If anything is ambiguous or a command errors in a way these notes don't cover,
   **stop and report back** with the exact output rather than guessing.

---

## Step A — Apply pending migrations

From `server/`:

```bash
supabase migration list
```

Compare local vs remote. Local migrations present:

```
20260907* (proof_usage, profiles, progress, progress_stats, progress_library, user_media_storage)
20260908000000 drop_vestigial_profile_columns
20260908010000 advisor_fixes
20260909000000 support_messages
20260910000000 support_threads
20260911000000 crisp_sessions
20260912000000 support_media          <- expected UNAPPLIED (blocks support media)
20260913000000 app_store_review_alerts <- expected UNAPPLIED (for the review-poll fns)
```

Push whatever the list shows as unapplied:

```bash
supabase db push
```

Then re-run `supabase migration list` and confirm every migration shows applied on
remote. Report the before/after.

## Step B — Deploy `delete-account` (Apple 5.1.1 blocker)

This function is written (`server/supabase/functions/delete-account/index.ts`) but
not deployed. It verifies the caller's JWT itself and returns its own 401, so it
must deploy **without** the gateway JWT check:

```bash
supabase functions deploy delete-account --no-verify-jwt
```

Confirm the secrets it reads are present (do not print values):

```bash
supabase secrets list        # expect SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY to exist
```

(`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are provided to functions by the
platform; if `secrets list` doesn't show them that's normal — they're injected.)

**Verify it's up (unauthorized path):**

```bash
curl -s -o /dev/null -w "%{http_code}\n" -X POST \
  https://xafxoixbxaezijooutlw.supabase.co/functions/v1/delete-account
```

Expect **401** (or 405 for a GET). A **500** or connection error means it's
misconfigured — report it.

**Full round-trip test (do with Hayden, in the app):**
1. In Aura, sign up a throwaway account (email/password).
2. Settings → Profile → Edit → **Delete account**, confirm.
3. In the Supabase dashboard: Auth → Users shows the user **gone**, and Storage →
   `user-media` has no folder for that user id.
Report pass/fail.

## Step C — Redeploy `support-send` + `crisp-events`

These are already live, but need a redeploy to pick up the latest local code
(support-send: email-meta fix so Crisp doesn't email users; crisp-events: logging
stripped; both: the image/media path from migration `20260912000000`).

Match their current `verify_jwt` setting. `support-send` is called by signed-in
**and** signed-out users and verifies identity in its own body, and `crisp-events`
is a webhook Crisp calls with a shared secret — **both deploy `--no-verify-jwt`**:

```bash
supabase functions deploy support-send  --no-verify-jwt
supabase functions deploy crisp-events   --no-verify-jwt
```

Confirm the Crisp secrets they rely on still exist by name (don't print them):

```bash
supabase secrets list   # expect the CRISP_* keys the functions use to be present
```

**Verify up:**

```bash
for fn in support-send crisp-events; do
  printf "%s -> " "$fn"
  curl -s -o /dev/null -w "%{http_code}\n" -X POST \
    "https://xafxoixbxaezijooutlw.supabase.co/functions/v1/$fn"
done
```

Expect a 4xx (bad/empty body or unauthorized), **not** 5xx. Then in the app, send
one support message and confirm it lands in Crisp + the `#support` Slack heads-up,
and a Crisp reply comes back in-app within ~15s.

## Step D — Report + update the checklist

When done, tell Hayden exactly:
- which migrations were applied,
- the HTTP codes each function returned,
- delete-account round-trip result.

Then in `docs/LAUNCH_CHECKLIST.md`, tick:
- §8 in-app account deletion — flip `[~]` to `[x]` **only after** the round-trip passes.
- §10 "Final redeploys: `support-send` + `crisp-events`" — `[x]`.
- §10 rich support messages — note the migration is applied; move the "PENDING run
  migration + redeploy" wording to done for Phase 1.

**Not in this task (separate handoffs):** turning off the old Slack Event
Subscriptions (§10 — Slack dashboard), App Store Connect setup (§8), the
production RevenueCat key + web2wave decision (§2). Do those next, one at a time.
