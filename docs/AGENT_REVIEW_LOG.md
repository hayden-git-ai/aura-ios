# Agent Review Log

Purpose: keep the coding system self-improving without bloating `AGENTS.md`.

Read when: a task was slow, confusing, wrong, noisy, or repeatedly missed.

Do not read this whole file by default. Agents should read the current lessons
section only unless they are doing a process audit.

## Current Lessons Agents Must Follow

- Device-test packets must explicitly include reversible in-app state changes
  (selection, focus timers, earned-time spending); inspecting screens alone does
  not test behavior. Verify unfamiliar controls against source before declaring
  an authorization block (Aura Bank spends virtual coins). Preflight the exit
  control before changing modes; unsupported long holds can prevent restoration.
  Preserve original settings and record reward/balance changes.

- Before choosing an external review tool, verify that it accepts the existing project unchanged; a generated reconstruction cannot validate the release candidate.

- Before accepting command evidence, confirm completion and exit status. Blank output from a running/stalled command is not a clean tree or process clearance; use bounded content-hash checks when status stalls.

- For spacing-only changes, identify the exact view and constants, make one
  focused patch, build, screenshot, and stop if it matches. For visual concept
  selections, bind the actual user-confirmed image before coding; a later attached
  screenshot supersedes ambiguous option numbers. Embed the actual images in the user-facing final answer with names and source context; tool-only image output or numbered file links do not establish that the user saw the design. Compare against the image the user actually reviewed.
  Verify generated asset content and ordering visually, not by filenames or alpha-channel presence. Never substitute procedural artwork for approved reusable art without matching the reference; reuse existing app components first. Inspect the final native render for clipping, hierarchy, disabled states, and motion before accepting a worker's visual pass. For purchase handoffs, inspect first-visible destination frames and the count-up/countdown boundary: prepare layout and mascot before revealing Home, and use a live wall clock in isolated previews so a frozen fixture cannot hide timer discontinuities.
  For motif swaps in an approved raster card, extract the user-approved silhouette directly, lock measured centers/scale/rotation, and verify the finished asset inside the native card before presenting it. Do not redraw a simple motif or judge it only on a standalone canvas.
  When extending an illustrated control family, create the requested glyph as a dedicated asset with the family's existing body and engraving treatment. Never disguise an unrelated control by layering a sticker over its original glyph.
  Palette edits must preserve the approved gradient and hill contrast; do not
  replace translucent shading with opaque color blocks.
  When the user rejects both cards and background, redesign their composition
  together. Recoloring generic cards over a gradient does not address an
  environmental-art brief. Use the current approved screen imagery as the
  visual source, and show references before spending another generation cycle.
  Hayden's Pinterest-first requirement also applies to small control mockups:
  inspect and show relevant source images before ImageGen, even when an existing
  app screenshot is available. A brief approval does not waive this workflow.
- Preserve existing user flows: fix name persistence at the onboarding field,
  not by adding an unsolicited completion gate. Review visual evidence on the
  actual screen background and entry transition before claiming a visual fix.
- For launch work, keep changes narrow and move non-blockers to known risks.
- Before declaring launch readiness, compile Release and inspect its startup path;
  a passing Debug suite can conceal initialization accidentally gated by DEBUG.
- Verify worker handoffs against each acceptance ID and current production paths;
  compare actual displayed geometry using the same sizing basis. For keyed art,
  compare source/encoded eyes, nose and mouth alpha AND silhouette edges on
  light/dark screen colors;
  nonempty frames and clean silhouettes do not prove preserved facial detail.
  Sandbox codec failures do not prove host incompatibility. DEBUG-only fixes do not ship.
  Require an integrated build after parser checks, then verify the visible result.
- Never let raw analytics firehoses into Slack. Use digest or threshold-based
  reporting only.
- Treat Astra low as the default orchestrator for meaningful work. Escalate model
  effort only when uncertainty, impact, or failed evidence justifies it.
- Use subagents for independent parallel work or independent review, not tiny
  edits or overlapping changes to the same file. When the user assigns the root
  agent to planning and coordination, dispatch bounded research/implementation
  lanes before doing their work locally; keep the root on synthesis and review.
- Never claim a skill is installed or usable without the evidence required by
  `docs/SKILL_REGISTRY.md`.

## Weekly Operator And System Review

Review the previous week's completed tasks and record only actionable findings:

- model and effort used versus task difficulty;
- subagents used and whether they reduced elapsed time or correction loops;
- skills invoked and whether their registry evidence was current;
- number and cause of avoidable correction loops;
- verification missed, repeated unnecessarily, or performed at the wrong level;
- one prompt habit and one system rule to test during the next week.

Promote a lesson into `Current Lessons Agents Must Follow` only after it is
repeated, high impact, or clearly prevents a launch risk.

## New Lesson Template

```
Date:
Task:
What went wrong:
Root cause:
New rule:
Where added:
```

## Archived Retros

Add older lessons below this line during monthly coding-system review.

### 2026-09-13 — Monaco editor replacement
- Failure: generic editor fill appended old source during an approved backend deployment.
- Correction: select-all/paste, verify the complete exposed editor text before publishing, then compare freshly reloaded published bytes with the reviewed bundle. Both final functions matched and rejected unauthenticated requests.
- Apply this narrowly to dashboard code editors; do not infer replacement from a success toast. No new global approval rule or repeated full audit is needed.

### 2026-09-19 — Earn card export bounds
- Failure: SVGs without explicit intrinsic dimensions rasterized at an unexpected size, causing cropped borders and transparent padding in the native grid.
- Correction: set explicit SVG width/height before rasterizing, verify alpha bounds span the intended export, then inspect the installed grid after startup and animation complete.
