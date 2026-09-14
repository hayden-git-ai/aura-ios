# Product

## Register

product

## Users

People who default to doomscrolling and want to replace it with intentional
habits — completing a real habit (exercise, a photo-verified task, a synced
health metric) earns a fixed window of screen time. Used in short, frequent
touches throughout the day (checking if apps are unlocked, logging a habit,
occasionally reaching for Emergency Unlock when self-control fails). Primary
workflow on any given screen: either "how do I earn time back" (Gate/Home) or
"what exactly is blocked and why" (Apps).

## Product Purpose

Aura blocks distracting apps by default and only unlocks them when the user
completes a real habit — screen time is earned, not just budgeted or nagged
about. Success looks like a user trusting the block enough to stop
second-guessing it, with enough legitimate escape valves (Emergency Unlock,
Always Allowed apps) that the system feels supportive rather than punitive.

## Brand Personality

Calm, disciplined, quietly premium — a personal trainer, not a scold. Near-
black surfaces, one reserved signal-blue for earn/unlock moments, red used
sparingly and only for genuinely consequential/warning moments (Emergency
Unlock, locked states). Confidence expressed through restraint (generous
space, one consistent card language, one CTA style) rather than decoration.

## Anti-references

- Generic AI-slop product-UI tells: gradient text as decoration, glassmorphism
  used everywhere instead of purposefully, identical card grids, tiny
  uppercase eyebrow labels on every section, cards nested inside cards.
- Rainbow/neon accent treatments — Aura's palette is cool-family only
  (blue → violet), explicitly not warm/orange, decided after direct user
  feedback rejecting lime/ash/red-orange mascot concepts.
- Cream/beige/warm-neutral surfaces — Aura is intentionally near-black.
- Punitive, guilt-driven screen-time apps (generic "digital wellbeing" scolding
  tone) — Aura's tone is closer to a coach than a parental control.

## Design Principles

- One consistent card language and one CTA style, reused everywhere rather
  than hand-rolled per screen.
- Hierarchy through space and type weight before reaching for color; the two
  reserved signal colors (blue for earn/unlock, red for warning/consequential)
  never become general-purpose accents.
- Real, working state before decorative polish — every screen this pass ships
  with real (if in-memory/stubbed) data flowing through one shared store, not
  static mockup content.
- Match a reference app's craft only after confirming *why* it works (spacing
  rhythm, hierarchy, restraint) — the batch-by-batch Opal/One Thing review
  exists specifically so screens are informed choices, not copies.
- Placeholder-but-honest: anything not built yet (mascot art, real Family
  Controls entitlements, category management screens) is a clearly-named
  swappable stand-in, never a silently faked interaction.

## Accessibility & Inclusion

Respect Reduce Motion everywhere motion is added (e.g. freeze rather than
strip color from the Apps screen's rotating ring). No stated WCAG target yet;
default to system dynamic type and standard contrast expectations until the
user specifies otherwise.
