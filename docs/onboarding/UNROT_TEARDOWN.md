# Unrot Onboarding — Frame-by-Frame Teardown

Source: two screen recordings (Part 1 ~4:06, Part 2 ~4:24; ~8:50 total), reviewed frame by frame at 2fps across all 44 screens, plus the hold-to-confirm transformation at 6fps. Cross-checked against the written teardown doc. This is the reference for Aura's native onboarding: **structure and psychology are Unrot's; the visual design is Aura's own (light + fox, the app's design system).**

Every note below is what is actually on screen. "Aura" callouts say how each beat maps to our master prompt + which existing app component to reuse.

---

## 1. The conversion engine (why this works)

Unrot does not "onboard." It runs a **guided behavior-change intervention that ends in a sale**. The order is deliberate and every screen has one job in a chain:

1. **Earn trust fast** (rating + user count + the differentiated one-liner) so the user keeps going.
2. **Make the mascot a character you owe something to** ("I'm your brain… the one you kept ignoring at 2am"). The problem is now a relationship, not a setting.
3. **Diagnose conversationally, not with a survey.** The chat makes the user *recognize themselves* in a loop they didn't describe. Recognition = "this app gets me."
4. **Remove shame** ("you're not special, 290,000 people share your story") → converts an isolated, defensive user into a prospective group member.
5. **Destroy the alternatives** (screen-time limits, blockers, deleting apps, flip phone, willpower) so the user concludes *nothing they've tried can work* — then hands them relief: "it's not your fault."
6. **Name the enemy** (engineered apps, PhDs, billions) so failure is external and the product is the only fair countermeasure.
7. **Teach the mechanism visually** before configuring it, so the paid thing feels understood, not risky.
8. **Turn the user's own number into a loss** (5h/day → 76 days/year → a red life-grid). Self-produced, so it's owned, not argued.
9. **Reframe the product from punishment to permission** ("scroll guilt-free, because you earned it").
10. **Make them commit with their body** (hold-to-confirm) right before generating the plan — effort justification.
11. **Make the choice an identity, not a purchase** (red Brainrot self vs blue Unrot self).
12. **Answer the three real objections** (cost, efficacy, fear of failure) before showing price.
13. **Only now: price, anchored hard, wrapped in a countdown, with a looping save offer.**

The user reaches the paywall already having: recognized the problem, been absolved, understood the fix, seen their loss quantified, committed physically, and chosen an identity. Price is the *last* and smallest ask.

**The pain-point ladder (what it makes you feel, in order):** seen → not alone → it's not your fault → I've been fighting an unfair fight → there's a simple system → I'm losing 76 days a year → I could scroll without guilt → I just committed → I know which future I want → my objections are handled → this costs less than a coffee. Buy.

---

## 2. Global patterns (steal the pattern, not the pixels)

**The chat (screens 6–13) is the engine.** Design as observed:
- Clean **white** thread, iMessage-style. Header: mascot avatar (circle) + name + "● Online" (green dot) + back chevron.
- Incoming (Brain) bubbles: **light grey**, dark text, left-aligned. Each preceded by a **"•••" typing indicator** in a grey bubble.
- Messages **arrive one at a time (~0.5–1s apart) and accumulate**; the thread scrolls. Short fragments, one idea per bubble.
- **Emotional color-coding inside the text**: the gut-punch line renders in **red** ("that you can't trust yourself", "you. can't. stop."); the relief line renders in **green** ("it's not your fault"). This is the single most reusable trick — the copy carries emotion in color.
- Reply choices: **green pills, right-aligned**, with a "Click to choose an answer" hint above. Picking one drops the others and the fox continues.
- In-thread rich content: an **app-icon collage** (the adversary), **★★★★★ testimonial cards** (name + age), all rendered as chat attachments.
- *Aura reuse:* our intervention `MessageThreadView` + shared `FoxChatChrome` already IS this thread (blue fox bubbles, `TypingDots`, reply pills, the `fox()` cadence). Add the **red/green emphasis run** to bubble text. Aura's chat sits on the "Text From Aura" scene, not white — keep Aura's design.

**Mascot as a live actor.** The brain is never a static logo. It **idles/breathes on every screen**, cycles expressive poses on statement screens, looks **sad when the topic is loss** and **happy/lifts weights when the topic is the future**, and its expression **escalates during the hold** and gets swallowed by the flood. *Aura:* use the fox the same way — mood must track the message (drained on the cost beats, charged on the turn). We already have tired↔charged fox states.

**Card + color language.**
- Cost/pain = **red-outlined card, red numbers**.
- Future/gain = **blue**; loss/old-self = **red**; ✓ vs ✕ icons.
- Plan roadmap = **soft pastel cards**, one per week, each with a mascot illustration + a title + 3 outcome bullets.
- Selection state everywhere = **green outline + green check**.
- *Aura:* map to our tokens — red card = the "Tempting" red gradient + `StrokedNumber`; blue = `--blue`; pastel week cards = our hero-card style; selection = the option-row selected state (blue-wash + blue border).

**Motion language.** Typed builds (headline first, then subtext; name; the "Unrot" letter-by-letter); sequential reveals with ↓ arrows (quick math); grids that build then recolor (life grid); a **toggle that flips a whole panel red↔blue**; a **hold-ring → full-screen color flood**; loading "theater" with a filling arc + checklist. Everything animates *with meaning*.

**Copy voice.** Lowercase, blunt, funny, a little mean but on your side. Fragments. Talks *to* you by name after you give it. "willpower → lol." *Aura:* this is exactly our fox voice already.

**Urgency device.** A **countdown card ("Special offer expires in 04:51")** is planted under the roadmap and **ticks continuously** through the roadmap, two-path, testimonials, FAQ, and both paywalls (~4 min, never resets on scroll). Closing a paywall **loops back to a countdown gate**, then reopens the offer. One offer, one loop, no trap.

---

## 3. Screen-by-screen (all 44)

### Phase A · Brand, trust, conversational entry (1–6)

**1 · Splash** — Pink screen, brain face, "unrot" wordmark, ~1s. *Job:* mascot + brand imprint. *Aura:* our fox splash (already have SplashOverlay).

**2 · Landing promise** (held ~10s) — Outdoor scene (sky/tree/grass). Top: **"4.8 average rating" + "300K users worldwide"** (laurels). Mascot idles/waves. "**Unrot** / The app that makes you earn your screentime" / green "Get Started!". *Psych:* social proof + the differentiated mechanism stated in one line, immediately. *Aura:* keep our welcome (rotating "workout before Instagram" + fox). **No fabricated rating/user count** — we have none; use the promise line + fox instead.

**3 · Brain introduction** — White bg, brain cycles poses. Types in: "**Hey! I'm your brain.**" then "**(The one you kept ignoring at 2am)**". Green Continue. *Psych:* intimate first-person narrator + humor lowers resistance; makes the mascot someone you've wronged. *Aura master screen 2 (fox intro).* Build the two lines as a **statement** (fox + bubble, breathing room), not the heavy chat thread. This is the mistake to avoid: screen 2 is a warm handshake, not a conversation.

**4 · Name input** — "What's your name?", underlined field, keyboard, live typing ("Ha"→"Hayden"), Continue enables on input. *Job:* name for immediate reuse. *Aura master screen 3* — our `OnbQuestionScreen` + field.

**5 · Acquisition source** — "Where did you hear about us?" cards with icons: Other, App Store, TikTok, Friends, Instagram. *Job:* attribution disguised as onboarding. *Aura:* optional; our master prompt folds this into the diagnosis. Keep it lightweight if kept.

**6 · Personal message setup** — Sad brain. "**Hayden, it's time we talk about what's happening to us!**" / "This is personal, I'll send you a text message." A **push-notification from "Brain" drops down** ("Hey Hayden, we need to talk") used as the tap target → "**Chat to Brain**" opens the thread. *Psych:* the transition into a real messaging UI is itself persuasion — a "personal text" feels urgent and intimate. *Aura:* nice optional flourish; our master prompt goes straight into the fox thread at screen 5.

### Phase B · Interactive chat diagnosis (7–13) — the core

**7 · Guilt loop** — Brain types the loop, one bubble each (••• before each): "hey Hayden" → "does this sound familiar to you?" → "you scroll" → "feel guilty after" → "tell yourself you'll stop" → "scroll more" → "feel even more guilty" → "**repeat.**" Reply pills (green, right): "yea am i cooked?" / "stop calling me out" / "is this bad?". *Psych:* recognition through a behavioral loop, not a question. The reply options **voice the user's own defensiveness**, which increases engagement and ownership. *Aura master screen 5* — our chat thread, reply pills.

**8 · Normalization + belonging** — "don't worry…" → "you're not special" → "**290,000 people on here share the same story.**" → "all started exactly where you are". Replies: "wow ok" / "i want to join them". *Psych:* removes shame and **converts isolated victim → prospective group member**. *Aura master screen 6* — **but we have no users**: reframe belonging without a count ("everyone who ends up here got caught the same way").

**9 · Self-trust attack** — "This is called Brainrot" → "but you already know this" → "what you dont know is…" → "everytime you say '5 more minutes'" → "but keep scrolling" → "your brain learns something…" → "**that you can't trust yourself**" *(red)* → "that's why you feel bad after". Replies: "ouchie" / "ok that one hurt". *Psych:* escalates scrolling into an **identity + self-trust** wound — the deepest pain point. The red line is the knife. *Aura:* fold into the diagnosis; use the **red text run** on the gut line.

**10 · Failed-solution inventory** — "and you've probably tried to unrot before" → "but" → "screentime limit → u ignore them" → "app blockers → u delete them" → "deleting apps → u redownload them" → "switching to flip phone → lasts 2 days" → "**willpower → lol**" → "but here's the thing" → "**it's not your fault**" *(green)*. Replies: "wait what" / "go on" / "I'm listening". *Psych:* **disqualifies every alternative** the user might leave for, then hands **blame relief**. "X → consequence" formatting is punchy and undeniable. *Aura master screen 7-adjacent* — our master prompt keeps this honest by not assuming what they tried; keep "willpower → lol" energy, **green** on "it's not your fault".

**11 · Engineered adversary** — **App-icon collage** in-thread (TikTok, YouTube, X, IG, Snap, FB, Reddit). "many popular apps have 1000s of engineers" → "PHDs in psychology" → "billions in funding" → "all working together to make sure" → "**you. can't. stop.**" *(red, spaced periods)* → "it's not a fair fight". Replies: "that explains a lot" / "I feel a bit better". *Psych:* externalizes blame onto a designed adversary; positions the product as the only structural counter-move. *Aura master screen 7* — reuse app icons; the red "you. can't. stop." spacing.

**12 · Outcome testimonials (in chat)** — "but, some people do unrot!" then **★★★★★ cards in-thread**: "I wasted 6+ hours daily. Now I'm free!" etc. (name + age). "wanna see how they do it?" / "show me how!". *Psych:* proof + earns permission to demo. *Aura:* **skip fabricated testimonials.** Replace with the fox simply offering to show the mechanism.

**13 · Demo bridge** — "sure thing" / "here is a small 3 step demo of how the app works" / "Great." *Job:* shift emotion → mechanism. *Aura:* the fox hands off to the mechanism screens.

### Phase C · 3-step mechanism demo (14–17)

**14 · Apps go to jail** — Phone mockup; **black jail bars slide down over the app-icon grid**. "Your apps go to jail / To unblock them, you need to spend Brain Coins." *Psych:* one memorable metaphor for the default-blocked state. *Aura master screen 19 (lock)* — reuse `FrozenAppTile` / the frozen (ice) treatment; slide the freeze over the grid.

**15 · Earn coins** — Illustrated habits **cycle** (drink water, make bed, go outside, pushups, eat healthy, smile, read); the brain gives a **"Send me a photo of you [habit]"** proof prompt. "Earn Brain Coins / 25+ ways… create your own." *Psych:* real-world action becomes the currency; the photo prompt previews verification. *Aura master screen 20 (earn)* — reuse `EarnSuccessView`/charge visuals; **the "send me a photo" is our photo-proof mechanic**.

**16 · Buy screen time** — Home screen → modal "**Unblock these apps for 10 minutes? This will cost you 20**" + Confirm. "Use Brain Credits to purchase screentime." *Psych:* closes the economy — earned currency → controlled access. *Aura master screen 21 (verify)* — show the earned→unlock exchange.

**17 · Mascot feedback** — Phone mockup + a **mood meter**; brain sad when scrolling, happy when healthy. "I reflect how well you're doing." *Psych:* the mascot becomes a live behavioral mirror + emotional reward. *Aura:* the fox already does this (Home charge + fox mood) — one bubble screen.

### Phase D · Personalized setup (18–21)

**18 · Setup bridge** — Happy brain. "It's time to Unrot, Let's get you set up! / I'll ask you a few questions…". *Job:* demo → configuration.

**19 · Habit selection** — "How do you want to earn brain coins?" **Category-grouped multi-select** (Physical / Mental / Wellness / Creative), scrollable, **green selection state**, "add your own later." *Psych:* ownership + builds the personalized earn menu (reused later in the two-path chips). *Aura master screen 24* — our option rows, grouped, multi-select.

**20 · Daily commitment** — "How much time…daily?" 30 Casual / 60 Regular / 90 Serious / 120 Hardcore. *Psych:* aspirational commitment + intensity segmentation. *Aura master screen 25.*

**21 · Scrolling estimate** — "How many hours…each day? / best guess." <2 / 2–4 / 4–6 / 6–8. *Job:* the input for the loss math. *Aura master screen 9.*

### Phase E · Time-loss calculation (22–24) — the gut-punch

**22 · Quick math** — "Here's some quick math, Hayden." **Red-outlined card**, red numbers reveal one at a time with **↓ arrows**: "5 Hours a day ↓ 150 Hours a month ↓ 76 Days a year" → "**…spent scrolling.**" *Psych:* scales an ordinary daily number into an unbearable annual loss; self-produced from *their* estimate. *Aura master screen 16* — red gradient card + `StrokedNumber`, sequential reveal.

**23 · Year grid** — "This is a year in your life." A **dot grid builds**. *Job:* establish the reusable time model.

**24 · Free-time scarcity** — Grid **shrinks to the free-time subset** ("after sleep, work, life admin"), then those dots **turn red (scrolling) + yellow (other)** one by one. "**Ouchie. This is why you probably don't feel you have enough time in a day.**" *Psych:* reframes scrolling as eating **discretionary life**, not clock time — far more painful than "hours." *Aura master screen 17* — one grid, build → shrink → recolor red.

### Phase F · Emotional consequence + relief (25–27)

**25 · Post-scroll feelings** — "Do you ever have any of these feelings after scrolling? / Select all that apply." Guilty, Empty, Anxious, Like I'm wasting my life, Low energy, Foggy thoughts, Regretful. Multi-select, green checks. *Psych:* guided self-diagnosis — the user **names their own pain**, so it's owned, not accused; feeds later personalization. *Aura master screen 11.*

**26 · Earned-scrolling relief** — Brain cycles happy poses. "**With Unrot, you won't feel guilt or shame after scrolling, because you've earned it.**" *Psych:* the pivot — product = **permission, not deprivation**; sells relief from guilt, not just less screen time. This is Aura's whole thesis. *Aura master screen 18.*

**27 · Outcome graph** — "Unrot users live more and scroll less." **Green "Living" rises, red "Scrolling" falls, lines cross** (Day 1→30). "Got it!" *Psych:* compresses the transformation into one image; crossing lines = decisive identity reversal. *Aura:* a clean two-line chart; frame as a model, not a guarantee.

### Phase G · Ratings + permissions (28–31) — **Aura skips these in onboarding**

**28 · Rating request** — native iOS star prompt over testimonials, at the emotional high. **Skip** (premature; and don't fabricate).
**29 · Rating proof wall** — "4.8 / 1M Unrotters," review carousel, celebrating brain. **Skip** (no reviews/counts).
**30 · Privacy/learning primer** — "The more people use Unrot, the smarter Brian gets… Tap Continue, then Allow" + "**We can't see your data / Protected by Apple's Privacy Rules**". **Permissions move to Aura's post-paywall setup** — and that privacy card is **already reused** on our setup Screen-Time screen.
**31 · Notification primer** — yellow bell rocks; "gentle reminders"; native notification dialog. **Aura's setup "Stay on track" screen already IS this** (post-paywall).

### Phase H · Commitment ritual + plan generation (32–35)

**32 · Hold-to-confirm** — "Are you ready to live your best life, Hayden? / Hold your finger on the button to confirm." Circular button + **filling ring** (~2s); the **brain's expression escalates** (worried → strained → hopeful). *Psych:* effort justification + embodied consent — a hold means far more than a tap. *Aura master screen 26* — reuse `HoldToConfirmButton`.

**33 · Transformation declaration** — On release, a **green circle expands upward from the button and floods the whole screen** (~1.5s, swallowing the mascot). "You're about to…" types in, then the brand builds **letter by letter: U → Un → Unr → Unro → Unrot**. Then the **"Unrot (verb)" definition**: "the opposite of brainrot… you work out, you study… instead of scrolling." "Let's go." *Psych:* **brand-as-verb = identity naming**; the flood makes the commitment feel like a state change. *Aura:* our hold-to-commit → a **charge/color flood** in Aura blue, fox perks up; we can't make "Aura" a verb the same way, but the flood + reveal is reusable.

**34 · Setup theater** — Brain meditates; a **semicircle arc fills** + checklist resolves: "Analyzing your answers ✓ / Creating your profile ✓ / Preparing your habits ✓." *Psych:* labor illusion — makes personalization feel earned. *Aura master screen 27.*

**35 · Future-self card** — Wipe to outdoor scene; **brain lifts weights**. "In 4 weeks you won't recognize yourself, Hayden. / Your personalized plan is ready." *Psych:* vivid future self + certainty (a fixed horizon makes change feel near). *Aura:* fox in a "charged" hero; drop the rating/user proof marks.

### Phase I · Personalized outcome plan (36–39)

**36 · Four-week roadmap** — "**You will unrot by Aug 15, 2026.**" Vertically scrolled **pastel week cards**, each with a mascot illustration + title + 3 outcome bullets: Week 1 "The reset begins," Week 2 "The Shift," Week 3 "The rewire," Week 4 "The Comeback." Sticky "Start My Unrot Journey." A **countdown card is planted here** and starts ticking. *Psych:* goal-gradient + implementation roadmap; the **date** turns aspiration into a scheduled identity change. *Aura master screen 28a.*

**37 · Two-path identity contrast** — "Two paths. Which one do you choose?" A **toggle flips the whole panel**: **red Brainrot** (✕: "waste half your day scrolling," "procrastinate, guilty after," "wake up tired from late-night scrolling," "can't focus without distraction") vs **blue Unrot** (✓: "complete meaningful tasks," "do what you plan," "sleep without scrolling, wake refreshed," "focus without your phone"). **Personalized chips stream** from the user's own habit picks (gains) vs their inverses (losses). *Psych:* loss aversion + **identity-based choice** — not "buy a subscription," but "which future person are you." The single strongest pre-paywall screen. *Aura master screen 28b* — red/blue, ✕/✓, chips from their answers.

**38 · Testimonial community wall** — "Join Team Unrot… 200000+ Unrotters," review stack. *Aura:* **skip** (no proof to show).

**39 · FAQ objections** — "You might ask…": "**Is it worth the cost?**" → "less than 1 coffee per month for 1000+ hours back. You decide." / "**Will this actually work for me?**" → efficacy + commitment. / "**What if I fail?**" → "Progress, not perfection." Countdown still ticking. *Psych:* pre-empts the **three real objections** (price, efficacy, fear of failure) before checkout. *Aura master screen 28c* — adapt: cost ("less than a coffee a month"), efficacy ("you can't fake it — real proof or the apps stay frozen"), failure ("one bad day won't wipe your streak"). No user count.

### Phase J · Urgency + paywalls (40–44)

**40 · Urgency gate** — "Where will you be in 4 weeks?" (fall back into the cycle, or unrot) + a white "**Special offer expires in 04:xx**" countdown + "Claim Limited Discount." *Psych:* future pacing + artificial scarcity; delay = choosing the bad path.

**41 · 93%-off paywall** — Scenic scene, celebrating brain, **"Limited Time Offer / 93% OFF / You will never see this again!"** 4-item benefit checklist. Anchor **$10.61/wk struck → $0.67/wk, billed $34.99/year.** "Claim my limited time offer." *Psych:* extreme anchoring + scarcity + benefit stacking + annual reframing.

**42 · Native purchase** — Apple sheet "$34.99/year / Double Click to Subscribe." *Psych:* system trust.

**43 · Personalized-plan paywall (variant)** — **Fan of app-screenshot cards**; "Your personalized program is ready / Unlimited access to Unrot Pro." Two plans: **$69.99/yr ($1.34/wk, SAVE 87%)** selected vs **$9.99/wk** decoy. "Continue" + Cancel anytime / Terms / Privacy / Restore. *Psych:* **decoy pricing** makes annual dominant; "personalized program" = sunk-cost/ownership.

**44 · Exit interception loop** — Closing a paywall returns to the countdown gate, then reopens the offer. One truthful save loop, dismissible. *Psych:* recaptures price-rejectors without trapping them.

*Aura paywall (master 30–31), stubbed for now:* our design system says **blue field, floating fox, plan cards** (not a scenic photo). Pricing is ours: **$69.99/yr ($1.35/wk) anchor + $9.99/wk decoy**, exit = **$34.99/yr (50% off) scratch-to-reveal**. Reuse the decoy structure, the benefit line, the countdown/urgency, and the single dismissible exit loop. Real prices via RevenueCat later.

---

## 4. What Aura takes, changes, and refuses

**Take (structure/psychology):** the conversational diagnosis; the recognition loop; shame-removal; failed-solution disqualification; the engineered-adversary frame; the visual mechanism demo; self-produced loss math + life grid; the permission (not punishment) reframe; hold-to-commit + flood; the named/identity plan; two-path red/blue; objection FAQ; anchored price + one dismissible exit offer; the **continuous countdown**; **in-text red/green emotional color-coding**; mascot mood that tracks the message.

**Change (to Aura's design):** everything is **light + fox + our tokens**, not Unrot's white-chat/scenic-green. Chat = our `MessageThreadView`/`FoxChatChrome`. Cards = our red/blue gradients + `StrokedNumber`. Paywall = blue field + fox. Voice = our fox (already aligned).

**Refuse (honesty gate — we have no users/reviews):** no fabricated rating, no "X people," no testimonials, no "290,000 share your story," no borrowed authority. Belonging/efficacy get reframed without counts. Every number is real or a labeled estimate.

**Move out of onboarding:** all permissions (Screen Time, notifications) and account creation → the **post-paywall setup flow** (already built). The privacy card and the notifications "gentle reminders" screen already live there.

## 5. Unrot → Aura map (quick reference)

| Unrot | Aura master screen | Reuse |
|---|---|---|
| 2 landing | 1 welcome | fox splash, rotating promise |
| 3 brain intro | 2 fox intro (statement, not chat) | fox + bubble |
| 4 name / 21 hours | 3 name / 9 estimate | `OnbQuestionScreen` |
| 7–11 chat diagnosis | 5–7 chat | `MessageThreadView` + red/green runs |
| 14–16 mechanism | 19–21 lock/earn/verify | `FrozenAppTile`, earn/charge, photo-proof |
| 22 quick math | 16 | red card + `StrokedNumber` |
| 23–24 life grid | 17 | dot grid build→shrink→recolor |
| 25 feelings / 26 relief | 11 / 18 | option rows / fox statement |
| 32 hold / 33 flood | 26 | `HoldToConfirmButton` + charge flood |
| 34 theater / 35 future | 27 / (reveal) | loading checklist / charged fox |
| 36 roadmap / 37 two-path / 39 FAQ | 28a / 28b / 28c | pastel cards / red-blue toggle / objection cards |
| 41/43 paywall + 44 exit | 30 / 31 | blue field + plans + scratch exit (stubbed) |
| 28–31 ratings/permissions | — | **skip in onboarding** (setup flow / no fabrication) |

---

# Unrot — Variation B (the A/B-tested second onboarding)

Source: a separate screen recording (6:19, 759 frames, reviewed frame by frame at 2fps). This is a **different onboarding Unrot was A/B testing** against Variation A (above). Same product, same brain mascot, same green scenic look, but **longer, far more interactive, more structured, and more gamified**. It reads like the "polished direct-response" variant: fewer walls of chat text, more moments where the user *does* something (taps to scroll, drags a slider, watches a real product demo, earns coins).

**The single biggest signal for Aura:** Variation B independently adopted three devices that are already in Aura's master prompt, which means Unrot's own testing validated them:
1. the **rotating promise tagline** ("The app that makes you [habit] before [app]"),
2. **name + birthday** collection up front,
3. an **interactive deterioration slider** (drag hours up, the mascot's face decays to a skull).

## Variation B, screen by screen (frame-verified)

**1 Splash** — pink, brain face, "unrot."

**2 Landing (rotating promise)** — scenic. Brain idles. Headline **"The app that makes you [read a book / workout / go for a walk / study] before [Instagram / TikTok / YouTube]"**, the habit word and app word each with an icon, rotating through pairs. "4.8 / **1M** users" (A said 300K). Green "Get Started." *This is Aura's welcome exactly. Validated.*

**3 Name** — "What's your name?", live typing, Continue.

**4 Birthday** — "Hayden, what's your birthday?" **wheel date picker** (month/day/year). *Aura master 4. A did not collect this.*

**5–7 Simulate your own doomscroll (interactive)** — "Hayden, tell me if this sounds familiar." Then a phone-mockup feed with a big **"Scroll" button the user taps repeatedly**. Each tap: the clock ticks (**10:30 PM to 11:30 PM**), self-talk bubbles play ("Just a quick scroll... then I'll do the thing I need to do" then "Just one more. Then I'll get to it"), and the bubbles recolor **green to yellow to red** ("Oh no, it's too late now!"). Payoff: "10:30 PM to 11:30 PM. **1 hour gone. You didn't do the thing you wanted to.**" *The user physically performs the wasted hour. This is the strongest recognition device in either variation and is more interactive than A's passive guilt-loop chat.* **Aura should build this** (a tappable "keep scrolling" that burns a visible clock and ends on "an hour gone").

**8 The Brainrot Loop (named diagram)** — "Hayden, you're stuck in **The Brainrot Loop**. Does this look familiar?" A 3-node cycle with red curved arrows: **Scroll now -> Avoid life -> Regret after -> (repeat)**. *Names the pattern as a cycle. Mirrors Brainrot's psychology; reused later as a positive flipped loop.*

**9 Reframe** — "The problem isn't scrolling for an hour. It's scrolling instead of doing."

**10–13 Diagnosis questions** — "How often does this happen?" (every day / most days / few times a week); "What do you end up **not** doing because you scroll?" (multi: sleep / study / working out / cleaning / going outside / seeing friends / something important); "How do you feel after wasting time scrolling?" (multi: empty / annoyed at myself / guilty / tired but wired / honestly nothing). *Personalizes the sacrifice + the emotional cost. Aura master 11–13.*

**14–15 Personalized consequence playback** — "So you don't sleep. Doomscroll instead. And then feel nothing at all." (replays their own answers), then "Over time you learn... Easy now, dopamine now, regret after." *Uses their answers verbatim to state the consequence. Powerful and cheap.*

**16 Fear question** — "**What scares you most, if this continues?** Be completely honest." (multi: waste even more time / to feel behind others / keep promising tomorrow / feeling tired and unmotivated / not discipline / **I don't become who I could be**). *Projects the negative future through the user's own stated fears. Aura should add this; it is more honest than One Thing's ghost because the user names it.*

**17 Testimonials** — "Our users get things **done**... and then scroll **guilt free**." star cards. *Aura keeps a reviews screen with real tester reviews.*

**18–19 What you've tried + why it failed (personalized)** — "What have you tried to fix this before?" (multi: screen time limits / told myself I'll stop / deleting apps / put phone in another room / other screentime apps / nothing). Then a **playback of pink cards, one per pick**, explaining the failure: "Screen time limits work... until you just press 'ignore'", "Willpower works... until the next craving hits", "Deleting apps work... until you install them again." Lands on "They make you fight your phone. Block, limit, punish. No wonder people quit." *A's version was chat text; B's is a personalized visual card stack keyed to their selections. Better.*

**20 Reactance science (real citation)** — "Researchers call this **reactance**. When a tool feels controlling, people look for ways around it. Ignore. Reinstall. Turn it off." Small cited card: "Strict digital self-control tools can trigger reactance." (Lukoff, Lyngs & Alberts, 2020). *A defensible, sourced reason blockers fail, which sets up the "we don't block, we flip it" pitch. Aura can cite real research the same way (fits our science screen).*

**21 Unrot flips the loop** — "That's why Unrot flips the loop." A green positive cycle mirroring the red Brainrot Loop: **Do the thing first -> Earn Screentime -> Scroll guilt free.** *The mechanism reframe as the inverse of the problem loop. Aura's earn-first thesis, visualized.*

**22 Testimonials** — "Thousands love this simple system" (includes an ADHD reviewer). 

**23 How to Unrot (mechanism summary)** — 4 rules: "We lock apps that steal your time. You [habit] to earn brain coins. You use coins to buy scroll time. No more minutes, just earn more."

**24–26 Interactive real-UI mechanism demo** — uses actual app screenshots. "Your apps get locked" (tap a notification) -> "Earn scroll coins with tasks" (the real Unrot home + task list; tapping a task opens a **25-minute focus timer**) -> "Spend coins, scroll guilt-free" (a **Screentime Store** to buy time, then the real feed opens with a **countdown timer overlay 14:58**). *More concrete than One Thing's abstract counter: the user sees the actual product loop. Aura master 19–21, using our real screens.*

**27 Pride beat** — "Hayden, most don't make it this far. You did. Respect."

**28 Completion reward (gamified)** — "**You earned 20 coins for making it this far!**" coins rain down, brain celebrates. *Gives real product currency for finishing onboarding, creating investment before the paywall. Aura could grant starter coins.*

**29–31 Rating + privacy + setup bridge** — native rating popup (**Aura skips the popup**), "the smarter Brian gets" privacy primer + "We can't see your data" (**Aura: permissions post-paywall**), "Let's get you set up to start Unrotting!".

**32 Interactive deterioration slider** — "How much time do you lose to scrolling most days?" A **number stepper (1 to 12 hours)** where the **mood emoji decays as the number rises**: calm smile at 1-2h, worried in the middle, **skull at 12h**. The user drags up and down and watches the face react. *This is Brainrot's severity slider, confirmed again. Aura master 15; use the fox draining instead of an emoji.*

**33 Habit selection** — "How do you want to earn brain coins?" category-grouped multi-select (Physical / Mental / Wellness / Creative), then "Good choice! Thousands earn their scroll time with these tasks" + review cards.

**34–36 Screen Time permission + app picker + build theater** — native Screen Time authorization, "Now let's put the bad apps in Jail" -> native Family Controls picker, then "Building your plan..." arc + checklist (Apps selected / Earning actions picked / Coin rules created). *Aura keeps permission + picker in the post-paywall setup flow.*

**37 Plan ready** — "Hayden, your Unrot plan is ready." card: "Earn coins by... Running 5, Yoga 5, +more" / "Spend coins on... [apps]."

**38 Cost math (count up, red)** — "You said you scroll **12** hours a day. That's..." a red number **counts up to 360h in just 1 month.** Tired brain.

**39 Reclaim (count up, green) + concrete wins** — "Taking back just **25%**, that's... **90h**. Extra hours for..." green benefit cards: "15+ books", "G+ grades", "60+ workouts." *Red loss counts up, green recovery counts up, then translates hours into tangible wins. Aura master 16/23-style.*

**40 Real-cost reframe** — "The real cost isn't the number. It's what the time could be."

**41 Positive future-self** — "This is just 1 month. If you stick with this, you will be unrecognizable." (happy brain). *Positive mirror of One Thing's negative ghost. Aura should prefer this framing: show the better self, not call the user "defeated."*

**42 Testimonials** — "Unrot users feel **more** productive!" star cards (ADHD reviewer again).

**43 Paywall** — "Join **1M+** others living more and scrolling less!" "4.8 / 1M+" + reviews behind. Plans: **$69.99/year** vs **$9.99/week** decoy. "Continue." Terms / Privacy / Restore. *Same pricing as A's plan-variant paywall; a cleaner single-choice reviews-backed wall.*

## What Aura takes from Variation B specifically (beyond A)

- **The interactive "simulate your own doomscroll"** (tap Scroll, clock burns 10:30 to 11:30, "1 hour gone"). Highest-value new mechanic. Build it as a recognition beat.
- **The named loop diagram** (Scroll now -> Avoid life -> Regret after) and its **positive inverse** (Do first -> Earn -> Scroll guilt free). One visual language for the problem and the fix.
- **The fear question** ("what scares you if this continues") and **personalized consequence playback** ("so you don't sleep... feel nothing"). Self-authored future dread, more honest than a ghost.
- **Personalized failed-solutions card stack** keyed to what they picked, with **reactance cited as real science**.
- **The interactive deterioration slider** with the mascot decaying (confirms Brainrot; use the fox).
- **Interactive real-UI mechanism demo** (lock -> task timer -> store -> feed countdown) using actual app screens.
- **Completion reward** ("earned 20 coins for making it this far") to create pre-paywall investment.
- **Cost math that counts up** to a big red monthly number, then a green reclaim with **concrete wins** (books, workouts).
- **Positive future-self** framing ("unrecognizable in a month") instead of a defeated ghost.

**A vs B for Aura:** A is the tighter persuasion spine (the chat diagnosis is stronger). B is more interactive and gamified (simulate-the-scroll, the slider, the coin reward, the real-UI demo). **Aura should merge them: A's chat-diagnosis spine + B's interactive beats (simulate-the-scroll, slider, coin reward, real-UI demo, fear question, count-up cost math, positive future-self).** All in Aura's light + fox design.
