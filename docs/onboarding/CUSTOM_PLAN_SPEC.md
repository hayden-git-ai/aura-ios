# Custom Plan screen spec

The payoff reveal right after the loader. One long vertical scroll, sticky Continue.
Adapts Unrot's plan sequence (hero payoff, 4-week timeline, two-paths, reviews, FAQ)
into Aura's language: white fox, blue ground, lowercase house voice, no fabricated stats.

Status: copy humanized, awaiting final founder lock. Do not build until founder says build.

Flow position: inserts between `qLoading` and `qImmediate`. Absorbs the standalone
Reviews screen and the two-paths ("the science") screen. Both are folded in here.

Design constraints (locked, do not re-litigate):
- White fox mascot, not a brain. Blue ground (LightSheet.blue). No green.
- Lowercase house voice for titles/copy; proper case for names and real nouns.
- No em dashes. Copy run through the humanizer ruleset (blader/humanizer).
- No fabricated ratings, user counts, or reviews. Honesty gate.
- Aura components / SheetType type scale / Theme.Spacing. Translucent black.opacity(0.16)
  cards with the always-on 2.5pt white outline, matching the benefits screen.

Personalization: DEEP. Every section pulls from real onboarding answers.
Charge art: ONE fox at the hero. No glow ring. No per-week fox states.

---

## Scroll order

A. Hero payoff
B. Your scroll profile (real bars)
C. The 4-week arc
D. Two paths (drained vs charged toggle)
E. Your plan recap
F. Reviews (PLACEHOLDER, real at launch)
G. FAQ
Sticky CTA: Continue

---

## A. Hero payoff

- One fox, upbeat pose, on the blue ground. No ring.
- Headline (heroCompact bold, lowercase, personalized name):
  "in 4 weeks, you won't recognize yourself, Hayden."
  (no-name fallback: "in 4 weeks, you won't recognize yourself.")
- Ready confirmation: white check + "your plan is ready"
- Date pill: "you'll feel like yourself again by **Oct 3**"
  - date = today + 28 days, formatted "MMM d". Computed live, never hardcoded.
- No laurels. The data profile in section B carries the proof instead.

---

## B. Your scroll profile

Header: "here's what we're working with"
Three labeled bars driven by real answers. Track white.opacity(0.22), fill white or #00BFFF.

1. **daily screen time** — value "6h"
   - fill = `hours / 12`
   - under it: "about {daysPerYear} days a year on your phone"

2. **when you're most exposed** — mornings <-> evenings track, marker at their time
   - `worstTime` marker position (0 = far left):
     - "First thing in the morning" -> 0.08
     - "During the day"             -> 0.42
     - "Evenings"                   -> 0.92
     - "Honestly, all day"          -> full bar lit, label "all day"
     - "Not sure"                   -> 0.5, muted
   - end labels: "mornings" / "evenings"

3. **mental drain** — low <-> high
   - fill = min(1, feelings.count/6 * 0.6 + hours/12 * 0.4)
   - under it: "mostly showing up as {top feeling}"
   - end labels: "low" / "high"

---

## C. The 4-week arc

4 cards, Aura material, no fox. Each: week label + title (fixed) + 2 fixed lines +
1 DYNAMIC line from their data.

**week 1 — the drain stops**
- you scroll less without forcing it
- the itch to check gets quieter
- dynamic (top `feeling`, else `goal`):
  - Bad sleep / goal Sleep better   -> your nights stop disappearing to the feed
  - Anxiety / overstimulation        -> your head feels a little less wired
  - No focus / procrastination       -> the fog starts to lift
  - Productivity loss                -> you start the thing you keep putting off
  - Mentally fried                   -> your brain gets a minute to breathe
  - Less time with friends / family  -> you look up and someone's there

**week 2 — the turn**
- your focus holds instead of snapping every few minutes
- you reach for your phone less on autopilot
- dynamic (`worstTime`):
  - morning    -> mornings stop starting in bed with your phone
  - during day -> your work hours stop leaking away
  - evenings   -> your evenings start to feel like yours
  - all day    -> the all-day pull starts to loosen
  - not sure   -> the dead-time scrolling starts to fade

**week 3 — the rewire**
- picking up your phone takes real effort now
- the habits stop needing willpower
- dynamic (first favorited habit or exercise `name`):
  - earning coins with {habit} feels automatic now
  - (no picks) -> your good habits start running themselves

**week 4 — you, charged**
- calm mornings, sharper focus
- your phone's a tool again, not a leash
- dynamic (`goal`):
  - Improve focus             -> you finish what you start
  - Reduce mindless scrolling -> the feed's just an app now, not a reflex
  - Sleep better              -> you fall asleep without the doomscroll
  - Be more present           -> you're where you are
  - Be more productive        -> your days have room in them again
  - Just curious              -> you get why people don't go back

---

## D. Two paths (drained vs charged toggle)

Adapts Unrot's Brainrot/Unrot toggle. Aura's version = drained vs charged.
Header: "two paths. which one do you pick?"
Sub: "toggle to see the difference"
Segmented toggle: **drained** (red ground, #FF3B30 family) | **charged** (blue ground, LightSheet.blue)
Background of the whole section swaps with the toggle.

DRAINED side (red X rows, deep personalized from `feelings`, first row always the hours):
- you lose about {hours} hours a day to your phone
- No focus / procrastination      -> you put off what matters, then feel bad later
- Bad sleep                       -> you scroll in bed and wake up tired
- Anxiety / overstimulation       -> you feel wired and can't wind down
- Productivity loss               -> your to-do list rolls to tomorrow again
- Mentally fried                  -> your head feels fried by the afternoon
- Less time with friends / family -> the people around you get your leftovers
- (fallbacks to reach 4) -> you can't focus without checking your phone
                          -> half your day goes somewhere you can't name

CHARGED side (blue check rows, personalized from `skips`, first row always the reclaim):
- you get those {hours} hours back
- Sleep                            -> you sleep through the night
- The gym                          -> you make it to the gym
- Work or study                    -> you get real work done
- Time with people                 -> you're present with people
- Getting outside                  -> you get outside
- Something you'd promised yourself-> you start the thing you promised yourself
- (fallbacks to reach 4) -> you do what you set out to do
                          -> you focus without reaching for your phone

Optional chips row (their picked habit stickers on the charged side). Cut if it crowds.

---

## E. Your plan recap

Header: "your plan, built from what you told us"
One recap card showing their real inputs:
- goal chip
- habit + exercise sticker chips (the app stickers) for everything they favorited
- commitment: "{dailyMinutes} min a day · {tier}"  (30 Casual / 60 Regular / 90 Serious / 120 Hardcore)
- payoff line: "on track to win back +{yearsOfLifeLost} years of your life"

---

## F. Reviews  (PLACEHOLDER)

Header: "people who stopped scrolling"
2-3 white review cards: name + quote + 5 stars.
PLACEHOLDER copy. MUST be swapped for real tester reviews before launch (honesty gate).

- [placeholder] "got my mornings back. i make breakfast now." — 5 stars
- [placeholder] "earning my screen time is the only thing that ever worked for me." — 5 stars
- [placeholder] "down from 7 hours to under 2. didn't think it was possible." — 5 stars

---

## G. FAQ — "you might be wondering"

Honest answers, no fake user counts. Cards on Aura material.

- **is this just another screen-time app?**
  no. a blocker you can switch off in a tap does nothing. Aura makes you earn screen
  time by doing the things you keep meaning to do. the friction is the point.

- **what if i slip?**
  you will, everyone does. the plan runs on momentum, not a perfect streak. one bad
  day doesn't reset you.

- **is it worth it?**
  it costs less than a coffee a month. you're trying to win back {reclaim} hours a day
  of your own life. you decide.

---

## Laurels

Cut. No laurel badges on the hero. The section B data profile carries the proof.

---

## Sticky CTA

"Continue" (into the benefits screen).

---

## Open items for founder

1. Final read of the humanized copy, edit anything that still feels off.
2. Reviews placeholders confirmed OK for now; real ones tracked for launch.
