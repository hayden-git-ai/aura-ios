# Aura Onboarding — Locked Flow

Locked 2026-09-06. This is the source of truth for onboarding screen order.
Beats are woven between individual questions and each reacts to the answer
just before it. New beats live in the diagnosis / stakes / proof phases, never
in the Wrapped payoff. The Wrapped is pure payoff and runs straight into commit
then paywall.

Arc: diagnose -> quantify the pain -> build the fix -> show the transformed
future (Wrapped) -> prove the method -> commit -> pay.

---

## Phase 1 — Hook
1. `welcome` — existing
2. `meet` — existing, meet the fox
3. `name` — existing
4. `age` — existing
5. `handoff` — existing

## Phase 2 — Diagnosis + how it works
6. `chat` — existing (covers the loop, why blockers fail, the adversary)
7. **NEW: Loop demo (interactive)** — tap-through, green -> yellow -> red "too late now," one tap breaks the loop. Reacts to the chat.
8. `demoFreeze` — existing, block distracting apps
9. `demoEarn` — existing, earn Aura Coins
10. `demoSpend` — existing, buy screen time
11. `reframe` — existing
12. `bridge` — existing

## Phase 3 — Questions + reacting beats
13. `qGoal` — existing, + reaction
14. `qSlider` — existing, their lost-time number surfaces in its own result state
15. `qFeelings` — existing, + reaction
16. `qPersona` — existing, + reaction
17. `qWorstTime` — existing, + reaction
18. **NEW: Doomscroll profile beat** — reacts to feelings + persona + worst-time. Sits here so all three are answered first. (Moved out of the Wrapped.)
19. `qSkip` — existing, + reaction
20. **NEW: Review drop-in** — one real tester quote (placeholder now, real at launch).

## Phase 4 — Why nothing worked + stakes
21. `qTried` — existing
22. `qWhyFlopped` — existing, "Did you know?" personal-cost stats (4 hrs/day, 58 checks, sleep, eyes)
23. **Reclaim as things** — reworked `qReclaim`. Their time as 15+ books / 6+ courses / 60+ workouts, dropping in one at a time. Numbers derive from their real slider input.

## Phase 5 — Build the plan
24. `qHabits` — existing
25. `qExercises` — existing
26. `qDailyGoal` — existing

## Phase 6 — Loading -> Wrapped payoff
27. `qLoading` — existing
28. `qCustomPlan` — existing, rebuilt as the Wrapped tap-through:
    hero -> your 4 weeks (absorbs `qImmediate`'s benefits) -> two paths -> recap.
    Story progress bars, one beat per screen, tap to advance. Payoff only, no
    cost math, no doomscroll profile (that moved to Phase 3).

## Phase 7 — Proof -> Commit -> Paywall
29. **The science** — NEW build. Harvard / UCL / Atomic Habits, three research
    cards. Assets ready (`LogoHarvard`, `LogoUCL`, `CoverAtomicHabits`).
    Header "The science behind your plan." Fox line "i didn't make this up.
    it's the same stuff the researchers use." Honesty gate: cite the work, do
    NOT imply Harvard or UCL endorse Aura.
30. **Reviews wall** — real tester testimonials at launch, placeholder now. No
    native rating popup.
31. `qCommit` — existing, hold to commit (seals intent)
32. **Paywall** — stub (RevenueCat later)

## Phase 8 — Permissions (post-purchase)
33. Setup handoff — existing

---

## Retired / cut
- Standalone `qImmediate` — folded into the Wrapped (screen 28, "your 4 weeks").
- `qLifeWeeks` — retired.
- Brainrot Loop beat — cut. The chat sells the loop and the slider quantifies it; a third loop visualization was redundant.
- Standalone "cost as one number" — cut. The slider and reclaim beat carry the number.
- The invented Phase 4 four-punch (why-blockers-fail / a new science screen / the-flip) — cut. Blockers-fail is in the chat, stats are `qWhyFlopped`, research is the science screen (29).

## Net new to build
1. Loop demo, interactive (7)
2. Doomscroll profile beat, moved to Phase 3 (18)
3. Review drop-in (20)
4. Reclaim as things, reworked (23)
5. Wrapped rebuild, tap-through (28)
6. The science, Harvard/UCL/Atomic Habits (29)

Everything else already exists.

## Standing rules (apply to every screen)
- No em dashes anywhere.
- All copy through the humanizer ruleset. No AI slop.
- Proper capitalization everywhere EXCEPT the chat diagnosis screen (lowercase fox voice).
- Never refer to the app/content AS "the scroll" or "the feed" (nouns). "scroll / scrolling / scroller" as a verb/agent and "doomscroll" are fine.
- Never use "willpower" in product copy.
- Honesty gate: no fabricated data. Reviews are real testers, science cites real work with no implied endorsement, personalized numbers derive from the user's real inputs.
- Use the app typography scale (SheetType / RowType tokens), never ad-hoc sizes or weights.
- Gamified progress bar runs the full flow and advances on beats too, so passive screens still feel like progress.
