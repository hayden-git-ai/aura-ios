# Aura Onboarding — Master Build Reference (competitor-informed)

The single source of truth for rebuilding Aura's onboarding **properly**. Synthesizes frame-by-frame teardowns of the three competitor onboardings into one actionable Aura architecture. Every competitor recording was reviewed frame by frame (2fps across all screens, key animations at 6fps).

**Companion docs:**
- Unrot (the strongest *structural/persuasion* model): `UNROT_TEARDOWN.md`. **Two A/B-tested variations** are broken down there: Variation A (44 screens, tighter chat-diagnosis spine) and Variation B (6:19, more interactive/gamified). Aura merges them: A's chat spine + B's interactive beats (simulate-the-scroll, deterioration slider, fear question, count-up cost math, completion coin reward, positive future-self, named loop diagram + its positive inverse, reactance-cited failed-solutions).
- One Thing (36 screens, the clearest *mechanism + life-grid* model): this file, §3
- Brainrot (27 screens, best *tactile interaction + named profile*, fastest funnel): frame-verified teardown in §3.5 below
- Aura content spec (screen list + copy): `superwall/ONBOARDING_MASTER_PROMPT.md`
- Aura visual system: `superwall/DESIGN_SYSTEM.md`

**Aura's law:** competitors are the reference for **structure and psychology only**. Aura's visual design is its own — **light ground, one blue accent, Rubik, chunky rounded cards, stroked numbers, the fox** — reusing the app's existing components (intervention chat, sunburst success, Stats cards, `FrozenAppTile`, `HoldToConfirmButton`, `StrokedNumber`, `LightPrimaryButton`). No dark funnels, no ghost/brain, no white iMessage chat — those are *their* skins.

---

## 1. The universal conversion spine (all three share it)

Every one of these is a **guided behavior-change intervention that ends in a sale.** Price is the last and smallest ask. The order never changes:

1. **Promise + trust** — state the differentiated mechanism in one line ("earn your screen time"), preview it visually.
2. **Blame relief** — "it's not your fault" *before* the diagnosis, so the user isn't defensive.
3. **Name the engineered adversary** — 10,000+ engineers / PhDs / billions → "you. can't. stop. scrolling." (red). You've been losing an unfair fight.
4. **Diagnose the user's own pain** — via their answers, not accusation. They name it, they own it.
5. **Quantify the loss visually** — their scroll number → an annual/lifetime loss on a grid. Self-produced.
6. **Teach the mechanism visually** — lock → earn → spend → verify, in cause-and-effect states, before any feature list.
7. **Reframe: permission, not punishment** — "scroll guilt-free, because you earned it."
8. **Commit physically** — hold-to-confirm before the plan is generated (effort justification).
9. **Make it an identity, not a purchase** — two futures (red vs blue self); named profile.
10. **Credibility + humanity** — science, a real founder story, real reviews.
11. **Handle objections** (cost / efficacy / failure), then **price** — anchored, one dismissible discount.

**The feeling ladder (what to engineer, in order):** seen → not alone → not my fault → I've been fighting an unfair fight → here's a simple system → I'm losing *[N] days/years* → I could scroll *without guilt* → I just committed → I know which future I want → real people (and the founder) stand behind this → my objections are handled → it's less than a coffee. **Buy.**

## 2. Best-in-class per beat (what Aura borrows from whom)

| Beat | Best executor | What to steal |
|---|---|---|
| Conversational diagnosis | **Unrot** | typing-dots chat, accumulating bubbles, reply pills that voice the user's defensiveness, **in-text red(pain)/green(relief) color runs** |
| Shame removal → belonging | Unrot | "you're not special, everyone here got caught the same way" |
| Disqualify alternatives | Unrot | "screentime limit → u ignore them … willpower → lol" |
| Adversary scale | **One Thing** | stat stack (engineers/funding/PhDs) → red "you. can't. stop. scrolling." on a reddening field |
| Future-self dread | **One Thing** | the drained self + **relentless notification cascade** overwhelming the mascot |
| Interactive deterioration | **Brainrot** | drag a slider, the mascot visibly drains — self-produced consequence |
| Life-cost visualization | **One Thing** | **life-in-years grid**: obligations color-fill → green free time → red phone theft → **same grid, red→green recovery** |
| Quick-math escalation | Unrot | red-bordered card, red numbers, ↓ arrows (5h/day → 76 days/yr) |
| Mechanism demo | **One Thing** | **4 cause-effect states**: lock (desaturate) → earn (counter counts **up**) → spend (counts **down**, re-lock) → verify carousel |
| Permission reframe | Unrot | "you won't feel guilt after scrolling, because you've earned it" |
| Hold-to-commit | Unrot / Brainrot | ring fills → **full-screen color flood** → identity reveal |
| Named attention profile | **Brainrot** | processing theater → named type + trait bars from their answers |
| Two-path identity | Unrot | toggle flips whole panel **red(✕) ↔ blue(✓)**, personalized chips stream |
| Roadmap | Unrot | dated 4-week plan, pastel week cards, sticky CTA |
| Science credibility | One Thing / Unrot | Harvard/UCL/Atomic Habits (Aura already has the assets) — cite, don't imply endorsement |
| Reviews wall | One Thing | real testimonial cards + rating laurels (**real tester reviews only**) |
| Objection FAQ | Unrot | cost / efficacy / failure answered pre-price |
| Paywall | Unrot / One Thing | benefit checklist, anchored annual + weekly decoy, "Most Popular", one dismissible exit |
| Urgency | Unrot | a **continuously ticking countdown** that runs from the plan through the paywall |

## 3. One Thing — frame-verified teardown (the new findings)

Dark/black, cinematic, statement-driven. A **ghost** mascot (a depleted phone user) whose costume/state changes with the topic. No chat thread. 36 states, 3:23.

**Phase 1 · Blame + adversary + mission + future self (0–7)**
- **0 Splash** — black, floating ghost staring at a phone, "One Thing."
- **1 Promise** — "Scroll Less. Live More." A **phone mockup animates blocked-app → home → a "0m" balance counter**, previewing the whole product. White "Get Started" + secondary "I already have an account."
- **2 Blame relief** — "It's" → "It's not" → "It's not your fault." builds **word by word** on near-empty black. Manual "Tap to continue."
- **3 News collage** — real headlines (Guardian/CNN/BBC: "Meta and YouTube found liable in social media addiction trial") **tilt/stack/slide** in. *Aura: one restrained, sourced line — not a chaotic collage.*
- **4–5 Adversary scale** — stat stack "10,000+ engineers / $100B+ funding / PhDs in behavioral psychology" → "All working to make sure **you. can't. stop. scrolling.**" (red, period-spaced) on a **reddening** field. Continue.
- **6 Mission** — "**Live More.** (gold) Scroll Less. (white)" + activity icons **orbiting** + "4.8 / 280K" laurels. *Aura: no fabricated rating/count.*
- **7 Future-self ghost** — the slumped ghost with a **relentless ~19s notification cascade** (Gmail, TikTok, Tinder, Candy Crush…) piling from the top. "This is the ghost of your future you. / **Tired. Defeated. Exploited.** / We're going to change that." *Aura: a drained fox + notification overwhelm — show the wasted-day identity without calling the user "defeated."*

**Phase 2 · Questions (8–12)** — progress bar; dark rounded cards + radio.
- **8 Age** (Under 18 … 55+), **9 Lifestyle** (Student/Professional/Entrepreneur/Parent/Between jobs/Other — *use it to change suggested habits*), **10 Phone use** ("2-4h · about average" … "8+h · time to take back control" — **escalating diagnostic labels**), **11 Vulnerable time** (morning/evening/all day, illustrated cards — *preconfigure a real schedule*), **12 Reality-check loading** — ghost inside **expanding rings**, "Analyzing… Calculating years lost… Mapping your remaining months…"

**Phase 3 · Life-cost (13–24)** — the emotional core.
- **13–18 Life-in-years grid** — "Your life in years / Each square is one year." Obligations color-fill sequentially as the **ghost changes costume**: blue 27yr sleeping, purple 18yr working, 7yr commuting, magenta 3yr chores → the small **green remainder "20 years of actual free time"** enlarges.
- **19 Phone theft** — **6 green squares turn red** one by one. "Your phone will steal 6 of them. / That's 30% of your free time, gone."
- **20–21 Relationship graph** — lines draw (Parents decline, Partner rises, Kids peak/fall); a **bright red Phone line overlays and dominates** ("180 minutes. Every single day"). *Aura: skip or heavily soften — generalized population data presented as personal; the doc's own biggest-weakness call-out.*
- **22 Six-year consequence** — "**That's 6 years**" held fixed while the meaning **crossfades** (loved ones / parents growing older / watching other people live / not becoming who you're meant to be) over ~14s of black. *Aura: use 1–2, not 4 — shame fatigue.*
- **23 Years regained** — **same grid, red→green recovery**, "regain 5 years of your life."
- **24 Relationships-first** — the phone line **drops** (red→green).

**Phase 4 · Authority + mechanism + features (25–32)**
- **25 Method/science** — two scientist ghosts + Harvard/UCL logos. *Aura master 29; cite real research, no implied endorsement.*
- **26 Daily lock** — apps float into a **dotted tunnel, desaturate, get lock overlays**. "At the start of every day, your apps lock." *Aura: `FrozenAppTile` freeze over the user's picked apps.*
- **27 Earn** — habit cards drop ("Gym +30 min", "Reading +15 min"); a big **minute counter counts UP**; the ghost does the activity. "Do a habit to earn screen time. No bypasses or workarounds."
- **28 Spend** — the counter counts **DOWN** as distracting apps are used, apps **re-lock at 00m**, ghost returns to doomscrolling. "The only screen time you get is what you earn."
- **29 Verify** — **carousel of proof chips** (Photo scan / Apple Health / Motion verified / Steps / Mindfulness) with green "verified" + real activity photos. *Aura: photo-proof + Apple Health + steps + timed session.*
- **30–32 Secondary features** — "That's not all" → Scheduled Blocks (red schedule card) → Daily App Limits (red limit rings). *Keep secondary; the earn loop is the hero.*

**Phase 5 · Humanity + proof + price (33–35)**
- **33 Founders** — two real founder photos + quote "We built One Thing because we were tired of losing our best years to a screen…" + "No investors. No other employees. Just us." *Aura: SKIP. Hayden does not want a founder-story beat in the onboarding. (Team facts still matter for about/company copy elsewhere: Hayden + a cofounder + an investor, applying to YC; never "solo / no investors".)*
- **34 Reviews wall** — "4.8 / 280K" laurels + horizontal testimonial cards ("Deep work blocks work", "Finally stuck with it"). *Aura: **keep a reviews screen with real tester testimonials**; real numbers only.*
- **35 Paywall** — floating app icons; "80,000+ happy users / Start your 21-day reset. Get 90% off today." benefit checklist; **Yearly $39.99 90% OFF "Most Popular"** vs **Weekly $7.99 decoy**; native "Double Click to Subscribe." *Doc flags the 280K↔80,000 inconsistency — Aura keeps every number consistent.*

**One Thing's lesson for Aura:** the mechanism demo (26–29) and the life grid (13–19, 23) are the two things to copy almost exactly (in Aura's look). Its weakness is density/overreach (news collage, relationship graph, 4× consequence, precise lifetime math as personal fact, unlicensed logos, inconsistent counts) — Aura earns more trust by being lighter and honest.

## 3.5 Brainrot — frame-verified teardown (fastest + most tactile)

Doc: `1drOYW6ELpOUB0Ez0Kh9Ahnw8Cv-Kl1opdeWf6MEgOhs`. Recording reviewed frame by frame (2:37, 314 frames, 27 states). **Light** theme (white / pale-blue, blue CTAs), a limbed tan **brain** mascot that walk-cycles and emotes. Its value is **compression and tactile interaction**: it reaches a commitment ritual and paywall in under three minutes, and it lets the user physically manipulate the cause-and-effect. Less persuasive/educational than Unrot, but faster and more interactive.

- **1 Splash** — white, the brain **walk-cycles** holding a phone.
- **2 Rotating carousel** — tilted **phone mockups** + page dots + a stable blue "Get started": "Stop scrolling. Save your Brain." / "Heal your brain with Focus Mode." / "Unlock themes and customize." *Aura shows the mechanism first via the rotating tagline, not a mockup carousel; customization is not our hero.*
- **3 Welcome declaration** — "Welcome to Brainrot! / It's time to regain control of your screen time." builds word by word.
- **4 Meet your brain** — "Meet your brain / He's doing OK." mascot cycles poses. *Bonding: a character to protect. Aura's fox intro.*
- **5 Decay statement** — "The more you brainrot, the more your brain rots." builds word by word as the brain scrolls. *Rhyme is memorable but medically loaded; Aura avoids "your brain rots" as a claim.*
- **6 See-for-yourself SLIDER (signature)** — "See for yourself!" a green->red slider with a brain-face thumb; dragging it **morphs the mascot healthy -> worried -> exhausted -> flattened -> shriveled -> melted red puddle**. *The best tactile mechanic in the whole set. Self-persuasion through touch. Aura screen 15, fox draining (truthful variable: daily scroll hours).*
- **7 Adversary** — "You're not addicted. Your brain is being exploited." **notification chips pile over the flattened brain** ("Someone liked", "Trending now", "New post just dropped") -> "Modern apps are engineered to hijack attention. Brainrot helps you take control, without deleting your apps." *"You're not addicted" is an unsupported diagnosis; Aura says the apps are rigged without diagnosing the user.*
- **8 Personalization bridge** — brain writes on a **clipboard**; "Your answers help us map your attention patterns."
- **9-15 Questionnaire (~33s)** — goal / how screen time affects you / identity segment / when you lose control ("rot the most") / prior attempts / a "Did you know?" stat-card reveal (4h/day, 58 checks/day; *no sources shown, Aura cites or skips*) / age.
- **16 Screen-time slider** — "How much time on screens daily? We don't judge, tell the truth!" drag an orange phone-thumb slider (6 -> 7 Hours), "This is a significant percentage of your life."
- **17 Processing theater** — "Personalizing your experience!" 3 filling bars ("Analyzing your habits / Calculating your profile / Generating insights") under a **purple "?" brain silhouette** (mascot hidden to build the reveal). Labor illusion.
- **18 Named profile reveal (signature)** — a **blue radial burst** unveils the brain ringed with notification chips: "Your attention profile is **The Compulsive Checker**. Short checks turn into long sessions, driven by automatic habits rather than intention." + two **trait bars** (Check frequency Low->High; Daytime vulnerability Morning->Evening). *Named-type effect; memorable, feels personal. Aura screen 23, type + bars from answers, honest read not random.*
- **19-20 Rating + belonging** — native "Enjoying Brainrot?" star popup (**Aura skips the popup**) over "Brainrot was made for people like you" + "4.7 / 650K+ users" + human photos. *Aura: real tester reviews, no fabricated counts.*
- **21 First-week plan** — "This week, Brainrot will help you:" cards enter one by one (regain control / save 3+ hrs/day / focus / healthier habits). *"Save 3 hours" is an aggressive guarantee; Aura frames as a plan, not a promise.*
- **22 Hold-to-ascend (signature)** — "Hold the button to help the brain ascend!" holding a glowing diamond button **floods the gray environment to saturated blue, water ripples spread, the brain rises, and stones stack one at a time into a tower beneath it.** *Embodied commitment + elevation. Aura screen 26: hold + charge/color flood, fox perks up.*
- **23 Confirmation** — "Let's go! You're committed. The first step is often the hardest." (stone tower remains).
- **24 Before/After** — bar charts "Before 7h 24m -> After 1h 9m / Use Brainrot and gain **2+ Hours** back" + benefit rows + "10,000+ Reviews / 650,000+ users." *Model, not guarantee; Aura no fabricated counts and the after-number must derive from their input.*
- **25 Paywall** — **blue field, floating brain**, "Rebuild your brain with Brainrot", benefit line, **Yearly $0.96/week (billed $49.99/yr) preselected vs Weekly decoy**, links (cancel anytime / money-back / pay in app).
- **26-27 Exit 50%-off** — closing slides up a white sheet with a **detective-hat brain**: "50% OFF FOREVER / Limited time offer / $2.08/mo (billed $24.99/yr, $49.99 struck) / Redeem Offer." Dismissing returns to the blue paywall (one loop). *Doc caution: "limited time" vs "forever" conflicts; offering 50% instantly teaches users to reject the first price.*

**Brainrot's lesson for Aura:** it is the **pacing + tactile-interaction** reference. Copy almost exactly (in Aura's look): the **deterioration slider** (6), the **named attention profile + radial burst + trait bars** (18), and the **hold + full-environment color flood** (22). Its weaknesses: medical-sounding claims ("brain rots", "you're not addicted"), unsourced stats, guaranteed hour-savings, and an instant 50%-off that trains price rejection.

**Visual DNA (Hayden flagged this, with the Figma board):** Brainrot already shares Aura's design language: a **light ground**, a **blue accent right next to our #2586FF**, **puffy sticker-style icons** (white contour + soft shadow, i.e. our exact sticker pipeline), **rounded chunky cards**, and **word-by-word text builds**. So unlike the dark One Thing or the white-chat Unrot, Brainrot's actual **layouts and compositions can be adapted directly** into Aura's onboarding: keep the composition, swap the brain for the fox, and use Aura's real tokens + sticker assets. It is our **strongest visual reference, not just a structural one** (still Aura's components/fox/stickers, never Brainrot's brain art). The team collects competitor onboardings in the Figma "Inspiration-Competitor-Onboardings" (fileKey `6pSqDVj9x8ALtnm23v8AJE`; the Brainrot board is node `448-443`), and this session can open it via the Figma MCP (get_screenshot / get_design_context).

## 4. Aura's honesty + differentiation gate (UPDATED)

- **Reviews/testimonials: YES.** Build a reviews/testimonial screen (One Thing/Unrot style) — populated with **real testimonials from testers** before launch. Real numbers only, consistent everywhere. **Do NOT fire the native iOS rating popup during onboarding** (that's the one thing to skip).
- **Founder story: NO.** Hayden does not want a founder-story beat in the onboarding. (The team facts still matter for any about/company copy elsewhere: Hayden + a cofounder + an investor, applying to YC; never "solo founder / no investors".)
- **No fabrication:** no invented user counts/ratings until real; no borrowed authority (no Harvard/UCL *endorsement*, only "research in habit formation" + Atomic Habits as the named method); no generalized population data dressed as personal forecast; every number real or a **labeled estimate**.
- **Permissions + account creation live in the post-paywall Setup flow** (already built): Screen Time, notifications, app picker, sign-in. Onboarding asks **zero permissions**. (One Thing/Unrot fire permission primers mid-funnel; we don't.)
- **Voice:** the fox — dry, lowercase, blunt, funny, on your side. No "willpower" as a virtue, no corporate uplift, no em-dashes.

## 5. Aura onboarding architecture (the build list)

Merges `ONBOARDING_MASTER_PROMPT.md` with the learnings above. Each screen: **archetype · psychological job · key interaction · reused component · honesty note.** Build **phase by phase**, verify each batch visually. Chat beats = the intervention thread design (`FoxChatChrome`); statements = light fox + bubble; cost/reveal/paywall = bespoke.

**Phase 1 · Brand & disarm**
1. **Welcome** (splash) — promise + fox; rotating "workout before Instagram"; get started / already have an account. *No fake rating.*
2. **Fox intro** (statement, NOT the chat thread) — fox + bubble "hey. it's Aura." → "glad you're here." single CTA.
3. **Name** · 4. **Birthday** (question layout).

**Phase 2 · Diagnosis chat** (the intervention thread, red/green emphasis)
5. Recognition loop · 6. Normalization (belonging w/o counts) · 7. Adversary (app-icon collage + "you. can't. stop." red).
8–13. Goal · scroll estimate · dynamic reaction · feelings (multi) · vulnerable time · what's failed. *(progress bar on 8–13; option rows.)*

**Phase 3 · The cost**
14. Reality-check loading (real steps). 15. **Interactive deterioration slider** (Brainrot) — drag daily hours, fox drains. 16. Quick math (red card + `StrokedNumber`, ↓ reveal). 17. **Life grid** (One Thing) — build → shrink to free time → recolor red.

**Phase 4 · The turn (mechanism)**
18. Earned-access reframe (permission). 19. Lock (`FrozenAppTile` freeze) · 20. Earn (counter counts up) · 21. Verify (proof chips). *One Thing's 4-state demo, in Aura's look.*

**Phase 5 · Named profile** (Brainrot)
22. Processing theater · 23. Attention-profile reveal (named type + trait bars from answers).

**Phase 6 · Personalize**
24. Starter habit (multi) · 25. Daily commitment.

**Phase 7 · Commit + build**
26. **Hold-to-commit** (`HoldToConfirmButton`) → charge/color flood. 27. Building-plan theater.

**Phase 8 · Your plan** (one scroll)
28a. Dated 4-week roadmap · 28b. Two-path red/blue toggle (chips from answers) · 28c. Objection FAQ (cost/efficacy/failure). Sticky CTA.

**Phase 9 · Proof, price, save**
29. **Science** (Harvard/UCL/Atomic — cite, no endorsement). **29b. Reviews wall** (real tester testimonials; no native rating popup). 30. Paywall (blue field + fox, annual anchor + weekly decoy, benefit checklist; **stubbed** — RevenueCat later). 31. Exit scratch-to-reveal discount (one dismissible loop).

**Then → post-paywall Setup flow** (already built): welcome → sign in → notifications → screen time → app picker → all set → app.
