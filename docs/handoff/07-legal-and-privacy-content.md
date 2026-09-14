# Handoff 07 — Legal + privacy content (§7, §8, §10)

**For:** GPT can draft the policy/terms text and the App Store data-safety answers;
**Hayden** publishes the web pages and fills the App Store Connect form. **A privacy
policy + terms are legal documents** — have a human (ideally a lawyer) review before
publishing. The one hard rule: everything must match what the app *actually* does
(honesty gate) — no boilerplate claiming practices Aura doesn't have, and no
omission of ones it does.

## The pages must live at these exact URLs (the app already links them)

From `AuraLink.swift` — if any 404s, it's a broken link in-app and an App Store
review risk:
- **Privacy:** `https://www.downloadaura.app/privacy`  ← required, §8
- **Terms:** `https://www.downloadaura.app/terms`  ← required, §8
- Help: `https://www.downloadaura.app/help`
- Report a bug: `https://www.downloadaura.app/report-a-bug`
- Contact: `https://www.downloadaura.app/contact`
- Manage subscription: `https://www.downloadaura.app/manage-subscription`

## Data-practices inventory (ground truth — the policy MUST reflect exactly this)

Pulled from the code + prior checklist work. If a drafter adds anything not on this
list, verify it against the code first.

**Data collected / handled**
- **Account:** email + name (Supabase Auth). Sign-in via Apple, Google, or
  email/password.
- **Verification photos:** transmitted to **Google Gemini** (primary) or **OpenAI
  `gpt-5-mini`** (fallback) to verify a habit. Transient — not stored by Aura for
  verification. (Gemini is on the paid tier; Google does not train on them.)
- **Wall-of-Wins photos + avatar:** **stored** in Supabase private, owner-scoped
  Storage (`user-media`), no public URLs.
- **Screen Time / app+website usage:** selected via Apple Family Controls. Tokens
  are **opaque** and stay on-device / in the app group; Aura never receives
  readable app or site names, and this data is not sent to a server.
- **Support chat:** messages + account name/email go to **Crisp (Crisp IM SAS)** as
  a support processor, with an internal Slack heads-up.
- **Subscriptions/billing:** **RevenueCat** (App Store IAP), **web2wave + Paddle**
  (web funnel), **Superwall** (paywall presentation).
- **Transactional email:** **Resend** (from `mail.downloadaura.app`).
- **Device identifier:** an anonymous device id, app-functionality only. No tracking
  (`NSPrivacyTracking=false` in `PrivacyInfo.xcprivacy`).

**Third-party processors to name:** Supabase, Google (Gemini AI + Google Sign-In),
OpenAI, RevenueCat, Superwall, web2wave, Paddle, Crisp, Resend.

## Step 1 — Draft + publish the Privacy Policy (`/privacy`)

Must state, at minimum:
- What's collected (the inventory above) and why (all app-functionality; no
  advertising/tracking).
- **Photos:** verification photos are transmitted to Google/OpenAI for verification
  and not retained for that; Wall-of-Wins photos + avatar are stored privately.
- **Screen Time data stays on device** (opaque tokens; no readable names leave the
  device).
- The processor list above, Crisp explicitly included as a support processor.
- Account deletion is available in-app (Settings → Profile → Edit → Delete account)
  and wipes the account + stored media.
- Contact + effective date.

## Step 2 — Draft + publish the Terms (`/terms`)

Standard subscription-app terms: subscription + auto-renew disclosure (weekly
$9.99 / annual $69.99, managed by Apple or the web biller), acceptable use, the
habit-verification / screen-time nature of the service, disclaimers, governing law,
contact. Keep the auto-renew language consistent with what the paywall shows.

## Step 3 — App Store Connect data-safety / privacy answers

Fill the App Privacy section to match the inventory **and** `PrivacyInfo.xcprivacy`
(email, name, photos, user content, anonymous device id; app-functionality only;
tracking = No). The ASC answers and the manifest must not disagree.

## Step 4 — Verify the other linked pages exist

Make sure `/help`, `/contact`, `/report-a-bug`, and `/manage-subscription` resolve
(even simple pages), so no in-app link 404s during review.

## Checklist

- §8 `Privacy policy + terms pages live (downloadaura.app)` → `[x]` when both publish.
- §7 `Privacy policy states photos transmitted for verification AND Wall-of-Wins
  stored` → `[x]`.
- §8 `Data-safety / privacy nutrition label filled to match reality` → `[x]`.
- §7/§8 `App Store privacy answers match actual photo/analytics/AI behavior` → `[x]`.
- §10 `Privacy policy: add Crisp as a support data processor` → `[x]`.
