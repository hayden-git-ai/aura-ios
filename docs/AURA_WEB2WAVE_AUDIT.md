# Aura Source-of-Truth Repository Audit

**Purpose:** factual input for a Web2Wave engagement brief.
**Method:** direct inspection of the repository. Nothing inferred from what a
similar app would normally contain.
**Repo root:** `/Users/haydenberio/Desktop/Aura iOS`
**Audit date:** 2026-08-10

**Status vocabulary used throughout:** IMPLEMENTED / PARTIALLY IMPLEMENTED /
CONFIGURED BUT NOT CLEARLY USED / REFERENCED-PLANNED / NOT FOUND /
NOT DETERMINABLE FROM CODEBASE.

---

## FIVE FINDINGS THAT CHANGE THE BRIEF

Read these before anything else. Each is evidenced in the sections below.

1. **There are two onboarding implementations. The larger, fully-specified one is
   dead code.** `OnboardingCoordinator` + `OnboardingStep` (52 screens) is
   referenced only by other files in its own island and never by the app's launch
   gate. The live flow is `Part1Flow` + `Part2Flow`, driven by
   `RootGate.swift`.

2. **There is no paywall in the live onboarding flow.** The final screen's CTA is
   a placeholder that advances into the app. `PurchaseService` is never called by
   any live code path.

3. **The app emits zero analytics events.** A complete, well-designed event
   taxonomy exists (`OnboardingAnalytics`), but every call site is inside the dead
   coordinator. The live flow logs nothing, and the only transport is a
   `print()` in DEBUG.

4. **There is no attribution, deep linking, or user identity of any kind.** No URL
   scheme, no associated domains, no SDKs, no accounts, no user ID. A web user
   cannot currently be matched to an app user by any mechanism.

5. **The blocking system is written but has never executed.** Family Controls
   cannot run in the iOS Simulator, and there is no evidence in the repo of a
   device build having been run.

---

# 1. Executive Product Summary

**What is Aura?**
An iOS app (SwiftUI, deployment target **26.5**, bundle ID **`Aura-App.Aura-iOS`**)
that blocks distracting apps by default and unlocks them only in exchange for
completed real-world habits. Source: `PRODUCT.md` lines 8–22;
`Aura iOS.xcodeproj/project.pbxproj` (`IPHONEOS_DEPLOYMENT_TARGET = 26.5`,
`PRODUCT_BUNDLE_IDENTIFIER = "Aura-App.Aura-iOS"`).

**Core user problem** (from `PRODUCT.md:8–14`): "People who default to
doomscrolling and want to replace it with intentional habits."

**Core behavioral mechanism:** screen time is a currency that must be earned.
Habits pay **coins**; coins buy **minutes**; minutes unlock the apps.
`HabitStore.swift`: `coinBalance` (line 651), `chargeForScreenTime` (line 1014),
`grantScreenTime` (line ~1011), `unlock(seconds:)`.

**What a user must do to earn screen time:** four methods, all IMPLEMENTED as
UI flows:
- **Photo Proof.** Photograph the habit, AI verifies
- **Camera Reps.** On-device rep counting
- **Lock In.** A timed focus session (phone down)
- **Passive Income.** Claim Apple Health activity
Source: `Models/Habit.swift:10–35` (`HabitCategory`), `App/QuickAction.swift`.

**After successful verification:** for a *focus* habit, a countdown session
starts and pays out on completion; for a *quick* habit, coins are granted
instantly. `PhotoProofFlowRoot.swift:100–112`.

**After failed verification:** the user is routed to `PhotoProofRetryView`. No
attempt limit, no cooldown, no penalty found.

**What Aura can block:** individual apps, whole Apple activity categories, and
web domains, plus Apple's automatic adult-content web filter.
`LiveScreenTimeService.apply(_:)`.

**Difference from a traditional blocker:** a traditional blocker is a schedule or
a limit. Aura's shield has no timer of its own. It lifts only when the user
spends earned currency. Additionally, four "intervention" experiences run when a
blocked app is opened (`Features/Intervention/`).

**Major features IMPLEMENTED:** habit catalogue and custom habit builder; four
earn methods; three-rule blocking model; coin wallet and screen-time purchase;
streaks with freezes; 90-day consistency board; Stats (two modes); Live Activity
/ Dynamic Island; four interventions; Settings with difficulty, reminders,
intervention styles, cancellation flow.

**Planned but unfinished:** the paywall; analytics transport; real Screen Time
execution on device; live photo verification (endpoint not deployed); onboarding
persistence into the app (`HabitStore+AppConfig.swift` TODO); real Screen Time
statistics (report extension exists, unverified); user accounts.

**Primary journey today:** launch → Part 1 onboarding (21 screens) → Part 2
onboarding (11 screens) → **straight into the app, no paywall** → Home (Gate).

**Concise description (codebase only):**
Aura is an iOS screen-time app that inverts the usual blocker model: distracting
apps stay shielded, and the only way to open them is to earn minutes by doing
something real. Four earn methods are built: an AI-verified photo, camera-counted
reps, a timed focus session, and synced Apple Health activity, each paying coins
at rates set per habit. Coins convert to minutes at 1:1 and are spent from a
balance that resets daily. Blocking is organised into three always-on rules:
Always Allowed, Always Blocked, and Distracting, with only the Distracting rule
lifting when time is bought. Retention is carried by streaks with earned freezes,
a 90-day board, a coin economy, and a fox mascot. A 32-screen onboarding flow
collects name, age, life stage, gender, acquisition source, screen-time estimates
and goals, then requests notification and Screen Time permissions. The app
currently ends onboarding without a paywall, emits no analytics, and has no user
identity or attribution of any kind.

---

# 2. Core Product Mechanic

## The loop

| Stage | Implementation | Status |
|---|---|---|
| Method selection | FAB → 4-card popover, `App/FABMenuRow.swift`, `App/QuickAction.swift` | IMPLEMENTED |
| Habit selection | `Features/AddHabit/`, catalogue in `HabitStore.defaultHabits` | IMPLEMENTED |
| Duration | `Habit.defaultFocusMinutes`, user-adjustable in session sheet | IMPLEMENTED |
| Photo capture | `Features/PhotoProof/PhotoCaptureController.swift` (AVFoundation) | IMPLEMENTED |
| Camera permission | `NSCameraUsageDescription` in project.pbxproj | IMPLEMENTED |
| AI verification | `Services/ProofVerifier.swift` seam; `MockProofVerifier` active | PARTIALLY IMPLEMENTED |
| Success | `PhotoProofFlowRoot.startAndDismiss` (line 100) | IMPLEMENTED |
| Failure | `PhotoProofRetryView` | IMPLEMENTED |
| Earned currency | `HabitStore.coinBalance` (line 651) | IMPLEMENTED |
| Purchase of time | `chargeForScreenTime` (line 1014) | IMPLEMENTED |
| Unlock | `unlock(seconds:)` | IMPLEMENTED |
| Re-lock (app alive) | `HabitStore.tick()` → `lock()` | IMPLEMENTED |
| Re-lock (app dead) | `AuraShieldMonitor` DeviceActivity extension | IMPLEMENTED, NEVER EXECUTED |
| Live Activity | `Services/LiveActivityController.swift` + `AuraTimerWidget` | IMPLEMENTED |

## Earned-time calculation

- **Focus habits:** `Int((Double(minutes) * habit.rewardRate / 60).rounded())`
  `PhotoProofFlowRoot.swift:104`. Rate is coins *per hour*.
- **Quick habits:** flat `habit.rewardMinutes`, paid immediately, `oncePerDay`.
- **Exercise:** `units × rate`, zero until `unitsToStartEarning` reached:
  `Models/ExerciseModels.swift:34–37`. **No cap.**
- **Health:** per-unit coin rates, `Services/HealthService.swift`.
- **Coins → minutes is 1:1.** `chargeForScreenTime(minutes:)` compares
  `coinBalance >= minutes` directly.

## Wallet behaviour

`coinBalance = todayEarnedCoins − spentToday`, both dated, so the **balance
resets at midnight** and unspent coins are lost. Documented deliberately at
`HabitStore.swift:645–656`.

## Emergency bypass

`useEmergencyUnlock()` (`HabitStore.swift:878`) grants **45 minutes** free.
Gated by `hardMode` (line 123) which disables it. `emergencyUnlockUsed` is a
plain Bool with a **TODO: "wire to a real weekly-reset scarcity timer"**
(line 669–671). I.e. the weekly allowance is not enforced.

## Can users cheat?

Evidenced weaknesses:
- Verification fallback **passes** on any network/endpoint failure
  (`LiveProofVerifier.fallbackPasses`, default `true`). Airplane mode currently
  yields a pass.
- `MockProofVerifier` (live today) **always passes**.
- Emergency Unlock has no real weekly limit (TODO above).
- Exercise earning has no cap.
- Apple's shield can be bypassed by deleting the app; no protection found.

Safeguards found: two separate `ManagedSettingsStore`s so clearing the soft rule
cannot lift the hard rule; `hardMode`; adult-content filter on the hard store.

## Full habit catalogue

All from `Store/HabitStore.swift:24–125`. `rewardRate` = coins/hour (focus);
`rewardMinutes` = flat coins (quick).

### Photo Proof. Focus habits (timed)

| Habit | Emoji | Default min | Rate | Tag | Proof hint |
|---|---|---|---|---|---|
| Read | 📚 | 30 | 15 | focus | "Book in frame and readable. Open, closed, or e-reader, they all count." |
| Hit the gym | 💪 | 40 | 15 | exercise | "Point it at whatever you're about to lift. The treadmill counts too." |
| Deep Work | 🔒 | 40 | 20 | focus | "Show the work or the setup. Screen, desk, or notebook." |
| Study | 🎓 | 40 | 20 | focus | "Notes, textbook, flashcards. Show what you're grinding through." |
| Side Hustle | 📈 | 40 | 20 | focus | "Show what you're building. The screen, the project, the orders." |
| Play an instrument | 🎸 | 30 | 20 | creative | "Instrument in frame and ready. Tuning counts as starting." |
| Hang out with someone | 👋 | 60 | 5 | social | "Selfie with the crew, or a shot of wherever you're hanging out." |
| Go for a walk | 🚶 | 30 | 10 | exercise | "Point it at the path ahead. Fresh air only, hallways don't count." |
| Go for a run | 🏃 | 40 | 15 | exercise | "Show the road, trail, or track before you take off." |
| Meditate | 🧘 | 20 | 10 | focus | "Show your spot, set up and quiet. Cushion, corner, or floor all work." |
| Write in your journal | 📝 | 20 | 10 | focus | "Journal open, pen in frame. Today's page is all I need." |
| Do some yoga | 🧘‍♀️ | 30 | 15 | exercise | "Mat down, phone propped, you in frame before the first pose." |
| Do some gardening | 🪴 | 30 | 10 | home | "Show the plot, the pots, or whatever you're about to fuss over." |

### Photo Proof. Quick habits (instant, once per day)

| Habit | Emoji | Coins | Tag | Proof hint |
|---|---|---|---|---|
| Smile | 😊 | 3 | social | "Point the camera at your face and give me a real one." |
| Touch grass | 🌱 | 5 | health | "Your hand on actual grass, in frame. I do mean literally." |
| Eat a healthy meal | 🍎 | 7 | health | "Show the plate. I'm looking for real food, not the wrapper." |
| Brush your teeth | 🪥 | 3 | health | "Toothbrush in frame, paste on, before you start brushing." |
| Make your bed | 🛏️ | 5 | home | "Show the bed, made and flat. Pillows count as effort." |
| Clean your room | 🧹 | 7 | home | "Show the room once it's actually clear, floor included." |
| Drink some water | 💧 | 3 | health | "Glass or bottle in frame, filled and ready. Water only, sorry." |
| Do your skincare | 🧴 | 3 | health | "Products lined up, or the routine mid-glow. Either works." |
| Take your vitamins | 💊 | 3 | health | "Show the bottle or the handful you're about to take." |

### Camera Reps: `Models/ExerciseModels.swift:46–50`

| Exercise | Reps to start earning | Default coins/rep | Form tip |
|---|---|---|---|
| Push-ups | 5 | 1.0 | "Phone on the floor, side-on. I need your head and hips in frame." |
| Squats | 5 | 1.0 | "Stand side-on and back up till you fit. A rep lands when you stand up." |
| Sit-ups | 5 | 1.0 | "Phone on the floor beside you, tilted up. Shoulders and knees in frame." |
| Jumping Jacks | 10 | 1.0 | "Back up further than feels necessary. Arms have to stay in frame." |
| Lunges | 5 | 1.0 | "Side-on, a few steps back. Both legs stay in frame the whole way down." |

### Passive Income (Apple Health): `Services/HealthService.swift:14+`

| Metric | Coin rate |
|---|---|
| Run / Walk | 8 per km |
| Exercise Minutes | 1 per minute |
| Mindful Minutes | 1 per minute |
| Steps | 0.003 per step (3 per 1,000) |
| Calories Burned | 0.06 per kcal (6 per 100) |

**Note:** the AI prompt is **not** per-habit. One prompt template in
`server/supabase/functions/verify-proof/index.ts` interpolates `habitName` and
the habit's `proofHint`.

---

# 3. Blocking System

## Frameworks (all IMPLEMENTED in code)

| Framework | Where | Purpose |
|---|---|---|
| FamilyControls | `Services/LiveScreenTimeService.swift` | authorization + app picker |
| ManagedSettings | same, + `Services/SharedBlocking.swift` | the shields |
| DeviceActivity | `LiveScreenTimeService.scheduleReshield`, `AuraShieldMonitor/` | re-shield at expiry |
| DeviceActivityUI | `AuraStatsReport/` | screen-time report rendering |

**Entitlement:** `com.apple.developer.family-controls` present on the app,
`AuraShieldMonitor`, and `AuraStatsReport`.
**App Group:** `group.Aura-App.Aura-iOS` on all three.

## The three-rule model

`Store/BlockingEngine.swift`:
- **Always Blocked** (`hardTokens`). In every plan; never lifted.
- **Distracting** (`softTokens`). Lifted when `softLifted(isUnlocked:inSession:)`
  is true, i.e. `isUnlocked && !inSession`.
- **Always Allowed** (`exceptTokens`). Only meaningful when `blockEverything`.

Two named stores keep them physically separate: `.auraHard` / `.auraSoft`
(`SharedBlocking.swift:16–21`).

## App / category selection

Only via Apple's `FamilyActivityPicker`. Tokens are opaque; the app cannot read
app names or icons except through `Label(token)`
(`DesignSystem/Components/AppIconView.swift`). In the Simulator a stand-in
picker runs instead (`Services/MockAppPicker.swift`).

## Authorization

`requestAuthorization(for: .individual)`. Requested lazily **when the user opens
the app picker** (`LiveScreenTimeService.swift:68–74`). Not during onboarding.
If denied, `presentAppPicker` returns `.empty` and every `apply` throws;
`HabitStore.refreshShield()` catches and sets `lastBlockingFailed`, surfaced as a
retry affordance in `BlocksView`.

## Re-locking when the app is dead

`scheduleReshield(at:)` starts a `DeviceActivitySchedule` **beginning** at expiry
(not ending), documented as a deliberate workaround for Apple's 15-minute minimum
interval. `AuraShieldMonitor.intervalDidStart` re-applies the soft shield.

## Implemented separately

- **Adult content:** `hard.webContent.blockedByFilter = .auto()`. Apple's own
  filter, toggled by `blockAdultWebsites`.
- **Block everything:** `.all(except:)` on categories.
- **Emergency Unlock:** 45 minutes, disabled by `hardMode`.
- **Interventions:** four styles, `Features/Intervention/`.

## NOT FOUND

Scheduled blocking, usage limits/thresholds, sleep/bedtime mode, grace periods,
`DeviceActivityEvent` thresholds. `docs/blocks/BLOCKS_BUILD_SPEC.md` is
referenced in project history as having cut Sleep Mode.

## Current technical limitation

**None of this has run.** FamilyControls fails in the Simulator by design, and
`HabitStore.screenTime` selects `MockScreenTimeService` under
`#if targetEnvironment(simulator)`. Everything above is compiled and
unexercised.

---

# 4. Onboarding

## Two implementations. Which is live

| Implementation | Files | Status |
|---|---|---|
| **Part 1 / Part 2** | `Features/Onboarding/Part1/`, `Part2/`, `RootGate.swift` | **ACTIVE** |
| Coordinator / 52-screen | `OnboardingView.swift`, `OnboardingCoordinator.swift`, `Screens/*`, `Models/Onboarding/OnboardingStep.swift` | **DEAD** |

Proof: `RootGate.swift` constructs only `Part1Flow` / `Part2Flow`.
`OnboardingCoordinator` is referenced solely by `OnboardingView.swift` and the
four files in `Screens/`, which are themselves referenced by nothing else.

**Consequence:** everything in `docs/onboarding/generated/*` describes the dead
implementation. Treat those documents as specification, not as the shipping app.

## Live flow. Part 1 (`Part1Step`, `Part1Flow.swift:13–17`)

Order: `logoReveal, welcome, typewriterIntro, name, age, lifeStage, gender,
attribution, transition, chat, demo1, demo2, demo3, demo4, science, setupIntro,
earnMethods, dailyTime, scrollEstimate, quickMath, yearFull`: **21 screens.**

Captured, with persistence status:

| Screen | Captures | Persisted? |
|---|---|---|
| name | `draft.preferredName` | Yes → `OnboardingDraft` |
| age | `flow.ageRange` | **No**: "analytics only, not yet persisted" (`Part1Flow.swift:37`) |
| lifeStage | `flow.lifeStage` | **No**: same |
| gender | `flow.gender` | **No**: same |
| attribution | `flow.acquisition` | **No**: "analytics only, not yet persisted" (line 35) |
| dailyTime | `flow.dailyMinutes` | **No enum, kept on flow** (line 33) |
| scrollEstimate | `draft.estimate` | Yes |

**Attribution question options** (`Part1IntroScreens.swift:490–491`):
`"Instagram", "TikTok", "Facebook", "YouTube", "App Store", "Friends", "Google",
"ChatGPT"`. Question copy: **"Where did you hear about us?"**
This is the only acquisition-source data collected anywhere, and it is **not
stored and not sent anywhere.**

`allowsBack` is false on `logoReveal, welcome, typewriterIntro, name, chat`.

## Live flow. Part 2 (`Part2Step`, `Part2Flow.swift:12–15`)

Order: `postScrollFeelings, feelingsReflection, liveMoreScrollLess, socialProof,
permissionsPrimer, notificationsPrimer, screenTimePrimer, distractionSelection,
commitment, settingUp, programReveal`: **11 screens.**

`allowsBack` false on `feelingsReflection, settingUp, programReveal`.

Notable screens:
- **socialProof** (`Part2Components.swift:479`). Headline **"Aura was made for
  people like you"**, a `5.0` / "AVERAGE RATING" laurel badge, two scrolling
  review marquees.
- **notificationsPrimer** → `LiveNotificationService.requestAuthorization`
  (real system prompt).
- **screenTimePrimer** → Screen Time primer.
- **distractionSelection** (`Part2Components.swift:1192`). Explicitly labelled
  **"(placeholder)"**: *"Stands in for the real Screen Time app-picker until
  `FamilyControls` authorization is wired up."*
- **commitment**: `CommitHoldButton`.
- **programReveal** (`Part2ProgramReveal.swift`). The terminal screen.

## Paywall transition

**There is none.** `Part2ProgramReveal.swift:159–162`:

```
Button {
    // Placeholder. The real paywall/claim screen this
    // leads to hasn't been built yet.
    flow.advance()
}
```

`Part2Flow.onFinish` sets `showApp = true` (`RootGate.swift`). **Onboarding can
be completed without subscribing because there is nothing to subscribe to.**

## Completion flag

The live flow writes **no completion flag**. `OnboardingDraft.completedAt`
exists but is set only by the dead coordinator. The only persistence of
"skip onboarding" is `debugSkipOnboarding` in `UserDefaults`, **DEBUG-only**
(`RootGate.swift:50`). A fresh launch of a release build re-enters onboarding
every time.

## Onboarding → app handoff

`Features/Onboarding/HabitStore+AppConfig.swift` applies only `displayName` and
zeroes counters. Its TODO (lines 24–28): *"map config.starterHabitIDs → habits,
apply the FamilyControls shield for the selected apps, and set the protection
schedule."* **Selected apps and habits chosen in onboarding never reach the
app.**

---

# 5. Current Paywall + Monetization

**Overall status: NOT IMPLEMENTED in any live path.**

| Item | Finding |
|---|---|
| Paywall screen | **NOT FOUND** in live flow (placeholder, §4) |
| RevenueCat | **NOT FOUND** in code. Mentioned only in `docs/onboarding/generated/*` as an option |
| Superwall | **NOT FOUND** anywhere |
| StoreKit | Protocol + Mock only. `Services/PurchaseService.swift` header: *"The Live impl … lands in Phase E"* |
| Live purchase code | **NOT FOUND**: no `Product`, `Transaction`, `AppStore` usage |
| Entitlement checking | `refreshEntitlement()` exists; called only from dead coordinator |

## Product identifiers: `Models/Onboarding/SubscriptionCatalog.swift:24–30`

Marked in-file: **"PLACEHOLDER. Must match App Store Connect."**

| Plan | ID | Price | Notes |
|---|---|---|---|
| Annual | `com.aura.sub.annual.yearly` | $69.99/yr | 7-day trial |
| Weekly | `com.aura.sub.weekly` | $9.99/wk | no trial |
| Exit offer | `com.aura.sub.annual.exit` | $34.99/yr | no trial unless StoreKit says so |

Derived merchandising (same file, lines 36–70):
- Annual per-week **$1.34**, **"Save 87%"**
- Exit per-week **$0.67**, **"93% off"**
- Both percentages computed against $9.99 × 52 weeks, deliberately so they stay
  mathematically valid. Trial = **7 days**.

**No monthly plan. No lifetime plan.** Default selected plan is `.annual`
(`OnboardingDraft.selectedPlan`).

## Offer UI that does exist

`Part2ProgramReveal.swift` renders a **"Special offer expires in"** countdown
with a **"Claim Limited Discount"** button (lines 754, 845). The countdown is
local UI; no product is attached and the button does not purchase.

## Cancellation flow. IMPLEMENTED

`Features/Profile/ManageSubscriptionSheet.swift`: "Your plan" / "Aura Premium" /
"Cancel subscription" → reason survey → free-text → *"We'll take you to our
cancellation page with instructions for both App Store and web subscriptions."* →
opens `https://downloadaura.app/manage-subscription`.
**Note:** this sheet displays "Aura Premium" unconditionally; there is no real
subscription state behind it.

## Restore purchases

`PurchaseService.restore()` exists in the protocol and Mock. **No live restore
UI found.**

---

# 6. Web-to-App Readiness

**This is the most constrained area of the codebase.**

| Capability | Status |
|---|---|
| Custom URL scheme | **NOT FOUND**: no `CFBundleURLTypes` / `CFBundleURLSchemes` |
| Universal links | **NOT FOUND**: no `com.apple.developer.associated-domains` |
| Deep-link routing code | **NOT FOUND**: no `onOpenURL`, no `widgetURL` |
| Deferred deep linking | **NOT FOUND** |
| Branch / AppsFlyer / Adjust / Singular | **NOT FOUND** |
| Firebase Dynamic Links | **NOT FOUND** |
| RevenueCat web billing | **NOT FOUND** |
| Web purchase recognition | **NOT FOUND** |
| Authentication (any) | **NOT FOUND**: no Sign in with Apple, Google, email, Supabase auth |
| User ID / anonymous ID | **NOT FOUND** |
| Account-based entitlement sync | **NOT FOUND** |
| UTM / campaign / referral handling | **NOT FOUND** |

Verified by targeted search across all Swift, plist, entitlements and project
files. The only `associated-domains`-adjacent finding is its absence from
`Aura iOS/Aura iOS.entitlements`, which contains exactly three keys:
family-controls, application-groups, healthkit.

## Identity

**How is identity created?** It isn't. `HabitStore.displayName` is hardcoded
`"Hayden"` (`HabitStore.swift:660`) with the comment *"Placeholder until real
accounts exist."* Onboarding may overwrite it with the typed name.

**Does identity survive reinstall?** No. All state is local files in Application
Support (`draft.json`, `app_config.json`, `block-config.json`, `day-log.json`,
`habits.json`, `wins.json`, `running-timers.json`) plus a few `UserDefaults`
keys. Deleting the app deletes everything.

**Could a web user be matched to an app user?** **No.** There is no identifier of
any kind. No account, no device ID persisted, no IDFV usage, no attribution SDK,
no deep-link payload.

## Known values

- Bundle ID: `Aura-App.Aura-iOS`
- Extensions: `.AuraTimerWidget`, `.AuraShieldMonitor`, `.AuraStatsReport`
- App Group: `group.Aura-App.Aura-iOS`
- Marketing version `1.0`, build `1`
- **App Store ID: NOT DETERMINABLE FROM CODEBASE**
- **DEVELOPMENT_TEAM: not set in project.pbxproj**
- Web domain referenced: `downloadaura.app`

## What Web2Wave is currently blocked from doing

1. Sending a user from web to a specific in-app destination: **no deep links.**
2. Carrying any campaign/UTM parameter into the app: **no handler.**
3. Matching a web signup to an app install: **no identity.**
4. Selling on web and entitling in app: **no auth, no RevenueCat, no receipt
   handling.**
5. Measuring anything that happens after install: **no analytics transport.**
6. Attributing installs to campaigns: **no SDK, no SKAdNetwork config.**

---

# 7. Analytics + Event Tracking

## Providers

| Provider | Status |
|---|---|
| Any third-party SDK | **NOT FOUND** (no Amplitude, Mixpanel, PostHog, Segment, Firebase, Meta, TikTok) |
| `ConsoleAnalyticsService` | IMPLEMENTED, `print()`, wrapped in `#if DEBUG` |
| `RecordingAnalyticsService` | IMPLEMENTED, in-memory, for tests |

`Services/AnalyticsService.swift` header: *"Provider-agnostic analytics seam."*
`ConsoleAnalyticsService` doc: *"Used until a real SDK is selected (Phase F)."*
`docs/onboarding/generated/ONBOARDING_ANALYTICS_PLAN.md:3`: *"The repo currently
has **no analytics**; this is net-new."*

## The critical finding

`OnboardingServices.makeDefault()` wires `ConsoleAnalyticsService`, but every
call site of `OnboardingAnalytics` is inside `OnboardingCoordinator.swift`:
**dead code (§4)**. `Part1Flow` and `Part2Flow` contain no analytics calls; the
word appears only in two comments saying answers are *"analytics only, not yet
persisted."*

**Net effect: the shipping app emits no events at all, to anywhere.**

## Defined events (all currently unreachable)

| Event | Trigger | Properties | Provider | File |
|---|---|---|---|---|
| `onboarding_started` | flow start | onboarding_version | Console (DEBUG) | AnalyticsService.swift |
| `onboarding_resumed` | resume | base set | Console | same |
| `onboarding_screen_viewed` | each screen | onboarding_version, screen_id, position, phase, entry_source, variant | Console | same |
| `onboarding_back_tapped` | back | from, to | Console | same |
| `onboarding_completed` | terminal | total_ms, purchased, degraded | Console | same |
| `onboarding_answer_selected` | any answer | screen_id, options (enumerated IDs only) | Console | same |
| `onboarding_permission_prep_viewed` | primer | type | Console | same |
| `onboarding_permission_result` | grant/deny | type, status | Console | same |
| `onboarding_app_picker_opened` | picker |, | Console | same |
| `onboarding_app_selection_completed` | picker done | app_count, category_count | Console | same |
| `onboarding_habits_selected` | habit pick | count | Console | same |
| `onboarding_plan_generated` | plan |, | Console | same |
| `onboarding_commitment_completed` | commit |, | Console | same |
| `onboarding_paywall_viewed` | paywall | screen_id | Console | same |
| `onboarding_plan_selected` | plan tap | plan | Console | same |
| `onboarding_exit_offer_viewed` | exit offer |, | Console | same |
| `onboarding_purchase_started` | purchase | plan | Console | same |
| `onboarding_purchase_completed` | success | plan | Console | same |
| `onboarding_purchase_failed` | failure | plan, reason | Console | same |
| `onboarding_restore_started` | restore |, | Console | same |
| `onboarding_restore_result` | restore done | outcome | Console | same |

**No events at all exist for:** habit completion, verification, earning,
blocking, screen-time purchase, sessions, streaks, notifications, retention.

## Web2Wave measurement matrix

| Step | Measurable today |
|---|---|
| Ad click | NOT DETERMINABLE (web side, outside repo) |
| Landing-page visit | NOT DETERMINABLE (web side) |
| Web onboarding start / completion | NOT DETERMINABLE (web side) |
| Web paywall view / checkout start / web purchase | NOT DETERMINABLE (web side) |
| App install | **NO**: no attribution SDK, no SKAdNetwork |
| First app open | **NO**: no transport |
| Account match | **NO**: no identity |
| Onboarding completion | **NO**: event defined but unreachable |
| Screen Time permission | **NO**: event defined but unreachable |
| First habit started | **NO**: event does not exist |
| First verification | **NO**: event does not exist |
| First successful verification | **NO**: event does not exist |
| First earned screen time | **NO**: event does not exist |
| Paywall view | **NO**: no paywall |
| Trial start | **NO**: no purchase code |
| Subscription | **NO** |
| Renewal | **NO** |

---

# 8. Attribution + Paid Acquisition Infrastructure

Exhaustive search result: **NOTHING IS CONFIGURED.**

| Item | Status |
|---|---|
| Meta SDK / App Events | NOT FOUND |
| TikTok SDK | NOT FOUND (the string "TikTok" appears only as an app-icon asset name and an onboarding answer option) |
| Google Ads | NOT FOUND |
| Apple Search Ads / AdServices | NOT FOUND |
| SKAdNetwork (`SKAdNetworkItems`) | NOT FOUND |
| ATT / `NSUserTrackingUsageDescription` / `ATTrackingManager` | NOT FOUND |
| AppsFlyer / Adjust / Branch / Singular | NOT FOUND |
| RevenueCat attribution | NOT FOUND |
| IDFA / IDFV usage | NOT FOUND |
| UTM / campaign / referrer handling | NOT FOUND |

There are **no third-party package dependencies of any kind** in the project.
No SPM packages, no CocoaPods, no Carthage.

The only acquisition-source signal in the product is the onboarding question
"Where did you hear about us?", which is discarded (§4).

---

# 9. User Data + Personalization

## Persisted: `OnboardingDraft` (`Models/Onboarding/OnboardingDraft.swift`)

| Field | Collected at | Influences product? | Web2App personalization potential |
|---|---|---|---|
| `preferredName` / `prefersNoName` | Part 1 name screen | Yes, Profile display name, ProgramReveal copy | Yes |
| `goal` (`PrimaryGoal`) | dead flow only | No |, |
| `estimate` (`ScreenTimeEstimate`) | Part 1 scrollEstimate | Feeds TimeProjection screens | Yes |
| `consequence`, `vulnerableTime`, `previousAttempts` | dead flow only | No |, |
| `dayLossHours`, `targetReductionMinutes` | dead flow | No |, |
| `screenTimeAuth` | Part 2 primer | Recorded only |, |
| `blockedSelectionToken`, `blockedAppCount`, `blockedCategoryCount` | Part 2 (placeholder screen) | **No**: never applied (§4 TODO) | Counts only |
| `protectionTiming` | dead flow | No |, |
| `earningMethods`, `starterHabitIDs` | Part 1 earnMethods | **No**: never applied | Yes |
| `dailyCommitment` | Part 2 commitment | No |, |
| `postScrollFeelings` | Part 2 | Used in reflection copy | Yes |
| `notificationAuth`, `reminderChoice` | Part 2 | Recorded |, |
| `selectedPlan`, `subscriptionStatus`, `exitOfferShown` | dead flow | No |, |

## Collected but NOT persisted anywhere

`ageRange`, `lifeStage`, `gender`, `acquisition`, `dailyMinutes`. All held on
`Part1Flow` in memory only (`Part1Flow.swift:33–40`). **Lost when onboarding
ends.**

## App-side state (`HabitStore`, local files)

`displayName` (hardcoded "Hayden" default), `coinBalance` (derived, resets
daily), `lifetimeEarnedMinutes`, `daysSinceInstall`, `streak` + freezes,
`dayRecords` (`day-log.json`), `habits` (`habits.json`), `wins` (`wins.json`),
`blockConfig` (`block-config.json`), `hardMode`, `remindersEnabled`,
`interventionStyles`, `isHealthConnected`, `emergencyUnlockUsed`,
`deepFocusSessions`.

**NOT FOUND:** user ID, email, age (persisted), gender (persisted), referral
data, attribution data, rank/XP.

---

# 10. Gamification + Retention

| Mechanic | Rules | Source |
|---|---|---|
| **Coins** | Earned per habit; 1 coin = 1 minute; **balance resets at midnight** | `HabitStore.swift:645–656` |
| **Streak** | Derived by replaying the day log; a day counts when `habitsCompleted > 0` | `Store/DayLog.swift` `streakRun` |
| **Streak freezes** | Earned on a day with **≥2** quests; **max 2** held; window-bounded | `DayLog.swift:410–414` (`StreakFreeze.earnAt = 2`, `.maximum = 2`) |
| **90-day board** | 15 × 6 grid; anchored to first day used; caps at 90 then restarts | `Features/Stats/StatsView.swift` `consistencyCard`, `DayLog.journeyDays` |
| **Wall of Wins** | Verified photos kept as a gallery | `Store/WinLibrary.swift`, `Features/Stats/WallOfWins.swift` |
| **Stats** | Two modes: Daily Habits / Screen Time | `Features/Stats/StatsView.swift` |
| **Live Activity** | Countdown on Lock Screen + Dynamic Island | `Services/LiveActivityController.swift`, `AuraTimerWidget/` |
| **Interventions** | 4 styles, randomly chosen, all on by default | `Features/Intervention/InterventionStyle.swift` |
| **Mascot** | White fox; `AuraNavProfileFox`, `TiredFoxFrameAnimation`, per-habit `FoxHabit*` stickers | `DesignSystem/Components/TiredFoxFrameAnimation.swift` |
| **Celebration** | Streak screen on first completion of the day | `Features/Gate/StreakScreen.swift` |

**NOT FOUND:** XP, rank or level system, sub-ranks, achievements/badges,
referrals, social or community features, unlockable content, home-screen widget
(the widget target contains **only** the Live Activity).

---

# 11. Notifications + Re-engagement

| Item | Status |
|---|---|
| Permission request | IMPLEMENTED, `LiveNotificationService`, `[.alert, .badge, .sound]`, prompted in Part 2 |
| Push / APNs / Firebase | **NOT FOUND**: no remote notification registration anywhere |
| Scheduled reminders | **NOT IMPLEMENTED**: `scheduleReminders` body is a documented no-op: *"Reminder content/timing design comes later (Phase E)"* (`NotificationService.swift:59–62`) |
| Streak / habit / screen-time reminders | **NOT FOUND** |
| Settings toggles | Present but inert, `HabitStore.remindersEnabled` carries **"TODO: schedule/cancel the real UNUserNotification requests off this"** (line 114) |
| Win-back / paywall notifications | NOT FOUND |

**The only notification actually scheduled in the entire app:**
`Services/InterventionNotifier.scheduleTimeUp(minutes:)`.
Title **"Time's up"**, body **"Your apps are blocked again."**, fired
`minutes × 60` seconds after a purchase.

Reminders sheet copy (`Features/Profile/RemindersSheet.swift`):
- *"A gentle nudge when it's time to earn. Nothing pushy."*
- *"A heads-up when you're getting close to your daily screen time goal."*

---

# 12. App Navigation + Main Screens

`App/RootTabView.swift:19`. Five tabs: `gate, apps, earn, stats, profile`.

| Tab / Screen | File | Purpose |
|---|---|---|
| **Home (Gate)** | `Features/Gate/GateView.swift` | Fox, countdown or locked state, Earned Today, Quests/Scroll actions, streak badge |
| **Blocks (apps)** | `Features/Blocks/BlocksView.swift` | Blocking Now strip; three rule cards; emergency unlock |
| **Earn (FAB)** | `App/FABMenuRow.swift`, `App/QuickAction.swift` | 4-method popover |
| **Stats** | `Features/Stats/StatsView.swift` | Daily Habits / Screen Time toggle, banners, peak hours, 90-day board, Wall of Wins |
| **Profile** | `Features/Profile/ProfileView.swift` | Profile hero + settings entry |
| Settings | `Features/Profile/SettingsScreen.swift` | Rows + all outbound links |
| Subscription | `Features/Profile/ManageSubscriptionSheet.swift` | Plan display + cancellation survey |
| Reminders / Difficulty / Interventions / Name | `Features/Profile/*Sheet.swift` | Preferences |
| Help | `Features/Profile/HelpScreen.swift` | Support, shield retry |
| Screen-time store | `Features/Store/ScreentimeStoreView.swift` | Spend coins for minutes |
| Streak celebration | `Features/Gate/StreakScreen.swift` | Streak, milestones, freezes |
| Photo Proof flow | `Features/PhotoProof/` | Setup → camera → verify → retry/streak |
| Lock In flow | `Features/DeepFocus/` | Setup → active timer |
| Camera Reps flow | `Features/Exercise/` | Rep counting |
| Apple Health | `Features/AddHabit/AppleHealthView.swift` | Metric list, collect |
| Interventions | `Features/Intervention/` | Dialogue / Breathing / Mirror / Message |

**No paywall screen exists in the navigation graph.**

---

# 13. Brand + UI Source of Truth

## Colours

**Dark theme**: `DesignSystem/Theme.swift`:
`background #0B0B0E` · `surface #16161B` · `surfaceAlt #1B1B20` ·
`hairline #26262B` · `textSecondary #8A8A90` · `textTertiary #5C5C61` ·
`signalUnlock #00BFFF` · `signalWarning #DF152D` · `signalWarningDeep #FF0000` ·
`signalGood #34C77B` · `signalGain #21C55E` · `signalCaution #E8A33D`

**Light sheets**: `DesignSystem/Components/LightSheet.swift`:
`blue #2586FF` / shade `#1C69D6` · `orange #FF6B03` / shade `#D15702` ·
`danger #F0453E` · `surface #EEEDF0` · `title #1C1C1E` · `subtitle #9B9BA3` ·
`controlIdle #767676` · `track #ECECEE` · `divider #EDEDF1` ·
`healthPink #FF61AD` · `healthRed #FF2719`

**Live Activity accents**: `AuraTimerWidget/AuraTimerLiveActivity.swift`:
blue `rgb(0.145, 0.525, 1)`, orange `rgb(1, 0.42, 0.012)`, violet
`rgb(0.482, 0.357, 1)` (violet marked "placeholder").

## Typography

Two bundled variable fonts, runtime-registered via Core Text
(`DesignSystem/FontRegistration.swift`):
- **Montserrat.** Display/headers/numerals (`Montserrat-Variable.ttf`)
- **Rubik.** Body/labels (`Rubik-Variable.ttf`)
- `GeneralSans-Variable.ttf` exists in `Resources/Fonts/` but is **not
  registered**. Unused.

## Spacing / radii: `DesignSystem/Theme.swift`

Spacing: `xs 4, s 8, m 12, l 16, xl 24, xxl 32, xxxl 48`. A strict 4-grid.
Radii: `micro 6, tile 8, field 12, card 16, hero 24, panel 32, sheet 38, pill 999`.
Layout: `navBarClearance 92`, `scrollBottomClearance 160`.

## Assets

`AuraLogo`, `AuraAppIcon`, `AuraCoinIcon`, `AuraNavProfileFox`,
`AuraHomeBackgroundDay/Night`, `WelcomeBackground`, `SpecialOfferCardBackground`,
`StreakFireIcon`, `LogoHarvard`, `LogoUCL`, `CoverAtomicHabits`, ~20 `FoxHabit*`
stickers, `FoxPushups/Squats/Situps/JumpingJacks/Lunges`, `FoxDeepFocus`,
competitor app icons (`AppIconInstagram`, `AppIconTikTok`, …).

**Animation:** frame-sequence PNG animation only (`TiredFoxFrameAnimation`,
`tired_fox_animation_001…`). **No Lottie, no Rive.**

**Light/dark:** the app forces `.preferredColorScheme(.dark)` at the root
(`Aura_iOSApp.swift`); light "sheets" are a design language, not a system theme.

**Haptics:** `DesignSystem/Haptics.swift`. Impact/selection/notify, used widely.
**Sound:** NOT FOUND.

---

# 14. Product Copy Bank

Exact wording, unaltered.

## Problem statements
- "Aura users live more\nand scroll less": `Part2Components.swift:212`
- "Ditch the mindless scrolling, change your life.": `Part2ProgramReveal.swift:369`
- "Stuck in the same cycle, or free from doomscrolling and finally living your best life?": `Part2ProgramReveal.swift:446`

## Benefit / transformation claims
- "In 4 weeks you won't recognize yourself, {name}.": `Part2ProgramReveal.swift:188`
- "You will beat your phone addiction by". Line 233
- "Congratulations, your personalized plan is ready". Line 227
- "Where will you be in 4 weeks?". Line 440
- "Two paths. Which one do you choose?". Line 262

## Headlines
- "Aura was made for people like you": `Part2Components.swift:515`
- "Aura's Science-Backed Plan": `Part1MechanismScreens.swift:35`
- "How do you want to earn screen time?": `Part1MechanismScreens.swift:306`
- "First, what's your name?": `Part1IntroScreens.swift:277`
- "Where did you hear about us?": `Part1IntroScreens.swift:494`
- "Join others just like you using Aura": `Part2ProgramReveal.swift:387`
- "You might ask…". Line 406

## CTAs
- "Get Started" · "Continue" · "Let's Get Started" · "Claim Limited Discount" · "Nevermind" · "Cancel subscription"

## Method descriptors: `Models/Habit.swift:32+`
- Photo Proof: "Snap a pic, Aura verifies your habit, earn coins"
- Camera Reps: "The more you do the more coins you earn"
- Lock In / Passive Income. See `HabitCategory.tileDescriptor`

## Screen-time language
- "UNTIL YOUR APPS LOCK AGAIN" · "Apps stay locked till the timer's up!" · "Until apps unlocked" · "Earned Today"

## Live Activity lines: `Features/LiveActivity/AuraTimerAttributes.swift`
- Bought time: "This is rented screen time 👀"
- Lock In (timed): "Staying locked in pays 💰"
- Lock In (Extreme Focus): "Cash out whenever 💰"
- Photo habit: "The pic was the easy part 😅"

## Interventions: `Features/Intervention/InterventionStyle.swift`
- "Talk to Aura": "The fox asks if you really need it, and charges you if you do."
- "Breathing Pause": "A guided breath before you decide."
- "Mirror Check": "Aura calls, and you answer looking at yourself."
- "Text From Aura": "The fox texts you, and you answer."

## Notification copy
- Title "Time's up" / body "Your apps are blocked again.": `InterventionNotifier.swift:27–28`

## Objection handling (FAQ): `Part2ProgramReveal.swift`
- "Is it worth the cost?": "Aura costs less than 1 coffee per month. For potentially 1,000+ hours of your life back. You decide."
- "Will this actually work for me?": "Aura is built on decades of behavioral science research from leading institutions like Harvard and UCL. The system works when you commit to the process."
- "What if I fail?": "Every small step counts. The app is designed to help you build momentum gradually. Progress, not perfection."

## Cancellation
- "What's the biggest reason you're canceling?" · "Anything else we should know?" · "Specific feedback helps us figure out what to fix." · "Thanks for your feedback!" · "We'll take you to our cancellation page with instructions for both App Store and web subscriptions."

---

# 15. Claims + Proof. COMPLIANCE CRITICAL

| Claim | Where | Sourced? |
|---|---|---|
| **"5.0" AVERAGE RATING** + 5 stars | `Part2Components.swift:590–615` (social proof screen) | **UNSOURCED. Product is unreleased, no App Store rating can exist.** |
| **"4.8" AVERAGE RATING** | `Part2ProgramReveal.swift:218` | **UNSOURCED, and contradicts the 5.0 above.** |
| "In 4 weeks you won't recognize yourself" | ProgramReveal:188 | Unsourced |
| "You will beat your phone addiction by {date}" | ProgramReveal:233 | Unsourced |
| "Aura costs less than 1 coffee per month. For potentially 1,000+ hours of your life back." | FAQ | Unsourced; also inconsistent with $9.99/wk weekly plan |
| "built on decades of behavioral science research from leading institutions like Harvard and UCL" | FAQ | Partially supported by the science screen below |
| "Join others just like you using Aura" | ProgramReveal:387 | Unsourced, implies an existing user base |
| "Aura users live more and scroll less" | Part2Components:212 | Unsourced |
| "Save 87%" / "93% off" | SubscriptionCatalog | **Mathematically derived and documented**: annual vs $9.99×52 |

## Properly cited claims: `Part1MechanismScreens.swift:32–47`

The science screen carries three real citations with source logos:
- **Harvard**: "Habits form through repeated actions in stable contexts, taking weeks to months to become automatic." *Wood, W., & Rünger, D. (2016). Psychology of Habit. Annual Review of Psychology.*
- **UCL**: "96 participants performed a daily behavior, and automaticity was modeled to plateau at an average of 66 days, with a range of 18–254 days." *Lally, P., et al. (2010). How are habits formed. European Journal of Social Psychology.*
- **Atomic Habits**: "On average, it takes more than two months before a new behavior becomes automatic—66 days to be exact." *Clear, J. (2018). Atomic Habits. Avery.*
- Badges: "1,500+ CITED / GOOGLE SCHOLAR", "1,000,000+ SOLD / NY TIMES BEST SELLER" (these describe the *sources*, not Aura).

**Conflict to flag:** two different average ratings (5.0 and 4.8) are shown in
the same onboarding flow, both for an unreleased product.

---

# 16. Testimonials + Social Proof

All ten are **hardcoded fictional content** in
`Features/Onboarding/Part2/Part2Components.swift:448–472`, every one 5 stars,
first names only, no source attribution.

| Name | Title | Body |
|---|---|---|
| Reese | Screen time cut in half | "I went from 7 hours a day to under 3. Aura changed what I do before I scroll." |
| Devon | It actually works | "I always bypassed other blockers. Earning my screen time is the first thing that worked." |
| Sofia | Fixed my mornings | "Instead of opening TikTok, I make my bed, drink water, and go outside first." |
| Malik | Back in control | "I can still use the apps I enjoy, but they no longer control my day." |
| Grace | Perfect for studying | "Blocking social media until I study has made it much easier to stop procrastinating." |
| Theo | Made for founders | "I need social media for work. Aura helps me finish important tasks before I start scrolling." |
| Nadia | Sleeping better | "I stopped scrolling late at night. Now I sleep earlier and wake up with more energy." |
| Cole | Gym consistency | "I haven't skipped the gym in three weeks because I have to earn my screen time." |
| Amara | I was skeptical | "One month later, my screen time is down and I'm reading again. I finally have my attention back." |
| Liam | Worth every penny | "Getting hours of my day back is worth far more than the subscription." |

**"Screen time cut in half" / "7 hours to under 3" is a specific quantitative
outcome claim presented as a user testimonial for an unreleased product.**

The source comment (line 475) states the screen was *"Adapted from a competitor
onboarding reference (rating/user-count laurels…)"*.

**NOT FOUND:** press logos, awards, trust badges, real App Store rating
integration, user counts with a source.

---

# 17. Pricing / Subscription Objection Handling

All of it lives in the ProgramReveal FAQ and the cancellation sheet. Quoted in
full in §14. Summary of what is addressed:

| Objection | Addressed | Copy location |
|---|---|---|
| Price | Yes, coffee comparison | FAQ |
| "Does this work?" | Yes, Harvard/UCL appeal | FAQ |
| Fear of failure | Yes, "Progress, not perfection." | FAQ |
| Urgency/scarcity | Yes, "Special offer expires in" countdown | ProgramReveal:754 |
| Cancellation | Partially, survey then external page | ManageSubscriptionSheet |
| Trial objection | **NOT FOUND**: no trial-explainer copy |
| Privacy concerns | Partially, a `screenTimePrivacy` step exists in the **dead** flow only |
| Permission concerns | Yes, Part 2 primers |
| AI/photo concerns | **NOT FOUND** |
| Losing access | **NOT FOUND** |

---

# 18. Privacy + Permissions

| Permission | Requested where | System string | Leaves device? |
|---|---|---|---|
| **Camera** | Photo Proof + Camera Reps + Mirror intervention | "Aura shows a live view of you when you're about to unblock an app, so you can see yourself make the call." | **Yes**: photo-proof images to the verification endpoint |
| **HealthKit (read)** | Apple Health method | "Aura reads today's steps, workouts and mindful minutes so your real-world activity can earn screen time." | No |
| **Notifications** | Part 2 primer | system default | No |
| **Family Controls / Screen Time** | On first app-picker open | system default | No |
| Photos / Microphone / Location / Contacts / Calendar / ATT | **NOT REQUESTED** |, |, |

**Camera string mismatch to flag:** the usage description describes only the
mirror intervention, but the camera's primary use is habit verification, which
uploads images. This is likely an App Review and disclosure problem.

## Photo upload path

`LiveProofVerifier` → `ProofImage.encoded` (downscale 768px, JPEG 0.7) →
POST base64 to `HabitStore.proofEndpoint` → Supabase Edge Function
`verify-proof` → Google `generativelanguage.googleapis.com`
(`gemini-2.5-flash`). The function stores nothing; the client uses an ephemeral
`URLSession` with caching disabled.
**Currently inert:** `proofEndpoint` is `nil`, so `MockProofVerifier` runs and no
image leaves the device.

## Legal / support surface: `Features/Profile/SettingsScreen.swift:9–17`

- Site `https://downloadaura.app`
- Privacy `https://downloadaura.app/privacy`
- Terms `https://downloadaura.app/terms`
- Contact `https://downloadaura.app/contact`
- Manage subscription `https://downloadaura.app/manage-subscription`
- Instagram `https://www.instagram.com/downloadaura`
- TikTok `https://www.tiktok.com/@downloadaura.app`
- Support email `help@downloadaura.app` (`Services/SupportMail.swift:18`)

**NOT FOUND:** account deletion, data deletion, logout, in-app data reset
(the only reset is `OnboardingPersistence.reset()`, DEBUG `-ob_fresh`).

---

# 19. Backend + Infrastructure

| Layer | Reality |
|---|---|
| Frontend | SwiftUI, iOS 26.5, `@Observable` |
| Architecture | Single `HabitStore` via `@Environment`; protocol seams with Live/Mock pairs |
| Targets | App + 3 extensions: `AuraTimerWidget` (Live Activity), `AuraShieldMonitor` (DeviceActivityMonitor), `AuraStatsReport` (DeviceActivityReport) |
| Dependencies | **None.** No SPM/CocoaPods/Carthage |
| Backend | One Supabase Edge Function, **not yet deployed** |
| Database | **NOT FOUND**: no schema, no migrations, no Supabase client in-app |
| Auth | **NOT FOUND** |
| Storage | Local JSON in Application Support + App Group `UserDefaults` |
| AI provider | Google Gemini `gemini-2.5-flash`, server-side |
| Env vars | `GEMINI_API_KEY` (name only; not in repo) |
| Environments | **NOT FOUND**: no staging/production split, no build configs beyond Debug/Release |
| Feature flags / remote config | **NOT FOUND** |

The Supabase function (`server/supabase/functions/verify-proof/index.ts`) is
written and documented (`server/README.md`) but the README's deploy steps have
not been run: `proofEndpoint` in `HabitStore` is `nil`.

---

# 20. Experimentation Infrastructure

| Capability | Status |
|---|---|
| Remote onboarding changes | **NO**: every screen is a compiled SwiftUI view |
| Superwall | **NOT FOUND** |
| Paywall experiments | **NO**: no paywall |
| Feature flags | **NOT FOUND** |
| Remote config | **NOT FOUND** |
| A/B framework | **NOT FOUND** |
| Experiment assignment | **NOT FOUND** |
| Analytics `variant` property | Defined in `OnboardingAnalytics.base()` but always `nil`, nothing sets it |
| Change copy without release | **NO** |
| Change pricing presentation without release | **PARTIAL**: StoreKit `displayPrice` would come from App Store Connect once a live PurchaseService exists; percentages/`perWeek` are computed in-app |
| Change onboarding order without release | **NO** |

**Every experiment Web2Wave wants to run on the app side currently requires an
App Store release.**

---

# 21. Current Product Constraints Web2Wave Must Know

1. **No paywall exists.** Users reach the app for free. There is no trial start,
   no purchase, no entitlement.
2. **No analytics reach any destination.** Nothing after install is measurable
   today.
3. **No deep links, no URL scheme, no universal links.** A web funnel cannot
   route into any specific screen.
4. **No user identity.** Web→app matching is impossible by any current mechanism.
5. **No attribution SDK and no SKAdNetwork configuration.** Installs cannot be
   attributed.
6. **Screen Time permission is an Apple-native prompt** that can only be granted
   on-device, cannot be pre-granted from web, and **is currently requested late**
. On first app-picker open, not during onboarding.
7. **Apple's Family Controls tokens are opaque.** Aura cannot know or report
   which apps a user blocks; only counts. Any creative implying "we see your
   apps" is wrong.
8. **The blocking system has never run.** It is unverified on a real device.
9. **The app is unreleased**, so all rating and testimonial content is fabricated
   (§15, §16) and must not be reused in ads.
10. **Onboarding answers are largely discarded.** Age, gender, life stage,
    acquisition source and selected apps never persist.
11. **Onboarding has no completion flag in release builds.** It repeats on every
    launch.
12. **The coin balance resets at midnight**, which is a product rule any messaging
    must respect.
13. **Prices and product IDs are placeholders** not yet in App Store Connect.
14. **No App Store ID and no development team** are set in the project.

---

# 22. What Is Fixed vs Configurable

| Area | Current State | Web2Wave can change without app release? | Source |
|---|---|---|---|
| Onboarding copy | Hardcoded SwiftUI | **No** | `Part1*`, `Part2*` |
| Onboarding order | `Part1Step` / `Part2Step` enums | **No** | `Part1Flow.swift:13`, `Part2Flow.swift:12` |
| Onboarding questions | Hardcoded | **No** | same |
| Paywall copy | Does not exist | **No** | §5 |
| Prices | Placeholder constants + StoreKit at runtime | **Partially**: App Store Connect price, once a live PurchaseService exists | `SubscriptionCatalog.swift` |
| Trial | 7 days, constant | **No** (would be an ASC product config) | `SubscriptionCatalog.trialDays` |
| Offer structure | Annual / weekly / exit, hardcoded | **No** | same |
| Product screenshots / app icon | Asset catalogue | **No** (ASC metadata is separate) | `Assets.xcassets` |
| Verification rules | Prompt lives **server-side** | **YES**: edit the Edge Function | `server/supabase/functions/verify-proof/index.ts` |
| AI model choice | Pinned server-side | **YES** | same, `MODEL` constant |
| Habit list | `HabitStore.defaultHabits` + `habits.json` | **No** | `HabitStore.swift:24` |
| Blocking behaviour | Compiled | **No** | `BlockingEngine.swift` |
| Notification copy | Compiled | **No** | `InterventionNotifier.swift` |
| Deep links | Do not exist | **No** | §6 |
| Subscription products | Not in ASC yet | **No** | §5 |
| Analytics | No transport | **No** | §7 |
| Attribution | None | **No** | §8 |
| Web checkout | Not supported | **No** | §6 |
| User identity | None | **No** | §6 |

**Only two things are changeable without an App Store release: the verification
prompt and the AI model**. Both because they live in the Edge Function.

---

# 23. Missing Information

## Product
- Intended paywall placement and gating (hard vs soft). No implementation to read.
- Whether Screen Time permission should move earlier in onboarding.
- Intended Emergency Unlock weekly allowance (TODO, unspecified).
- Whether onboarding-selected apps/habits are meant to carry into the app (TODO exists, values unspecified).

## Marketing
- Real positioning and category.
- Whether any of the fabricated testimonials correspond to real users.
- App Store listing copy, screenshots, keywords. Not in repo.

## Pricing
- Final products and prices (repo values are explicitly placeholders).
- Whether the exit offer ships.
- Real App Store Connect product IDs.
- Whether the "Special offer expires in" countdown is intended to be real scarcity.

## Analytics
- Which SDK will be adopted.
- Event taxonomy for the *app* loop (none defined. Only onboarding).
- Whether the dead coordinator's taxonomy will be ported to the live flow.

## Attribution
- Which MMP, if any.
- SKAdNetwork conversion-value schema.
- Whether ATT will be requested.

## Web2App
- Whether accounts are planned at all.
- Intended web→app entitlement mechanism.
- Universal link domain and App Store ID.
- Whether `downloadaura.app` is live and who controls it.

## Legal / compliance
- Whether privacy policy and terms exist at the referenced URLs.
- Photo-retention and disclosure policy for AI verification.
- Substantiation for every claim in §15.
- Whether the camera usage string will be corrected before submission.

## Brand
- Final violet for the Live Activity (marked placeholder).
- Whether `GeneralSans` is intended (bundled, unregistered).
- Final mascot art for the intervention screens (placeholders in use).

## Operations
- Apple Developer team and App Store ID.
- Supabase project reference.
- Launch timing and TestFlight status.

---

# 24. Repository Source Index

**Onboarding (ACTIVE)**
`Features/Onboarding/RootGate.swift` · `Part1/Part1Flow.swift` ·
`Part1/Part1IntroScreens.swift` · `Part1/Part1MechanismScreens.swift` ·
`Part1/Part1YearGridScreens.swift` · `Part2/Part2Flow.swift` ·
`Part2/Part2Components.swift` · `Part2/Part2ProgramReveal.swift` ·
`Models/Onboarding/OnboardingDraft.swift`

**Onboarding (DEAD. Do not treat as truth)**
`Features/Onboarding/OnboardingView.swift` · `OnboardingCoordinator.swift` ·
`Screens/*` · `Models/Onboarding/OnboardingStep.swift` ·
`docs/onboarding/generated/*`

**Paywall / subscriptions**
`Services/PurchaseService.swift` · `Models/Onboarding/SubscriptionCatalog.swift` ·
`Features/Profile/ManageSubscriptionSheet.swift`

**Blocking**
`Store/BlockingEngine.swift` · `Services/ScreenTimeService.swift` ·
`Services/LiveScreenTimeService.swift` · `Services/SharedBlocking.swift` ·
`Services/MockAppPicker.swift` · `Models/BlockConfig.swift` ·
`Features/Blocks/*` · `AuraShieldMonitor/AuraShieldMonitor.swift`

**Verification**
`Services/ProofVerifier.swift` · `Services/LiveProofVerifier.swift` ·
`Features/PhotoProof/*` · `server/supabase/functions/verify-proof/index.ts` ·
`server/README.md`

**Habits & earning**
`Store/HabitStore.swift` · `Models/Habit.swift` · `Models/ExerciseModels.swift` ·
`Services/HealthService.swift` · `Features/AddHabit/*` · `Features/Exercise/*` ·
`Features/DeepFocus/*`

**Analytics**: `Services/AnalyticsService.swift`

**Authentication / backend.** None in app; `server/`

**Notifications**: `Services/NotificationService.swift` ·
`Services/InterventionNotifier.swift` · `Features/Profile/RemindersSheet.swift`

**Navigation**: `App/RootTabView.swift` · `App/QuickAction.swift` ·
`App/FABMenuRow.swift` · `Aura iOS/Aura_iOSApp.swift`

**Design system**: `DesignSystem/Theme.swift` · `DesignSystem/Typography.swift` ·
`DesignSystem/FontRegistration.swift` ·
`DesignSystem/Components/LightSheet.swift`

**Live Activity**: `Features/LiveActivity/AuraTimerAttributes.swift` ·
`Services/LiveActivityController.swift` ·
`AuraTimerWidget/AuraTimerLiveActivity.swift`

**Stats**: `Features/Stats/*` · `Store/DayLog.swift` · `Store/WinLibrary.swift` ·
`AuraStatsReport/*`

**Configuration**: `Aura iOS.xcodeproj/project.pbxproj` ·
`Aura iOS/Aura iOS.entitlements` · `AuraShieldMonitor/*.entitlements` ·
`AuraStatsReport/*.entitlements` · `*/Info.plist`

**Product docs (specification, not implementation)**: `PRODUCT.md` ·
`DESIGN.md` · `docs/onboarding/PART1_BUILD_SPEC.md`
