# Full physical-device acceptance — September 16, 2026

Status: execution authorized September 16 at approximately 13:30 Eastern;
target deadline 15:30 Eastern. User reports the newest build installed; device
operator must confirm its number. Luna device/fix/service workers dispatched.
Checkpoint: phone is build 3. Focus reward fix is packaged as local build 4;
TestFlight upload approval is pending. A transient Mirroring lock was cleared
with normal Resume; focus settlement and earned unlock/re-block were observed.
Full acceptance remains incomplete; the checklist records exact residual tests
and the manual ten-second hold needed to restore Hard Mode OFF after testing. Current evidence and exact resume steps are in the
workspace checklist; full device acceptance is incomplete.
This plan supersedes the older multi-day schedule and Sol assignments in
`../../device-testing-checklist.md`, not its recorded results or test coverage.

## Outcome and baseline

Complete the full physical-iPhone checklist within the requested two-hour window,
with agents doing every remotely operable action while Hayden is away. Queue
actions agents cannot perform for his return; never wait on him during the run.
Record the actual start and deadline when execution
begins; planning is not permission to silently extend an already-running deadline.
Every case ends as pass, reproduced failure, or explicitly blocked with an owner.
Blocked is not complete. Simulator results never count as device acceptance.

Latest evidence: workspace `device-testing-checklist.md` (September 15) records
TestFlight 1.0 (2) installed, launch confirmed, paywall/cancellation passes and
partial annual purchase/restore coverage. Setup picker, denial handling, viewport
and subscription transition have reported failures. Current dirty source already
contains proposed fixes; inspect and preserve them rather than reimplementing.
Build 2 does not establish that these local fixes are installed. The referenced
`launch-today` board was not found; do not reconstruct status from stale checklists.

## Owners and concurrency

Use existing task lanes as ownership boundaries; no new sidebar tasks are needed.
At most Astra plus three Luna workers run concurrently. These are planned roles,
not claims that existing tasks have had their model settings changed.

| Owner | Model / effort | Work and exclusive resources |
| --- | --- | --- |
| Coordinator / 00 | Astra low | Priorities, source freeze, file leases, integration review, shared docs, final acceptance; Astra medium only for consequential unresolved diagnosis |
| Device / 01 | Luna medium | Sole phone operator and build/install owner; execute every controllable checklist step, capture evidence, queue exact physical actions for Hayden |
| Fixes | Luna medium | Inspect existing setup/picker/denial/viewport/paywall fixes, run focused verification through 01, fix reproduced failures in assigned files; no broad redesign |
| Services / 02, 03, 04, 08 | Luna low for inventory, medium for fixes | Sequential bounded packets: purchase/restore states, backend/support/sync, website/privacy, reviewer access and App Store preparation; no simultaneous phone or shared-browser control |
| Hayden, after returning | Human | Only residual unavailable controls, biometrics/secure prompts, camera positioning/body movement and necessary physical actions; final design decisions |

Before resuming another task, read its latest handoff and assign a non-overlapping
scope. Keep duplicate older 01/04 tasks idle. Services hands purchase scenarios to
01 rather than opening a second device-control session. Workers do not spawn workers.

## Two-hour execution sequence

Time boxes allocate attention; none permits skipping checklist rows. Start delayed
expiry, reminder and focus cases early, and inspect results while running other cases.

| Elapsed | Physical-device work | Concurrent agent work |
| --- | --- | --- |
| 0–10 min | Confirm installed version/build, iPhone/iOS, usable controls versus video only, test accounts and available second device; reproduce setup blockers | Identify existing edits and their evidence; establish source/build identity and shortest already-valid signing/install route |
| 10–30 min | Verify fixed picker count/Save/persistence, denial/retry, full-width setup and subscription transition on corrected device build | Review existing patches, targeted checks, one serialized build/install; start any necessary Apple processing immediately |
| 30–60 min | Full Screen Time matrix: apps/categories/Safari, all blocking lists, changes, earned-time unlock, force-quit expiry, relaunch, Hard Mode, real usage, Live Activity | Prepare exact sandbox states and backend checks; diagnose failures without competing for phone control |
| 60–85 min | Complete outstanding annual/weekly purchase, restore, cancel/pending/failure, entitlement relaunch/expiry/renewal and applicable web-access checks; all auth paths and A→B→A isolation | Check entitlement evidence and reviewer access; fix only reproduced failures |
| 85–110 min | Every shipped exercise, photo proof valid/invalid/offline, permissions grant/deny/recovery, Health rewards, habits/balance, focus, widgets, reminders, sync, network, support and disposable-account deletion | Agents perform all accessible steps; queue physical/system dependencies without waiting for Hayden |
| 110–120 min | Fresh/update persistence where outstanding, small-screen/larger-text/keyboard/legal checks, affected retests and full checklist reconciliation | Deliver exact failures, remaining blocked cases and prioritized final design/code changes |

01 maintains a residual-action queue with exact steps and expected results for
Hayden's return. Every shipped exercise and every checklist row stays in scope;
physical reps and camera capture cannot pass without actual physical evidence.
Preserve valid build-2 passes where unaffected;
retest any behavior changed in a replacement build.

Autonomous operating rule: check connected phone access, controllable mirroring,
lock behavior and account availability immediately. Use supported controls only;
do not bypass locks, security prompts or permission boundaries. If control is
lost, attempt supported reconnection, then continue independent work and record
the device block. Do not impersonate physical exercise with prerecorded input.
Where an action still lacks required authorization, prepare it and continue other
work. Do not stop the entire run to ask an absent user. This is an active bounded
run; no recurring automation or additional sidebar task is needed.

At minute 10, report feasibility from actual device/control and build readiness.
If a corrected build is unavailable by minute 30, test independent accessible
paths on build 2 while 01 resolves installation; label its results accordingly.
Never repeat a known failed provisioning route without new evidence. A complete
pass cannot be guaranteed if Apple processing, device availability, midnight
rollover, sensor data or sandbox timing exceeds the window. Identify those cases
and the earliest real test opportunity; do not replace them with simulated proof.

## Remaining launch work alongside and after acceptance

- Backend: verify September 15 support delivery changes/migration separately from
  September 13 deployed support/delete functions; authenticated support/reply,
  attachment and deletion checks require their specific authorized test actions.
- Billing: remaining native sandbox states, existing web subscriber access,
  reviewer fresh-login entitlement, Apple/Superwall connection and subscription
  staging where latest evidence still shows gaps. Preserve RevenueCat authority
  and no-trial pricing; no duplicate grants or real charged test purchases.
- Website/privacy: verify actual current publication against prepared corrections
  before publishing anything again; preserve DNS and existing site ownership.
- Final UI: resolve observed defects, then Hayden's final design decisions;
  capture physical-device before/after evidence and rerun affected acceptance.
- Store: reconcile signed build/privacy/metadata/review notes, authentic Aura app
  and subscription-review screenshots, final build attachment and Rork review.
  Rork's reconstructed-copy review does not validate the actual release candidate.
  Design-held media waits for design approval. No App Store submission in this plan.
- Defer new features, broad cleanup/refactors, provider migration and unrelated
  infrastructure work. Existing authorizations remain valid; check only genuinely
  missing action-specific authorization, without reopening settled approvals.

## Worker packet and economical handoff

Send each worker this packet, filled from the assigned row:

```text
Goal: [one observable result]. Model: gpt-5.6-luna; effort: [low/medium].
Read: AGENTS.md, routed docs, exact current evidence and relevant source only.
Own: [files/resources]. Exclude: [other lanes, production writes not authorized].
Baseline: [source fingerprint, installed build, existing dirty changes].
Execute: [bounded steps]; physical-device proof required for device cases.
Acceptance: [expected outcomes, evidence path, affected retests].
Stop/escalate: resource collision, missing prerequisite, or two failed approaches.
Return: <=200 words; result, files, proof, blockers, next action, optional one lesson.
```

Use fresh narrow context, targeted searches, log tails and evidence links. One
build owner reuses build caches and batches compatible fixes; no duplicate builds,
whole-repo re-audits, or frequent unchanged polling. Strong-model review focuses
on auth, entitlement, shielding, signing and destructive changes. Maintain test
results in the existing checklist, not parallel status documents.

Workers propose lessons; coordinator alone edits shared rules. Replace duplicates
before adding, keep AGENTS.md <=120 lines, playbook <250 and current lessons <=12.
Review elapsed time, repeated checks and rework at the milestone; retain a rule
only if evidence shows benefit. Token counts are measured when available, never
invented. Process maintenance gets at most five minutes of this execution window.

Coordination reference: [OpenAI subagent guidance](https://learn.chatgpt.com/docs/agent-configuration/subagents).
Model assignments above use the callable models exposed in this session.
