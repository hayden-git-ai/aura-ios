# Aura Next-Chat Handoff

Date: 2026-09-13

Purpose: preserve the current app, launch, Slack, automation, and agent-system
state so a new Codex task can continue without rediscovery or accidental rollback.

## Current launch execution checkpoint

The approved launch plan is now executing with iPhone-only selected. Read the latest launch-today/00-status.md before interpreting historical findings below: the reviewed baseline passed Release simulator build,32ordinary tests(including8account-isolation tests), and independent review.01owns signing/platform/build,02subscriptions/revieweraccess,08backend deployment;03website and04ASC preparation follow as slotsfree. Remaining owner tasks are only minorUI/UX, device testing, Rorkscreenshots and RorkAIreview. Distinct mandatory live-action approvals remain required; never repeat completed audits or overwrite the dirty checkout.

## Start Here

Repository:

`/Users/haydenberio/Desktop/Aura iOS`

Xcode project:

`/Users/haydenberio/Desktop/Aura iOS/Aura iOS/Aura iOS.xcodeproj`

Primary scheme: `Aura iOS`

Read these before changing code:

1. `AGENTS.md`
2. `docs/AURA_PRODUCT_SOURCE_OF_TRUTH.md`
3. `docs/ENGINEERING_PLAYBOOK.md`
4. `docs/KNOWN_RISKS.md`
5. `docs/LAUNCH_CHECKLIST.md`
6. `docs/SKILL_REGISTRY.md`
7. The feature-specific spec for the task

Do not read every document into context by default. Load only the core rules and
the files relevant to the active task.

## Product Ownership and Fixed Decisions

- Hayden owns product development, product design, onboarding, paywall, and all
  customer-facing product decisions.
- Jesse owns marketing strategy, paid acquisition, creative operations, Web2Wave
  coordination, and the marketing teams.
- Aura does **not** offer free trials. Never add, imply, test, or advertise a free
  trial without a new explicit product decision from Hayden.
- Time-aware screens use the night background from 7:00 PM through 6:59 AM and
  the day background from 7:00 AM through 6:59 PM, using the device's local time.
- RevenueCat is the App Store billing and entitlement source of truth. Superwall
  presents and tests the paywall. Paddle/Web2Wave entitlement is checked through
  the separate web entitlement path.
- Do not change Namecheap or any DNS records unless Hayden explicitly requests a
  specific DNS change.
- Do not paste credentials, private keys, API tokens, recovery codes, or customer
  data into source, documentation, Slack, or chat.

## Current Working Tree

The repository is intentionally dirty. Do not revert or overwrite these changes.
They contain the latest launch fixes and coding-system documentation.

Modified product/project files at handoff:

- `Aura iOS/Aura iOS.xcodeproj/xcshareddata/xcschemes/Aura iOS.xcscheme`
- `Aura iOS/Aura iOS/Aura_iOSApp.swift`
- `Aura iOS/Aura iOS/Features/Onboarding/LaunchOnboarding/LaunchOnboardingFlowView.swift`
- `Aura iOS/Aura iOS/Features/Onboarding/OnboardingCompanion.swift`
- `Aura iOS/Aura iOS/Features/Setup/AppGate.swift`
- `Aura iOS/Aura iOS/Features/Setup/SetupScreens.swift`
- `Aura iOS/Aura iOS/Features/Subscription/SubscriptionGateView.swift`
- `Aura iOS/Aura iOS/Models/Onboarding/OnboardingEnums.swift`
- `Aura iOS/Aura iOS/Models/Onboarding/OnboardingStep.swift`
- `Aura iOS/Aura iOS/Models/Onboarding/SubscriptionCatalog.swift`
- `Aura iOS/Aura iOS/Services/EntitlementService.swift`
- `Aura iOS/Aura iOS/Store/HabitStore.swift`

New coding-system documents are also uncommitted, including `AGENTS.md`, the
engineering playbook, operator guide, known-risks file, handoff template, agent
review log, safe-skills document, and skill registry.

Do not commit until Hayden asks. Before any eventual commit, inspect the full
diff, rerun verification, and confirm no secrets or generated artifacts are
included.

## Most Recent App Work

Completed in the latest coding pass:

- Removed all user-facing free-trial promises and trial configuration from the
  active subscription/onboarding flow.
- Preserved annual and weekly paid plans with no trial.
- Added or corrected RevenueCat logout/reset handling.
- Added Superwall identify/reset handling for account changes.
- Improved paywall presentation telemetry so presentation is distinguished from
  an attempted registration.
- Corrected first-run routing and debug launch configuration.
- Refactored `AppGate` so launch side effects are outside the SwiftUI body.
- Applied the shared 7 AM/7 PM day/night rule to setup system chrome.
- Improved setup progress accessibility.
- Made typewriter copy resolve immediately when Reduce Motion or VoiceOver is
  enabled.
- Temporarily enabled Reduce Motion in Simulator, captured evidence, and restored
  the setting afterward.
- Repaired the shared Xcode scheme so both unit and UI test targets run.
- Corrected website-category shielding in `LiveScreenTimeService` and the shared
  re-shielding helper. Explicit Always Blocked websites now refresh in both modes.
  Safari category blocking, purchased-time lifting, and expiry re-shielding still
  require hardware verification.

## Current launch continuation

Coordination root: `/Users/haydenberio/Documents/Codex/2026-09-13/aura-next-chat-handoff-date-2026/outputs/launch-today`. Read shared-contract.md and launch-board.md for exclusive ownership, active workers and exact approvals. Control owns shared integration; 01 alone runs builds/devices. Maximum three workers.

Dirty candidate HEAD fe516f1 is not a frozen release. Worktree-versus-HEAD hashes prove uncommitted source; blank stalled status output was not evidence of a clean tree. No commits by Control.

Source patches pending current verification: prior subscription/startup fixes; 03 account-scoped photo consent and identifier minimization; 01 Release sample-statistics containment; 07 support cache/transport isolation with 00 HabitStore lifecycle hooks. Broader local profile/history/library/photo isolation is still a confirmed blocker, not fixed by support hooks.

No current-candidate build or test pass. 01 corrected misattributed pass claims: stopped attempts produced compilation progress only. Historical 23-test and Release welcome/sign-in evidence predates current changes. Native StoreKit has no passing runtime evidence. Early archive failed missing profiles; old simulator process, signing approval and physical-device access remain unresolved. Source changes invalidate relevant earlier verification.

Superwall app33253 Apple ID6809618566 and bundle Aura-App.Aura-iOS were approved, saved and reload-verified. Do not redo. Products remain no-trial annual69.99/weekly9.99; RevenueCat/app aura_pro is authoritative. pro mapping alone is not a reproduced gate failure; do not perform speculative mapping changes. ASC connection, published version and real purchase/restore/account/web acceptance remain open.

Website corrections are prepared locally for www.downloadaura.app, including a full live-to-proposed diff of older unpublished changes. Retention/copy review, Vercel contributor access and exact publication approval remain pending. Login does not authorize deployment.

Immediate shared blockers: isolate personal data across accounts without losing unsynced data; resolve analytics/replay consent/indication; remove unsupported launch testimonials; repair deletion HTTP error handling and truthful disclosures; verify camera lifecycle and actual support attachment policy. Real usage reporting and historical sample baseline provenance remain open after sample suppression.

Require reviewed lane handoffs/cleanup dispositions, frozen source fingerprint and build number, 05 review, 01 final relevant/full checks and signed archive validation. Upload needs exact action-time approval. Submission needs all shipping gates plus processed-build metadata and separate final approval. Do not guarantee same-day Apple approval.

Final App Store screenshots/Rork Studio remain held until Hayden explicitly confirms design readiness. Desired remaining categories (optional polish, physical-device testing, Rork screenshots, Rork review) are a target only; billing, privacy, signing, account and publication failures remain explicit gates.

## Slack Workspace State

Workspace: Aura, `aura-app.slack.com`

Operating principle:

- Slack is the business command center.
- Automated reporting channels receive automated top-level posts only.
- Discussion happens in threads.
- Decisions are summarized back into the parent message or the appropriate
  decision channel.
- Prefer concise digests, thresholds, and exceptions over raw event firehoses.

The authenticated Slack integration currently sees 45 active public/private
channels. Important operating channels include:

- High priority: `#agent-briefings`, `#app-errors`, `#general`, `#legal-updates`
- Company metrics: `#core-metrics`, `#financial-reports`, `#revenue-reports`
- Revenue: `#app-store-revenue`, `#app-store-revenue-risk`,
  `#web-funnel-revenue`, `#web-revenue-risk`, `#mercury-transactions`,
  `#upcoming-expenses`
- Growth: `#marketing`, `#meta-ads`, `#clippers`, private `#aura-web2wave`
- Product analysis: `#posthog-analytics`, `#posthog-inbox`,
  `#onboarding-analytics`, `#paywall-analytics`, `#app-review-status`
- User focus: `#support-messages`, `#booked-calls`, `#call-summaries`,
  `#app-reviews`, `#flagged-reviews`
- Product/design: `#product-design`, `#product-decisions`, `#design-audits`,
  `#design-md-audits`
- Development: `#development`, `#github-activity`, `#deployments`,
  `#release-notes`, `#coding-system`
- Agent/workspace operations: `#agent-ops`, `#automation-health`,
  `#slack-improvements`
- Security: `#security-key-rotation`, `#password-health-review`

Sidebar sections are personal to each Slack user. Hayden and Jesse may need to
place new channels into matching sections separately.

## New Meta Ads Agent Workflow

Created 2026-09-13 and confirmed Jesse is a member:

- `#marketing-agent-ops` — channel ID `C0C1E1N0EMC`
- `#meta-creative` — channel ID `C0C1FU5A0SW`
- `#meta-testing` — channel ID `C0C10JRGU31`
- `#marketing-decisions` — channel ID `C0C2AA8EY9E`
- Existing `#meta-ads` — channel ID `C0C0XEU0Y31`

Source-of-truth Canvas:

`https://aura-app.slack.com/docs/T0BQ58BLFGQ/F0C10JPG4SK`

Title: `Aura Meta Ads Agent Operating System — Jesse Handoff`

The Canvas contains:

- Jesse's paste-ready GPT Marketing Orchestrator prompt.
- Human ownership and non-negotiable approval boundaries.
- Performance, creative strategy, creative QA, funnel, and orchestration roles.
- Phase 0 through Phase 8 setup and operating workflow.
- Daily, weekly, and monthly automation plan.
- Alert, audit, creative-brief, test, and decision templates.
- Training steps, acceptance tests, and definition of fully operational.

Channel starter rules were posted in all four new channels. Jesse and Hayden are
members. Do not duplicate these channels or replace the Canvas with another doc.

## Meta Workflow Dependencies

Do not activate recommendation or mutation automations until these are complete:

1. Jesse connects the correct Meta Business account through an approved Meta
   Marketing API integration/MCP.
2. Web2Wave is connected separately. Meta and Web2Wave are distinct sources.
3. One controlled reporting period is reconciled for spend, purchases, and
   revenue.
4. Jesse approves target CAC, minimum contribution margin, target LTV:CAC,
   payback period, minimum evidence, fatigue threshold, anomaly threshold, and
   maximum spend deviation.
5. Agents complete a one-week shadow period where they report but humans perform
   all live ad-account actions.

Jesse remains the approver for campaign launches, pauses, deletions, audiences,
budgets, attribution, and creative publication. Hayden owns product-side funnel
changes. Agents may analyze, draft, QA, recommend, and report.

## Slack Automations: Previously Built or Published

Conversation history indicates these were built or published. The next task must
verify current Zap status and recent run history before relying on them:

- Cal.com booking alerts to `#booked-calls`.
- Mercury transaction webhook/enrichment to `#mercury-transactions`.
- Weekly financial reporting to `#financial-reports`.
- Daily revenue reporting to `#revenue-reports`.
- Web2Wave web-funnel revenue reporting to `#web-funnel-revenue`.
- Paddle live billing events to `#web-funnel-revenue`.
- Paddle/Web2Wave risk filtering to `#web-revenue-risk`.
- App Store/RevenueCat revenue-risk routing to `#app-store-revenue-risk`.
- App Store Connect review/build-status automation.
- Rich App Store review alerts to `#app-reviews`.
- Reviews under four stars routed to `#flagged-reviews`.
- Weekly growth/core-metrics digest, currently incomplete as a full scorecard.
- Expense reminders and security/password review schedules.

Do not claim any automation is healthy merely because it is published. Verify its
last successful run, source connection, destination, sample payload, error path,
and owner.

## Slack Automation Work Remaining

- Rebuild PostHog-to-Slack reporting as digests and threshold alerts. The prior
  raw-event destination flooded `#posthog-analytics` and was disabled.
- Cleaning the old PostHog bot spam remains on the to-do list; do not assume every
  message was deleted.
- Finish `#core-metrics` with real source-backed CAC, LTV, LTV:CAC, MRR, ARR,
  retention, and contribution/profit margin.
- Build Meta automations after Jesse completes the dependencies above:
  - daily exception digest to `#meta-ads`
  - weekly performance audit to `#meta-ads`
  - weekly creative report to `#meta-creative`
  - test decision reminders to `#meta-testing`
  - weekly executive brief to `#agent-briefings`
  - monthly system audit to `#marketing-agent-ops`
- Build onboarding and paywall analytics only after Hayden locks the revised
  onboarding/paywall and the event taxonomy is stable.
- Audit newer channels that currently lack Slack purposes/descriptions, including
  `#github-activity`, `#development`, `#coding-system`, `#meta-testing`,
  `#design-md-audits`, `#release-notes`, `#slack-improvements`, `#agent-ops`,
  `#deployments`, `#marketing-agent-ops`, `#design-audits`, `#meta-creative`,
  `#product-design`, `#product-decisions`, `#automation-health`, and
  `#marketing-decisions`.
- Audit important channel Canvases/bookmarks against current ownership and links.
- Keep `#posthog-inbox`; it is PostHog's automated system channel. Do not confuse
  it with human-readable `#posthog-analytics`.
- Keep `#clippers`; it is reserved for the future organic clipping team and Whop
  operations.

## Slack Safety Rules

- Never post secrets or full payment details.
- Do not create firehose destinations.
- Do not let agents autonomously alter ad spend or live campaigns.
- Do not let agents autonomously modify financial, legal, security, account, or
  production settings.
- Use explicit action-time approval before live mutations.
- Test every automation with a safe sample, verify the destination, then publish.
- Add an owner, failure destination, and periodic health check to each automation.

## Coding and Agent System

The new coding system is documented in the repo. The intended pattern is:

1. Hayden provides outcome, constraints, references, and acceptance criteria.
2. The orchestrator scopes the task and loads only relevant context.
3. Specialized agents research or implement bounded subtasks.
4. The implementing agent builds, tests, visually verifies, and reports honestly.
5. A reviewer checks regressions, risks, and missing verification.
6. Proven lessons update the smallest appropriate document.

Skills already smoke-tested include the iOS debugger, SwiftUI patterns, SwiftUI
view refactor, product design audit, Superwall review, Superwall read-only CLI,
WWDC research, OpenAI docs, and the skill installer. Consult
`docs/SKILL_REGISTRY.md` before claiming any other skill is installed or tested.

## Suggested First Prompt for the Next Codex Task

```
Continue Aura using docs/NEXT_CHAT_HANDOFF_2026-09-13.md as the handoff.
Read AGENTS.md, the handoff, KNOWN_RISKS.md, and only the feature-specific files
needed for the first task. Do not revert the dirty working tree or change live
dashboards without action-time approval.

First, confirm the current build/test baseline and summarize the three highest
priority App Store blockers. Then proceed with the first safe, code-local blocker.
Keep Slack work separate unless I explicitly direct you to the Slack backlog.
Aura never offers free trials, and its time-aware screens use night mode from
7 PM to 7 AM local time.
```

## Definition of a Safe Continuation

The next task should:

- Preserve all current user and Codex changes.
- Distinguish automated-test success from device/live-service verification.
- Treat the live Superwall audit as newer than stale checklist claims.
- Never resurrect free-trial copy.
- Keep Slack concise and decision-oriented.
- Report exactly what was changed, verified, not verified, and still blocked.
- Update this handoff only when a material fact changes; do not turn it into a
  running log.
