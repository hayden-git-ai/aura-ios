# Aura DESIGN.md

Design is a trust signal, and trust is what converts. This file is the single
source of truth for how Aura looks and feels. Point your AI tool at it:
**"Follow DESIGN.md for all UI work."**

It documents Aura's *actual* system (the tokens already in code) plus the rules
that keep 100 AI-generated screens from drifting into slop. Written from a
screen-by-screen audit of the app on 2026-09-07; the anti-slop, copy, motion,
and token-discipline layers (§9 to §12) were added 2026-09-08 from the
impeccable, humanizer, frontend-design, ui-ux-pro-max, shadcn, and GSAP sources.

**Meta-rules for this doc:** every rule anchors to a token, a number, or a
concrete example; no rule rests on an adjective ("make it friendly" is not a
rule). Every "do" carries a "don't." If a rule can't be checked in review, it
isn't written yet.

---

## Source of truth (never invent values inline, use these)

| Concern | Where it lives |
|--------|----------------|
| Spacing, radius | `DesignSystem/Theme.swift` → `Theme.Spacing`, `Theme.Radius` |
| Color | `DesignSystem/Components/LightSheet.swift` → `LightSheet.*` (~40 semantic tokens) |
| Type | `DesignSystem/Typography.swift` (`auraFont`, `Typography.*`) + `SheetType`, `RowType` |
| Buttons / press | `LightPrimaryButton`, `PillPressButtonStyle`, `PressBounceStyle` |
| Onboarding chrome | `Features/Onboarding/OnboardingKit.swift` (`OnbTopBar`, `OnbSkyBackground`, `HillShape`) |

If a value you need isn't a token yet, **add a named token** to the file above.
Do not paste a raw number or hex into a feature view.

---

## 1. Type, Lilita One display and Rubik UI

- Approved 2026-09-20: headlines, titles, and display words use bundled **Lilita One** at existing point sizes. Body text, controls, captions, and UI labels stay **Rubik**.
- Live timers and changing counters retain Rubik's tabular numerals. Lilita One has proportional digits and no tabular-number feature.
- Lilita One has one static weight; do not synthesize bold/black variants. The older one-family rules below are superseded for these display roles.

- All text uses **Rubik** via `auraFont(.display | .body, size, weight)`. Bold
  (700) is the weight ceiling for the whole app.
- Sizes come from `SheetType`: `hero 34`, `heroCompact 28`, `title 22`,
  `banner 20`, `cta 18`, `cardTitle 15`, `subtitle 13`, `cardBlurb 13`;
  row text from `RowType`: `label 13`, `subLabel 12`.
- **RULE:** never `.font(.system(...))` on **Text**. `.system` is only for SF
  Symbol `Image`s. *(Sole exception: screens that deliberately replicate native
  iOS UI, e.g. `IncomingCallView`.)*
- **RULE:** any number that **changes** (balances, timers, counters, stats) uses
  **tabular figures**, `Typography.tabularNumerals(...)` or `.monospacedDigit()`,
  so digits don't jitter width.
- **Stroked hero numerals:** big showcase numbers (streak, coin balance,
  achievement counts) use the sticker-outlined display numeral
  (`Typography.displayUIFont` / `StrokedLabel`). One of the three deliberate
  weight-ceiling exceptions. Keep these for hero numbers only.

## 2. Spacing, 4pt scale

- `Theme.Spacing`: `xs 4 · s 8 · m 12 · l 16 · xl 24 · xxl 32 · xxxl 48`.
- Every padding, margin, and stack gap is one of these. No arbitrary numbers.
- One-off art sizes (fox heights, hero clearances) are allowed but must be
  **named constants** at the top of the view, never bare literals scattered in
  the body.

## 3. Radius + corners

- Approved 2026-09-21: custom close, back, settings, help, and delete controls use the `AuraWood*` illustrated assets through `CircleIconButton` / `WoodButtonArtwork`; Create Your Own uses `AuraWoodAdd`. Symbols are centered on the front wooden face, excluding the bottom edge and shadow. Preserve at least 44 × 44pt hit areas, accessibility labels, and existing actions. Arithmetic steppers and system controls retain their existing treatment.

- `Theme.Radius`: `micro 6 · tile 8 · field 12 · card 16 · hero 24 · panel 32 ·
  sheet 38 · pill 999`. Pick by role (a field ≤ a card ≤ a hero tile).
- **RULE:** every rounded shape uses `style: .continuous` (squircle). Never the
  `.cornerRadius()` modifier. *(Audit: already 100% compliant, keep it that way.)*

## 4. Color, semantic tokens only

- `LightSheet` already defines the palette: `ground`, `field`, `title`,
  `subtitle`, `subtitleDark`, `blue #2586FF`, `blueShade`, `danger`, `surface`,
  `divider`, and ~30 more.
- **RULE:** no inline `Color(hex:)` in a feature file. Need a colour? Add a named
  token to `LightSheet`.
- **The dark highlight pill** (Aura's translucent-dark fill on colour) is
  `Color.black.opacity(0.16)`. Use it for cards/pills sitting on a colour ground.
- **Section-world palette (intentional):** each domain owns a colour world,
  blue = focus/healthy, orange = exercise, purple = deep focus, red/pink =
  passive income & "tempting", dark = "forbidden". Keep a domain's colour stable
  across screens.
- **Allowed inline hex (comment it):** replicating a real third-party app's brand
  colour (the Loop Demo IG feed, real app-icon accents) and multi-stop art
  gradients (the sunburst). These are art, not UI tokens.

## 5. Icons, stickers + SF Symbols, never emoji

- **Brand / content** icons are custom **sticker assets**: `Image("EarnCardIcon")`,
  `Image("AuraCoinIcon")`, the fox stickers, the frozen-app tiles.
- **Standard affordances** are **SF Symbols**: `chevron.left/right`, `xmark`,
  `checkmark`, `square.and.arrow.up`, `bolt.fill`, `eye`. `Image(systemName:)`.
- **RULE:** **no emoji as UI icons** anywhere in the app. *(Onboarding still has
  a few emoji, those are being replaced with stickers.)*

## 6. Shadows, one scale

- **RULE:** content **cards** share one `cardShadow`; **sheets/modals** share one
  `modalShadow`. Define them once; don't hand-tune opacity/radius per view.
- **Illustration drop-shadows are separate and intentional**, the fox, the phone
  mockup, the bank card, sticker art carry their own depth shadows. Leave those.

## 7. Motion + feedback

- **Every interactive element reacts.** Primary CTAs use `LightPrimaryButton`
  (`PillPressButtonStyle`: 0.96 scale + sink + **light haptic on press**).
  Tappable cards/rows use `PressBounceStyle`.
- **Haptics** on meaningful actions via `Haptics.impact(...)`.
- Standard press/settle spring: `spring(response ~0.24, dampingFraction ~0.55)`.

## 8. Native feel

- **Safe areas:** content respects them; only *backgrounds* use
  `.ignoresSafeArea()`.
- **Tap targets ≥ 44pt.** The *visual* element can be smaller, pad the hit area
  and set `.contentShape(...)` (see `OnbTopBar`'s 40pt disc / 44pt hit area).
- **Sheets:** native sheet + grab handle, or the app's `FocusSheetGrabber` +
  `focusSheetMaterial` convention for focus sheets.
- **Tab bar:** floating capsule, ≤ 5 tabs, clear active-tab highlight. Frosted on
  colour grounds, solid dark on white grounds.
- **CTA on a scroll:** a real pinned button; if it must be "transparent," float it
  over the content on the dark highlight pill (`black.opacity(0.12)`, a little
  bigger than the button), never a white footer bar. See the create-your-own
  FAB and the custom-plan CTA.

---

## 9. Anti-slop, the AI tells we never ship

The exact failure this section exists to stop: a fox **emoji** dropped in a
**white circle with a blue glow behind it** as the paywall hero. That is three
tells in one element (emoji-as-art, decorative glow orb, centered filler). Banned.
Real fox sticker/art or nothing. *(Sources: impeccable.style/slop, frontend-design,
ui-ux-pro-max.)*

**Color / surface**
- No purple-to-blue gradients. Anywhere. It is *the* AI palette. Aura is white +
  one blue accent (`#00BFFF`).
- No glassmorphism-for-cool, neon glow, blurred orb, or dark-page-with-a-colored-glow-shadow.
  (Aura's only real glass is the frosted tab bar on colour grounds, §8: a chosen
  use, not decoration.)
- No radial-gradient halo behind a screen as "atmosphere."
- Neutrals tint toward the brand hue. No pure `#000` or pure gray for text/fills;
  use the tinted `title`/`subtitle` tokens (a very dark desaturated blue reads more
  Aura than black).
- No gray text on a colour ground (washed out), no gradient text (kills
  scannability), no text under 4.5:1.

**Cards / borders**
- No thick colour border on one side of a card. The single most recognizable tell.
- No hairline border + wide diffuse shadow (fake depth). Use the one `cardShadow`.
- No cards inside cards inside cards. Past two levels of nesting, flatten.
- No 24px+ radius that turns a control into a blob (radius by role, §3).

**Typography**
- Rubik is the one family (§1). Never add Inter, Geist, Space Grotesk, Instrument
  Serif, or an italic-serif hero headline.
- No rounded-square icon tile stacked above every heading (the universal AI feature
  card).
- Fewer sizes, more contrast: adjacent steps differ by ~1.25x or more. No flat
  hierarchy with sizes a few points apart.
- No all-caps body, no body under 12px, no line-height under 1.3, no crushed or
  wide tracking on body copy.

**Layout**
- No hero-metric block (big number, small label, three stats, accent) unless the
  number is genuinely the point. It is the template answer.
- No screen that is just an identical repeating icon+title+text card grid.
- Spacing has rhythm (§2); text never touches the container or screen edge
  (min inner padding = `Theme.Spacing.m`).
- One accent carries emphasis. One visual metaphor per surface: don't stack glass
  on ice on clay. Pick the domain's world (§4) and commit.

**Then remove one thing.** Spend boldness once: one signature moment per screen,
everything else quiet. Before shipping a screen, delete one decorative element.

## 10. Copy, write like the fox, not like a model

Run every user-facing string through this. *(Sources: blader/humanizer,
[[no-em-dashes]], [[aura-humanizer-copy-rule]], [[aura-intervention-copy-voice]].)*

**Clarity (never vague, this is the rule broken most often):** Write at a **5th-grade
reading level**. Short sentences, plain everyday words, simple and clear. Every line
must mean something **concrete to someone who has never opened Aura**. Name the real
thing: "Block the apps that distract you most," not "block the apps that pull you in."
If a line could describe almost any app, it is too vague, rewrite it. No insider words
a newcomer won't know (coins, check-ins, streaks, freeze) unless that same line
explains them. **Never describe a feature the app does not have.** When unsure what a
feature really is, read the code or the screen map, don't guess.

**Capitalization (the rule I keep breaking):** all UI and product copy uses proper
**sentence case** by default: headlines, subheads, buttons, labels, paywall, settings,
onboarding, everything. Capitalize the first word and any proper noun (Aura, Settings,
Screen Time). The ONLY lowercase copy is **the fox actually speaking**: intervention
scripts and mascot speech bubbles, where dry all-lowercase is the character's voice.
If it is not the fox talking in-character, do not lowercase it. (all-caps micro-labels
like a small `AURA PRO` badge are a separate, allowed UI pattern, not "copy".)

**The fox's spoken voice (only place lowercase lives):** dry, all-lowercase, a little
guilt-trippy, feelings match the animation. Fox emojis in its lines are fine 🦊. This
is the one deliberate override of humanizer's sentence-case default, and it applies to
mascot speech only, never to headlines/buttons/product copy.

**Never (hard):**
- **No em dashes.** Ever. Break into periods, commas, colons, or parentheses.
- **Banned words:** actually, additionally, align with, crucial, deep dive, delve,
  emphasize, enhance, foster, garner, highlight (verb), interplay, intricate,
  key (adj), landscape (abstract), meticulous, pivotal, quietly, robust
  (figurative), showcase, tapestry, testament, underscore (verb), valuable,
  vibrant. (crucial/key/valuable/quietly sneak into guilt-trip microcopy: watch them.)
- **No buzzwords:** streamline, empower, supercharge, world-class, enterprise-grade.
- **No "not just X, it's Y"** and no "this doesn't mean X, it means Y."
- **No staged openers:** "here's the thing," "let's dive in," "honestly?", "to be clear."
- **No fake-deep closers, no fragments-for-drama, no "at its core."**
- **No forced triads:** three items only when there are genuinely three.
- **No fabricated data, reviews, stats, or user counts** (honesty gate). "4.2x
  faster" and "lowest price ever" are banned unless true. "50% off" is fine when
  `$69.99 -> $34.99`.
- Straight quotes, not curly. No chatbot residue ("great question!"). No "experts
  say." Active voice, plain verbs (is/are/has, not "serves as/boasts/features").

**Do:** say it once, plainly. Name the actor. Vary sentence openings. One concrete
claim beats one aphorism. Use the same word for the same action across a flow (a
button that says "unlock" produces a state that says "unlocked").

## 11. Motion craft (extends §7)

§7 is the press-feedback baseline; this is the choreography layer. *(Source: GSAP /
greensock gsap-skills.)*

- **Direction of ease:** enters ease-out (`.easeOut` or a settling spring), exits
  ease-in, moves ease-in-out. Never ease-in-out on an entrance.
- **Durations:** micro-interactions (tap, toggle, press) 150-350ms; screen / sheet /
  hero transitions 400-700ms; a deliberate showcase beat up to ~1s, never routine UI.
- **Duration scales with distance/size.** A big element travels longer than a small
  one. No single uniform duration for everything.
- **Stagger** lists/grids 60-100ms per item so a set cascades instead of popping in
  at once.
- **Orchestrate** related motion on one animation with shared timing, not scattered
  independent delays that drift out of sync.
- **Overshoot (`back`/`elastic`/bounce) is a reward flavour only:** the fox reacting,
  a coin payout, a success burst. One overshoot per moment. Never on frequent
  utilitarian controls (see §9: no bounce as a default).
- **Interruptible:** a new gesture retargets the in-flight animation from its current
  value; never snap-to-end-and-restart. (SwiftUI `withAnimation` on state does this;
  avoid manual hard resets.)
- **Every animation earns its place by showing cause and effect** (what changed, from
  where, to where). Decorative motion gets cut.
- **Reduced motion:** gate large position/scale/parallax behind
  `@Environment(\.accessibilityReduceMotion)`, fall back to an opacity crossfade.
  Linear easing only for ambient loops (glow pulse, spinner), never for spatial moves.

## 12. Token discipline (extends §4)

Aura already uses semantic tokens; these sharpen them. *(Source: shadcn theming.)*

- **Surface/foreground pairs:** every surface token has a paired text token chosen to
  pass contrast by construction (title on ground, text-on-blue), so legibility is
  never eyeballed per screen.
- **One base drives a scale:** radius steps derive from one base (§3), type sizes from
  a small set (§1). Retune from one knob, keep proportion.
- **A `muted`/secondary text role plus weight carries de-emphasis,** not a new one-off
  point size.
- **Explicit structural tokens** for divider / field-border / selection, so hairlines
  and selected states are uniform, not ad-hoc per control.
- **Charge bars, stats, and charts get their own colour slots,** kept separate from
  the UI accent.
- **Any colour, size, or radius that appears twice is a missing token.** Name it in
  the source-of-truth file; never repeat the literal.

---

## Weekly 20-minute tell-list audit

- [ ] Any `.font(.system(...))` on **Text**? → move to `auraFont`/Rubik.
- [ ] Any **changing number** without tabular figures? → add `.monospacedDigit()`.
- [ ] Any inline `Color(hex:)` that isn't a brand-replica or art gradient? → token.
- [ ] Any rounded shape missing `.continuous`?
- [ ] Any card/modal shadow off the `cardShadow`/`modalShadow` scale?
- [ ] Any tap target under 44pt hit area?
- [ ] Any emoji used as a UI icon?
- [ ] Every new interactive element has a press state + (where meaningful) haptic.
- [ ] Any purple-blue gradient, glow orb, glassmorphism-for-cool, or emoji-as-art? → §9.
- [ ] Any side-border card, hairline+diffuse-shadow, or 3-deep card nesting? → §9.
- [ ] Any banned word, em dash, fabricated stat, or curly quote in copy? → §10.
- [ ] Enters ease-out / exits ease-in, overshoot only on a reward beat, reduced-motion path? → §11.
- [ ] Any literal colour/size/radius used twice that should be a token? → §12.

---

## Fixed (2026-09-07 pass) + honest correction of the audit

The first audit over-counted by conflating correct usages with problems. What was
actually true and done:

1. **Tabular numerals, was real, now DONE.** Added `displayUIFont(tabular:)`
   for the stroked hero numerals (timer, streaks, coin balance, Home countdown,
   Stats + Profile stat values) and `.monospacedDigit()` on the SwiftUI changing
   numbers (success tiles, habit-detail stats, buy-sheet, screen-time total +
   Apps/Pickups, rep counters, scrubbers). The one genuine, high-leverage gap.
2. **Sub-44 tap targets, mostly already fine.** The shared `CircleIconButton`
   (`minimumTarget = 44`) and the heart favorite were already 44pt hit areas.
   Only ~5 bespoke Profile buttons were real; those are fixed. ("~25" was wrong.)
3. **SF-font-on-text, was largely a false finding.** Nearly all `.font(.system)`
   is on SF Symbols (correct), emoji fallbacks (`habit.emoji`, system font
   required), or the deliberate native-mimic screens (`IncomingCallView`,
   `MessageThreadView`, `SupportChatView`). Only the FocusLengthScrubber tick
   labels were genuine → moved to Rubik. The app already follows one-family.
4. **Inline hex, one genuine repeat.** `FF3B30` (7 files, the destructive /
   "Tempting" red) → `LightSheet.rippleRed`. The rest is gradient art and
   native-mimic replicas, which stay inline by design.
5. **Shadows, already systematic.** Illustration depth uses `foxShadow()` /
   sticker-shadow tokens; the remaining `.shadow()` values are purpose-specific
   (card 0.07–0.14, text-on-photo 0.18–0.35, sticker-outline 0.45–0.55), not
   drift. Added `cardShadow()` / `modalShadow()` as the standard for new cards;
   did **not** force-retrofit the intentional purpose-specific shadows.

**Follow-up:** the DeviceActivityReport screen-time banner is a separate
extension target with its own font pipeline, tabular there is a later task.

**Onboarding:** clean on corners (100% continuous), one family (Rubik), press
states, and haptics. Its only real gap is **emoji used as icons**, already slated
for sticker replacement.

**Not vibe-coded, keep it that way.** Aura has a real identity (arctic fox +
blue world + Rubik + stickers). No purple-blue hero gradients, no Inter, no
generic 3-card heroes, no colored left-border strips, no emoji-in-a-glow-circle.
That distinctiveness is the trust signal; protect it on every new screen. §9 to
§12 are the enforceable version of this paragraph: read them before building any
new surface (a paywall included).
