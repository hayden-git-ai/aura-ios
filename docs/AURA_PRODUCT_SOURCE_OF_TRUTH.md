# Aura Product Source of Truth

*Prepared for Web2Wave. Everything below is taken from the Aura codebase as it
stands today. Aura is still in development. Anything temporary, placeholder or
likely to change before launch is labelled inline.*

---

## 1. What Aura Is

**The problem.** People open their phone to do one thing and lose an hour. They
know it's happening. They've tried blockers, and they've learned to swipe past
them. The app's own copy names this directly: *"I always bypassed other
blockers."*

**The intended user.** **18 to 30. Gen Z and young millennials.** People who
want to get their act together (the gym, studying, reading, a decent morning
routine) and lose hours a day to apps they don't actually want to delete.

Strongest segments: **students**, **gym and self-improvement**, and **young
professionals early in their career**. Creators are a possible fit. Entrepreneurs
are not the target.

The habits tell you who this is for: alongside the gym and studying sit *make
your bed, brush your teeth, take your vitamins, do your skincare, touch grass*.
Someone building a baseline, not optimising a calendar.

**The central idea.** Screen time isn't budgeted or nagged. It's **earned**.
Your distracting apps are locked by default, and the only way to open them is to
do something real first: a workout, a study session, a walk, a made bed. Aura
verifies it, pays you, and you spend what you earned.

**One sentence.** *Aura locks your distracting apps and only unlocks them when
you've earned the time by doing something real.*

**How it differs from a normal blocker.** A normal blocker is a rule. A
schedule, a daily limit, a timer that runs whether you deserve it or not. Aura's
lock has no clock of its own. It doesn't lift on Tuesday at 6pm or after your
first 30 minutes. It lifts when you've paid for it with effort. The relationship
is transactional rather than restrictive: you're not banned from Instagram,
you're buying your way in.

**The transformation it's reaching for.** **Scroll guilt-free.**

The goal isn't less screen time. It's screen time you don't feel bad about. You
earned it, so you can enjoy it.

And you get there without willpower. No limits you set and break, no forcing
yourself, no bargaining every time you pick up your phone. Aura holds the line so
you don't have to. The hours that used to disappear into doomscrolling go into
the gym, studying and reading, and you still get to scroll at the end of it.

---

## 2. How Aura Works

**The loop, in order:**

1. **You pick something productive to do.** Four methods (§3), each with its own
   set of activities.
2. **Aura confirms you did it.** A photo the AI checks, reps the camera counts,
   a focus timer that runs while your phone is down, or activity read from Apple
   Health.
3. **You get paid in coins.** Rates vary by how demanding the habit is.
4. **You spend coins on minutes.** The exchange rate is **1 coin = 1 minute**.
   You choose how much to buy at the moment you want to scroll.
5. **Your distracting apps open** for exactly the time you bought. A countdown
   runs on the Lock Screen and Dynamic Island so you can see it draining.
6. **When the time runs out, the apps lock again automatically.** A notification
   says **"Time's up. Your apps are blocked again."**
7. **The next day, your coin balance resets to zero.** Unspent coins do not carry
   over.

**Coins, minutes and balance in plain terms:** coins are the score you earn today.
Minutes are what you convert them into. Both are the same number. 40 coins buys
40 minutes. Your balance is *what you earned today minus what you've spent
today*, and it's gone at midnight.

**Mechanics likely to change before launch:**

- **The daily coin reset** is deliberate and documented in the code, but it's a
  strong product rule worth confirming with Hayden before it appears in
  messaging.
- **AI verification is currently mocked.** Right now every photo passes. The
  real verification service is written but not yet connected.
- **Emergency Unlock** (see §5) has a note in the code that its weekly limit
  isn't enforced yet.

---

## 3. Ways Users Can Earn Screen Time

### Photo Proof
**What the user does:** picks a habit, photographs it, and Aura's AI checks the
photo against what that habit is supposed to look like. Every habit carries its
own instruction. For "Touch grass" it's *"Your hand on actual grass, in frame. I
do mean literally."*
**Rewards:** real-world actions that are easy to prove visually.
**Why it's interesting:** the verification has personality. The hints are written
in the fox's voice and are frequently funny, which turns a compliance step into
part of the product's character. *(Verification is currently mocked. Every photo
passes.)*

### Camera Reps
**What the user does:** props the phone up and does push-ups, squats, sit-ups,
jumping jacks or lunges while the camera counts.
**Rewards:** physical effort, measured in volume rather than time.
**Why it's interesting:** it's the most direct version of the premise. You are
physically working for your screen time, and doing more earns more. Each exercise
has a form tip about camera placement (*"Back up further than feels necessary.
Arms have to stay in frame."*).

### Lock In
**What the user does:** starts a timed focus session and puts the phone down. The
session pays out when it completes. There's also an open-ended "Extreme Focus"
mode with no timer that you end yourself.
**Rewards:** sustained attention away from the phone.
**Why it's interesting:** it's the only method where the reward is for *not*
using the phone, and while it runs your distracting apps stay locked even if you
have time banked.

### Passive Income (Apple Health)
**What the user does:** nothing extra. Aura reads today's steps, distance,
exercise minutes, mindful minutes and calories from Apple Health, and you claim
them as coins.
**Rewards:** activity you were already doing.
**Why it's interesting:** it's the on-ramp. You can open Aura on day one and
already have something to collect. The rates are deliberately low compared to
active methods. The code notes it's "deliberately stingy on the passive ones."

---

## 4. Habit Library

Rewards below are in coins. **Timed** habits pay by the hour and run a session;
**Quick** habits pay a flat amount instantly and are limited to once per day.

### Timed habits (Photo Proof)

| Habit | Type | Default length | Reward |
|---|---|---|---|
| Deep Work | Focus | 40 min | 20/hr |
| Study | Focus | 40 min | 20/hr |
| Side Hustle | Focus | 40 min | 20/hr |
| Play an instrument | Creative | 30 min | 20/hr |
| Read | Focus | 30 min | 15/hr |
| Hit the gym | Exercise | 40 min | 15/hr |
| Go for a run | Exercise | 40 min | 15/hr |
| Do some yoga | Exercise | 30 min | 15/hr |
| Go for a walk | Exercise | 30 min | 10/hr |
| Meditate | Focus | 20 min | 10/hr |
| Write in your journal | Focus | 20 min | 10/hr |
| Do some gardening | Home | 30 min | 10/hr |
| Hang out with someone | Social | 60 min | 5/hr |

### Quick habits (Photo Proof, once per day)

| Habit | Type | Reward |
|---|---|---|
| Eat a healthy meal | Health | 7 |
| Clean your room | Home | 7 |
| Touch grass | Health | 5 |
| Make your bed | Home | 5 |
| Smile | Social | 3 |
| Brush your teeth | Health | 3 |
| Drink some water | Health | 3 |
| Do your skincare | Health | 3 |
| Take your vitamins | Health | 3 |

### Camera Reps

| Exercise | Minimum to start earning |
|---|---|
| Push-ups | 5 reps |
| Squats | 5 reps |
| Sit-ups | 5 reps |
| Lunges | 5 reps |
| Jumping Jacks | 10 reps |

Earn rate is user-adjustable; default is 1 coin per rep, and nothing is paid
until the minimum is reached.

### Apple Health

| Metric | Rate |
|---|---|
| Run / Walk | 8 coins per km |
| Exercise Minutes | 1 coin per minute |
| Mindful Minutes | 1 coin per minute |
| Calories Burned | 6 coins per 100 kcal |
| Steps | 3 coins per 1,000 |

### Custom habits
Users can build their own: name it, set the hourly rate, choose timed or quick,
and write their own photo instruction. The field prompt reads *"What should the
photo show?"* with the note *"This helps Aura verify niche habits."*

---

## 5. Blocking Experience

Aura can block **individual apps, whole categories** (social, games,
entertainment and so on) **and websites**. Users pick them through Apple's own
picker.

Everything is organised into **three lists that are always on.** There are no
schedules and no daily limits:

**Always Allowed.** Apps Aura never touches. Only meaningful when a user has
chosen to block everything.

**Always Blocked.** Permanently off. This list is never lifted, not by earned
time and not by Emergency Unlock. In the app's own words: *"it's called Always
Blocked for a reason."* The contents are kept private in the UI. The Blocks
screen shows the count as "Hidden" rather than the apps, on the reasoning that
someone who permanently blocks something may not want it on a screen a friend
glances at.

**Distracting.** The working list, and the only one that ever opens. It unlocks
when you spend earned time, and locks again when that time runs out.

**One important interaction:** starting a Lock In or a photo-habit session
re-locks your Distracting apps even if you have time banked. You can't buy your
way around the session you're being paid for.

**Emergency Unlock.** A 45-minute release valve for when self-control fails.
It cannot open Always Blocked. Turning on **Hard Mode** in Settings removes it
entirely. *(The code notes its weekly limit isn't enforced yet.)*

**Adult content.** A single toggle using Apple's own automatic filter rather
than a list Aura maintains.

**Interventions.** When you open a blocked app, one of four experiences runs
before you can buy your way in. See §7.

### Limitations the marketing team should understand

- **Aura cannot see which apps a user blocks.** Apple hands over anonymous
  tokens, not names. The app can count them and display Apple's own icon, but it
  never learns that you blocked Instagram. Any creative implying Aura knows or
  reports your app list would be wrong.
- **Blocking has not yet been tested on a real device.** It cannot run in a
  simulator, so it is written and unverified.
- **Deleting Aura removes the blocking.** There is no protection against this.

---

## 6. Main Product Features

| Feature | What it does | Status |
|---|---|---|
| **Earn screen time** | Four methods convert real activity into coins, coins into minutes | Implemented |
| **App blocking** | Three always-on lists; only Distracting ever opens | Built, untested on device |
| **Habit library** | 22 built-in habits plus a custom habit builder | Implemented |
| **Custom habits** | Name, rate, timed/quick, and your own photo instruction | Implemented |
| **Photo verification** | AI checks the photo against the habit's instruction | **Mocked, everything passes today** |
| **Camera Reps** | Camera counts reps for five exercises | Implemented |
| **Lock In** | Timed focus session, plus an open-ended Extreme Focus mode | Implemented |
| **Apple Health** | Claim steps, distance, exercise, mindful minutes, calories | Implemented |
| **Screen-time store** | Choose hours and minutes to buy with coins | Implemented |
| **Streaks** | Consecutive days with at least one completed habit | Implemented |
| **Streak freezes** | Earn one on any day with 2+ habits; hold up to 2 | Implemented |
| **90-day board** | A 15×6 grid of your journey; day 1 first, restarts after 90 | Implemented |
| **Stats** | Two views, your habits, and your screen time | Habits view implemented; **screen-time view still sample data** |
| **Wall of Wins** | Your verified photos kept as a gallery | Implemented |
| **Live Activity** | Countdown on the Lock Screen and Dynamic Island | Implemented |
| **Interventions** | Four experiences when you open a blocked app | Implemented |
| **Streak celebration** | A dedicated screen on the first completion each day | Implemented |
| **Fox mascot** | Animated on Home, and a character throughout | Implemented |
| **Hard Mode** | Removes Emergency Unlock | Implemented |
| **Reminders** | Toggles exist in Settings | **Not functional, nothing is scheduled** |
| **Cancellation flow** | Reason survey then out to the web | Implemented (but no real subscription behind it) |
| **Home-screen widget** |, | **Does not exist.** The only widget is the Live Activity |

---

## 7. Gamification + Retention

**Coins.** Earned per habit, spent on minutes, 1:1. **The balance resets every
midnight**, so there's no banking a weekend's worth.

**Streaks.** A day counts when you complete at least one habit. Buying or
spending time doesn't count; you have to actually do something.

**Streak freezes.** Earned by doing **two or more** habits in a day, and you can
hold a maximum of **two**. They automatically cover a missed day so the streak
survives. This is the product's answer to the usual all-or-nothing streak
anxiety.

**The 90-day board.** A grid of 90 dots, one per day, filled when you completed
a habit. It starts at your first day and restarts after day 90. Sits under the
heading *"Your past 90 days."*

**Stats.** Two toggleable views. The habits side is real. The screen-time side
still shows sample data.

**Wall of Wins.** Every verified photo is kept, so the app slowly accumulates a
gallery of evidence that you did the things. Currently labelled by habit and
date.

**Celebrations.** A full streak screen on the first habit of each day, with
milestone progress and a challenge card.

**The fox.** Aura's mascot and its voice. It appears animated on Home, as a
sticker on every habit, and as a character in the interventions, where it speaks
directly to you.

**Interventions.** The most distinctive retention mechanic. Opening a blocked
app triggers one of four:
- **Talk to Aura.** The fox asks if you actually need it, and charges you if you
  say yes
- **Breathing Pause.** A guided breath before you decide
- **Mirror Check.** Aura "calls" you, and you answer looking at your own face
- **Text From Aura.** The fox texts you and you reply

All four are on by default and one is chosen at random. The dialogue is written
in the fox's voice: *"Be real with me… do you need this or are you just bored?"*

**Live Activity.** A countdown on the Lock Screen and Dynamic Island whenever
anything is running, with lines like *"This is rented screen time 👀"*.

### Mechanics that do NOT exist

Despite appearing in older planning documents:
- **No rank, level or XP system**
- **No achievements or badges**
- **No referrals**
- **No social or community features**
- **No leaderboards**
- **No home-screen widget**

---

## 8. Main App Navigation

Five tabs.

**Home.** The fox, and the state of your day. Shows either a countdown (*"Until
apps unlocked"*) or the locked state, plus "Earned Today", a streak badge, and
two action cards: Quests and Scroll.

**Blocks.** What's blocked right now, shown as a scrolling strip of app icons
with a padlock badge. Below it, the three lists to configure, and Emergency
Unlock.

**Earn (centre button).** Opens a four-card picker for the earning methods,
which leads into that method's flow.

**Stats.** Toggle between Daily Habits and Screen Time. Charts by day, peak
hours, the 90-day board, and the Wall of Wins.

**Profile.** Your card, and the way into Settings.

**Settings.** Difficulty (Hard Mode), reminders, intervention styles, rename,
subscription, help, and all outbound links.

**Screen-time store.** Where coins become minutes. You dial hours and minutes on
a picker and confirm.

**Habit flows.** Each earning method has its own multi-screen flow: setup →
action → verification → result.

**Streak celebration.** A full-screen moment on your first completed habit of
the day.

**Interventions.** Full-screen takeovers that run when a blocked app is opened.

---

## 9. Current Onboarding Direction

> **The current onboarding is being completely redesigned. Nothing in it should
> be treated as final, and several parts are explicitly placeholder or
> fabricated.**

**Current structure at a high level:** two parts, roughly 21 screens then 11.

**Part 1. Establish the problem and the person.** Logo reveal, welcome, a
typewriter intro, then questions: name, age, life stage, gender, and *"Where did
you hear about us?"* Then a conversational beat, a short demo sequence, a
science screen, and a set of screens that turn the user's own screen-time
estimate into a yearly figure.

**Part 2. Emotional framing, permissions, commitment.** How scrolling makes you
feel, a reflection beat, *"Aura users live more and scroll less"*, a social-proof
screen, permission primers, app selection, a hold-to-commit moment, a loading
screen, then a personalised program reveal.

**Information it currently asks for:** name, age range, life stage, gender,
acquisition source, daily screen-time estimate, how scrolling makes them feel,
which earning methods appeal, and a daily commitment.

**Permissions it introduces:** notifications (real system prompt) and Screen
Time (primer only. The real permission is currently requested later, the first
time a user opens the app picker).

**Product concepts it teaches:** that screen time is earned, the four earning
methods, that apps lock and unlock, and the daily rhythm.

**Psychological ideas it's reaching for:** loss framing (your time, projected out
over a year), identity (*"In 4 weeks you won't recognize yourself"*), social
proof, commitment (a physical hold-to-commit gesture), authority (Harvard, UCL,
Atomic Habits), and urgency (a countdown on the final screen).

### What should NOT be treated as final

- **The app-selection screen is explicitly a placeholder.** Labelled as standing
  in for the real Screen Time picker.
- **The final screen's CTA goes nowhere.** Its code comment says the real
  paywall/claim screen *"hasn't been built yet."* Onboarding currently ends by
  dropping the user into the app for free.
- **All testimonials and ratings on the social-proof screens are fabricated.**
  See §13.
- **The urgency countdown is decorative.** No offer is attached to it.
- **Most answers are discarded.** Age, life stage, gender, acquisition source and
  the apps chosen during onboarding are not saved and never reach the app.
- **There is an entire second, unused onboarding implementation** in the codebase
  (a 52-screen version) along with a set of planning documents describing it.
  It is dead code. If anyone shares `docs/onboarding/generated/*`, those describe
  a flow that isn't in the app.

---

## 10. Pricing + Monetization Direction

> **All of this is placeholder. The code marks the product identifiers
> "PLACEHOLDER. Must match App Store Connect", and no purchase is possible in
> the app today.**

**Intended structure as currently represented:**

| Plan | Price | Framing |
|---|---|---|
| Annual | **$69.99/year** | shown as **$1.34/week**, **"Save 87%"** |
| Weekly | **$9.99/week** | the comparison anchor |
| Exit offer | **$34.99/year** | shown as **$0.67/week**, **"93% off"** |

**Trial:** 7 days, on the annual plan only.
**Default selection:** annual.
**No monthly plan. No lifetime option.**

**How the discounts are calculated:** both percentages compare the annual price
against paying $9.99 weekly for 52 weeks. The code does this deliberately so the
claimed percentages stay mathematically correct if prices change. Meaning
"Save 87%" and "93% off" are honest arithmetic *given that comparison*, not
invented numbers.

**Offer copy that exists today:**
- *"Special offer expires in"* with a live countdown
- *"Claim Limited Discount"*
- FAQ: *"Aura costs less than 1 coffee per month. For potentially 1,000+ hours of
  your life back. You decide."*. Note this is inconsistent with a $9.99/week
  plan, and the "1,000+ hours" figure has no source.

**Cancellation** is built: a reason survey, a free-text box, then out to the web
with *"instructions for both App Store and web subscriptions."*

---

## 11. Brand + Visual Identity

### Overall tone
Playful, characterful, youthful, slightly teasing. Motivating and culturally
current rather than clinical or corporate.

### Primary visual language
**Aura is a light app.** Bright, tactile surfaces with white cards and strong
blue CTAs. Home is a full-bleed painted illustration: a fox on a mountain
peak, with day and night variants of the same scene. Everything else (Blocks,
Stats, Profile, Settings, every sheet, the interventions) sits on a soft light
grey with white cards that have a visible darker bottom edge, giving buttons and
cards a pressable, physical quality.

Two surfaces break the pattern deliberately, and both are moments rather than
screens: the **screen-time store** is a full blue field, and the **Stats** header
is a blue band that a habit's illustration sits half on top of.

Full-screen dark backgrounds appear only in immersive moments. The Lock In
timer, camera capture screens, and the streak celebration. Where the point is
to take the whole screen. **Dark is not the brand.**

### Core colors
| Role | Hex |
|---|---|
| **Primary blue**: CTAs, filled states, the store, the Stats band | `#2586FF` |
| Blue shade, the pressed/drop edge under blue | `#1C69D6` |
| Accent orange, focus sessions, streaks | `#FF6B03` |
| Alert red, Emergency Unlock, destructive actions | `#F0453E` |
| Unlock cyan, the unlock glow | `#00BFFF` |
| Light surface, the app's ground | `#EEEDF0` |
| Card white + hairline dividers | `#FFFFFF` / `#EDEDF1` |
| Ink, headings and body | `#1C1C1E` |
| Muted, secondary copy | `#9B9BA3` |

`#0B0B0E` exists in the system but functions as an **ink/outline colour** (it
draws the black keyline around Home's big numerals) and as the ground for the
few immersive full-screen moments. It is not a background brand colour.

### Typography
**Montserrat.** Headings, statistics, large numerals.
**Rubik.** Body copy, labels, captions.
Large numerals get a sticker treatment: white fill with a heavy black outline.
Layout runs on a strict 4-point spacing grid.

### Mascot
White arctic fox. Appears as a frame-by-frame animation on Home, as a face in
navigation and the Live Activity, as a sticker on every habit, and as a
character in the interventions. It speaks casually and in first person.

### Illustration / icon direction
Rounded, tactile, sticker-like. Bold outlines, simplified forms, bright flat
colour, soft drop shadows, readable at small sizes. Illustrated scenes (Home's
landscape) carry more painted detail than the UI stickers, but share the same
warmth. Nothing in the product is flat-grey utility iconography.

### Brand behavior
The fox can tease, challenge or call the user out without sounding parental.
Copy should read like a friend who knows exactly what you are about to do.

### Creative production notes
- Product mechanics should stay visually obvious.
- Blue is the primary conversion/CTA signal.
- The mascot supports the product idea; it is not a children's character.
- Avoid generic productivity-app visuals and sterile wellness imagery.
- **Avoid dark, premium, "cinematic" framing.** It is not what the app looks
  like.

### Major branded assets
`AuraLogo`, the app icon, the coin icon, the fox in many poses, ~20 habit
stickers, the streak flame, the Home day/night landscapes, the special-offer
card. Animation is frame-sequence PNG and SwiftUI motion. No Lottie or Rive.

---

## 12. Voice + Messaging

Aura's product copy is written as **one character speaking to one person**. It
isn't interface text with jokes added. The fox is the narrator of the whole
app, and almost every string is something it says to you.

**The voice in one line:** a friend who knows exactly what you're about to do,
says so, and then lets you decide.

### The six rules the existing copy follows

**1. It talks to you, never about you.**
Second person, present tense, direct. The product never describes its own
features in the abstract.
> "How do you want to earn screen time?"
> "Hey. Do you actually need this right now?"

**2. The frame is a transaction, not therapy.**
This is the single strongest tonal signature and the thing that separates Aura
from every wellness app. Time is rented, effort is paid, coins are charged.
Nothing is a "journey."
> "This is rented screen time 👀"
> "Alright. Pay up. 10 coins."
> "Staying locked in pays 💰"

**3. It closes the excuse before you make it.**
Nearly every habit instruction anticipates the specific dodge and shuts it in
the last few words. This is where most of the product's humour lives.
> "Your hand on actual grass, in frame. I do mean literally."
> "Show the plate. I'm looking for real food, not the wrapper."
> "Point it at whatever you're about to lift. The treadmill counts too."
> "Glass or bottle in frame, filled and ready. Water only, sorry."

**4. It never moralises, praises or shames.**
When you make the good choice it is understated. When you make the bad one it
charges you and moves on. There is no lecture in either direction.
> "Nah, you're right" → "Good call. I'll keep it blocked."
> "You're out of coins. Go earn some and come back."

**5. Short. Often fragments.**
The interventions run in three- and four-word sentences. Length signals
seriousness, and Aura almost never needs to be serious.
> "Alright. How long?"
> "Okay. 10 minutes."
> "Time's up. Your apps are blocked again."

**6. Humour arrives at the end, dry, and once.**
Never a setup and a punchline. Just a final clause that undercuts the
instruction. One emoji maximum, at the end, as punctuation.
> "The pic was the easy part 😅"
> "Back up further than feels necessary. Arms have to stay in frame."

### How the register shifts by context

| Where | Register | Example |
|---|---|---|
| **Status & system** (Live Activity, notifications, Home) | Flat, factual, faintly wry. States the situation, doesn't editorialise. | "Until apps unlocked" · "Time's up. Your apps are blocked again." |
| **Habit instructions** | A coach holding the camera. Practical and physical first, one joke last. | "Mat down, phone propped, you in frame before the first pose." |
| **Interventions** | A friend confronting you. Real dialogue with turns, pauses and a decision. | "Be real with me… do you need this or are you just bored?" |
| **Earning & reward** | Plainly commercial. The deal, stated. | "The more you do the more coins you earn" |
| **Celebration** | Restrained. A number and a fact, not confetti language. | "12 day streak!" · "Day 8 of 30" |

### What the voice never does

- **No em dashes.** A stated brand rule. The copy uses periods and ellipses to
  carry a pause instead. *(Two strings currently break this: a camera tip and
  a quoted citation. Both should be corrected.)*
- **No wellness vocabulary.** No "journey", "mindfulness", "digital detox",
  "screen-time hygiene". None of it appears anywhere in the product.
- **No shame or guilt.** The app never tells you that you have a problem.
- **No enthusiasm inflation.** Exclamation marks appear four times in the entire
  app.
- **No corporate hedging.** No "we're here to help you", no "let's".
- **Never parental.** It challenges as a peer, not as an authority.

### Where the voice is strongest today

The **interventions** and the **habit proof hints** are the most fully realised
writing in the product, and the best reference for anyone producing new copy.
The intervention dialogue in particular is written as a scene with turns:

> "Be real with me… do you need this or are you just bored?"
> *Nah, you're right* → "Bet. Keeping it blocked for you."
> *Yeah, I do* → "Alright. How long?" → "Alright. Pay up. 10 coins." → "Okay.
> 10 minutes."

Read that sequence before writing anything in Aura's voice. It contains all six
rules in about thirty words.

### Where the voice is weakest today

The **onboarding** is written in a different, more conventional register:
"Congratulations, your personalized plan is ready", "In 4 weeks you won't
recognize yourself", "You will beat your phone addiction by {date}". This is
generic growth-funnel language and does not sound like the fox. Since onboarding
is being redesigned anyway (§9), it should not be used as a voice reference.

---

## 13. Claims Web2Wave Should NOT Use Yet

**This section matters most. Aura is unreleased, so every social-proof element in
the app today is invented.**

### Fabricated. Do not use in any advertising

| Claim | Where | Why it can't be used |
|---|---|---|
| **"5.0" AVERAGE RATING**, five stars | Onboarding social-proof screen | The app has never shipped. No rating exists. |
| **"4.8" AVERAGE RATING** | Onboarding program reveal | Same, and it **contradicts the 5.0** shown a few screens earlier. |
| **"I went from 7 hours a day to under 3."** (Reese) | Testimonial marquee | Invented. A specific quantitative outcome claim from a fictional person. |
| **"Screen time cut in half"** | Testimonial title | Invented outcome claim. |
| **"I haven't skipped the gym in three weeks…"** (Cole) | Testimonial | Invented. |
| **"One month later, my screen time is down and I'm reading again."** (Amara) | Testimonial | Invented. |
| *(and six more)*, Devon, Sofia, Malik, Grace, Theo, Nadia, Liam | Testimonial marquees | **All ten reviews are hardcoded fiction**, all five stars, first names only. |
| **"Join others just like you using Aura"** | Program reveal | Implies an existing user base. |
| **"Aura users live more and scroll less"** | Part 2 | No user data exists to support it. |

### Unsourced product claims. Not fabricated, but unsubstantiated

| Claim | Note |
|---|---|
| "In 4 weeks you won't recognize yourself" | No study, no data. |
| "You will beat your phone addiction by {date}" | A dated promise of a clinical-sounding outcome. |
| "1,000+ hours of your life back" | Arithmetic from the user's own estimate, but presented as a product outcome. |
| "Aura costs less than 1 coffee per month" | Inconsistent with the $9.99/week plan. |
| "built on decades of behavioral science research from leading institutions like Harvard and UCL" | Partly supported, see below, but "Aura is built on" overstates what the citations show. |

### Properly sourced. Safe to reference, with care

The onboarding science screen carries three **real, correctly attributed**
citations:

- **Harvard**: "Habits form through repeated actions in stable contexts, taking
  weeks to months to become automatic." *(Wood & Rünger, 2016, Annual Review of
  Psychology)*
- **UCL**: "96 participants performed a daily behavior, and automaticity was
  modeled to plateau at an average of 66 days, with a range of 18–254 days."
  *(Lally et al., 2010, European Journal of Social Psychology)*
- **Atomic Habits**: "On average, it takes more than two months before a new
  behavior becomes automatic—66 days to be exact." *(Clear, 2018)*

**Important nuance:** these describe *habit formation in general*. They are not
evidence that Aura works. Using them to support a claim about Aura's results
would misrepresent them.

The **"Save 87%" / "93% off"** figures are also sound. Real arithmetic against
the weekly price, provided the final prices don't change.

---

## 14. Current Product Strengths for Marketing

*Factual differentiators visible in the product.*

1. **Access is earned, not restricted.** The lock has no timer of its own. This
   is the structural difference from every schedule- or limit-based blocker.
2. **Four genuinely different earning methods**, from active (reps) to passive
   (Health), so there's an on-ramp for someone who won't do push-ups.
3. **Physical behaviour is tied directly to phone access.** Camera Reps is the
   clearest version: do more push-ups, get more minutes.
4. **Habits are verified, not self-reported.** A photo has to show the thing.
5. **Screen time functions as a currency** with a balance, a price, and a
   purchase moment: a familiar mental model applied to attention.
6. **You keep your apps.** Aura is a relationship with Instagram, not a deletion
   of it. The fabricated-but-directionally-real testimonial framing: *"I can
   still use the apps I enjoy"*. Reflects the actual product design.
7. **Interventions happen at the moment of temptation**, not in a settings
   screen. Four distinct experiences, including one where the fox video-calls
   you and you answer looking at your own face.
8. **Streak freezes are earned by doing more**, which softens the all-or-nothing
   failure that kills most streak systems.
9. **The Wall of Wins accumulates evidence.** A photo record of everything you
   did to earn your time.
10. **A character, not a utility.** The fox speaks throughout, and the writing has
    a consistent voice.
11. **Live Activity keeps the countdown visible** on the Lock Screen while time
    drains.

---

## 15. What Is Still Unfinished

Things that directly affect messaging, funnels, ads, screenshots or claims:

- **Onboarding is being completely redesigned.** Don't build funnel concepts
  against the current flow.
- **There is no paywall.** Onboarding currently ends by letting the user into the
  app for free.
- **Pricing is placeholder** and the product IDs aren't in App Store Connect yet.
- **AI photo verification is mocked.** Every photo currently passes. The real
  service is written but not connected.
- **Blocking has never run on a real device.** It cannot be tested in a
  simulator.
- **The Screen Time half of Stats is sample data**, so any screenshot of it shows
  invented numbers.
- **Reminders don't work.** The toggles exist; nothing is scheduled. The only
  real notification is "Time's up."
- **All testimonials and ratings are fabricated** and must not appear in ads or
  App Store screenshots as they stand.
- **Most onboarding answers aren't saved.** Age, gender, life stage, acquisition
  source and app selection are collected and discarded.
- **Onboarding repeats on every launch** in release builds; there's no
  "completed" flag yet.
- **No user accounts**, so nothing syncs across devices and nothing survives a
  reinstall.
- **Analytics, attribution and deep linking are not implemented.** Worth knowing
  for funnel planning, but they're on the roadmap rather than broken.
- **Some artwork is placeholder**, including the fox poses used in the
  interventions and the colour used for one Live Activity state.

---

## 16. Questions for Hayden

**Audience & positioning**
1. Who is the primary target. Students, young professionals, founders, parents?
   The app currently speaks to all of them.
2. Is Aura positioned as a productivity tool, a digital-wellbeing tool, or an
   anti-addiction tool? The copy currently spans all three.
3. What's the single sentence you want someone to repeat after seeing an ad?

**Pricing & offer**
4. Are $69.99/year and $9.99/week final, or still being tested?
5. Does the exit offer ship, and is the countdown meant to be real scarcity or
   presentation?
6. Is the 7-day trial confirmed, and annual-only?
7. Is a monthly plan deliberately excluded?

**Launch scope**
8. Which features are definitely in the launch build? Specifically: are
   interventions, Camera Reps and Apple Health all shipping day one?
9. Will the Screen Time stats view have real data at launch, or ship as-is?
10. Is Aura launching with accounts, or device-local only?

**Claims & proof**
11. Do you have *any* real user results. Beta testers, personal data, anything
    substantiable?
12. Will you run a beta to generate real testimonials before ads start?
13. Are you comfortable citing Harvard/UCL/Atomic Habits in ads, given they
    support habit formation generally rather than Aura specifically?
14. What outcome claim are you willing to stand behind and defend?

**Brand**
15. Does the fox have a name, and should it speak in ads the way it speaks in the
    product?
16. Is the playful, teasing tone right for paid acquisition, or is that an in-app
    voice only?

**Onboarding & funnel**
17. What's the direction for the redesigned onboarding, and when will it be
    stable enough to build funnel concepts against?
18. Should Screen Time permission be requested during onboarding or later? It's
    currently late, and the product is inert without it.
19. What's the goal of the web funnel. Pre-selling subscriptions, warming before
    install, or collecting emails?
20. What is Web2Wave allowed to change or test independently, and what needs your
    sign-off?
