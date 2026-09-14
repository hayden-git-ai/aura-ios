# Aura · Onboarding + Paywall Master Build Prompt (Superwall / HTML-CSS)

You are building Aura's onboarding and paywall funnel: **31 screens**, mobile web, in **HTML/CSS (+ small JS)** to run inside **Superwall**. Build it in one pass, then we iterate.

Aura is an iOS app that helps people stop doomscrolling. The mechanism: you pick your distracting apps and **they lock**. To unlock screen time you **do a real habit** (workout, read, meditate, etc.) and **prove it** (a photo, Apple Health, steps, a timer). Doing habits earns screen-time; using the apps spends it. A **fox mascot** ("Aura") is the guide and reflects how you're doing. There is **no free trial**; the paywall sells a subscription directly, with an exit discount.

Read `DESIGN_SYSTEM.md` first. It defines every color, type, spacing, radius, shadow, component, and the layout archetypes (A–F) referenced below. Match the app exactly: **light** ground, one blue accent, Rubik, rounded chunky cards, stroked numbers, the fox.

---

## 1. Global build rules

- **Mobile portrait**, 390px artboard, centered in `max-width:430px`. Everything responsive to smaller widths.
- **One decision per screen.** Never stack two asks.
- **Persistent primary CTA** at the bottom (drop-lip pill, §6.1). Disabled until the screen's input exists. Exactly one primary CTA per screen; any secondary action is a plain text button.
- **Progress bar + back chevron** only on the diagnosis/question stretch (screens 8–13, 24–25). Hidden on splash, chat, immersive cost beats, ritual, and paywall (a progress bar there cheapens the moment).
- **No permission prompts and no account creation anywhere in onboarding.** Sign-in, Screen Time authorization, the app picker (Family Controls), notifications, and camera all happen **after** the paywall, in-app. Onboarding asks zero permissions. This is deliberate: less friction before the paywall.
- **Transitions:** forward slide-and-fade up (~250ms ease-out), back reverses. Reveals count up / stagger in. Respect `prefers-reduced-motion`.
- **Accessibility:** tap targets ≥ 44px, visible focus, `aria-selected` on options, `aria-live` on dynamic reactions, real labels on inputs. Contrast per the palette.
- **State:** carry answers across screens (JS object or Superwall variables) so later screens personalize. Nothing is re-asked.
- **Never** use an em-dash. **Never** invent stats, ratings, or user counts; leave them as `[placeholder]` for real, defensible numbers.

---

## 2. The fox's voice

The fox ("Aura") is a **dry, blunt, lowercase, slightly guilt-trippy** coach. It calls you out, but it's on your side. Think a friend who's done pretending your scrolling is fine. This is the same voice as the app's intervention scripts.

**Do**
- lowercase almost everything, including headings and the start of sentences.
- short lines. fragments are fine. one idea per line.
- dry, deadpan, a little funny. mild guilt, never cruelty.
- talk *to* the user, using their name occasionally after they give it.
- a **sparse** emoji is allowed *only inside a fox line* when it earns the joke (e.g. "😬", "😔"). Never more than one, never in headings, buttons, or body/benefit copy.

**Don't**
- no corporate uplift ("unlock your potential", "start your journey").
- no fake enthusiasm, no exclamation stacking.
- no shaming the person's worth. attack the scroll, not them.
- no em-dashes, no title case, no emoji outside fox lines.

**Voice samples (calibration):**
> "you scroll. feel like garbage. swear you'll stop. scroll more. repeat."
> "[4] hours a day. every day. that's a part-time job you didn't apply for."
> "here's the part you'll like: you scroll guilt-free. because you earned it."
> "leaving already? fine. [50]% off. don't tell the others."

Button labels stay plain and lowercase-friendly but readable: "continue", "that's me", "show me", "i'm in", "no thanks".

---

## 3. Humanizer rules (apply to ALL copy)

Every line must pass the [humanizer](https://github.com/blader/humanizer) check. Enforce these while writing and reviewing:

1. No em/en-dashes. Use periods, commas, colons, parentheses.
2. No emoji except the fox's sparse exception above.
3. Lowercase headings; straight quotes only; no title case.
4. Cut AI-tell words: *actually, additionally, quietly, testament, landscape, showcasing, delve, dive in, unlock (as fluff), elevate, seamless, effortless, journey, empower*.
5. No "not X but Y" false contrasts. State it straight.
6. No forced groups of three. Use the number of items you actually need.
7. No "from X to Y" range padding. List the real things.
8. No shallow "-ing" analysis ("reflecting", "symbolizing", "helping you to...").
9. No filler ("in order to" → "to"). No qualifier stacking ("could potentially maybe").
10. No sales flourish, no "at its core", no "let's dive in", no "honestly? it depends".
11. No defensive answers to objections nobody raised (except the dedicated FAQ screen, which answers *real* ones).
12. Prefer active voice; name the actor. Direct verbs over "serves as / features / boasts".
13. End on a concrete point, not a warm generic sign-off.

If a line sounds like a wellness app wrote it, rewrite it in the fox's voice.

---

## 4. Data model

Collect these as the user answers; compute the rest. Use `[bracket]` tokens in copy; replace at runtime.

**Collected**
- `[name]` · text (screen 3)
- `birthday` → `[age]` (screen 4)
- `[goal]` · focus / sleep / presence / stop wasting time / productivity (screen 8)
- `scrollHours` · range → midpoint `[hours]` (screen 9): <2→1.5, 2–4→3, 4–6→5, 6–8→7, 8+→9
- `[feelings]` · multi-select (screen 11)
- `[worstTime]` · morning / daytime / evening / in bed / all day (screen 12)
- `[triedBefore]`: telling myself to stop / screen-time limits / deleting apps / cold turkey / nothing yet (screen 13)
- `[habit]` · starter habit (screen 24)
- `[commit]` · 5 / 15 / 30 min (screen 25)

**Computed**
- `[daysPerYear]` = round(`hours` × 365 ÷ 24). (e.g. 5h → 76 days)
- `[hoursPerWeek]` = round(`hours` × 7). `[hoursPerMonth]` = round(`hours` × 30).
- `[lifeWeeksLeft]` = (80 − `age`) × 52. `[weeksSpent]` = round(`lifeWeeksLeft` × `hours` ÷ 24).
- `[reclaimTarget]` · user picks on screen 15 (share of the daily hours to win back).
- `[type]` · named profile, derived (screen 23), mapping in §6.
- `[date]` · today + 28 days, formatted "Mon D, YYYY" (screen 28).
- Prices/offer (real values; StoreKit via RevenueCat localizes at runtime, these are the USD reference):
  - `[annualPrice]` = **$69.99/yr** · `[perWeek]` = **$1.35/wk** (annual ÷ 52)
  - `[weeklyPrice]` = **$9.99/wk** (decoy)
  - win-back: `[discountPrice]` = **$34.99/yr** = `[discountPct]` **50% off** the $69.99 anchor · `[perMonth]` = **$2.92/mo**

**Dynamic reactions:** several fox reactions scale with the answer. Louder judgment for worse answers, never crossing into cruelty. Provide 3 tiers keyed off `scrollHours` and `feelings` (see screens 10 and 16).

---

## 5. The 31 screens

Format per screen: **layout** (A–F), **job** (psychological purpose), **copy** (verbatim, fox voice), **interaction/animation**, **data**.

### Phase 1 · Brand & disarm

**01 · Welcome** · *A (splash)*
Job: brand recognition + state the transformation before mechanics.
Copy: wordmark "Aura". Tagline builds under a fox animation: **"the app that makes you [workout] before [Instagram]."** The habit word and app word rotate through a few pairs (workout/Instagram, read/TikTok, touch grass/YouTube). CTA: "get started". Secondary text link: "i already have an account".
Animation: fox idles/breathes; the two rotating words swap with a quick fade. Keep the current app's welcome animation feel.
Data: none.

**02 · Fox intro** · *C*
Job: give the app an intimate first-person guide; lower resistance with warmth + humor.
Copy: fox bubble types in "hey. it's Aura." then a beat, then "glad you're here." CTA: "hey".
Animation: two messages type in sequentially with the fox present.

**03 · Name** · *B (text input)*
Job: collect the name for immediate reuse.
Copy: fox bubble "so, what do i call you?" Input placeholder "your name". CTA: "continue" (enabled once non-empty).
Data: `[name]`.

**04 · Birthday** · *B (date/segments)*
Job: collect age for the life-cost math; make it feel purposeful.
Copy: "[name], when's your birthday?" small line beneath: "i use this to do some honest math later." Input: month/year (or age range if simpler). CTA: "continue".
Data: `birthday` → `[age]`.

### Phase 2 · Fox-thread diagnosis (chat, then clean cards)

Screens 05–07 are one continuous **chat thread** (archetype for §6.4). Fox messages type in with the typing indicator; the user taps reply pills to advance. Keep it tight · this is recognition and shame-removal, not a wall of text.

**05 · Recognition loop** · *chat*
Job: create recognition through the behavioral loop, not a survey question.
Fox: "real quick." → "you scroll." → "feel like garbage." → "swear you'll stop." → "scroll more." → "repeat." → "sound familiar?"
User reply pills: "...how do you know that" / "stop calling me out" / "yeah. it's bad".

**06 · Normalization** · *chat*
Job: remove shame. We have **no users and no reviews**, so never cite a count, rating, or "X people" anywhere in the funnel.
Fox: "don't spiral. you're not broken." → "this is just how the apps are built. everyone who ends up here got caught the same way."
User reply pills: "ok, go on" / "that helps".

**07 · Adversary / blame relief** · *chat*
Job: externalize blame onto engineered apps; position Aura as the counter-move. (Does NOT assume what the user has tried.)
Fox: an app-icon cluster appears. "here's the thing." → "you're not weak. it's rigged." → "these apps have teams of engineers and psychologists, and endless funding, all aimed at keeping you scrolling." → "you were never gonna out-scroll that on your own." → "so let's rig it back. 🦊"
User reply pills: "that explains a lot" / "i'm listening".
Note: no fake news headlines, no borrowed logos, no user counts. one honest line.

**08 · Primary goal** · *B*
Job: goal labeling → ownership; personalizes later copy.
Copy: "so what are we actually fixing?" Options: "getting my focus back" · "sleeping without my phone" · "being present" · "wasting less of my day" · "just being less fried".
Data: `[goal]`.

**09 · Scroll estimate** · *B*
Job: capture the key number for the cost math.
Copy: "how many hours a day do you catch yourself doomscrolling?" small: "best guess. no judgment yet." Options: "under 2" · "2 to 4" · "4 to 6" · "6 to 8" · "8+".
Data: `scrollHours` → `[hours]`.

**10 · Reaction (dynamic)** · *C*
Job: make the user feel heard/called-out; earn the next question.
Copy (pick by `scrollHours`):
- ≤2h: "okay. not the worst. still adds up though."
- 3–5h: "[hours] hours. every day. that's a part-time job you didn't apply for."
- ≥6h: "[hours]+ a day. daily. yeah, we're definitely fixing that."
CTA: "continue".

**11 · Consequence (emotional, multi-select)** · *B (multi)*
Job: the emotional core. user names their own pain, so it's owned not accused.
Copy: "when you finally stop doomscrolling... how do you feel?" small: "pick all that apply." Options (multi): "guilty" · "empty" · "anxious" · "behind on everything" · "numb" · "like i lost the day". CTA: "continue".
Data: `[feelings]`.

**12 · Vulnerable time** · *B*
Job: identify the trigger window (used later for the plan).
Copy: "when do you doomscroll the most?" Options: "first thing in the morning" · "during work" · "at night" · "in bed" · "honestly, all day".
Data: `[worstTime]`.

**13 · What's failed** · *B*
Job: capture stage-of-change; set up "telling yourself to stop was never going to work" without assuming what they tried.
Copy: "what've you already tried that flopped?" Options: "just telling myself to stop" · "screen time limits" · "deleting the apps" · "going cold turkey" · "nothing yet, you're my first". CTA: "continue".
Data: `[triedBefore]`. (If "nothing yet", the later reframe softens the "you've tried everything" tone.)

### Phase 3 · The cost

**14 · Reality-check loading** · *E (theater)*
Job: anticipation; signal the answers produce a real result. Name the real computation, don't be vague.
Copy: header "adding it up." steps resolve: "counting your daily hours" · "stretching them across a year" · "then across your life". Brief (~1.5s).

**15 · Interactive deterioration** · *E (interactive)*
Job: self-persuasion through touch. the user produces the consequence.
Copy: "drag it to your honest daily number." A slider 0–12h; as hours rise the **fox visibly drains** (bright/upright → tired/slumped) and a live number updates. Feedback line at high end: "that's a lot of you, gone." CTA: "continue" (prefill from screen 9; let them adjust).
Data: may refine `[hours]`.
Truthfulness: the fox getting tired is a mood metaphor, not a medical claim. No "your brain rots".

**16 · Quick math** · *E (stat, stacked reveal)*
Job: scale a daily number into an emotionally significant loss.
Copy, revealed one line at a time inside a red-outlined card: "[hours]h a day" → "[hoursPerWeek]h a week" → "[daysPerYear] days a year" → "...gone to the scroll." Numbers use the **stroked-number** treatment. CTA: "continue".

**17 · Life grid** · *E (visual)*
Job: convert time into a finite, visible resource.
Copy: "you've got about [lifeWeeksLeft] weeks left, [name]." Grid builds (§6.6): muted cells = already spoken for (sleep, work); the rest glow as your free weeks; then "[weeksSpent] of them go to scrolling" turns that share red. Line: "at [hours] hours a day, that's how many you hand over." CTA: "i want them back".
Data: uses `[age]`, `[hours]`, `[lifeWeeksLeft]`, `[weeksSpent]`. Label the model as an estimate; keep assumptions honest.

### Phase 4 · The turn (relief + mechanism)

**18 · Earned-access reframe** · *C*
Job: reframe the product from punishment to permission. (Aura's whole thesis.)
Copy: fox bubble: "here's the part you'll like." → "with me, you still scroll." → "you just earn it first." → "so no guilt after. because you paid for it in real life." CTA: "how?".

**19 · Mechanism 1 · lock** · *C (demo)*
Job: define the default state in one visual.
Copy: "every app you pick gets frozen." The user's-style app icons animate into a frozen/locked state (use the frost treatment). Sub: "no more waking up and disappearing into it." CTA: "continue".

**20 · Mechanism 2 · earn** · *C (demo)*
Job: teach the currency: real habits mint screen time.
Copy: "do a real habit, earn it back." Animated: a habit card (e.g. "workout") → "+30 min" counting up. Sub: "workout, read, walk, whatever's yours." CTA: "continue".

**21 · Mechanism 3 · verify** · *C (demo)*
Job: differentiate from honor-system trackers.
Copy: "and no faking it." → "you prove the habit. snap a photo, or let aura read your steps and apple health." Small carousel of proof chips (photo proof, steps, apple health, a timed session) with a green "verified" mark. CTA: "got it".

### Phase 5 · Named "attention profile"

**22 · Profile processing** · *E (theater)*
Job: labor illusion; anticipation for the reveal.
Copy: header "reading you." steps resolve: "matching your pattern" · "finding your worst window" · "naming your type". (~1.5s.) Fox hidden to build suspense.

**23 · Attention profile reveal** · *E (reveal)*
Job: named-type effect (like Brainrot's "attention profile"). a specific, memorable label that feels personal and steers the rest of the plan.
Copy: "your scroll type is..." then a profile card: the **[type]** name, a one-line description, and **three trait bars** filled from their answers. CTA: "yeah, that's me".
The profiles (pick one from `worstTime` + `scrollHours` + `feelings`; it's a nickname, never a diagnosis):
| pick when | [type] | description |
|---|---|---|
| worstTime = in bed / at night | "the 2am doomscroller" | "your phone's the last thing you see. sleep loses every time." |
| worstTime = morning | "the alarm-to-instagram type" | "you're scrolling before both eyes are open." |
| worstTime = work | "the productive procrastinator" | "the scroll shows up the second real work does." |
| worstTime = all day | "the background scroller" | "it's always running. you barely clock when it started." |
| feelings include anxious or empty, and hours ≥ 6 | "the doom refresher" | "you scroll to feel better. it does the opposite." |
| anything else / moderate | "the just-one-more-video type" | "one video. it's never one video." |

Three trait bars (each low→high, marker set from their answers, so different people see different bars):
- **scroll intensity** · from `scrollHours` (under 2 = low ... 8+ = maxed out)
- **worst window** · a morning→night scale with the marker at `[worstTime]`
- **guilt weight** · from how many/heavy `[feelings]` they picked (one mild = light ... several heavy = heavy)

The chosen `[type]` also nudges later defaults: which starter habits surface first (24) and the plan wording (28). Keep the bars an honest read of their answers, not random.

### Phase 6 · Personalize

**24 · Starter habit** · *B (multi, pick 1–3)*
Job: ownership; builds the earn menu.
Copy: "what do you want to trade scrolling for first?" Options: "workout" · "read" · "walk" · "meditate" · "study" · "journal" · "drink water" · "make my bed" · "cook". Sub: "add more later." CTA: "continue". (Surface the ones that fit their `[type]` first.)
Data: `[habit]`.

**25 · Daily commitment** · *B*
Job: an aspirational daily target + intensity segment.
Copy: "how much time do you want to commit to new healthy habits daily?" Options: "5 min · easing in" · "15 min · for real" · "30 min · all in". CTA: "continue".
Data: `[commit]`.

### Phase 7 · Commit, then build

**26 · Hold-to-commit** · *E (interactive)*
Job: embodied commitment, right before the plan is built.
Copy: "hold to lock it in, [name]." A button with a filling ring; hold ~2s. The fox reacts as it fills; on release the screen blooms (color floods in, fox perks up). Line after: "done. you said it, not me. 😏" CTA: "let's go".

**27 · Building plan** · *E (theater)*
Job: labor illusion; visible payoff for answering.
Copy: header "setting up app…" steps resolve one by one: "analyzing your answers" · "creating your profile" · "preparing your habits". (~2s.)

### Phase 8 · Your plan (ONE long scrolling screen)

**28 · Your plan** · *one continuous vertical scroll, sticky CTA at the bottom.* This single screen holds three sections, scrolled as one page (these were four separate screens before). No social-proof/testimonial section anywhere: we have no users or reviews, so never invent one.

*28a · Dated roadmap.* Copy: "alright [name]. you won't recognize yourself by **[date]**." Then a week-by-week roadmap (4 cards):
- week 1 "the detox": "you scroll less. sleep hits deeper. small wins feel good again."
- week 2 "the shift": "focus lasts longer. you stop avoiding things."
- week 3 "the rewire": "hard things get easier. the urge quiets down."
- week 4 "the comeback": "you reach for your phone way less. days feel longer."

*28b · Two-path contrast* (D toggle, inline). Copy: "two paths, [name]. which one do you choose?" A toggle flips the whole panel:
- **keep scrolling** (red, ✕): "you lose [daysPerYear] more days this year." "you stay behind." "you keep feeling [feelings.0]." "nothing changes."
- **earn it back** (blue, ✓): "you do your [habit] first." "you scroll without the guilt." "you get your [worstTime] back." "the [type], reformed."
Personalized chips stream from their answers.

*28c · Objection FAQ* (inline cards). Copy: "you're probably thinking..." three cards:
- "is it worth it?" → "less than a coffee a month, for the hours you lose every day. your call."
- "will it actually work?" → "it works because you can't fake it. real proof, or the apps stay frozen."
- "what if i slip?" → "you will. one bad day won't wipe your streak. keep going."

Sticky CTA across the whole scroll: "start my plan" → goes to the paywall.

### Phase 9 · Proof, paywall, save

**29 · The science** · *C/E (credibility)*
Job: convert the emotional persuasion into credibility right before price. (Hayden likes this beat from the web2wave funnel; the app already has the content.)
Copy: header "the science behind your plan." Three research cards, reusing the app's existing assets and citations: **Harvard** and **UCL** (behavioral-science research on habit formation and digital wellbeing) and **Atomic Habits** by James Clear (Clear, J. (2018) — the habit-loop method Aura is built on). Assets already in-app: `LogoHarvard`, `LogoUCL`, `CoverAtomicHabits`. Fox framing line: "i didn't make this up. it's the same stuff the researchers use." CTA: "continue".
Honesty gate: cite real work (these institutions research this; Atomic Habits is the named source). Do NOT imply Harvard or UCL endorse Aura.

**30 · Paywall (RevenueCat)** · *F*
Job: convert. anchored annual, decoy weekly, direct sale, no free trial. Purchases + entitlements run through **RevenueCat** (native paywall UI wired to RevenueCat offerings/entitlements, or a RevenueCat paywall template).
Layout: a blue gradient/radial field, the fox floating gently near the top, headline, one short value line, two selectable plan cards, one CTA, small legal links. No reviews or user counts.
Copy: header "get your time back, [name]." value line: "earn your scroll. freeze the apps. i keep you honest." Plans:
- **yearly** `[annualPrice]` ($69.99) · shown as "`[perWeek]`/wk" ($1.35/wk), "billed as $69.99/year" · preselected, tagged `best value`.
- **weekly** `[weeklyPrice]`/wk ($9.99/wk) · the decoy.
CTA: "continue". Small links under it: restore · cancel anytime · terms · privacy (add "money-back guarantee" only if it is real). No "free trial" copy. All prices come from RevenueCat offerings (localized), never hardcoded.

**31 · Exit discount (scratch-to-reveal)** · *F (intercept)*
Job: one honest save offer for users who bounce off price, made tactile.
Trigger: dismissing screen 30. The field dims and a white offer sheet slides up; the fox reappears holding a scratch card.
Interaction: a **scratch-to-reveal** card (reused from the web2wave funnel). The user drags a finger across a foil panel to scratch it off, uncovering the discount underneath. Revealing it animates the price: `[annualPrice]` struck through → `[discountPrice]` ("`[perMonth]`/mo, billed yearly").
Copy: fox before the scratch: "leaving already? fine. scratch this. 🤫" after reveal: "[discountPct]% off. one time only." CTA (appears after reveal): "claim it" + a plain "no thanks". Dismissing returns to screen 30 (one loop, no trap). Purchase via RevenueCat; prices from RevenueCat config.

---

## 6. Notes for the build

- Reuse components: every screen is composed from the archetypes and recipes in `DESIGN_SYSTEM.md`. Build the option row, drop-lip button, fox+bubble, chat message, hero card, life grid, progress bar, and paywall plan card **once**, then reuse.
- Keep the fox present as the through-line: it opens (02), runs the diagnosis chat (05–07), reacts (10), teaches the mechanism (18–21), and closes the deal (28b two-path, 29 science, 30–31 paywall + scratch save).
- Personalize relentlessly: by screen 28 the plan should echo their `[name]`, `[habit]`, `[worstTime]`, `[feelings]`, and `[type]`. That echo is what makes the paywall feel earned.
- Truthfulness gate: every number is real or a labeled estimate; every claim is defensible; no borrowed authority; no fabricated social proof.
- Voice + humanizer gate: read every final string against §2 and §3 before shipping. If it sounds like a wellness brand, rewrite it as the fox.

## 7. Build checklist

- [ ] All 31 screens, in order, one decision each.
- [ ] Progress bar only on 08–13 and 24–25; back chevron on reversible screens.
- [ ] No permission prompts, no account creation, no reviews/user counts. No em-dashes. No emoji outside fox lines. No "willpower".
- [ ] Every `[token]` wired to collected/computed data or Superwall config.
- [ ] Dynamic reactions (10, 16) tier correctly by `scrollHours`.
- [ ] Chat thread (05–07) types in with the typing indicator and reply pills.
- [ ] Attention profile (23) picks a distinct `[type]` + trait bars per answers.
- [ ] Hold-to-commit (26) sits right before building-plan (27).
- [ ] Screen 28 is one long scroll (roadmap + two-path + FAQ), sticky CTA.
- [ ] Life grid (17) and two-path (28b) reuse the same visual language.
- [ ] Science (29) cites real work, no fake endorsement; paywall (30) RevenueCat, no trial; exit (31) is a scratch-to-reveal, loops once, dismissible.
- [ ] `prefers-reduced-motion` respected; tap targets ≥44px; light theme throughout.
