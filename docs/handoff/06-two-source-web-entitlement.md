# Handoff 06 — Switch to two-source web entitlement (revert forwarding) (§2)

**Decision changed:** we are **dropping web2wave → RevenueCat forwarding** and going
**two-source** so web (Paddle) revenue does not count toward RevenueCat MTR.
RevenueCat stays the source for App Store IAP; web subscriptions are checked
separately and OR'd into the gate.

**Split:** GPT does Part A (undo) + Part B (edge function). The app change (Part C)
is iOS — Claude will implement it against the fixed contract below; GPT does not
touch Swift.

## Part A — Undo the forwarding (GPT, dashboards)

1. In **web2wave**, disable the RevenueCat forwarding/integration.
2. In **RevenueCat**, **revoke/delete the dedicated secret key** created for
   web2wave (it's now unused; don't leave a live server key sitting around).
3. Confirm RevenueCat is no longer receiving integration events from web2wave.

**Guardrail:** revoking that secret key is safe — the app uses the separate public
`appl_` SDK key. Do **not** touch the `appl_` key. Leave the App Store IAP path
(RevenueCat) exactly as it is.

## Part B — `web-entitlement` edge function (GPT, Supabase + web2wave API)

Create a new Supabase function that the app calls to learn a user's **web**
subscription status. It holds the web2wave key server-side so the app never does.

- Deploy `--no-verify-jwt` (it verifies the caller's bearer itself, like
  `delete-account`).
- **Input:** the caller's Supabase JWT (Authorization: Bearer). Extract the
  verified user id (and email if web2wave needs it).
- **Lookup:** query web2wave's API (server-held secret `WEB2WAVE_API_KEY` via
  `supabase secrets set`, never printed) for that user's subscription, keyed by
  **external user id = the Supabase user id** — the same id the app passes to
  `Purchases.shared.logIn(...)`. GPT: pull the exact web2wave endpoint, auth
  header, and the correct lookup field (external id vs email) from web2wave's API
  docs/dashboard; if web2wave only keys by email, use the JWT's email claim and
  say so in the report.
- **Response contract (fixed — the app builds against this, do not change shape):**
  ```json
  { "active": true, "store": "paddle", "expiresAt": "2026-10-01T00:00:00Z" }
  ```
  `active` boolean (required); `store` string or null; `expiresAt` ISO-8601 or null.
- **Error behavior:** on any upstream/web2wave error, return HTTP 200 with
  `{"active": false, "store": null, "expiresAt": null}` **and** a distinct
  `"error": "<reason>"` field so the app can tell "confirmed not subscribed" from
  "couldn't reach web2wave." (The app caches last-known-good so a transient error
  doesn't instantly re-gate a paying web user — see Part C.)
- **Secrets:** `WEB2WAVE_API_KEY` server-only. Never in the app or repo.

**Verify:** `curl` an empty/unauth POST → expect 401. Then a real signed-in user
with a web sub → `active:true`; a user without → `active:false`.

## Part C — App wiring (Claude, iOS — do NOT edit in GPT)

In `EntitlementService.swift`:
- Add a small `WebEntitlementService` that POSTs to `web-entitlement` with the
  Supabase JWT and decodes the contract above.
- In `LiveEntitlementService`, compute `isSubscribed = revenueCatActive ||
  webActive`.
- **Cache** the last web result (UserDefaults, with a TTL, e.g. 24h). If a fresh
  web query fails (the `error` field), fall back to the cached value rather than
  instantly gating a web subscriber. RevenueCat-active users are never affected by
  a web-query failure.
- No web2wave key in the app; it only calls the Supabase function with the user's
  JWT.

## Checklist (§2)

- `Decide: forwarding vs direct query` → mark **direct query chosen**.
- `If not forwarding: add the web2wave query and OR it into currentlySubscribed`
  → this is now the active task; tick when Parts B + C are live and tested.
- Revert/adjust any "forwarding enabled" note from the prior handoff.

**Blocking input GPT must surface:** web2wave's subscription-status API details
(endpoint, auth, and whether it keys by external user id or email). Part C's app
code is ready to write against the fixed contract once Part B's function exists.
