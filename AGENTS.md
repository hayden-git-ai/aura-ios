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
- Coordinated physical-device acceptance: read `docs/DEVICE_EXECUTION_PLAN.md`
  and the workspace's `../device-testing-checklist.md`; preserve recorded passes.
- Cofounder review fixes: use `docs/DEVICE_REVIEW_BACKLOG.md` for item IDs,
  agent ownership and the current implementation/upload hold.

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

## Execution Ownership

- Astra low coordinates; Luna low handles bounded checks and mechanical work,
  Luna medium handles focused implementation. Escalate a concrete unresolved
  diagnosis to Astra; do not increase every worker's effort.
- Use at most three workers plus the coordinator. Give each a short task packet:
  outcome, owned files/resources, source/build ID, evidence, acceptance, stop rule.
- Reuse existing lane ownership across tasks. One writer per file, one operator
  per phone/browser session, one build owner. No nested delegation by default.
- Agents perform every supported physical-device interaction and verification.
  Hayden handles only specific inaccessible controls or physical actions. A
  simulator pass never completes a physical-device checkbox.
- During an unattended run, queue human-only or permission-blocked cases for
  Hayden's return and continue independent work; never label skipped cases passed.
- Preserve dirty changes. Bind evidence to installed build and tested source;
  pending local fixes are not present in an older TestFlight installation.
- The coordinator alone integrates status and shared-doc edits. Workers return
  changed files, evidence, blockers and affected retests, normally under 200 words.

## Bounded Improvement

- Propose at most one evidence-backed process lesson per completed task; skip
  routine success. Coordinator deduplicates and replaces an obsolete rule first.
- Keep this boot file at most 120 lines, the playbook under 250, and current
  review-log lessons at most 12 bullets. Archive history outside boot reads.
- Track elapsed time, repeated checks and correction loops in existing task
  evidence; record token usage only when available. Remove experiments that add
  overhead without improving the next comparable task. No recursive doc audits.

## Definition Of Done

A task is done only when:

- The requested change is implemented or the blocker is clearly identified.
- The app builds, unless the task is docs-only or build is impossible.
- Visual changes have screenshot evidence when practical.
- Tests/checks run or the reason they could not run is stated.
- Remaining risks are listed.
- The handoff follows `docs/AGENT_HANDOFF_TEMPLATE.md`.
