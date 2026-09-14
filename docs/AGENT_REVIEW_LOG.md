# Agent Review Log

Purpose: keep the coding system self-improving without bloating `AGENTS.md`.

Read when: a task was slow, confusing, wrong, noisy, or repeatedly missed.

Do not read this whole file by default. Agents should read the current lessons
section only unless they are doing a process audit.

## Current Lessons Agents Must Follow

- Before choosing an external review tool, verify that it accepts the existing project unchanged; a generated reconstruction cannot validate the release candidate.

- Before accepting command evidence, confirm completion and exit status. Blank output from a running/stalled command is not a clean tree or process clearance; use bounded content-hash checks when status stalls.

- For spacing-only changes, identify the exact view and constants, make one
  focused patch, build, screenshot, and stop if it matches.
- For visual work, do not rely on explanation. Capture screenshot evidence.
- For launch work, keep changes narrow and move non-blockers to known risks.
- Before declaring launch readiness, compile Release and inspect its startup path;
  a passing Debug suite can conceal initialization accidentally gated by DEBUG.
- If a handoff claims something is broken, verify against the current repo before
  treating it as true.
- Never let raw analytics firehoses into Slack. Use digest or threshold-based
  reporting only.
- Treat Astra low as the default orchestrator for meaningful work. Escalate model
  effort only when uncertainty, impact, or failed evidence justifies it.
- Use subagents for independent parallel work or independent review, not tiny
  edits or overlapping changes to the same file.
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
