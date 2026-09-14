# Aura Launch Checklist

Everything between here and shipping, grouped by area. Status reflects the code as
of 2026-09-07, refreshed 2026-09-11.

Legend: `[x]` done in code · `[~]` partial · `[ ]` not started · **(device)** needs
real hardware to verify · **(dash)** a Supabase/App Store dashboard step.

---

## Current execution checkpoint — September13,2026

Latest lane evidence in launch-today/00-status.md supersedes historical unchecked items below. Reviewed baseline: Release simulator build and32tests passed;8account-isolation tests are included, native StoreKit excluded; independent review passed. Source fingerprint283f04fb… and privacy manifestf38ead4f… bind that evidence. iPhone-only is now approved and01must refresh affected signing/build evidence. Remaining agent work is signing/distribution, backend andwebsite publication/verification, subscriptions/revieweraccess, and App Store preparation. Device testing and finaldesign/Rorkmedia remain Hayden-owned. Do not restart resolved audits from old rows.

---

## 1. Accounts and Auth
- [x] Supabase Auth wired: Sign in with Apple (nonce + id token), Google (native id token), email/password
- [x] Real sessions stored by supabase-swift (Keychain)
- [x] Profile row auto-created on signup; name/email sync
- [x] App ships only the publishable key
- [ ] **(device)** Test each sign-in path on a real device (simulator has no Apple ID)
- [x] **(dash)** Auth rate limits reviewed (Supabase defaults kept) — 2026-09-08
- [x] **(dash)** Leaked-password protection ON + min password length 8 (needed the Pro upgrade) — 2026-09-08
- [x] **(dash)** Redirect allowlist clean (Site URL = https://www.downloadaura.app, zero wildcards; sign-in is native so no app redirects) — 2026-09-08
- [x] **(dash)** Custom SMTP live: Resend on the `mail.downloadaura.app` subdomain (verified, DKIM/SPF, tested end to end). Kept OFF the root domain because web2wave sends from it (quiz CNAME + amazonses SPF). Marketing/preorder mail should use a separate subdomain later. — 2026-09-08
- [ ] Test account-linking edge case: a web email/password user who later taps "Sign in with Apple"
- [x] **(dash)** Google OAuth ready for production: consent screen **Publishing status = In Production** (was Testing), User type External, no sensitive/restricted scopes so no Google verification triggered (no logo uploaded, on purpose). Branding filled: homepage/privacy/terms on downloadaura.app, authorized domain `downloadaura.app`. iOS OAuth client `509845153438-568v0jseqals794sj4iu6nf20ri0ghst` confirmed type iOS, bundle ID `Aura-App.Aura-iOS` (project "My First Project", `project-04cdf72f-6b44-4ded-90c`). — 2026-09-11

## 2. Subscriptions and entitlement (the main functional gap)
Two sources: RevenueCat (App Store IAP) and Paddle via web2wave (web funnel). Both
resolve client-side, so no Supabase entitlement table/webhook is needed for launch.
Gate scaffolding is built (seam + Mock/Live + AppGate + placeholder paywall); the
remaining items need external inputs.
- [x] `EntitlementService` seam (protocol + Mock + Live behind `#if canImport(RevenueCat)`)
- [x] `HabitStore.isSubscribed` resolved per identity/process; serialized billing transitions and owner-scoped web fallback. Never trust the legacy ownerless flag
- [x] Gate in `AppGate`: onboarding done + subscribed + setup -> app; not subscribed -> paywall (`-subscribed` debug bypass)
- [x] `subscribe()` / `restorePurchase()` wired to the seam
- [x] Architecture: **Superwall presents the paywall, RevenueCat is the billing backbone** (RevenueCat `PurchaseController` bridges them). `SuperwallKit` + RevenueCat packages added; `SuperwallBootstrap.start()` + `RevenueCatBootstrap.start()` at launch; app compiles clean against both.
- [x] `SubscriptionGateView` registers the `paywall` placement (no longer RevenueCatUI `PaywallView`)
- [~] **Superwall presentation configured; production acceptance blocked**: paywall 265638 Active; campaign `paywall` targets unsubscribed users at 100%. Live 2026-09-13 audit: products map to `pro` while RevenueCat/app use `aura_pro`; Apple ID 6809618566 and bundle Aura-App.Aura-iOS saved/reload-verified; ASC API not configured; published version not proven. SDK audit found no gating defect from pro/aura_pro alone; do not change mapping without reproduced need. Live corrections require action-time approval.
- [x] Products created in App Store Connect + RevenueCat + Superwall (`aura_annual` $69.99/yr, `aura_weekly` $9.99/wk)
- [x] RevenueCat API key: production Apple public SDK `appl_` key is in `RevenueCatBootstrap.apiKey` (publishable, safe to ship). — 2026-09-11
- [~] Superwall API key: production `pk_` key is in `SuperwallBootstrap.apiKey` (publishable, safe to ship)
- [x] **Decide:** enable web2wave -> RevenueCat forwarding (one source) vs. a direct web2wave query. Decision changed to **direct query / two-source entitlement** so web/Paddle revenue stays out of RevenueCat MTR; web2wave -> RevenueCat forwarding disabled and the dedicated RevenueCat secret key revoked. — 2026-09-11
- [x] Two-source web entitlement (chosen over forwarding): `web-entitlement` function deployed (`--no-verify-jwt`, holds `WEB2WAVE_API_KEY`), and the app OR's it into `currentlySubscribed` with a cached fallback (`EntitlementService`). Real web-purchase verification is the device/purchase test below. — 2026-09-12
- [ ] Test: Test Store purchase now; App Store sandbox + web/Paddle + lapse + restore before launch
- [x] **Cancel-survey feedback**: `ManageSubscriptionSheet` records the reason (enum rawValue) + notes to a `cancel_feedback` table via `SupabaseManager.sendCancelFeedback` (RLS insert-own, best-effort/fire-and-forget) before the Apple hand-off. Migration `20260914000000_cancel_feedback.sql` deployed. — 2026-09-12
- See the integration sketch at the end of this doc.

## 3. Sync (account-isolation blocker; device verification pending)
- [ ] **Account isolation:** local personal data survives sign-out and can merge into the next account. Support-cache isolation/hooks are patched, unverified; HabitStore personal-data isolation remains open. Require A -> B -> A checks with no cross-account upload.
- [x] Day-log (streak, journey, coins, charts)
- [x] Stats achievement counters
- [x] Habits + routines (last-write-wins)
- [x] Wall of Wins photos + avatar (private Storage)
- [x] All tables and the `user-media` bucket applied on the project
- [ ] **(device)** Verify cross-device sync end to end with real sessions

## 4. Photo verification / Gemini
- [x] verify-proof deployed; dual auth (Supabase JWT for signed-in, shared key fallback)
- [x] Per-user / per-device daily rate cap (`proof_usage`)
- [x] Kill switch (`PROOF_DISABLED`), verified live
- [x] Fixed model/prompt/schema, image byte cap, upstream timeout, minimal response
- [x] Supabase off free-tier auto-pause (upgraded to Pro 2026-09-08; a pause returned NXDOMAIN and silently passed every photo)
- [ ] **(device)** Real camera-photo verification round trip
- [ ] **(device)** Support-attachment round trip: send one support image from the app, confirm it lands in Crisp as a JPEG (server re-encode ran), then run `cleanup-orphaned-support` once and confirm the referenced/new file survives (not deleted). Backend is deployed + scheduled; this is the on-device smoke test. — 2026-09-12
- [ ] **(device)** Break-glass fallback test: set an invalid `GEMINI_API_KEY`, take one real photo verification, confirm the logs show the OpenAI `gpt-5-mini` fallback ran and returned a normal verdict (not a 502), then restore. Needs a device (photo-proof is camera-only). Log markers already in `verify-proof`. Started 2026-09-12 but not completed (Gemini restored); moved here. — 2026-09-12
- [x] Gemini on the **paid** tier: the key's project ("Photo Proof Aura", `gen-lang-client-0125222143`) is Tier 1 · Prepay ($100 prepaid, auto-refill under $25). Google no longer trains on the photos; higher limits. Same key, transparent to `verify-proof` (probed live: 401 gate, up). — 2026-09-09
- [x] Gemini quota ceiling set: GenerateContent 60 req/min/region on `gen-lang-client-0125222143` — 2026-09-09
- [x] **Cross-provider fallback deployed**: Gemini primary → OpenAI `gpt-5-mini` on any Gemini failure → fail-open only if both fail (a Google outage no longer free-passes everyone). `OPENAI_API_KEY` set (service-account, restricted, Photo Proof Aura project, 60 RPM, $50 hard spend cap). Probed live: up, gated, verify_jwt off. — 2026-09-09
- [x] **Fallback OpenAI key fixed.** Was stored under the wrong Supabase secret name (`supabase-verify-proof-fallback`), which `verify-proof` never reads, so the Gemini→OpenAI fallback was dead (a Gemini outage would 502 → app fail-opens). Resolved 2026-09-12: minted a fresh OpenAI key, set it as `OPENAI_API_KEY`, removed the mis-named secret. Fallback now active. — 2026-09-12
- [ ] (optional, secondary) Break-glass test of the fallback — moved to §5 device tests (needs a real photo verification).
- [ ] per-IP limit on the endpoint (deferred hardening)

## 5. Screen Time / blocking (device-only, entirely untested)
- [~] **Screen-time usage reminders wired; device verification pending**: current code registers the five `DeviceActivityEvent` thresholds (15m/45m/2h/4h/8h) against the Distracting selection, mirrors the Settings toggle to the app group, and posts notifications from `AuraShieldMonitor.eventDidReachThreshold`. Verify threshold delivery, daily reset, selection changes, and toggle-off suppression on hardware. The earlier "not wired" entry was stale. — 2026-09-13
- [ ] Set `DEVELOPMENT_TEAM` in Signing (step zero for any device build)
- [ ] **(device)** Family Controls authorization prompt
- [ ] **(device)** App picker returns real tokens; apps actually shield
- [ ] **(device)** Web-domain shielding: selected categories now apply to websites in both `LiveScreenTimeService` and the re-shielding extension; explicit Always Blocked websites refresh in block-everything mode as well (code correction 2026-09-13). On hardware, verify category-selected sites in **Safari**, buying time lifting only Distracting websites, re-shielding after force-quit/expiry, and switching selections/modes without stale blocks. Third-party browsers still need separate verification; do not infer support from Simulator tests.
- [ ] **(device)** Buying time lifts only the Distracting rule
- [ ] **(device)** Re-shield at expiry with the app force-quit; Live Activity ends (not stuck at 0:00)
- [ ] **(device)** Cross-lane app exclusivity (token set-subtract fixed in code; confirm on device)
- [ ] **(device)** Hard Mode (denyAppRemoval) sets and clears

## 6. Exercise / camera / pose (device-only, untested)
- [ ] **(device)** Pose skeleton tracks a moving body (orientation likely needs a fix)
- [ ] **(device)** Rep counting per exercise (thresholds were chosen, not measured)
- [ ] **(device)** Framing hints, success screen, both leave-early states
- [ ] **(device)** Focus-habit streak lands on the timer, not the photo; app-closed case

## 7. Storage and photo privacy
- [x] Private, owner-scoped `user-media` bucket (wins + avatar), authenticated-only, no public URLs
- [x] Verification photos are transient to Gemini, not stored
- [x] Upload hardening: **client side DONE** (every stored image routes through `ImageSanitizer` — decode check → 2048px cap → JPEG re-encode stripping EXIF/GPS → 8MB ceiling — for wins/avatar/support). **Server-side re-encode of the founder-facing path DONE + DEPLOYED:** `support-send` (redeployed `--no-verify-jwt`) downloads → re-encodes (imagescript, capped JPEG) → overwrites the support image in place before relaying to Crisp, so a modified client can't push a raw/metadata-bearing image to the founder. Scoped to the support path only — wins/avatar are RLS-scoped to the user's own private folder. Device smoke test (send one support image, confirm JPEG in Crisp) is in §5. — 2026-09-12
- [x] Abandoned-upload cleanup: **DEPLOYED + SCHEDULED** — `cleanup-orphaned-support` (`--no-verify-jwt`) deletes orphaned support-prefix files older than 24h that no `support_messages.media_url` points at. `CLEANUP_KEY` set (server-side, not printed); unauthorized call returns 401. Daily cron `cleanup-orphaned-support-daily` at `0 4 * * *` (job ID 2, active). First authorized run: `{"checked":0,"deleted":0}` (0 support objects currently exist, as expected). Referenced/new-file survival check folded into the §5 device smoke test. — 2026-09-12
- [ ] **Public privacy correction required**: 2026-09-13 browser audit contradicts earlier publication claim. Policy still denies Aura photo processing/cloud wins storage and omits OpenAI fallback, support attachments and replay details. Draft corrections prepared; publication pending approval.
- [x] App Store privacy answers match actual photo / analytics / AI behavior — data-safety / App Privacy label published to match (photos for verification, anonymous analytics via PostHog, crash data via Sentry, AI verification).

## 8. App Store Connect + submission requirements
- [x] Register the App IDs / Bundle IDs: `Aura-App.Aura-iOS`, `Aura-App.Aura-iOS.AuraShieldMonitor`, `Aura-App.Aura-iOS.AuraStatsReport`, and `Aura-App.Aura-iOS.AuraTimerWidget` registered in Apple Developer with required capabilities. — 2026-09-11
- [x] Create the **app record** in App Store Connect: Aura exists for `Aura-App.Aura-iOS`, SKU `aura-ios-001`, Apple ID `6809618566`. — 2026-09-11
- [x] **Family Controls (Distribution) entitlement** — granted by Apple (2026-07-31) AND declared in all three targets (`com.apple.developer.family-controls` in Aura iOS + AuraShieldMonitor + AuraStatsReport entitlements). Verified 2026-09-09. (Device authorization/shielding still to test on hardware.)
- [x] `DEVELOPMENT_TEAM` set in Xcode Signing for app + extensions: `ARJKQYBWDW` / Aura App LLC, automatic signing on. — 2026-09-11
- [x] Create the **subscription products** in App Store Connect and link them in RevenueCat: App Store Connect has `aura_annual` and `aura_weekly` in the Aura Pro group with pricing confirmed by Hayden, and RevenueCat links both App Store products to `aura_pro`. — 2026-09-11
- [x] **In-app account deletion** (Apple 5.1.1): `delete-account` edge function (verifies the caller's JWT, wipes Storage + deletes the auth user, cascades DB) + Settings → Account → Delete account with confirm/progress/error. **Round-trip verified 2026-09-12**: signed in (Google), deleted from the app → it signed out cleanly with no error (proving the function returned success), and the `auth.users` row confirmed gone in the Supabase dashboard. — 2026-09-12
- [x] `PrivacyInfo.xcprivacy` privacy manifest — declares UserDefaults (CA92.1/1C8F.1) + System Boot Time (35F9.1) Required Reason APIs, NSPrivacyTracking=false, and real collected data types (email/name/photos/user-content/anon-device-id, app-functionality only). Verified bundled; StoreKit test config excluded from release. — 2026-09-09
- [x] Purpose strings present (camera, HealthKit, photo library)
- [ ] Privacy and Terms pages render, but Terms §5.3 still promises an annual seven-day trial. Remove that and matching Pricing/FAQ claims; Aura offers no trials. Publication requires approval. — 2026-09-13
- [~] Metadata, age-rating worksheet, review notes, screenshot inventory and public-copy correction drafts prepared 2026-09-13. Public Contact page renders. Final iPhone/iPad screenshots, verified review account, processed build and ASC entry remain pending.
- [ ] **App Review demo account + notes** (submission blocker): the app is gated behind sign-in AND subscription, so App Review needs a pre-subscribed demo account plus notes explaining the loop and that Family Controls (self-use, blocks the user's own apps) only works on-device. Without it, review can't see the app. — 2026-09-11
- [ ] Pre-submission review pass with rork.com/app-store-reviewer before submitting. — 2026-09-11
- [x] Data-safety / privacy nutrition label filled to match reality — published (Name/Email/Photos/Support/User Content/User ID/Purchase History linked; Device ID/Crash/Diagnostic + PostHog Product Interaction not linked; Tracking No). — 2026-09-12

## 9. Security hardening (mostly done)
- [x] Owner-only RLS on every exposed table
- [x] Secrets off-device; service-role and Gemini keys server-only
- [x] App Transport Security strict; zero third-party app dependencies
- [x] Repo under version control
- [x] Endpoint auth + rate cap + kill switch
- [x] Dropped the vestigial `coins`/`current_streak`/`longest_streak` columns on `profiles` — 2026-09-08
- [x] **(dash)** Security + Performance Advisors resolved: revoked public EXECUTE on the SECURITY DEFINER trigger functions; wrapped `auth.uid()` as `(select auth.uid())` in every RLS policy (profiles/progress/storage). 0 warnings; the 2 remaining suggestions are correct-by-design (proof_usage RLS-no-policy is service-role-only; auth connection strategy is Supabase-managed). Migration `20260908010000_advisor_fixes.sql`. — 2026-09-08
- [x] Storage bucket limits: `user-media` private, 10 MB cap, MIME `image/jpeg,png,heic,webp` (app uploads image/jpeg) — 2026-09-08
- [x] On Supabase **Pro** (fixes free-tier auto-pause that took `verify-proof` offline) — 2026-09-08
- [x] **(dash)** Spend Cap decision: intentionally **OFF** (so real launch traffic can't throttle the DB), monitor via the Billing **Projected Costs** figure (~$25 base expected; investigate near $50). Supabase exposes no custom $-alert; it auto-emails on quota overage. — 2026-09-08
- [x] **(dash)** MFA/2FA on the Supabase account: Ente Auth (primary) + Microsoft Authenticator (backup) — 2026-09-08
- [x] **(dash)** 2FA on all business accounts (Apple Developer, Google Cloud, RevenueCat, Superwall, +) + 32-char unique passwords with special chars, rotated. — 2026-09-12
- [x] Install and run Gitleaks + TruffleHog (working tree + git history): TruffleHog 0 findings; Gitleaks flagged known-safe publishable/app-shipped keys plus one untracked local Superwall editor session file under `.agents`, with no committed service-role/Gemini/OpenAI/Crisp/DB/private signing secret found. — 2026-09-11
- [x] Reconcile the remote migration-history table: confirmed the early migration objects exist, then repaired remote history one migration at a time. `supabase migration list` now shows every local migration from `20260907000000` through `20260913000000` applied remotely. — 2026-09-11
- [ ] Deeper Storage hardening: EXIF strip, server-side re-encode, magic-byte checks, abandoned-upload cleanup (later pass)

## 10. Support chat (Crisp)
- [x] Two-way in-app support live: app -> `support-send` -> Crisp per-user conversation (+ Slack #support heads-up); founder reply in Crisp -> `crisp-events` -> app (~15s poll). Signed-out users get a sign-in prompt, not a silent drop. Verified end to end 2026-09-09. See [[aura-support-chat-and-booking]].
- [x] **Privacy policy:** Crisp (Crisp IM SAS) named as a support data processor (support messages + account name/email); live in the published policy 2026-09-11.
- [x] Turn OFF the Slack app's Event Subscriptions (retired the old `slack-events` reply path; #support is now a notify-only feed). Confirmed off in Slack and deleted the deployed `slack-events` function 2026-09-11.
- [x] Final redeploys: `support-send` (email-meta fix so Crisp does not email users) + `crisp-events` (logging stripped). Deployed 2026-09-11.
- [x] Rich support messages BOTH directions, Phase 1 (images): media columns on `support_messages` (migration `20260912000000`) applied 2026-09-11; `support-send` uploads user photos to Storage (signed URL) + posts to Crisp as a `file` message; `crisp-events` relays operator media (file/picture/audio/video/gif) back; app has a `+` PhotosPicker + inline image bubbles (optimistic + reconcile-by-URL) + tappable file chips for non-image operator attachments. Uses the existing private `user-media` bucket (images, 10 MB). **Phase 2 (files + video)** needs the bucket to allow more MIME types / larger size. **Phase 3 (audio memos)** needs record + playback UI. Speech-to-text already free via the iOS keyboard mic.

## 11. Deferred (post-launch, or when scale/economy demands it)
- [ ] Server-authoritative economy: immutable Aura ledger, server-derived streak, stored verification records, `complete_habit_verification` transaction. Needed only when points gain shared/real value.
- [ ] App Attest for the verification endpoint (when Gemini goes paid / abuse appears)
- [ ] RevenueCat/Paddle -> Supabase webhook + `user_entitlements` projection (durable server source of truth; lets the endpoint gate by subscription server-side)
- [ ] pgTAP RLS test matrix + CI gates (migrations-from-zero, negative RLS, secret scan, CodeQL)
- [ ] `private` schema: webhook_events, security_events, runtime_controls, api_usage_daily
- [ ] Independent mobile + backend penetration test before meaningful scale

---

## Entitlement integration sketch

There is no purchase gate today, so this is a fresh build, not a Mock swap. Target
shape:

```
enum EntitlementSource { case appStore, web }   // for analytics/debug only

@Observable @MainActor
final class EntitlementService {
    private(set) var isSubscribed = false

    // Call once at launch after the Supabase session is known, and on foreground.
    func configure(userID: String) { /* RevenueCat + web2wave identify(userID) */ }
    func refresh() async { /* read RevenueCat customerInfo (+ web2wave) -> isSubscribed */ }
}
```

- **RevenueCat:** `Purchases.configure(withAPIKey:appUserID:)` where `appUserID` is the
  Supabase user id, so one Aura account maps to its App Store subscription.
  `isSubscribed = customerInfo.entitlements["premium"]?.isActive == true`.
- **web2wave:** identify with the same Supabase user id; either
  (a) **forwarding on** — web2wave pushes Paddle subs into RevenueCat, so the app
  reads only RevenueCat (simplest, recommended), or
  (b) **two-source** — also query web2wave for web subscription status and OR it in.
- **Gate:** in `AppGate`, replace `onboardingDone && setupDone` with
  `onboardingDone && entitlements.isSubscribed && setupDone`; when not subscribed,
  present the paywall (onboarding screen 32) instead of advancing.
- **Identity timing:** call `configure(userID:)` after sign-in resolves the Supabase
  user id, and re-`refresh()` on foreground and after a purchase completes.
- **Do not** trust a local "isPremium" bool for anything server-paid. The only
  server-paid feature is Gemini verification, which is already rate-capped and
  free-tier, so a client-side gate is acceptable for launch; server-side gating is
  the deferred webhook item.

Blocking input before wiring: the RevenueCat API key and the entitlement id, the
web2wave forwarding decision, and the App Store Connect subscription products.
```
