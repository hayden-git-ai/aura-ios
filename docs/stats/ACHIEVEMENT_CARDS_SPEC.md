# Achievement Cards Redesign — Build Spec

Status: **locked, awaiting art** (2026-09-02). Do NOT build until Hayden sends the 4 new sticker raws (chest, apple, diamond, heart). Reference: gaming top-up store cards (rich icon art bleeding off, darkened, content clean on top).

## Scope
Redesign the 6 achievement cards on the Stats screen (`achievementCard` in `Features/Stats/StatsView.swift`). **Do NOT touch** the card shape (`RoundedRectangle` 28), size (172 × 172·1.18), the centered `StrokedNumber` + label, the depth shadow, or the `.scrollClipDisabled()` on the strip.

## Layered background (inside `.background`, clipped by the card shape)
Bottom → top:
1. **Base colour** — new per-card gradient (top→bottom), see palette below.
2. **`AchievementBurst`** — NEW shape/view: rays **and** concentric rings, anchored **bottom-centre** (behind the sticker), low white opacity. Same visual language as the lane cards' rays/rings but a fresh implementation — do NOT reuse `LaneCard`'s `rings` / `sunburst` / `cornerVignette`.
3. **Background sticker** — the per-card icon, oversized, anchored **bottom-centre**, bleeding off **left / right / bottom** (edges clipped by the card), **top edge ~¾ up the card** (~25% from top). Low opacity. Likely needs a per-sticker position/scale table (each icon's art bounds differ — same reason `LaneCard` has `artLayout`).
4. **Dark scrim** — bottom-weighted darkening over shape + sticker, so the number/label keep full contrast.
5. Number + label on top, unchanged.

## Icon → card mapping
| Card | Icon | Source |
|---|---|---|
| coins earned | Chest | NEW (Hayden sends) |
| best streak | Streak flame | exists → copy+rename raw |
| healthy habits | Apple (red) | NEW |
| reps completed | Diamond | NEW |
| time focused | Red clock | exists → copy+rename raw |
| time saved | Heart | NEW |

## Sticker treatment + naming
- **White sticker outline: YES.** All 6 go through the sticker-outline pipeline (`tools/sticker_outline.swift`) at the approved **AURA_OUTLINE=24**, white contour + shadow. Streak + clock use their RAW art (`Home_Aura Streak*`, `Lock In_Focus Length`) copied and renamed first.
- **Card-specific, independent imagesets** (nothing shared with the streak badge / focus screen):
  `Achievement_Coins`, `Achievement_BestStreak`, `Achievement_HealthyHabits`, `Achievement_Reps`, `Achievement_TimeFocused`, `Achievement_TimeSaved`.
- Principle: each card's bg colour matches its icon's colour family, so the (low-opacity, darkened) sticker **blends but stays visible** — this is what makes the set cohesive.

## Proposed colours (top→bottom gradient, tunable on first render)
- Coins / chest — gold: `#E8A317 → #B26A00`
- Best streak / flame — orange: `#FF7A33 → #D0491A`
- Healthy habits / apple — **red**: `#E8453B → #B22A22`
- Reps / diamond — blue: `#3BA9F5 → #1E5FB0`
- Time focused / clock — deep crimson (cooler/darker than apple, to stay distinct): `#C8324A → #8A1B2E`
- Time saved / heart — rose: `#FF5E8A → #C22E5A`

## Code touchpoints
- `AchievementItem`: repurpose the currently-unused `fox` field into `sticker` (bg icon asset); add per-sticker layout table if needed.
- New `AchievementBurst` shape/view (rays + rings, bottom-centre, low opacity).
- Rework `achievementCard`'s `.background` into the 4-layer ZStack.

## Pending from Hayden
4 new sticker raws: **chest, apple, diamond, heart**. (Streak + clock already exist as raws.)
