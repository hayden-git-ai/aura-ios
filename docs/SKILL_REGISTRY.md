# Aura Skill Registry

Purpose: prove which skills are installed, trusted, recognized, and tested.

Read when: installing, updating, assigning, or auditing agent skills. Do not
claim a skill is installed until its evidence checklist is complete.

## Status Definitions

- `Available`: Codex lists the skill in a fresh turn and its source is trusted.
- `Tested`: available and successfully invoked on a controlled Aura task.
- `Review pending`: source or permissions still need review.
- `Planned`: approved concept, but no skill has been installed.

## Installation Evidence Checklist

1. Record the exact source repository, path, and version or commit.
2. Read the complete `SKILL.md` and inspect every included script.
3. Check for credential access, external uploads, destructive commands, broad
   writes, hidden network calls, and instructions that conflict with `AGENTS.md`.
4. Install into the documented local path or through an approved plugin.
5. Start a fresh turn and confirm Codex lists the skill.
6. Invoke it on a small controlled task and record the result below.
7. Assign it only to the agents and task types that need it.

## Current Registry

| Skill | Source / installed path | Assigned use | Last verified | Smoke test | Status |
| --- | --- | --- | --- | --- | --- |
| `openai-docs` | Codex system skill: `~/.codex/skills/.system/openai-docs` | Current OpenAI and Codex guidance | 2026-09-12 | Model-selection guidance fetched from official OpenAI docs | Tested |
| `skill-installer` | Codex system skill: `~/.codex/skills/.system/skill-installer` | Curated or reviewed GitHub skill installation | 2026-09-12 | Installer workflow and destination verified | Tested |
| `build-ios-apps:ios-debugger-agent` | OpenAI curated `build-ios-apps` plugin `0.1.2` | Simulator build, run, screenshots, and runtime diagnosis | 2026-09-12 | Aura setup flow built and launched in Simulator | Tested |
| `build-ios-apps:swiftui-ui-patterns` | OpenAI curated `build-ios-apps` plugin `0.1.2` | SwiftUI screen and component implementation | 2026-09-12 | Setup status-bar, progress semantics, and motion accessibility fixes | Tested |
| `build-ios-apps:swiftui-view-refactor` | OpenAI curated `build-ios-apps` plugin `0.1.2` | Narrow SwiftUI structure and state cleanup | 2026-09-12 | AppGate launch configuration extracted from the view body | Tested |
| `product-design:audit` | OpenAI curated `product-design` plugin `0.1.55` | Screenshot-based UX, visual, and accessibility audits | 2026-09-12 | Setup welcome screen audit found status-bar, motion, and progress semantics risks | Tested |
| `superwall-review` | `~/.agents/skills/superwall-review` | Read-only Superwall launch-readiness audits | 2026-09-12 | Aura iOS integration, purchase bridge, identity, gating, and configuration audit | Tested |
| `superwall` | `~/.agents/skills/superwall` | Read-only dashboard inventory and App Store Connect readiness checks | 2026-09-12 | Live Aura project, product, entitlement, campaign, and paywall audit | Tested |
| Remaining `superwall-*` suite | `~/.agents/skills/superwall-*` | Dashboard writes, placements, paywall editing, migration, and implementation | 2026-09-12 | Pending controlled write or implementation test | Available |
| `wwdc` | `~/.agents/skills/wwdc` | Current Apple developer video and WWDC research | 2026-09-12 | Located and summarized Apple's current in-app purchase guidance | Tested |
| `aura-copy-qa` | Aura-owned skill; source not created yet | Product copy and launch-copy review | Not verified | Not run | Planned |
| `aura-launch-qa` | Aura-owned skill; source not created yet | App Store launch readiness audit | Not verified | Not run | Planned |
| Impeccable | Exact repository and path not approved yet | Potential visual quality workflow | Not verified | Not run | Review pending |
| Blade / humanizer-style skill | Exact repository and path not approved yet | Potential copy-quality workflow | Not verified | Not run | Review pending |

## Test Record Template

```
Date:
Skill:
Source version:
Test task:
Expected behavior:
Observed behavior:
Files or systems touched:
Result: pass / fail
Notes:
```

## Test Records

```
Date: 2026-09-12
Skill: product-design:audit
Source version: OpenAI curated product-design plugin 0.1.55
Test task: Combined UX and accessibility audit of the Aura setup welcome screen
Expected behavior: Capture and inspect fresh evidence, tie findings to that
evidence, identify accessibility limits, and avoid changing product code
Observed behavior: Fresh Simulator evidence was captured and inspected. The
audit identified low-contrast status-bar content, missing progress semantics,
and motion/announcement risks in the line-by-line typewriter treatment.
Files or systems touched: iOS Simulator; docs/SKILL_REGISTRY.md
Result: pass
Notes: Build succeeded. The screen's visual hierarchy, artwork, CTA placement,
and touch-target sizing appeared healthy. Full VoiceOver and Dynamic Type
behavior still require dedicated interaction tests.
```

```
Date: 2026-09-12
Skill: build-ios-apps:swiftui-ui-patterns
Source version: OpenAI curated build-ios-apps plugin 0.1.2
Test task: Correct three findings from the setup welcome-screen audit
Expected behavior: Reuse existing app patterns, keep the implementation narrow,
respect accessibility preferences, and verify the result in Simulator
Observed behavior: Setup system chrome now follows the shared 7am/7pm daylight
rule, the progress bar exposes its step and total, and typewriter copy becomes a
single stable message when Reduce Motion or VoiceOver is enabled.
Files or systems touched: Aura_iOSApp.swift, AppGate.swift, SetupScreens.swift,
OnboardingCompanion.swift, iOS Simulator, docs/SKILL_REGISTRY.md
Result: pass
Notes: Debug build succeeded. Night-mode contrast passed visual inspection.
The accessibility tree reported the complete message and "Step 1 of 6." With
Reduce Motion enabled, the complete message rendered immediately; the setting
was restored to off afterward.
```

```
Date: 2026-09-12
Skill: build-ios-apps:swiftui-view-refactor
Source version: OpenAI curated build-ios-apps plugin 0.1.2
Test task: Refactor AppGate launch configuration without changing routing
Expected behavior: Remove side effects from the SwiftUI body, retain local
Observation ownership, avoid a new view model, and preserve every debug route
Observed behavior: Flow callback setup and debug launch configuration moved to
named methods. The view body now reads as routing and presentation only.
Files or systems touched: AppGate.swift, iOS Simulator,
docs/SKILL_REGISTRY.md
Result: pass
Notes: Debug build succeeded. The -setup route rendered the expected setup
welcome screen, and the -plan route rendered the seeded custom-plan destination
with its expected Hayden sample content.
```

```
Date: 2026-09-12
Skill: superwall-review
Source version: Aura-installed skill; Superwall iOS SDK 4.16.3
Test task: Read-only launch-readiness audit of Aura's Superwall and RevenueCat flow
Expected behavior: Inspect configuration, purchase and restore handling, subscription
status, identity lifecycle, deep links, placement gating, products, analytics, and
dashboard readiness without changing product code
Observed behavior: The audit verified SDK initialization order, the RevenueCat
purchase controller, subscription-state mirroring, the launch paywall placement,
and PostHog purchase telemetry. It identified missing Superwall identify/reset,
RevenueCat logout handling, obsolete free-trial copy, and presentation telemetry
that recorded an attempt rather than confirmed presentation. Those code findings
were corrected immediately after the audit. The later live CLI audit verified the
dashboard products, entitlement, placement, campaign gating, and paywall. App Store
Connect linkage is currently absent.
Files or systems touched: iOS source read-only, Xcode Simulator build system,
docs/SKILL_REGISTRY.md
Result: pass
Notes: Debug build succeeded. The shared scheme was subsequently repaired to include
both test targets; the complete suite then passed 13 of 13 tests.
```

```
Date: 2026-09-12
Skill: wwdc
Source version: Aura-installed skill; public WWDC.ai and Apple session sources
Test task: Find current Apple guidance relevant to Aura's StoreKit subscription launch
Expected behavior: Locate a relevant session through the public index, return a
concise source-grounded summary, and link to Apple's original material without
touching the app or sending external feedback
Observed behavior: The skill found WWDC26 session 210, summarized current StoreKit
and App Store Connect subscription changes, and linked to the Apple Developer
session and related first-party documentation.
Files or systems touched: Public WWDC.ai index and session page;
docs/SKILL_REGISTRY.md
Result: pass
Notes: No product files or external accounts were changed. Aura's existing upfront
annual and weekly plans do not require the session's optional monthly commitment
features, and the local StoreKit configuration correctly contains no trial offer.
```

```
Date: 2026-09-12
Skill: superwall
Source version: Aura-installed skill; Superwall CLI authenticated to Aura
Test task: Read-only comparison of Aura's live Superwall dashboard with app code
Expected behavior: Verify the SDK key, products, trial configuration, entitlement,
placement, campaign, feature gating, paywall, and App Store Connect readiness
Observed behavior: The SDK key and `paywall` placement match the app. The active,
gated campaign routes 100% of eligible users to the paywall. Annual ($69.99) and
weekly ($9.99) products are attached to the `pro` entitlement with zero trial days.
The Superwall application still has no bundle ID or App Store Connect key and is
reported as not integrated.
Files or systems touched: Superwall read-only API; Aura source read-only;
docs/SKILL_REGISTRY.md
Result: pass
Notes: No dashboard values were changed. App Store Connect linking and an on-device
paywall presentation remain launch-readiness work, not failures of the skill.
```

## Update Rules

- Pin external skills to a reviewed version or commit when possible.
- Re-review source changes before updating a skill.
- Never place secrets, tokens, private keys, or credentials in this registry.
- Downgrade a skill to `Review pending` if its source, permissions, or behavior
  changes unexpectedly.
- Remove an agent assignment when the skill is not needed for that role.
