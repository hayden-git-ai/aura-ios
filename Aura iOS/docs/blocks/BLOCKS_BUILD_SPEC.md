# Blocks — Build Spec

Rewrite of the Blocks tab around **one always-on block set in three lanes**, replacing
schedules / limits / breaks / presets. Sections 1–3 ship with no app extension.
Sleep Mode is designed here and built when the DeviceActivityMonitor extension exists.

Status: **spec only — nothing built.** Locked decisions are marked ✅.

---

## 1. The model

### Lanes

Three lanes, one axis, user assigns each app to exactly one:

| Lane | Meaning | Coins | Emergency Unlock |
|---|---|---|---|
| **Always Allowed** | Never shielded. The exception list. | n/a | n/a |
| **Always Blocked** | Shielded permanently. The commitment. | ❌ cannot open | ✅ can open |
| **Distracting** | Shielded until time is earned or bought. The bargain. | ✅ opens | ✅ opens |

✅ Renamed from "Never Allowed" so the pair reads on one axis.

**Precedence — Always Blocked > Always Allowed > Distracting.** An app can be picked into
more than one lane (three separate system pickers, one device). Adding to a lane removes it
from the others, and the sheet says so inline: *"Instagram moved here from Distracting."*
Resolution happens at write time, not read time, so the stored config is always already
disjoint and the shield never has to arbitrate.

Always Blocked wins outright: allowing an app to override a user's own hard block is a
silent bypass of the strongest statement they can make in this app.

### Types

```swift
/// An opaque FamilyActivitySelection plus what's needed to render it.
/// Tokens are the only real identity — icon names are DEBUG-mock only.
struct AppSelection: Codable, Hashable {
    var token: Data?          // encoded FamilyActivitySelection
    var appCount: Int
    var categoryCount: Int
    #if DEBUG
    var mockIconNames: [String]   // AppCatalog stand-ins until the picker is live
    #endif
    var isEmpty: Bool { appCount == 0 && categoryCount == 0 }
}

enum BlockLane: String, Codable, CaseIterable {
    case allowed, blocked, distracting
}

struct BlockConfig: Codable, Hashable {
    var allowed = AppSelection()
    var blocked = AppSelection()
    var distracting = AppSelection()
    /// Shield everything except `allowed`, instead of only `distracting`.
    var blockEverything = false
    /// ManagedSettings' own adult-content restrictions. No picker, no extension.
    var blockExplicitContent = false
}
```

`BlockConfigFile` — load/save JSON in Application Support, same shape as `DayLogFile` /
`HabitFile`. Everything on the current Blocks screen is an in-memory `var`, so today a
user's blocks die on relaunch; that gets fixed here.

---

## 2. ScreenTimeService

Replace the single-shield seam with a lane-aware one.

```swift
protocol ScreenTimeService: AnyObject {
    var authorizationStatus: PermissionStatus { get }
    func requestAuthorization() async -> PermissionStatus
    func presentAppPicker(current: Data?) async -> AppSelectionResult

    /// Everything that should be shielded right now, already resolved.
    func apply(_ shield: ShieldPlan) async throws
    func clearAll() async
}

/// What the engine hands down. No policy in here — it's already decided.
struct ShieldPlan: Equatable {
    var hardTokens: Data?        // Always Blocked
    var softTokens: Data?        // Distracting, nil while unlocked
    var exceptTokens: Data?      // Always Allowed, only used with blockEverything
    var blockEverything: Bool
    var blockExplicitContent: Bool
}
```

### Live implementation notes

- **Two named stores.** `ManagedSettingsStore(named: .init("aura.hard"))` and
  `…("aura.soft")`. Settings from named stores union, so buying time clears *only* the
  soft store — no conditional shield-building, and no way for a bug to unshield the hard
  lane.
- **Block-everything mode** uses
  `store.shield.applicationCategories = .all(except: allowedTokens)`. This is the only
  reason Always Allowed means anything — with an explicit Distracting list, an allow-list
  is a no-op, because you'd simply not add the app.
- **Explicit content** rides on the hard store and needs neither the picker nor the
  extension: ManagedSettings exposes an automatic adult-web-content filter and
  explicit-media restrictions. ⚠️ Exact property names to be confirmed against the SDK at
  build time — do not copy from this doc.
- Icons render via FamilyControls' own `Label(token)`. There is no API to turn a bundle ID
  into a token, so app artwork never comes from our asset catalog.

`MockScreenTimeService` keeps driving everything until the entitlement is wired: it records
the last `ShieldPlan` so the UI and tests can assert on it.

---

## 3. The blocking engine — one path

One function decides what is shielded. Every surface reads it; nothing computes its own
answer. This is what the current code gets wrong — `gateCountdown` prefers a running focus
session while `blockedNowAppIcons` prefers bought time, so the Home pill and the block set
disagree during a focus session with time banked.

```
plan(config, now) -> ShieldPlan

1. Always Blocked  → always in the plan.
2. Distracting     → in the plan UNLESS a soft unlock is in effect.
3. Soft unlock is in effect when: bought/earned time is running
                    AND no focus session is active.
4. Always Allowed  → only meaningful when blockEverything is on.
```

✅ **A focus session outranks bought time.** Start a session with 20 minutes banked and
Distracting re-shields for the duration; the bank is untouched and resumes after. Otherwise
you can "focus" while scrolling, which makes the coins that session pays out fake.

**Re-apply on:** launch, foreground, config change, unlock start/end, focus start/end,
purchase, Emergency Unlock start/end, and the existing manual *Reload Aura*.

---

## 4. Store changes

**Delete:** `scheduledBlocks`, `appLimits`, `habitBlocks`, `blockedApps`, `habitLockName`,
`habitLockDays`, `blockedNowAppIcons`, `applyPreset`, `addScheduledBlock`,
`addHabitBlock`, `toggleScheduledBlock`, `toggleAppLimit`, `updateScheduledBlock`,
`deleteScheduledBlock`, `updateAppLimit`, `deleteAppLimit`, both `setBreak` overloads.

**Add:** `blockConfig: BlockConfig` (persisted via `didSet`), `setLane(_:selection:)` with
precedence resolution, `refreshShield()`, `currentPlan`, and `blockedNowTokens` for the
icon strip.

**Keep:** `isUnlocked`, `secondsRemaining`, `emergencyUnlockUsed`, `useEmergencyUnlock`,
`reapplyBlocking` (rename → `refreshShield`), the whole coin economy.

---

## 5. The screen

`BlocksView`, three sections top to bottom. Light surface, existing design system —
`FocusCard`, `bottomDropCard`, `Theme.Radius`, `LightSheet` tokens.

### 5.1 Top card — `TabTopCard`

- **Control row:** explainer `?` (left, `QuestExplainer.blocking`) + reload (right).
  ✅ **Add Block is deleted** — the FAB is the only way to change blocking.
- **Body:** current state — *Blocked · 14 apps* or *Unlocked · 12:34 left*, live ticking.
- **Bottom of the card:** ✅ **Emergency Unlock**, full width, red, opening the existing
  `EmergencyUnlockSheet`. Disabled with its reason visible once used for the week.

### 5.2 Blocking Now

Horizontal scroll of app icons under the section header — no cards, no names. It shows
**state**, which the lists below can't: they're configuration.

- Unlocked: shows Always Blocked only, with the caption *"Still blocked while you scroll."*
  It must not go empty — that would be a lie.
- Nothing configured: an empty state pointing at the FAB.

### 5.3 The three lanes

Three tiles in one row — Always Blocked, Distracting, Always Allowed — each a square
preview with the lane's sticker, its name, and its count beneath. Tapping opens that lane's
own screen. Same shape as Opal's Apps row, in Aura's card language.

✅ Blocks keep stickers — each lane carries one, re-rollable via the existing
`StickerPickerSheet`.

**Always Blocked previews as hidden by default** — an eye-slash tile reading *Hidden*
instead of icons, revealed by opening the lane. Someone who permanently blocks an app is
often blocking something they don't want on a screen a friend might glance at, and the
count is the only part anyone else needs to see.

### 5.4 Lane screens

Full-screen cover per lane, on the method-screen background in that lane's colour. Header:
back, lane name, `+` (opens the system picker). Then:

1. **What this lane promises** — one card, plain language. *"Aura will never block these."*
   / *"Blocked until you earn or buy time."* / *"Blocked permanently. Coins won't open
   these."*
2. **One row per app** — icon (`Label(token)`), name, and an `×` to remove. Not a
   *"3 apps selected"* summary: tokens are individually removable by subtracting from the
   set, so the list should be a list.
3. **Add App or Website** row at the bottom, opening the same picker as `+`.

Always Blocked additionally carries the **Adult Websites** row — see 6.1.

### 5.5 The FAB

✅ The tab bar `+` becomes context-aware: earn methods on Home, **lanes** on Blocks — the
same Cal-AI dimmed popover, `+`→`×`, three cards instead of four. Cost: while on Blocks,
earning is two taps instead of one. Acceptable — earning lives on Home and Home is default.

---

## 6. Editing

Adding apps is the system picker, opened from `+` or the Add row. Removing is the `×` on a
row. There is no separate edit mode and no Save button — the lane screen *is* the state.

### 6.1 Adult Websites — commit both ways

A row inside Always Blocked: *"Blocks adult websites across your browsers and disables
private browsing."*

**Turning it on** opens a confirm sheet with **Hold to Commit** — reuse the existing
`HoldToUnlockButton`. **Turning it off** opens its own confirm with **Hold to Allow**, and
that copy cites recency when it applies: *"You only turned this on today."*

Friction in both directions is the point, and the asymmetry most apps get wrong is making
the *off* switch free. A 2am decision to undo a commitment should cost more than a tap.

⚠️ Aura ships no "Hard Mode / no way to bypass" variant. Opal gates one behind Pro; a
permanent, un-undoable block is a support burden and an App Review risk, and Emergency
Unlock exists precisely so nothing in this app is a one-way door.

### 6.2 Editing rules

✅ **Editing is allowed at any time, applied immediately — no queue.** The picker hands back
its selection on save, and the hole isn't "editing during a session": at any moment a user
can remove an app from their own list and free it. No queue closes that. Unrot's
edit-lock doesn't either — it reads as an implementation guard for their session state
machine. Retention comes from the streak and the coins, not from making removal annoying.

Conflicts resolve silently with an inline note naming the lane the app came from.

### 6.3 "Not working?"

The Blocking Now state line carries the reload inline — *"Not blocking? Reload Aura."* —
rather than hiding it behind the top card's icon. It's the first thing someone looks for
when the shield has been cleared by a restart, and it's the only fix they can perform
themselves.

---

## 7. Deletions

Files: `CreateBlockerSheet.swift` (676), `BlockerBreakSheets.swift` (205),
`Models/BlockRule.swift` (`ScheduledBlock`, `AppLimit`, `HabitBlock`, `Breakable`,
`BreakClock`), `Models/BlockPreset.swift`, the preset catalogue.

In `BlocksView`: Blocking Now vs Scheduled Blocks split, `presetsSection`,
`appListsSection` in its old form, `blockCard`, `statusPill`, `PulsingDot`, `isActiveNow`,
`timeRange`, `limitSubtitle`, all break plumbing.

`Models/AppList.swift` — `AppList` goes; `AppCatalog` stays as the DEBUG mock catalogue.

Roughly two-thirds of the Blocks code, nearly all of which never worked.

---

## 8. Deep Focus

✅ Remove the **Apps to Block** card from `FocusTimerSetupView` (`appsCard`, ~line 123) and
its picker state. With apps always blocked, asking which to block during a session is a
question whose answer is fixed. Deep Focus becomes purely an earn method: focus N minutes,
earn coins. Setup keeps Focus Length and Extreme Focus.

---

## 9. Order of work

1. `AppSelection` / `BlockConfig` / `BlockConfigFile` + persistence.
2. `ShieldPlan`, service protocol, mock updated to record plans.
3. Engine + store surgery; every surface reads the one plan. Fixes the focus/bought-time
   disagreement.
4. Deletions (compiler drives this).
5. Screen rebuild — top card, Blocking Now, three lanes, Sleep placeholder.
6. Lane sheet + FAB popover.
7. Deep Focus trim.
8. Live `ScreenTimeService` behind the entitlement.

1–7 are real end to end against the mock. 8 swaps one line.

---

## 10. Open

- **Sleep Mode — cut for launch (2026-08-10).** Designed and deliberately not built: it
  needs a DeviceActivityMonitor extension, an App Group, and `BlockConfig` moved out of the
  app container, none of which the other three sections require. If it comes back, build the
  habit-gated version — apps lock at bedtime and stay locked until a quest is done the next
  morning, coins refused in between — and note that it's the only rule in which Always
  Allowed does any work.
- **Shield-hit count** ("you hit the block 23 times today") — needs the same extension;
  would give the Blocks screen a fourth section worth having.
- **Onboarding** must set the Distracting lane. Currently untouched by any of this.
- Exact ManagedSettings property names for explicit content — verify against the SDK.
