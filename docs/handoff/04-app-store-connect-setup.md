# Handoff 04 — App Store Connect + signing setup (§8)

**For:** Hayden (driving, logged into the Apple Developer account) with GPT desktop
guiding + verifying. This is the **critical-path** blocker: no TestFlight, no
subscriptions, no submission until it's done.

Most of this needs Hayden's Apple login + 2FA, so GPT's job is to walk each step,
verify state, and do the repo/Xcode parts. **Nothing here submits the app for
review** — this is setup only.

## Facts

- **App name:** Aura · **Primary bundle ID:** `Aura-App.Aura-iOS`
- **Extension bundle IDs** (each needs its own App ID):
  - `Aura-App.Aura-iOS.AuraShieldMonitor` (DeviceActivity monitor)
  - `Aura-App.Aura-iOS.AuraStatsReport` (DeviceActivityReport)
  - `Aura-App.Aura-iOS.AuraTimerWidget` (Live Activity widget)
- **Family Controls (Distribution) entitlement is already granted** by Apple and
  declared in the targets (checklist §8). Do not re-request it.
- **`DEVELOPMENT_TEAM` is currently unset** in the Xcode project.
- Capabilities per target live in the `.entitlements` files — GPT: read them to
  enumerate exactly what each App ID needs (Family Controls, App Groups, etc.)
  before registering, rather than guessing.

## Guardrails

- Do **not** change any bundle identifier.
- Do **not** submit for review or start a TestFlight external test here.
- Keep Family Controls + App Groups on every target that already declares them;
  a dropped capability breaks blocking/shared state.

## Step 0 — Paid Apps agreement + tax + banking (the real gate)

Subscriptions do nothing until this is signed. In App Store Connect →
**Business** (Agreements, Tax, and Banking):
1. Sign the **Paid Applications** agreement.
2. Complete **tax** forms and **banking** details.
Until this shows "Active", subscription products can't go live. Do this first.

## Step 1 — Register the App IDs (developer.apple.com → Identifiers)

For the main app and each of the 3 extensions, register the App ID with the
capabilities its `.entitlements` declares:
- Main `Aura-App.Aura-iOS`: Family Controls, App Groups (+ whatever else its
  entitlements list), Live Activities/Push as declared.
- `AuraShieldMonitor`: Family Controls, App Groups.
- `AuraStatsReport`: Family Controls, App Groups.
- `AuraTimerWidget`: App Groups.
(Xcode automatic signing can create these on first device build, but registering
explicitly avoids a signing scramble later. GPT: cross-check against the
entitlement files.)

## Step 2 — Xcode signing

In Xcode → each target → Signing & Capabilities:
1. Select the Team (this sets `DEVELOPMENT_TEAM`), enable **Automatically manage
   signing**.
2. Confirm every target resolves a provisioning profile with its capabilities.
Report the Team ID once set (it's not a secret; it's on every App ID).

## Step 3 — Create the app record (App Store Connect → Apps → +)

- Platform: iOS · Name: **Aura** · Primary language · Bundle ID:
  `Aura-App.Aura-iOS` · SKU (any stable string, e.g. `aura-ios-001`) · Full access.
This must exist before subscriptions, TestFlight, or submission.

## Step 4 — Subscriptions (reconcile, then link)

The checklist is inconsistent here: §2 says the products were created in ASC +
RevenueCat + Superwall, but §8 lists "create subscription products" as not
started. **Verify the real state first**, don't assume:
1. App Store Connect → the app → **Subscriptions**: confirm a subscription group
   exists containing `aura_annual` ($69.99/yr) and `aura_weekly` ($9.99/wk), each
   with pricing, a localized display name/description, and a review screenshot.
   Create/complete whatever's missing.
2. In **RevenueCat**, confirm both products are attached to the `aura_pro`
   entitlement and mapped to the App Store products. (The production `appl_` key
   swap is handoff #5, not here.)
Report exactly what existed vs. what you had to create.

## Step 5 — Store listing metadata (can run in parallel; finish before submit)

Screenshots, description, keywords, age rating, support URL, and the **privacy
policy URL** (the policy content itself is the legal handoff). Not blocking for
TestFlight, but required for submission.

## Report + checklist

In `docs/LAUNCH_CHECKLIST.md` §8, tick as each completes:
- Register App ID / Bundle ID → `[x]`
- `DEVELOPMENT_TEAM` set in Xcode Signing → `[x]`
- Create the app record → `[x]`
- Create subscription products + link in RevenueCat → `[x]` (or note what remained)
Leave screenshots/metadata and the privacy-policy URL unticked until they're real.

**Depends on this task:** handoff #5 (production RevenueCat key + purchase testing)
can't finish until the app record + Paid Apps agreement + products exist.
