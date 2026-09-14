# Aura Agent Rules

This is the short boot file for any coding agent working in this repo.

Read this every time. Then read only the task-specific docs listed below. Do not
load every markdown file by default.

## Routing

- Any coding task: read `docs/ENGINEERING_PLAYBOOK.md`.
- UI, copy, onboarding, paywall, setup, profile, or visual work: also read `DESIGN.md`.
- App Store, launch, signing, purchases, Family Controls, Screen Time, camera, or device testing: also read `docs/LAUNCH_CHECKLIST.md`.
- Known launch risk or ambiguous blocker: also read `docs/KNOWN_RISKS.md`.
- Installing skills/plugins or planning specialist agents: also read
  `docs/SAFE_AGENT_SKILLS.md` and `docs/SKILL_REGISTRY.md`.
- End-of-task handoff: use `docs/AGENT_HANDOFF_TEMPLATE.md`.
- After a mistake or slow task: update `docs/AGENT_REVIEW_LOG.md`.

## Non-Negotiables

1. Check `git status --short` before editing.
2. Never overwrite or revert unrelated user/agent changes.
3. Inspect the actual files before proposing or coding.
4. Keep launch work narrow. No broad refactors unless they remove a launch blocker.
5. For simple tasks, use one focused patch. Do not spawn subagents.
6. For visual tasks, capture before/after screenshots when practical.
7. Build after meaningful code changes.
8. Mark device-only checks clearly. Do not claim simulator proof for Family Controls, Screen Time shielding, camera capture, App Store sandbox purchases, or physical-device entitlements.
9. Never post, commit, or summarize raw secrets, API keys, private keys, recovery codes, bank details, or credentials.
10. If a task goes sideways, stop and write the failure pattern into `docs/AGENT_REVIEW_LOG.md`.

## Scope Contract

Before editing, state:

- Intended outcome
- Files likely to change
- Files explicitly out of scope
- Verification plan

Touching files outside the stated scope requires a brief reason in the handoff.

## Token Discipline

- Search first. Open only the files needed for the current task.
- Prefer `rg` and targeted file reads over whole-repo dumps.
- Read the latest source-bound lane summaries before older checklists; preserve valid evidence and rerun only checks affected by new changes.
- Do not paste large logs into the response. Summarize the relevant lines.
- Use small subagents only for independent side work.
- Use cheaper/faster models for small edits and checklists. Use stronger models for orchestration, launch-critical diagnosis, or cross-system decisions.
- Keep final handoffs compact.

## Definition Of Done

A task is done only when:

- The requested change is implemented or the blocker is clearly identified.
- The app builds, unless the task is docs-only or build is impossible.
- Visual changes have screenshot evidence when practical.
- Tests/checks run or the reason they could not run is stated.
- Remaining risks are listed.
- The handoff follows `docs/AGENT_HANDOFF_TEMPLATE.md`.
