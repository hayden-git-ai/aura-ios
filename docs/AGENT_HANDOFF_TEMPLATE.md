# Agent Handoff Template

Purpose: final report format for coding agents.

Read when: ending a coding task, pausing, or handing off to another agent.

Keep handoffs concise. Do not include full logs unless the user asks.

## Template

```
Task:
- One sentence.

Changed:
- File path: what changed.

Verified:
- Build:
- Tests/checks:
- Screenshots/UI:

Not verified:
- Device-only or blocked checks.

Risks:
- Remaining launch risks or regressions to watch.

Next:
- The next concrete step.

System lesson:
- Add one only if this task exposed a repeatable process problem.
```

## Rules

- Do not claim done without verification.
- Do not hide failed commands.
- Do not mention irrelevant files.
- Do not paste secrets or sensitive values.
- If no files changed, say so.

