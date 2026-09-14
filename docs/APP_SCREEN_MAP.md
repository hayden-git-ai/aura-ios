# Aura — Full App Screen Map (as-built)

The complete map of the shipped app, so the onboarding we build represents the real product faithfully. Verified by walking every tab in the simulator and reading every feature's code. Dark mascot pivoted to the **arctic fox**; the app is **light** on most surfaces with **day/night** artwork on Home/Intervention.

## The one-sentence product

Your distracting apps stay **frozen**. You **earn coins** by doing a real habit (and proving it), then **spend coins** to buy screen-time windows. The **fox** mascot reflects how you're doing (drained when apps are open, charged when you earn). 1 coin = 1 minute.

## The core loop (what the onboarding must teach)

1. Apps you pick sit in one of three lanes: **Forbidden** (gone), **Tempting** (frozen until you pay), **Allowed** (always open).
2. **Earn coins** four ways: **Healthy Habits** (photo proof), **Daily Exercise** (on-camera rep counter), **Deep Focus** (a lock-in timer), **Passive Income** (Apple Health activity). Focus habits pay after a timed session; quick habits pay instantly.
3. **Spend coins** in the **Scroll Bank** to buy minutes; the purchase is a tap-to-pay card-swipe ritual that prints a receipt.
4. Open a frozen app and the **Intervention** fires (the fox stops you): you either back out (free) or spend coins to buy time via a hold-to-confirm.
5. **Streak, charge bar, power-ups, wins wall** gamify it; day/night art and the fox's mood make the state legible.

---

## Shell + navigation

- **Splash** (`SplashOverlay`): fox flipbook + rotating conic sunburst over Aura blue; a circular hole opens to reveal the app.
- **AppGate** (`Features/Setup/AppGate.swift`): routes first run → onboarding → **Setup handoff** (permissions) → the app. `-home`/`-setup`/`-onboarding` debug args.
- **Floating capsule nav** (`AuraTabBar`): Instagram-style pill, icon-only sticker tabs — **Home (fox) · Apps (lock) · Stats (calendar w/ today's date) · Profile (fox avatar)**. No raised center; the "+" earn action is the Home Quests card / center. Frosted-dark on Home, solid-dark on white tabs; shrinks on scroll.

## Tab 1 — Home (`Features/Home/HomeView.swift`)

Day/night mountain background (`HomeBackground`, flips 7am/7pm). Elements: **AURA** stroked wordmark; **streak badge** (flame + count, opens the Streak screen); **Frozen Apps pill** (fanned app icons → BlockedNowSheet); the **fox focal** (fixed 260pt, tired flipbook or a "blocked" loop) — its mood is set only by whether Tempting apps are shut; a **coin balance** (big stroked numeral + coin) with a rising "+N" earn chip; a **4-segment charge bar** (power-ups at 25/50/75/100 coins, bolt nodes, skull at zero); and two cards: **Quests** (opens the earn popover) and **Scroll** (opens the Store).
- **Earn popover:** dimmed scrim + a 2×2 grid of method cards growing out of the Quests card: **Healthy Habits / Daily Exercise / Deep Focus / Passive Income**, each a fox + title + one-line descriptor in the method's color.
- Presents: Store, Streak screen, Streak celebration, rating ask, Blocked-now sheet, Habit session sheet, and the four earn-flow covers.
- **Streak screen** (`StreakScreen`): orange sunburst, streak fox with fire tail, day count, goal bar, and a **Streak Freeze** card. **Habit session sheet:** a 240pt ring timer with Pause/End.

## Tab 2 — Apps / Blocks (`Features/Apps/AppsView.swift`)

- **Frozen Apps** rail: `FrozenAppTile`s (real icon behind a glossy-ice frame with sparkles) — what's shielded right now.
- **Three lane cards** (`LaneCard`, chunky game-piece style, character bleeding off the corner over a ray/ring burst): **Forbidden** (cold near-black `#16151C`, skull tiles, pleading fox, hidden list, 10s-hold to remove, adult-website filter), **Tempting** (red `#FF3B30`, spiral-eyed doomscroller fox, frozen until you buy time), **Allowed** (blue, star-eyed fox, never frozen).
- **RuleSheet** (per-lane editor, no save — the sheet is the state), **BlockingHelpSheet** ("How Blocking Works" using the real lane cards), **BlockedNowSheet** (read-only frozen list + a buried **Emergency Unfreeze** → hold-to-redeem receipt "pass").

## Tab 3 — Stats (`Features/Stats/StatsView.swift`)

One gamified scroll: **top slab** (a screen-time card: today's total, most-used apps, pickups, a tappable Sun–Sat bar chart with a dashed average line) → **Achievements** (horizontal strip of bleed-off sticker cards on ray/ring bursts: coins earned, best streak, healthy habits, reps, time focused, time saved) → **Your past 90 days** (a 90-cell flame grid) → **Wall of wins** (photo-proof wins strip; empty state = crying fox). **WallOfWinsSheet** (full grid) → **WinDetailView** (full-screen photo). Analytics were deliberately cut down to this feed.

## Tab 4 — Profile (`Features/Profile/ProfileScreen.swift`)

Social-style: **stretchy mountain cover** + circular avatar + settings gear; a **blue identity band** (name as stroked numeral, "Joined YEAR", three stat pills — Best streak / Habits done / Time saved) + "Edit profile" / "Share Aura"; a purple **"Talk to the founders — Got feedback?"** card; a floating **support chat FAB** (blue bubble). 
- **SettingsScreen:** Preferences (Profile, Reminders, **Intervention Style**, Difficulty), Support & Legal, Follow us, Debug (DEBUG-only), version.
- **ProfileEditScreen** (name wired; email/password/delete stubbed pending accounts), **PasswordChangeScreen** (stubbed), **SupportChatView** ("Team Aura" local-only thread), **InterventionStyleSheet** (multi-select the four styles; last-one-on guard).

## The Intervention (`Features/Intervention/*`) — fires when you open a frozen app

Four user-selectable styles (Aura picks one at random per run, so it's not a button you learn to tap): **Talk to Aura** (dialogue), **Breathing Pause**, **Mirror Check** (a fake FaceTime from your own front camera), **Text From Aura** (an iMessage-style thread). Beats: challenge → back out (free) or insist → pick a duration → **hold-to-confirm to pay** coins → spent. The fox's pose and lines escalate (thinking → shades when you quit → arms-crossed → slumped → crying). Copy is the dry, lowercase, guilt-trippy fox voice (`InterventionScript`, 3 rotating). Shared chat chrome is `FoxChatChrome` (the same "Text From Aura" scene the onboarding fox chat should reuse).

## The four earn methods (`Features/PhotoProof`, `/Exercise`, `/DeepFocus`, `/AddHabit/AppleHealthView`)

Each owns a color + fox + flow root (in-place stage swaps), all converging on a shared success spine.
- **Healthy Habits / Photo Proof** (blue): pick habit + length → back-camera capture → AI verify (scan-motes overlay) → **pass** → success, or **fail** → red-ripple retake. Focus vs Quick split (timed session vs instant). Wins land on the Wall.
- **Daily Exercise / Camera Reps** (orange): pick exercise + goal → front-camera Vision rep counter (skeleton overlay, live "+N" coins, framing hints) → claim → success.
- **Deep Focus / Lock In** (violet): setup sheet (length, routine, Extreme untimed) → full-screen day/night lock-in timer (meditating fox, stroked countdown, immersive tap-to-hide) → success.
- **Passive Income / Apple Health** (pink-red): connected metrics list (rates, coin badges, "no activity", refresh toast) → Collect all → success; or a disconnected connect-prompt.
- **Shared spine:** `SunburstSuccessView` (method-hued rotating sunburst + `SuccessCelebrationArt` fox + 3 stat tiles + rank highlight + claim button), then `StreakCelebrationView` on the first habit of the day (streak fox with fire tail, count roll-up, goal bar). Add-habit launcher (`AddHabitFlowRoot`) has Focus/Quick tabs and difficulty filters, plus habit/exercise detail screens.

## The Store (`Features/Store/ScreentimeStoreView.swift`) — "The Scroll Bank"

All-blue. Balance + an `AuraBankCard`, a "Recent Transactions" panel, "Buy Screentime" → `BuyScreentimeSheet` (hours/minutes wheels, capped to balance) → an in-place **tap-to-pay card reader** (swipe the card up, authorizing dots, checkmark) → a printed **Scroll Receipt** ("GUILT-FREE SCROLLING", "You earned this one. Enjoy it.") → Start Scrolling.

## Design language (reuse for onboarding, per Brainrot)

- **Light** ground `#FAFAFA`; day/night art on Home/Intervention/Lock-in. One blue accent `#2586FF` (+ method accents: orange `#FF6B03`, focus violet `#5B4BE0`, health `#FF3B5C`). Danger red `#FF3B30`. Charge green `#21C55E`.
- **Rubik** only; **stroked sticker numerals** (`StrokedNumber`, black fill/white outline) for every hero number; **baked sticker art** (white contour + soft shadow) for icons; **chunky rounded cards** with the double shadow; **ray/ring bursts** behind hero cards; the **fox** carries mood; **`HoldToConfirmButton`**, **`PressBounceStyle`**, **`LightPrimaryButton`** (drop-lip pill).
- Spacing 4/8/12/16/24/32/48; radii field 12 / card 16 / hero 24 / panel 32 / sheet 38 / pill 999.

## What the onboarding must set up (hand-off contract)

Permissions + account creation live in the **post-paywall Setup flow** (already built): Screen Time auth, the app picker (which apps go in which lane), notifications, sign-in. So onboarding sells the loop above and hands to Setup; it asks **zero** permissions itself.
