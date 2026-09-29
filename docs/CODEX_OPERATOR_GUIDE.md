# Codex Operator Guide

Purpose: help Hayden get faster, cleaner results from Codex and future agents.

Read when: starting a new coding task, giving feedback, or deciding whether to
start a fresh chat.

## Default Operating Mode

For meaningful Aura work, start with **Astra low** as the orchestrator. State the
outcome, boundaries, and proof you need. The orchestrator should decide whether
to work directly or delegate independent pieces to specialist subagents.

You do not need to choose every subagent yourself. Ask the orchestrator to:

- use the lowest-cost model and effort that can reliably complete each subtask;
- avoid subagents for tiny edits;
- parallelize independent research, audits, or file areas;
- keep one agent responsible for integration and final verification;
- report which models, efforts, subagents, and skills were actually used.

Add this line when you want explicit orchestration:

```
Act as the orchestrator. Choose the smallest capable model and effort for each
part, delegate only independent work, integrate the result, and report the
models, agents, skills, and verification used.
```

## Model And Effort Ladder

Use this as a starting policy, then improve it from measured results.

| Work | Recommended starting point |
| --- | --- |
| Tiny copy, spacing, naming, or one-file mechanical edit | Luna low; coordinator directly when delegation adds overhead |
| Normal feature implementation or focused bug fix | Luna medium |
| Cross-file implementation or independent code review | Luna medium with bounded scope; Astra medium for unresolved risk |
| Orchestration | Astra low |
| Launch-critical diagnosis, security, purchases, signing, or conflicting requirements | Luna gathers evidence; Astra medium reviews consequential decisions |
| Exceptional unresolved problem after evidence-based attempts | Astra xhigh; use max or ultra only with a stated reason |
| Fast repository search, inventory, or mechanical comparison | Luna low |

Reasoning effort should follow uncertainty and consequences:

- `low`: clear task, narrow scope, easy verification.
- `medium`: several steps, some ambiguity, or integration judgment.
- `high`: difficult diagnosis, broad interactions, or costly mistakes.
- `xhigh` and above: rare escalation after lower effort produced evidence but
  did not resolve a genuinely hard problem.

Do not escalate merely because a task is taking time. First check whether the
scope, acceptance criteria, or source information is unclear.

## When To Use Subagents

Use subagents when at least one is true:

- two or more independent investigations can run in parallel;
- implementation and an independent review would materially improve safety;
- the task spans distinct specialties such as UI, purchases, backend, and QA;
- research can proceed without editing the same files as implementation.

Keep work with the orchestrator when:

- the change is tiny or confined to one obvious location;
- agents would need to edit the same file;
- delegation overhead is larger than the task;
- a single screenshot or build provides the answer.

The orchestrator owns the final diff, resolves conflicts, runs verification, and
produces the handoff. Subagent output is evidence, not automatically accepted.

For the current full physical-device pass, use `DEVICE_EXECUTION_PLAN.md`.
Agents execute all supported on-device actions; Hayden only supplies physical
actions or unavailable controls. Keep a single device operator and build owner,
and at most three concurrent workers. Follow AGENTS.md's documentation budgets.

## The Best Prompt Shape

Use this structure:

```
Goal:
Scope:
Do not change:
Reference:
Verification:
Stop when:
```

Example:

```
Goal: Fix the setup welcome screen spacing.
Scope: SetupScreens.swift only unless a shared component is clearly responsible.
Do not change: copy, button style, background, or fox art.
Reference: Follow DESIGN.md.
Verification: Build, launch with -setup -subscribed, screenshot.
Stop when: fox/text/button spacing matches the screenshot feedback.
```

## Feedback Shape

Use this when something is visually off:

```
Screen:
Problem:
Desired change:
Do not change:
Verification:
```

Example:

```
Screen: setup welcome
Problem: fox is about 20px too low
Desired change: move fox up, keep text and button in place
Do not change: copy, background, button style
Verification: screenshot after build
```

## Useful Slash Commands

These are prompt conventions for you and agents.

- `/plan`: stop and plan before edits.
- `/fix-one`: make one focused patch only.
- `/shipcheck`: check launch blockers and device-only risks.
- `/design-audit`: audit a screen against `DESIGN.md`.
- `/screenshot`: build/run and show visual proof.
- `/handoff`: summarize changed files, verification, risks, and next step.
- `/retro`: add a process lesson to `docs/AGENT_REVIEW_LOG.md`.
- `/orchestrate`: choose models, effort, subagents, and skills for the task.
- `/model-check`: explain whether the current model and effort fit the task.
- `/skills`: list the skills needed, prove they are available, and record any test.
- `/scope`: restate what files may change and what must not change.
- `/stop`: pause and report current state.

## Installing And Using Skills

Never accept “installed” without evidence. Ask:

```
/skills Audit this skill's exact source and scripts, install it, verify the files,
confirm it appears in a fresh turn, run a controlled smoke test, and update
docs/SKILL_REGISTRY.md. Do not call it installed unless every check passes.
```

For normal work, name a skill only when you know the exact one you want. You can
also ask the orchestrator to select from skills already marked `Available` or
`Tested` in `docs/SKILL_REGISTRY.md`.

Skills guide behavior; they do not replace verification. An agent must still
inspect the repo, respect scope, build when appropriate, and provide evidence.

## Context Management

Start a fresh chat when:

- The workstream changes.
- The chat gets long and starts mixing old decisions with new ones.
- A milestone is complete.
- A model starts repeating stale assumptions.
- You want a clean launch pass.

Good launch chat split:

- Onboarding launch pass.
- Setup/paywall pass.
- App Store checklist pass.
- Device testing pass.
- Backend/integrations pass only if needed.

## How To Save Tokens

- Ask for one focused task at a time.
- Give the exact screen/file when you know it.
- Say what not to change.
- Ask for screenshots instead of long explanations for visual work.
- Use `/fix-one` for tiny changes.
- Use `/plan` before broad work.
- Start a new chat after a milestone.
- Default to Astra low orchestration instead of manually assigning a powerful
  model to every subtask.
- Escalate effort only when uncertainty, impact, or failed evidence justifies it.

## What To Avoid

- "Make it better."
- "Fix everything."
- Combining design, backend, launch, and analytics in one prompt.
- Giving new feedback before the prior patch is verified.
- Asking multiple agents to edit the same file at the same time.

## The Golden Rule

A good prompt narrows the job. A good handoff proves the job.

## Your Improvement Review

During the weekly operator review, answer:

- Did I state the outcome, scope, exclusions, and verification clearly?
- Was the chosen model and reasoning effort proportional to the task?
- Did subagents save time or improve quality, or only add coordination?
- Were any skills claimed without registry evidence or a smoke test?
- How many correction loops were caused by an unclear prompt versus execution?
- Did we collect proof before declaring completion?
- What one operator habit should change next week?

Record only the resulting rule or measurable experiment. Do not turn this guide
into a diary.
