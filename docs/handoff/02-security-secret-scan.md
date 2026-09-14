# Handoff 02 — Secret scan + migration-history reconcile (§9)

**For:** GPT desktop (terminal + this repo on the same Mac).
**Goal:** run the pre-launch secret scan, and reconcile the Supabase migration
history that Handoff 01 flagged. Both are launch-checklist §9 items. No app/Swift
changes.

## Hard guardrails

1. **If a scan finds a real secret, do NOT paste its full value into chat.** Show
   the file + line and the first/last 4 characters only. Real leaked secrets get
   rotated + removed, not printed.
2. **Know the difference between a leaked secret and a shippable public key.**
   These are *safe by design* and are NOT findings to act on:
   - Supabase **publishable/anon** key (the app ships only this)
   - Superwall **`pk_`** key (publishable)
   - RevenueCat **public SDK `appl_`** key
   Real findings are: Supabase **service-role** key, **`GEMINI_API_KEY`**,
   **`OPENAI_API_KEY`**, any private signing key/`.p8`, DB passwords, Crisp
   secrets. These must live only in Supabase secrets / a keychain, never the repo.
3. For Part B: `supabase migration repair` only edits history bookkeeping. **Never**
   run `supabase db reset`. Verify a migration's objects really exist before
   marking it applied.

---

## Part A — Secret scan (Gitleaks + TruffleHog)

Install:

```bash
brew install gitleaks trufflehog
```

Run from the repo root. The git history is one commit, so scan both the working
tree and history:

```bash
# Gitleaks — working tree, then full history
gitleaks detect --source . --no-git --redact -v
gitleaks detect --source . --redact -v

# TruffleHog — filesystem, then git history, verified findings only
trufflehog filesystem . --results=verified,unknown
trufflehog git file://. --results=verified,unknown
```

Triage every hit against guardrail #2:
- **Publishable/public key** → ignore, note it as a known-safe match.
- **Real secret in the repo** → STOP and report it to Hayden immediately with the
  file/line (redacted value). Then: rotate the key at its provider, move it to
  Supabase secrets (`supabase secrets set NAME=...` from `server/`), and remove it
  from the file. Do not commit the removal until Hayden confirms.

Produce a short summary: total hits, how many were known-safe public keys, and any
real secrets (there should be none — the app is designed to ship only the
publishable Supabase key).

## Part B — Reconcile the Supabase migration history

Handoff 01 found the remote `supabase_migrations.schema_migrations` table is
missing older entries (some early migrations were applied via the SQL editor, not
`db push`). Fix the bookkeeping so a future `db push` behaves.

From `server/`:

```bash
supabase migration list
```

For every local migration that is **not** marked applied on remote, first confirm
its objects actually exist (use the dashboard SQL editor or Table editor — e.g.
`profiles`, `progress`, `proof_usage`, the storage policies, `support_messages`,
`support_threads`, `crisp_sessions`, `support_media` columns, `app_store_review_alerts`).
Only for the ones you've confirmed are truly applied:

```bash
supabase migration repair --status applied <version>   # e.g. 20260907010000
```

Do them one at a time; re-run `supabase migration list` after and confirm local
and remote now agree. If any migration is listed locally but its objects do NOT
exist on remote, do NOT repair it — report that one, because it means a real
migration never ran.

## Report + checklist

Tell Hayden: the scan summary (per Part A) and the before/after of the migration
list. Then in `docs/LAUNCH_CHECKLIST.md` §9, tick:
- `Install and run Gitleaks + TruffleHog` → `[x]` (with the result).
- `Reconcile the remote migration-history table` → `[x]` once list agrees.

**Not in this task:** enabling 2FA on Apple Developer / Google Cloud / RevenueCat /
Superwall (that's Hayden's — provider dashboards, not scriptable).
