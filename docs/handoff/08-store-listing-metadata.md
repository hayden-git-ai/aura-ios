# Handoff 08 — App Store listing metadata + review prep (§8)

**For:** GPT drafts the copy (description, subtitle, keywords, promo text, review
notes) and guides the App Store Connect form; **Hayden** makes the creative calls,
captures screenshots, fills the age-rating questionnaire, and submits. This is the
last ASC piece before the app can go to review.

## Read first — the three things that get an app rejected here

1. **DEMO ACCOUNT (highest risk).** The app is gated behind sign-in **and** an
   active subscription, so a reviewer with a fresh account hits the paywall and
   can't see the app. You **must** give App Review a working way in, in the "App
   Review Information" section:
   - Provide a **demo account** (email + password) that is already **subscribed**
     (grant it entitlement in RevenueCat, or a server flag), so the reviewer lands
     in the real app, not the paywall.
   - In the notes, say plainly how to use it and that the core loop is: do a habit
     → verify with a photo/timer → earn coins → unlock screen time.
2. **FAMILY CONTROLS context.** Aura uses the Family Controls entitlement. Explain
   in the review notes that it's a **self-use** screen-time/focus app: the user
   blocks **their own** apps and websites to build habits — not parental control of
   someone else. Note that Family Controls / app-shielding only works on a **real
   device**, not the simulator, so the reviewer should test blocking on hardware.
3. **SUBSCRIPTION disclosure.** Auto-renewable subs require the terms to be clearly
   presented. The paywall already has them; make sure the **description** also
   states plan lengths + prices (weekly $9.99, annual $69.99), that it auto-renews,
   and links to Terms (`/terms`) and Privacy (`/privacy`). (Guideline 3.1.2.)

## Required fields (App Store Connect → the app → App Information + the version)

- **Name** (≤30 chars): "Aura" (optionally "Aura: <short hook>"). — Hayden's call.
- **Subtitle** (≤30 chars): one-line hook. GPT drafts 3–5 options.
- **Primary/Secondary category:** candidates — **Productivity** (focus/blocking,
  where Opal/One Sec sit) or **Health & Fitness** (digital wellbeing; also matches
  HealthKit use). Pick primary for ASO; Hayden decides. GPT: give the tradeoff.
- **Promotional Text** (≤170 chars, editable anytime without review): GPT drafts.
- **Description** (≤4000 chars): GPT drafts — what Aura is (habit-gated screen-time
  blocker with the fox), the core loop, key features (photo/timer verification,
  app + website blocking, Hard Mode, streaks/coins), and the subscription
  disclosure block from note 3. Honest, no fabricated stats or fake reviews.
- **Keywords** (≤100 chars, comma-separated, no spaces after commas to save room):
  GPT drafts around screen time, focus, app blocker, habits, dopamine, study,
  productivity, digital wellbeing, self control. Don't repeat the app name or
  category (Apple indexes those already).
- **Support URL** (required): `https://www.downloadaura.app/help` (or `/contact`).
- **Marketing URL** (optional): `https://www.downloadaura.app`.
- **Privacy Policy URL:** already set to `https://www.downloadaura.app/privacy`.
- **Copyright:** e.g. "© 2026 Aura App LLC".
- **What's New / version notes:** simple for v1.

## Screenshots (Hayden — Claude can help capture)

- Apple needs the **6.9-inch iPhone** set (1320×2868 or 1290×2796), 3–10 images; it
  scales that set down to smaller phones. Add iPad only if the app targets iPad.
- Most screens render in the **simulator** (Home, Habits, Stats, Profile, paywall,
  onboarding) — fine for store screenshots. The **Family Controls picker / live
  blocking** only exists on a device; don't fake those, screenshot the real app UI.
- Claude can capture clean simulator screenshots of the key screens on request and
  hand them over for framing/captioning; say the word.
- Optional: a 15–30s **App Preview** video.

## Age rating

Fill the questionnaire honestly. No mature/objectionable content → expect 4+ (maybe
higher only if the questionnaire's own logic bumps it). Nothing to inflate.

## Submit

Attach the build (once TestFlight/processing is done), the metadata above, the demo
account + review notes, then submit for review. Don't submit until the demo account
actually lets a signed-out reviewer reach the app.

## Checklist (§8)

- `Screenshots, description, keywords, age rating, support URL` → `[x]` when filled.
- (The privacy nutrition label is already handled in the App Privacy form.)

**Depends on:** a processed build in App Store Connect (TestFlight), which needs the
device build + signing (done) and the app record (done). Purchase testing (§2, on
device) can run in parallel via TestFlight.
