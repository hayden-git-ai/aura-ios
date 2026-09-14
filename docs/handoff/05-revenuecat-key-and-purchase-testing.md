# Handoff 05 — Production RevenueCat key + web2wave forwarding + purchase testing (§2)

**For:** GPT desktop (code swap + RevenueCat/web2wave dashboards) with Hayden on
device for the actual purchase tests. This closes the last of the subscription
gap. Decision already made: **forward web (Paddle/web2wave) subs into RevenueCat**
so RevenueCat is the single source (the app already reads only RevenueCat).

## The one thing that silently breaks web purchases (read first)

The app identifies its RevenueCat customer by the **Supabase user id**:
`EntitlementService` calls `Purchases.shared.logIn(<supabase user id>)` after
sign-in, and reads the `aura_pro` entitlement off that customer.

So **web2wave forwarding must attach the Paddle subscription to the same
RevenueCat App User ID = the Supabase user id.** If web2wave forwards keyed on
email or a web2wave-native id that doesn't match, a real web subscriber stays
gated in the app. Verify the id mapping explicitly; don't assume.

## Facts

- Key to replace: `RevenueCatBootstrap.apiKey` in
  `Aura iOS/Aura iOS/Services/EntitlementService.swift` (currently the Test Store
  key `test_…`, line ~98). Stale comment on ~line 95 ("No-op until the package is
  added") should go — the package is added.
- Entitlement id: **`aura_pro`** (line ~51). Products `aura_annual` ($69.99/yr) +
  `aura_weekly` ($9.99/wk) attach to it (confirmed in handoff 04).

## Guardrail

The RevenueCat **public SDK key** (`appl_…`) is publishable and safe to ship in
the app. The RevenueCat **secret key** (`sk_…`) is server-only and must **never**
go in the app or repo. Swap in the `appl_` key only. Don't ship the `test_` key.

## Step A — Enable web2wave → RevenueCat forwarding

1. In the **web2wave** dashboard, enable forwarding of Paddle subscriptions into
   RevenueCat (RevenueCat integration / "send purchases to RevenueCat").
2. Configure it to identify the RevenueCat customer by the **Supabase user id**
   (the same value the app passes to `logIn`). If web2wave only knows the user by
   email, make sure the app's identity and the web funnel's identity reconcile to
   one RevenueCat customer (alias), or web subs won't unlock in-app.
3. In RevenueCat, confirm a **web2wave/Paddle store** integration is receiving
   events.

## Step B — Swap to the production public SDK key

1. RevenueCat dashboard → Project → **API keys** → **Apple App Store** → copy the
   **public SDK key** (`appl_…`), not the secret `sk_`.
2. In `EntitlementService.swift`, replace the `test_…` value of
   `RevenueCatBootstrap.apiKey` with that `appl_…` key, and delete the stale
   "No-op until the package is added" comment.
3. Build the app (`Aura iOS` scheme) and confirm it still compiles.

## Step C — Purchase testing (Hayden, on a device)

Gate behavior to confirm throughout: **not subscribed → paywall; subscribed →
app** (the `-subscribed` debug arg bypasses the gate; don't rely on it for these).

1. **App Store sandbox** (device + sandbox Apple ID):
   - Buy `aura_annual`; confirm the app unlocks.
   - Buy `aura_weekly` on a fresh sandbox account; confirm unlock.
   - **Restore:** delete + reinstall, tap Restore, confirm it re-unlocks.
   - **Lapse:** sandbox renewals expire in minutes; let one lapse and confirm the
     app re-gates to the paywall.
2. **Web / Paddle path:**
   - Buy through the web funnel as a user who is **signed into the app with the
     same Supabase account**.
   - Confirm web2wave forwards it into RevenueCat and the app unlocks on next
     launch/foreground `refresh()`.
   - This is the real test of the id-mapping caveat above.

## Report + checklist (§2)

Report the swap, the forwarding config, and each purchase-test result. Then tick:
- `RevenueCat API key … swap for the production appl_ key` → `[x]`.
- `Decide: web2wave -> RevenueCat forwarding vs direct query` → `[x]` (forwarding,
  enabled).
- `If not forwarding: add the web2wave query …` → mark **N/A (forwarding chosen)**.
- `Test: … App Store sandbox + web/Paddle + lapse + restore` → `[x]` once all pass.

**Note:** sandbox IAP and the web/Paddle round trip need a real device (App Store
sandbox doesn't run in the simulator), so this item overlaps the §5 device pass.
The code swap + forwarding config can be done now; the on-device tests happen
whenever the device session does.
