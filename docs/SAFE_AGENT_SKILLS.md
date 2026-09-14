# Safe Agent Skills

Purpose: recommended skills, plugins, and permission posture for Aura coding agents.

Read when: installing skills/plugins, assigning agent roles, planning PR review,
or deciding whether a task needs a specialist agent.

## Recommended Launch Chain

`SwiftUI implementation -> simulator build/run -> screenshot design QA -> copy QA -> local review -> GitHub PR review -> launch/App Store QA -> TestFlight/App Store Connect`

## Skills To Use Now

### iOS Build And Debug

Use:
- `build-ios-apps:ios-debugger-agent`
- `build-ios-apps:swiftui-ui-patterns`
- `build-ios-apps:swiftui-view-refactor`

Why:
- Build, run, screenshot, inspect logs, and keep SwiftUI changes aligned with existing patterns.

Risk:
- Low.

Where it fits:
- Daily implementation loop.

### Design QA

Use:
- `product-design:audit`
- Product/design screenshot review against `DESIGN.md`

Why:
- Catches visual drift, spacing issues, copy hierarchy problems, accessibility misses, and generic AI-looking UI.

Risk:
- Low.

Where it fits:
- Before a UI task is called done.

### Performance And Memory

Use when symptoms justify it:
- `build-ios-apps:swiftui-performance-audit`
- `build-ios-apps:ios-ettrace-performance`
- `build-ios-apps:ios-memgraph-leaks`

Why:
- Good for jank, high CPU, memory growth, retain cycles, and camera/media flows.

Risk:
- Medium because these can consume time. Use near launch or when symptoms are visible.

Where it fits:
- Final QA or targeted diagnosis.

## Skills To Create Later

### `aura-copy-qa`

Purpose:
- Check product copy, onboarding copy, paywall copy, App Store metadata, empty states, button labels, and error messages.

Rules:
- Follow `DESIGN.md` copy rules.
- Flag robotic phrasing.
- Flag vague claims.
- Flag unsupported App Store or marketing claims.
- Keep copy concrete, short, and user-facing.

Risk:
- Low.

Where it fits:
- After design QA and before screenshots/App Store metadata.

### `aura-launch-qa`

Purpose:
- Run Aura's launch checklist as a structured App Store readiness gate.

Rules:
- Check crashes, build status, IAP, demo account, privacy policy, App Privacy answers, screenshots, metadata, support URL, Family Controls notes, and device-only risks.
- Never mark device-only work verified from simulator evidence.

Risk:
- Medium because it gates submission. It should be strict.

Where it fits:
- Release candidate review.

## GitHub Plugin Posture

Use GitHub integration when:
- Reviewing PRs.
- Reading issues.
- Checking CI status.
- Linking commits to launch tasks.

Default permissions:
- Read PRs, issues, commits, checks, and files.
- Ask before commenting.
- Ask before creating branches, commits, labels, issues, or workflow runs.
- Never merge without explicit human approval.
- Never change repo settings without explicit human approval.
- Never delete branches/tags/releases without explicit human approval.

Risk:
- Medium to high if write/admin scopes are granted too broadly.

Recommended start:
- Install GitHub plugin when PR workflow begins.
- Scope to the Aura repo.
- Start read-first.
- Add write/comment permissions only when needed.

## When Not To Use A Specialist

Do not use extra skills or subagents for:
- One-line copy changes.
- Tiny spacing nudges.
- Obvious compiler errors in one file.
- Simple docs updates.

Use `/fix-one` instead.

