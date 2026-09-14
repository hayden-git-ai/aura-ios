# Aura Onboarding — Screen-by-Screen Build Spec

Every screen, every line, every option, every button, every state. Build-ready. Derived from `MASTER_ONBOARDING_BUILD.md` (the competitor teardowns and the conversion spine) and rendered in Aura's own language and design.

## Conventions (apply to every screen)

- **Voice split.** The **fox (Aura)** speaks in **lowercase**, dry, blunt, a little guilt-trippy, on your side. **Everything that is not the fox's own voice** (screen titles that frame a question, option labels, benefit lists, plan copy, science, reviews, paywall, and ALL button labels) uses **proper capitalization and grammar.**
  - Chat reply pills (the user texting the fox back) are kept in the casual texting register (lowercase) to match the shipped intervention thread. Say the word and I capitalize them.
- **Fox chat = the app's intervention thread** (`MessageThreadView` / `FoxChatChrome`): "Text From Aura" scene background, avatar + "Aura" header, blue fox bubbles, typing dots, white reply pills, the `fox()` typing cadence. In-text emphasis: the gut-punch line renders **red**, the relief line renders **green** (borrowed from Unrot).
- **Humanizer pass (done on every string).** No em-dashes. No emoji except a single sparse one inside a fox line where it earns the joke. No AI-tell words (actually, additionally, journey, unlock-as-fluff, elevate, empower, seamless, effortless, delve, dive in, at its core, landscape, testament, showcasing). No "not X but Y". No forced groups of three. No "from X to Y" padding. No shallow "-ing" analysis. Active voice, named actor. End on a concrete point. No "willpower" framed as a virtue.
- **No permissions and no account creation in onboarding.** Screen Time authorization, the app picker (Family Controls), notifications, and sign-in all happen **after** the paywall, in the existing Setup flow.
- **Honesty gate.** No fabricated ratings, user counts, or testimonials. `[placeholder]` marks any number that needs a real, defensible value. The reviews screen ships with **real tester testimonials**. No native App Store rating popup anywhere. No founder-story beat.
- **Paywall is stubbed** for now (real prices and purchase via RevenueCat later); build the full UI.
- **Progress bar + back chevron** on the tapped-question stretch only. Hidden on the splash, the chat, the immersive cost beats, the commitment ritual, and the paywall.

## Data captured (used to personalize later screens)

`[name]` (S3) · `[age]` from birthday (S4) · `[goal]` (S10) · `[hours]` daily scroll, from the slider (S11) · `[feelings]` multi (S13) · `[worstTime]` (S14) · `[skips]` what you miss, multi (S15) · `[tried]` multi (S16) · `[habit]` starter, multi (S24) · `[commit]` daily minutes (S25) · `[type]` attention profile, derived (S23).

Computed: `[daysPerYear] = round([hours] * 365 / 24)` · `[hoursPerWeek] = round([hours] * 7)` · `[date] = today + 28 days`, formatted "Mon D, YYYY".

Prices (USD reference; real values via RevenueCat): annual **[annualPrice] = $69.99/yr**, shown as **[perWeek] = $1.35/wk**; weekly decoy **[weeklyPrice] = $9.99/wk**; exit **[discountPrice] = $34.99/yr** = **[perMonth] = $2.92/mo**, 50% off the annual anchor.

---

# Phase 1 · Brand and disarm

### 1. Welcome (splash)
- **Layout:** full-bleed blue sunburst, celebration fox, rotating tagline, CTA, account link. No chrome.
- **Wordmark:** Aura
- **Tagline (rotates, proper case, the verb and app in blue):** "The app that makes you **work out** before **Instagram**." Rotating pairs: work out / Instagram · read / TikTok · go outside / YouTube · touch grass / Instagram.
- **Primary CTA:** Get started
- **Secondary (text link):** I already have an account
- **Behavior:** "Get started" advances to S2. "I already have an account" routes to sign-in (stubbed; real auth later).
- **Captures:** none.

### 2. Fox intro (statement, not the full chat thread)
- **Layout:** light ground, fox present, one bubble at a time, single CTA. Breathing room.
- **Fox says:** "hey. it's Aura." (beat) "glad you're here."
- **Primary CTA:** hey
- **Captures:** none.

### 3. Name
- **Layout:** question layout, fox bubble + text field + CTA. No progress bar yet.
- **Fox says:** "so, what should i call you?"
- **Field placeholder:** Your name
- **Primary CTA:** Continue (disabled until the field has a non-empty value; keyboard return also submits)
- **Captures:** `[name]`.

### 4. Birthday
- **Layout:** question layout, fox bubble + wheel date picker + CTA.
- **Fox says:** "[name], when's your birthday?"
- **Subtext (proper case, small):** I use this to do some honest math later.
- **Input:** date wheel (month / day / year), capped at today.
- **Primary CTA:** Continue
- **Captures:** `[age]` from birthday.

---

# Phase 2 · Diagnosis (the fox thread, plus one interactive beat)

Screens 5, 6, and 9 are one continuous chat thread. The fox types in with the typing indicator; the user taps reply pills to advance. Screens 7 and 8 break out of the thread for the interactive scroll and the loop diagram, then it resumes.

### 5. Recognition loop (chat)
- **Layout:** fox thread.
- **Fox says (each a separate bubble, typed in order):**
  1. "real quick, [name]."
  2. "you scroll."
  3. "feel like garbage."
  4. "swear you'll stop."
  5. "scroll more."
  6. "repeat."
  7. "sound familiar?"
- **Reply pills (user picks one; casual register):**
  - "yeah. that's me"
  - "stop calling me out"
  - "is it that bad?"
- **Behavior:** any pick appends the user bubble, then advances to S6.
- **Captures:** none (recognition beat).

### 6. Normalization (chat)
- **Layout:** fox thread (continues).
- **Fox says:**
  1. "don't spiral. you're not broken."
  2. "this is just how the apps are built."
  3. "everyone who ends up here got caught the same way."
- **Reply pills:**
  - "ok, go on"
  - "that helps"
- **Note:** no user count. Belonging is stated without a number.
- **Behavior:** advance to S7.

### 7. Simulate the scroll (interactive)
- **Layout:** full-screen phone mockup of a feed, a big **"Keep scrolling"** button, a clock in the corner. (Adapted from Unrot Variation B.)
- **Fox intro line (above the mockup):** "show me. tap to scroll, like you would at 11pm."
- **Interaction:** each tap on **"Keep scrolling"** advances the clock (10:30 pm to 10:45 to 11:10 to 11:30) and cycles a self-talk caption in the feed; the mockup tint shifts calm to warm to red as it escalates.
  - Captions cycle: "just one more." then "ok, last one." then "i'll get to it after this." then "oh. it's late now."
- **Payoff (after ~4-5 taps, the button locks):**
  - **Reveal:** "10:30 pm to 11:30 pm."
  - **Line (red):** an hour gone. and you didn't do the thing you wanted to.
- **Primary CTA:** oof (advances)
- **Captures:** none (embodied recognition).

### 8. The loop, named
- **Layout:** immersive, a three-node cycle diagram with curved red arrows (Scroll -> Avoid -> Regret -> back). (Adapted from Unrot B.)
- **Fox says:** "you're stuck in the scroll loop, [name]."
- **Diagram nodes (proper case labels):** Scroll now -> Avoid the thing -> Regret it -> (repeat)
- **Fox line under it:** "the problem isn't one hour. it's scrolling instead of doing."
- **Primary CTA:** so how do i stop?
- **Captures:** none. (This loop is mirrored later, flipped green, on the mechanism turn.)

### 9. The adversary (chat)
- **Layout:** fox thread (resumes), an app-icon cluster appears in-thread.
- **Fox says:**
  1. "here's the part that'll make you feel better."
  2. "you're not weak. it's rigged."
  3. "these apps have engineers, psychologists, and endless funding, all aimed at keeping you scrolling."
  4. (red) "you were never going to out-scroll that on your own."
  5. "so let's rig it back. 🦊"
- **Reply pills:**
  - "that explains a lot"
  - "i'm listening"
- **Note:** no fabricated headlines, no borrowed logos, no counts. One honest claim.
- **Behavior:** advance to S10 (the tapped-question stretch begins; progress bar appears).

---

# Phase 3 · Questions (progress bar + back chevron from here through S16)

Each: the fox poses the question in a bubble (lowercase); the options are proper case; the CTA is proper case. Single-select advances on tap unless noted; multi-select needs Continue.

### 10. Primary goal
- **Fox says:** "so what are we actually fixing?"
- **Options (single-select):**
  - Getting my focus back
  - Sleeping without my phone
  - Being present
  - Wasting less of my day
  - Just feeling less fried
- **Primary CTA:** Continue
- **Captures:** `[goal]`.

### 11. Scroll estimate (interactive slider)
- **Layout:** the deterioration slider (Brainrot / Unrot B). A drag track; as `[hours]` rises the **fox visibly drains** (bright and upright to tired and slumped) and a live number updates. (Reuses the fox mood states.)
- **Fox says:** "drag it to your honest daily number. no judgment yet."
- **Slider:** 0 to 12+ hours. Live readout: "**[hours]** hours a day".
- **Feedback line at the high end (proper case):** That is a real slice of your day.
- **Primary CTA:** Continue
- **Captures:** `[hours]`. Truthfulness: the fox tiring is a mood metaphor, not a medical claim.

### 12. Reaction (dynamic fox statement)
- **Layout:** fox + one line, generous space, single CTA.
- **Fox says (pick by `[hours]`):**
  - **<= 2h:** "okay. not the worst. still adds up though."
  - **3 to 5h:** "[hours] hours. every day. that's a part-time job you didn't apply for."
  - **>= 6h:** "[hours]+ a day, every day. yeah, we're definitely fixing that."
- **Primary CTA:** Continue
- **Captures:** none.

### 13. Consequence (feelings, multi-select)
- **Fox says:** "when you finally put the phone down, how do you feel?"
- **Subtext (proper case):** Pick all that apply.
- **Options (multi-select):**
  - Guilty
  - Empty
  - Anxious
  - Behind on everything
  - Numb
  - Like I lost the day
- **Primary CTA:** Continue
- **Captures:** `[feelings]`.

### 14. Vulnerable time
- **Fox says:** "when's it worst?"
- **Options (single-select):**
  - First thing in the morning
  - During work
  - At night
  - In bed
  - Honestly, all day
- **Primary CTA:** Continue
- **Captures:** `[worstTime]`.

### 15. What you skip (multi-select)
- **Fox says:** "what do you skip because you scrolled instead?"
- **Subtext:** Pick all that apply.
- **Options (multi-select):**
  - Sleep
  - The gym
  - Work or study
  - Time with people
  - Getting outside
  - Something you'd promised yourself
- **Primary CTA:** Continue
- **Captures:** `[skips]`.

### 16. What has failed
- **Fox says:** "what have you already tried that flopped?"
- **Options (multi-select):**
  - Telling myself to stop
  - Screen time limits
  - Deleting the apps
  - Going cold turkey
  - Nothing yet, you're my first
- **Primary CTA:** Continue
- **Captures:** `[tried]`. (If "Nothing yet", the later reframe softens the "you've tried everything" tone.)
- **Follow-on (S16b, shown only if `[tried]` has picks): why each flopped.** A short stack of cards, one per pick, proper case:
  - Screen time limits -> "You tapped Ignore. Every time."
  - Deleting the apps -> "You reinstalled by lunch."
  - Telling myself to stop -> "The next craving won."
  - Going cold turkey -> "It lasted about two days."
  - **Fox line under the stack:** "none of these are your fault. they all make you fight your phone. so people quit."
  - **Primary CTA:** Continue

---

# Phase 4 · The cost

### 17. Adding it up (loading)
- **Layout:** brief theater (~1.5s). Named steps resolve.
- **Title (proper case):** Adding it up.
- **Steps (resolve one by one):** Counting your daily hours -> Stretching them across a year -> Then across your life.
- **No CTA** (auto-advances).

### 18. Quick math (stat reveal)
- **Layout:** a red-outlined card, numbers in the stroked-number treatment, revealed one line at a time with a down-arrow between each.
- **Fox says (header):** "here's the math, [name]."
- **Reveal sequence (red numbers):** [hours]h a day -> [hoursPerWeek]h a week -> **[daysPerYear] days a year** -> "...gone to the scroll."
- **Primary CTA:** Continue
- **Captures:** none.

### 19. Life grid
- **Layout:** a grid of small squares (a year, or a life). Builds, then recolors. (One Thing's device, honest version.)
- **Title (proper case):** A year of your life.
- **Sequence:** the grid builds -> obligations dim (sleep, work) -> the remaining free squares glow -> `[daysPerYear]`-worth turns **red**.
- **Fox line under it:** "at [hours] hours a day, that's the part you hand over."
- **Primary CTA:** I want it back
- **Note:** label the model as an estimate; keep the assumptions honest.

---

# Phase 5 · The turn (relief, then the mechanism)

### 20. Earned access (the reframe)
- **Layout:** fox statement, single CTA. This is Aura's whole thesis.
- **Fox says:**
  1. "here's the part you'll like."
  2. "with me, you still scroll."
  3. "you just earn it first."
  4. "so no guilt after. because you paid for it in real life."
- **Primary CTA:** how?
- **Captures:** none.

### 21. Mechanism 1 · freeze
- **Layout:** demo. The user's-style app icons freeze over (the ice / `FrozenAppTile` treatment).
- **Title (proper case):** Every app you pick gets frozen.
- **Subtext:** No more waking up and disappearing into it.
- **Primary CTA:** Continue

### 22. Mechanism 2 · earn
- **Layout:** demo. A habit card, then a counter counting up. (Earn / charge visuals.)
- **Title (proper case):** Do a real habit, earn it back.
- **Demo copy on the card:** Workout -> +30 min
- **Subtext:** Work out, read, walk, whatever's yours.
- **Primary CTA:** Continue

### 23. Mechanism 3 · verify
- **Layout:** demo. A row of proof chips with a green "Verified" mark. (Photo proof, Apple Health, steps, a timed session.)
- **Fox says:** "and no faking it."
- **Line under it (proper case):** You prove the habit. Snap a photo, or let Aura read your steps and Apple Health.
- **Proof chips (proper case):** Photo proof · Apple Health · Steps · Focus session
- **Primary CTA:** Got it

### 23b. Flip the loop
- **Layout:** the same three-node diagram from S8, now green and flowing forward. (Unrot B's mirror.)
- **Fox says:** "so we flip your loop."
- **Diagram nodes (proper case):** Do the thing first -> Earn your time -> Scroll guilt-free
- **Primary CTA:** i'm in

---

# Phase 6 · Your attention profile

### 24. Reading you (processing)
- **Layout:** theater (~1.5s), fox hidden to build the reveal.
- **Title (proper case):** Reading you.
- **Steps (resolve):** Matching your pattern -> Finding your worst window -> Naming your type.
- **No CTA** (auto-advances).

### 25. Attention profile (reveal)
- **Layout:** a radial burst reveals a profile card: the named type, a one-line description, and three trait bars filled from the user's answers. (Brainrot's named-type effect.)
- **Header (proper case):** Your scroll type is...
- **Type card (name proper case; description is the fox, lowercase):** picked from `[worstTime]` + `[hours]` + `[feelings]`:
  | pick when | type name | description (fox) |
  |---|---|---|
  | in bed / at night | The 2am Doomscroller | "your phone's the last thing you see. sleep loses every time." |
  | morning | The Alarm-to-Instagram Type | "you're scrolling before both eyes are open." |
  | work | The Productive Procrastinator | "the scroll shows up the second real work does." |
  | all day | The Background Scroller | "it's always running. you barely clock when it started." |
  | anxious/empty and hours >= 6 | The Doom Refresher | "you scroll to feel better. it does the opposite." |
  | anything else | The Just-One-More-Video Type | "one video. it's never one video." |
- **Trait bars (proper case labels, filled from answers):** Scroll intensity (from `[hours]`) · Worst window (marker at `[worstTime]`) · Guilt weight (from `[feelings]`)
- **Primary CTA:** Yeah, that's me
- **Captures:** `[type]`. (Nudges which starter habits surface first on S24 and the plan wording on S30.)

---

# Phase 7 · Personalize

### 26. Starter habit (multi, pick 1 to 3)
- **Fox says:** "what do you want to trade scrolling for first?"
- **Subtext (proper case):** Add more later.
- **Options (multi-select, the ones fitting `[type]` surface first):**
  - Workout
  - Read
  - Walk
  - Meditate
  - Study
  - Journal
  - Drink water
  - Make my bed
  - Cook
- **Primary CTA:** Continue
- **Captures:** `[habit]`.

### 27. Daily commitment
- **Fox says:** "how much time a day do you want to put into real habits?"
- **Options (single-select):**
  - 5 min · Easing in
  - 15 min · For real
  - 30 min · All in
- **Primary CTA:** Continue
- **Captures:** `[commit]`.

---

# Phase 8 · Commit, then build

### 28. Hold to commit
- **Layout:** a button with a filling ring; hold ~2s. On release the screen floods with color and the fox perks up. (Reuses `HoldToConfirmButton`.)
- **Fox says (before):** "hold to lock it in, [name]."
- **During hold:** the ring fills; the fox reacts as it fills.
- **After release (fox):** "done. you said it, not me. 😏"
- **Primary CTA:** let's go
- **Captures:** none (embodied commitment).

### 29. Building your plan (theater)
- **Layout:** theater (~2s), an arc fills, checklist resolves.
- **Title (proper case):** Building your plan.
- **Steps (resolve):** Reading your answers -> Setting your earn rate -> Freezing your apps.
- **No CTA** (auto-advances).

---

# Phase 9 · Your plan (one continuous scroll, sticky CTA)

### 30. Your plan
- **Layout:** one vertical scroll, three sections, a sticky CTA at the bottom. No fabricated social proof anywhere.
- **Sticky CTA (proper case):** Start my plan (routes to the paywall, S33)

**30a. The dated roadmap**
- **Header (fox):** "alright [name]. you won't recognize yourself by **[date]**."
- **Week cards (proper case titles, plain-language bullets):**
  - Week 1 · The detox: You scroll less. Sleep hits deeper. Small wins feel good again.
  - Week 2 · The shift: Focus lasts longer. You stop avoiding things.
  - Week 3 · The rewire: Hard things get easier. The urge quiets down.
  - Week 4 · The comeback: You reach for your phone less. Days feel longer.

**30b. Two paths (a red/blue toggle, inline)**
- **Header (fox):** "two paths, [name]. which one do you pick?"
- **Toggle flips the whole panel:**
  - **Keep scrolling** (red, X icons): You lose [daysPerYear] more days this year. You stay behind. You keep feeling [feelings.0]. Nothing changes.
  - **Earn it back** (blue, check icons): You do your [habit] first. You scroll without the guilt. You get your [worstTime] back. The [type], reformed.
- Personalized chips stream from the user's answers.

**30c. You're probably thinking... (objection cards)**
- **Header (fox):** "you're probably thinking..."
- **Cards (question proper case; answer plain):**
  - Is it worth it? -> Less than a coffee a month, for the hours you lose every day. Your call.
  - Will it actually work? -> It works because you can't fake it. Real proof, or the apps stay frozen.
  - What if I slip? -> You will. One bad day won't wipe your streak. Keep going.

---

# Phase 10 · Proof, price, save

### 31. The science
- **Layout:** credibility. Three research cards, reusing the app's existing assets (`LogoHarvard`, `LogoUCL`, `CoverAtomicHabits`).
- **Header (proper case):** The science behind your plan.
- **Cards (proper case):**
  - Harvard · Behavioral research on habit formation.
  - UCL · Research on digital wellbeing.
  - Atomic Habits · James Clear (2018). The habit-loop method Aura is built on.
- **Fox line:** "i didn't make this up. it's the same stuff the researchers use."
- **Primary CTA:** Continue
- **Honesty gate:** cite the real work. Do not imply Harvard or UCL endorse Aura.

### 32. Real people (reviews)
- **Layout:** a rating badge and a testimonial wall. Populated with **real tester testimonials** before launch. No native rating popup.
- **Header (proper case):** People are getting their time back.
- **Rating badge (proper case):** [placeholder] average rating (real value before launch)
- **Testimonial cards (real, permissioned):** name + short quote. Example shape: "[real quote]" — [First name]. Ship 3 to 6 real ones.
- **Primary CTA:** Continue
- **Note:** if there are not enough real reviews at launch, cut this screen rather than fabricate.

### 33. Paywall (stubbed; RevenueCat later)
- **Layout:** a blue field, the fox floating near the top, headline, one value line, two selectable plan cards, one CTA, small legal links. No reviews or counts here.
- **Header (fox):** "get your time back, [name]."
- **Value line (proper case):** Earn your scroll. Freeze the apps. Aura keeps you honest.
- **Plan cards (proper case):**
  - **Yearly** [perWeek]/wk ([annualPrice]/yr) · preselected · tagged "Best value" · sublabel "Billed as [annualPrice] per year"
  - **Weekly** [weeklyPrice]/wk (the decoy)
- **Primary CTA:** Continue
- **Small links under it:** Restore · Cancel anytime · Terms · Privacy
- **Behavior:** stub. "Continue" completes onboarding and hands to the Setup flow. Add "money-back guarantee" only if it is real. No "free trial" copy. Real prices via RevenueCat, localized, never hardcoded.

### 34. Exit offer (scratch to reveal)
- **Layout:** intercept. Triggered by dismissing S33. The field dims; a white sheet slides up; the fox reappears holding a scratch card.
- **Fox says (before the scratch):** "leaving already? fine. scratch this. 🤫"
- **Interaction:** the user drags a finger across a foil panel to scratch it off, revealing the discount. Revealing animates the price: [annualPrice] struck through -> **[discountPrice]** ("[perMonth]/mo, billed yearly").
- **Fox says (after reveal):** "50% off. one time only."
- **Primary CTA (appears after reveal):** Claim it
- **Secondary (text):** No thanks
- **Behavior:** dismissing returns to S33 once (one loop, no trap). Purchase stubbed for now.

---

# After onboarding

"Continue" on the paywall (or claiming the exit offer) completes onboarding and hands to the existing **Setup flow**: welcome -> sign in -> notifications -> screen time -> app picker -> all set -> the app. All permissions and account creation live there, after the paywall.

---

## Build order (each phase verified visually before the next)

1. Phase 1 (1-4) · 2. Phase 2 chat + interactive (5-9) · 3. Phase 3 questions (10-16) · 4. Phase 4 cost (17-19) · 5. Phase 5 turn/mechanism (20-23b) · 6. Phase 6 profile (24-25) · 7. Phase 7 personalize (26-27) · 8. Phase 8 commit (28-29) · 9. Phase 9 plan (30) · 10. Phase 10 proof/price (31-34).
