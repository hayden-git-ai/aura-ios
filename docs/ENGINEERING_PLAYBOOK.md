# Engineering Playbook

Purpose: the repeatable workflow for coding in Aura.

Read when: doing any code, build, integration, launch, or repository work.

Max active length: keep this file under 250 lines. Move historical lessons to
`docs/AGENT_REVIEW_LOG.md`.

## Standard Workflow

1. Frame the task.
   - What is the user asking for?
   - What is launch-critical?
   - What is out of scope?

2. Inspect.
   - Run `git status --short`.
   - Search with `rg`.
   - Read the smallest relevant file set.
   - For UI work, read `DESIGN.md`.

3. Patch.
   - Use a small direct edit.
   - Prefer existing patterns and helpers.
   - Do not rename, restyle, or refactor unrelated surfaces.

4. Verify.
   - Build after meaningful code changes.
   - Run targeted tests if available.
   - Screenshot UI changes when practical.
   - Mark device-only checks as device-only.

5. Handoff.
   - Changed files.
   - What passed.
   - What could not be verified.
   - Remaining risks.
   - Next step.

6. Improve the system.
   - If the task was slow, confusing, or error-prone, add a short lesson to
     `docs/AGENT_REVIEW_LOG.md`.

## Launch Mode Rules

Until App Store submission:

- Fix blockers first.
- Prefer shippable over perfect.
- Avoid v2 features.
- Avoid broad architecture work.
- Avoid redesigning stable screens.
- Keep onboarding, setup, paywall, profile, purchases, and device-only flows on a short leash.
- If an issue is not launch-blocking, put it in `docs/KNOWN_RISKS.md` or a post-launch list.

## UI Task Rules

For spacing, layout, copy, and visual polish:

- Name the exact screen.
- Name the exact problem.
- Keep the edit to that screen unless a shared component is clearly responsible.
- Do not change copy during spacing-only tasks.
- Do not change layout during copy-only tasks.
- Capture a screenshot after the patch.
- Stop after one focused patch if the screenshot matches the request.

## Build Rules

- Use XcodeBuildMCP for simulator build/run/screenshot when available.
- A simulator build passing does not verify device-only capabilities.
- Device-only items include Family Controls, Screen Time shielding, camera capture, pose tracking, App Store sandbox purchase behavior, and physical entitlement behavior.
- If tests do not run because no runnable test bundle exists, report that as a test configuration gap, not a code failure.

## Subagent Rules

Use subagents only when work can run in parallel without blocking the next local step.

Good subagent tasks:

- Review launch checklist for stale items.
- Audit one screen against `DESIGN.md`.
- Research one integration.
- Review one disjoint file area.

Bad subagent tasks:

- Immediate blocking bug fix.
- Broad repo rewrite.
- Anything requiring secrets.
- Anything that touches the same files as another agent.

## Stop Conditions

Stop and ask or report when:

- The requested change requires a destructive action.
- A secret or credential is needed.
- The task would require changing DNS, billing, production secrets, or App Store metadata.
- The agent cannot reproduce or verify a visual issue.
- The third patch attempt still misses the same simple UI request.

