# Cofounder device-review checklist

## Build 11 release — September 30, 17:16 Eastern

Signed archive and all six strict signatures passed. Uploaded internal-only, Apple processing Complete, compliance saved using previously confirmed unchanged declaration. App Store Connect status Testing; assigned only to Aura Internal Testing (Hayden Berio and Jesse Stone, two testers). No App Review submission. Evidence: docs/evidence/2026-09-30-focus-hours/build11-release.json. Includes Focus hours and Live Activity source repairs. Physical-device acceptance remains open.

IMPORTANT: revised verify-proof source is staged in the Supabase editor but NOT deployed. Automatic approval review rejected production deployment for lack of explicit approval for this update. User was asked asynchronously; no deployment approval received yet. Existing live photo rules remain unchanged.


## September 30 afternoon — Focus hours and prompt audit (not shipped)

Live Activity expiry follow-up: user photographed loading overlays at 0:00 while first-use Allow was pending. Widget used Date.now...endsAt, an invalid reversed range after expiry. It now uses stable clamped start/end anchors. Controller no longer equates expiry with stale data, adopts stale activities left by prior versions, and refuses to heal/request already-expired unpaused timers. Simulator compile passed (build_sim_2026-09-30T20-59-06-535Z_pid79203_2df2ff5f.log). Exact first-use permission/lock-screen reproduction remains physical-device acceptance; spinner causality is not proven solely by source inspection. No automatic background dismissal guarantee: local timer remains at zero until app resumes and ends it. No upload.

Prompt audit follow-up: model-only evidence rules now explicitly accept gym mirror selfies, Side Hustle money, walking/running shoes alone, a visibly smiling user, and physically drinking water. These six rules replace conversational UI hints in provider prompts; each alternative is sufficient without extra scene requirements. Proposed full prompt export refreshed. Four backend tests pass, including actual outgoing prompt checks for all six habits (stubbed provider; real photo verdicts untested). Still not deployed; no new build.

User supersedes Hours saved/day with Focus hours: whole lifetime hours from completed Healthy Habits timers and Deep Focus. Profile now uses the same native StrokedNumber as the other stats; removed the remote DeviceActivity report host that produced a rectangular background. Existing lifetimeFocusMinutes account snapshot and Supabase progress.stats.focusMinutes carry the combined total; timer completion increments before the existing progress sync. Previously unrecorded Healthy Habits durations cannot be reconstructed. Paused/canceled timers and quick proofs do not earn completed timer minutes.

Simulator build passed; screenshot profile-focus-hours.jpg verifies 0 and no card. Integration test combines 35 Deep Focus + 25 habit minutes, checks whole-hour thresholds, repeat refresh, quick proof exclusion and local account reload (1 passed). Backend tests: 3 passed with stubbed provider. Real camera verdict and live Supabase round-trip not exercised in this pass.

Deep Work failure cause: shared server prompt rejected all screen photos, contradicting its Screen, desk, or notebook hint. Proposed local prompt accepts relevant computer work screens, preserving physical-habit anti-spoof rules. Full 22 current and proposed prompts exported under docs/evidence/2026-09-30-focus-hours/. User requests prompt audit before another build: no new TestFlight build or backend deployment.


## September 30, 2026 build 9 follow-up — shipped as build 10

Build 9 is installed according to Hayden’s TestFlight screenshots and is not accepted.
The following repairs shipped in build 10. The signed archive and all six bundle signatures passed verification. Upload succeeded at 06:39 Eastern; Apple processing is Complete. After explicit user confirmation, the encryption declaration was saved and build 10 assigned only to Aura Internal Testing (Hayden Berio and Jesse Stone, two testers). App Store Connect now shows Testing. No App Review submission occurred. Physical-device acceptance remains incomplete. Archive and release evidence: docs/evidence/2026-09-30-build9-review/build10-archive.json.

- App labels now receive the full cell width independently of icon sizing; frozen/lane icon views use token identity rather than array position. Native token rendering remains device-only acceptance.
- App picker separates individual-app selection from explicit whole-category selection. Existing stored categories are preserved; device acceptance remains open.
- Profile best streak now replays all preserved history, not 90 days. Habits done uses the persisted lifetime healthy-habit counter. Hours saved/day now calculates a lifetime daily average against seven pre-Aura baseline days inside the report extension. Host always displays 0 while unavailable. Complete historical coverage and the returned request interval require device verification; missing history is not fabricated.
- Actual earn category palettes feed all success screens. Latest palettes: mint #08FCC7/#5EFDDB, exercise #4198FF/#84BCFF, focus #9986FF/#BDB0FF, pink #F36FAC/#F7A1C9. Passive Income CTA uses Apple Health setup pink #FF3B5C with white text (latest explicit correction); other CTA colors unchanged.
- Profile, all success screens and earn details use black status-bar content. Home/image-backed earn main/Emergency/Wall of Wins use white. These later corrections supersede earlier blanket-white instructions.
- Custom nav profile photos retain the default sticker’s actual outline and footprint.
- Focus controls: thicker purple ring, larger outlined white timer, pulsing endpoint, purple Pause, plain red End session. Tip/offline cards use transparent category-colored borders.
- Hold controls start/stop haptic rumble; shield primary button uses #2586FF. Physical haptics/shield verification remains open.
- Raw diamond, treasure chest, heart, skull and coin pouch now receive the approved white outline. The 22 approved habit choices remain unchanged and unique.
- Latest sheet corrections: smaller 54pt frozen icons, transparent app cards with category borders, transparent red minus controls, category-colored Add more apps buttons with white text. NSFW lock rebuilt from raw artwork with 30px/512 white outline. Forbidden row now shares updated PowerUpSkull; Forbidden fox shifted 2pt right. Leave Hard Mode shares End Session sticker at 136pt. Focus timer outline now matches the purple Pause button.
- Welcome frame is rendered dark graphite; Get started uses the shared blue button with white text. Success headlines, subtitles and timer footnotes now use white. Card stickers use 32pt visible height based on cached opaque bounds, including the highlight diamond. All four updated screens captured in *-white-headings-normalized.jpg.
- Welcome phone uses a native nighttime Home capture at the original dynamite pose, with screenshot-only mock values (64 streak, 320 coins, full progress). Temporary mock/capture code is removed after capture; no account data is seeded.

Verification: Latest Debug build passed (build_sim_2026-09-30T09-35-02-247Z_pid79203_2dadcf27.log); final signed Release archive succeeded. Twelve focused tests passed (6 lifetime average, 4 lifetime streak, 2 selection identity). Current visual evidence is *-white-headings-normalized.jpg in docs/evidence/2026-09-30-build9-review/. Older tinted-rays and yellow Passive Income screenshots are superseded. The obsolete -success debug route was removed. The latest device check reported Hayden’s iPhone connected (no DDI); physical Screen Time, camera and haptic acceptance remains open. Upload succeeded with a nonblocking missing Sentry.framework dSYM warning.


## September 29–30, 2026 release repair pass — prior build history

Hayden authorized implementation, verification, and one new TestFlight upload for
Hayden and Jesse only. This supersedes the dated build/upload holds below.
App Review submission is not authorized. Historical device passes remain intact;
they do not validate the current unshipped source. Baseline: `4c3160e`, 1.0 (7).
Current work is uncommitted; corrected build 8 uploaded successfully as TestFlight
Internal Only. App Store Connect shows **Testing**, assigned only to Aura Internal
Testing (Hayden and Jesse). Build 8 is installed on the physical phone and launches to Home. Portrait
Discord shield and handoff were exercised; broader device acceptance remains
pending, including a reproduced generic intervention-name issue. No App Review submission.

Root is the sole integrator/build/upload owner. Three visible Luna-medium tasks
returned bounded patches: account/verification (`01a0f011-7e35-7413-9ad7-2b2606a5f05a`),
Screen Time/intervention (`01a0f011-93e2-70b0-bb97-7b0af8f5cee7`), and
habits/camera/visuals (`01a0f011-a16d-7711-8fa7-b8dc7a03f0b0`). All lanes are frozen.

### Reopened after Hayden's build 8 screenshots (September 30, 00:23)

Build 8 is **not accepted**. Reopened: token icon sizing on every surface,
nav avatar footprint/outline, centered black app names, missing Hours Saved,
intervention app-name handoff, sticker picker, and adding apps/categories.
Local repairs are in progress and **not installed or physically verified**.
The final exact-22 build 9 archive succeeded and strict signature verification passed
for the app and five extensions, all version 1.0 (9). This supersedes earlier build 9
archives. The running Simulator picker exposes exactly the approved 22 choices,
including one toothbrush. Build 9 upload explicitly authorized and completed; Apple processing is Complete.
Build ID: 1320505a-10e4-4d87-b15f-a632391fea0c. User explicitly confirmed the
encryption declaration; saved successfully. TestFlight status is Testing, assigned
only to Aura Internal Testing (Hayden and Jesse, two testers).
Physical installation/verification remains pending.
The live build 8 picker opened and a category selection increased its count;
the probe was canceled. Saved categories/websites were absent from `iconSources`.
Mirroring subsequently locked; Xcode reports no connected device.

### Consolidated root causes, changes, and remaining acceptance

| # | Report | Evidence and current disposition |
|---|---|---|
| 1 | Every photo scan unavailable | Production route accepts the shipped app key; upstream Gemini returns `API_KEY_INVALID` (2026-09-30 02:15 UTC). Hayden replaced `GEMINI_API_KEY`; live recheck at 03:19:59 UTC returned HTTP 200 and correctly rejected a synthetic blank gray JPEG. Credential outage resolved; this is not real-photo acceptance. Hayden explicitly approved production deployment; tested safeguards are deployed and freshly reloaded source matches exactly. Live checks: unauthorized 401, malformed image 415, synthetic blank 200 with passed:false. Real-camera acceptance remains pending. Relevant, irrelevant, ambiguous and unavailable cases remain live acceptance requirements. |
| 2 | Habit stickers | Corrected 22-candidate Figma contact sheet uses transparent fills and the existing outline utility. Every Healthy Habits choice has a mapping. Approved by Hayden with an explicit no-duplicate-toothbrush constraint. Applied all 22 files in place; catalog remains 38 unique entries with exactly one `FoxHabitBrushTeeth`. The September 30 correction supersedes the partial 22-file treatment: the picker contains exactly the 22 approved habit stickers with stronger white contours. All generic/method/Settings/Apple Health choices are excluded; unrelated assets were restored. Physical picker acceptance remains open. |
| 3 | Healthy Habits blue accents | Creation, reward chips, mode selector, Create/Save button, avatar background and sticker selection use the existing Healthy Habits mint accent. Final simulator screens visually checked; approved artwork replaced in place. |
| 4 | Hours Saved decimal/unit/box | Report renders rounded integer hours without `h`, transparent background, and zero until 14 completed days exist. Removed overlapping host fallback in Release. DeviceActivityReport rendering requires phone acceptance. |
| 5 | Generic intervention app name | Added Shield Configuration extension to record localized application names by token in the shared app group; notification carries the token to the app. All intervention styles consume the resolved name. Physical build 8 shield displays Discord, but the subsequent text intervention used “this”; metadata handoff remains unresolved. Do not mark this fix passed. |
| 6 | Wrong selected app removed | Offset identity replaced with stable token/asset identity; token display order is deterministic; confirmation captures the selected item. Two mock-selection regression tests pass. Real-token first/middle/last removal pending. |
| 7 | Tiny native app icons | Native Label icon intrinsic size is measured and fitted into the requested footprint. Mock art is unchanged. Real-token rendering is device-only and remains unverified. |
| 8 | Exercise exit buttons too high | Added flexible space above bottom actions in the fixed-height exit sheet. Native screenshot acceptance pending. |
| 9 | Navigation avatar too large | Reduced avatar footprint and stroke to match the tab family. Photo-avatar device review pending. |
| 10 | Landscape generic Restricted shield | No Shield Configuration extension existed. New extension supplies Aura copy/colors/buttons, including a functioning Close action. Orientation remains system-owned. Signed distribution archive verified. Physical build 8 portrait shield shows Discord and Aura copy/buttons; landscape and Close-action acceptance remain pending. |
| 11 | Splash audio persists after notification | Splash teardown now invalidates its display link, stops audio and deactivates the session when removed. Cold notification launch audio test pending. |
| 12 | FaceTime Accept/Decline stuck | Computed random intervention style changed on view reevaluation while beat state persisted. Style is now captured once per presentation. Simulator Accept reaches challenge; Decline returns Home. Physical repeated-launch test pending. |
| 13 | Settings suppresses intervention | Root presenter targets the top controller, retains window identity across full-screen covers, and preserves the underlying screen. Warm notification over Settings and cold-launch acceptance pending. |
| 14 | Selected apps missing from Your Apps cards | Observable selection path reviewed; no physical reproduction yet. Stable identity/order and native icon changes may address presentation, but this item remains unresolved until actual selections are inspected on device. |
| 15 | Status bar contrast | Home chooses day/night scheme; Healthy Habits keeps white status text over dark cave art while the builder uses light native controls; intervention surfaces select dark. Home night and Healthy Habits simulator contrast checked. Other screens remain device acceptance. |
| 16 | UI disagrees with blocking / purchased timer | Shield refresh now coalesces concurrent requests and reapplies the latest plan instead of dropping changes. Purchase animation waits while intervention covers Home. Existing purchase persistence/activation regressions pass. Actual shield, foreground/background, timer and purchase flow still require device acceptance. |
| 17 | Sign-out lands on wrong screen | Signed-out stale onboarding/setup flags reset to Welcome. Account snapshot is committed before auth is invalidated. Real sign-out/sign-in acceptance pending without deleting user data. |
| 18 | Unwanted subscription intermediary | Removed holding/fallback page; gate presents Superwall directly. Dismissal refreshes entitlement before returning to onboarding; failures/skips exit safely. Real paywall purchase/dismissal acceptance pending. |
| 19 | Home fox freezes | Video reconciles playback on window/app/audio lifecycle; frame animation pauses/resumes with screen visibility and scene state. Runtime foreground/return motion capture pending. |
| 20 | Exercise pose glitches | Display overlay retains last pose for only 0.18 seconds on transient misses; rep engine consumes actual current detections. Two orientation/crop transform tests pass. Real movement, lighting, occlusion and reward accuracy remain unverified. |
| 21 | Avatar/streak/coin persistence | Failed remote reads no longer trigger destructive pushes; dirty avatar edits are generation-guarded and writes serialized; sign-out preserves committed account snapshot. Account round-trip regression passes. Jesse's reported loss is not proven recovered or fully diagnosed; no real accounts were reset or deleted. Cross-device acceptance pending. |

### Verification and release gates

- Final approved source and all 22 sticker replacements compile in Release:
  `build_sim_2026-09-30T03-04-16-782Z_pid79203_bdaaee53.log`, succeeded in 296.1s.
  This is an unsigned simulator build, not a signed device archive or upload.
- Signing update: generated and downloaded `Aura Shield Configuration App Store`
  through Xcode. Profile `9de05544-9eb8-4cc8-86e9-3efb8e575829` includes
  Family Controls, `group.Aura-App.Aura-iOS`, and the correct extension bundle ID;
  expires September 13, 2027. Release signing is now manual, matching the other
  targets. Build 8 archive succeeded; strict signature validation passed for the app and
  all five extensions. First upload rejected: Shield Configuration used `ManagedSettings` instead
  of `ManagedSettingsUI` in its extension-point identifier. Corrected against
  the installed Xcode template; replacement archive `Aura-1.0-8-corrected.xcarchive` succeeded, its embedded
  identifier and signatures were verified, and internal-only upload succeeded.
  App Store Connect build `002773b6-3d84-4286-b5e9-329136f5714e` is Testing in
  the verified two-tester internal group. Export compliance uses the established
  system-encryption classification. Non-blocking Sentry dSYM warning
  remains (UUID `129869DE-8B80-3F3E-AE94-2B24ECDAAC88`).
- Hayden replaced the Gemini secret; live endpoint recovered (HTTP 200, blank
  image rejected). Physical phone has installed TestFlight 1.0 (8); Home startup,
  existing avatar, selected Discord cards, and portrait shield were observed.
  `devicectl` still reports no connected devices; broader checks remain pending.

- Approved sticker assets compile in Debug: `build_sim_2026-09-30T03-01-14-043Z_pid79203_8f187df6.log`. Catalog check: 38 unique entries, one toothbrush. Asset hashes are in `evidence/2026-09-29-release/approved-sticker-assets.json`.

- Final Debug source compiles (`build_sim_2026-09-30T02-57-39-136Z_pid79203_b8c88c9f.log`).
  [Healthy Habits](evidence/2026-09-29-release/healthy-habit-mint.png) and
  [sticker picker](evidence/2026-09-29-release/sticker-picker-mint.png) were
  visually checked on that binary, including mint controls, white status text
  over cave artwork and a legible native off switch.
- A second Release build passed (`build_sim_2026-09-30T02-47-56-400Z_pid79203_7918442a.log`).
  It predates the final Create-button/toggle colors and cave/builder appearance
  adjustments, which are Debug-compiled above. Final Release archive validation
  remains required once release dependencies are resolved.
- Source hashes: [snapshot](evidence/2026-09-29-release/source-snapshot.json).
  Disposable completed test-product bundles were removed for disk space;
  result bundles, logs, simulator products and signed archives were retained.

- Debug integrated build passed. Latest selected suite: **48 passed, 0 failed**;
  StoreKitLocalTests excluded intentionally. Result bundle:
  `~/Library/Developer/XcodeBuildMCP/workspaces/Aura-iOS-4b8535092641/result-bundles/test_sim_2026-09-30T02-34-59-560Z_pid79203_220568df.xcresult`.
  These tests do not exercise production Gemini, actual Screen Time tokens,
  hardware camera, or App Store purchases.
- Release compilation passed, including the retained-window presenter adjustment.
  The tool response timed out at 300 seconds, but its completed log ends with
  `** BUILD SUCCEEDED **` (`build_sim_2026-09-30T02-36-40-120Z_pid79203_bf884dc1.log`).
  The Release app was installed and launched in Simulator; Welcome rendered
  successfully ([startup](evidence/2026-09-29-release/release-startup.png)).
  Local verification-handler tests: 2 passed; these stub providers.
  Development installation remains unavailable (no registered test devices);
  the new extension’s distribution profile is now present locally.
- Evidence: [sticker sheet](evidence/2026-09-29-release/aura-sticker-candidates-contact-sheet.png),
  [mapping](evidence/2026-09-29-release/aura-sticker-candidates-manifest.md),
  [FaceTime accepted](evidence/2026-09-29-release/mirror-accepted.png),
  [FaceTime declined to Home](evidence/2026-09-29-release/mirror-declined-home.png).
- Pending: real-photo live acceptance,
  remaining device checks and diagnosis of generic intervention app naming.
  Production verification safeguards are deployed; build 8 is installed. Apple processing and
  internal group assignment for Hayden/Jesse are complete.
  The corrected archive is uploaded; do not create another build unnecessarily.

---

Status: local implementation integrated across the three Luna lanes. Further
findings may be appended before the next build upload. Implementation and local
verification are authorized; uploads, production deployments and phone
installations remain on hold during cofounder review. Open checkboxes below mean
acceptance remains pending, not that their implementation has not started.
Preserve earlier device evidence and the existing local changes.

September 17 correction hold: after the authorized simulator rerun, Hayden
rejected the added post-setup name gate and the Earn fox's dark head outline.
Remove the gate; retain name collection in existing onboarding. Inspect both
silhouette edges on the actual light screen color and facial interiors before
accepting new media. **No further build, install or upload is authorized.**
D05 remains open; Gemini acceptance rules and real-photo testing remain deferred.

## Implementation and verification — September 16

- A01–A12: navigation feedback, Home pill visibility, rating art, Island inset,
  light timer sheet with bottom controls, production Stats placeholders, icon
  sizing, Emergency Unfreeze wording, drop edges, corner controls and store copy/
  balance styling are prepared. A08 already used the requested visible title.
- B01–B12: constrained win-detail image layout restores corner controls; profile
  stats, required valid name (last name optional), two-letter initials, tab photo,
  Settings/sign-in updates, chat composer/attachments and avatar picker are
  prepared. Existing analytics opt-outs remain unchanged.
- C01–C06: shorter AI consent, account-scoped Settings toggle with submission-time
  recheck, camera scrim alignment, notification inventory, help sheets and habit
  hint keyboard handling are prepared.
- Tests: 16 setup/reward/profile/account-isolation tests and 4 AI-consent tests
  passed. All 22 backend tests passed, including attachment validation. Debug and
  Release compiled; existing Swift concurrency warnings remain. Final picker and timer adjustments compile in Release; final source verification
  is recorded in the local evidence folder.
- Local layout evidence: [rating sheet](../../device-testing-evidence/2026-09-16/review-local/rating-after.jpg)
  and [Deep Focus help](../../device-testing-evidence/2026-09-16/review-local/deep-focus-help-after.jpg).
  These are iPhone 17 Simulator captures of local source, not physical acceptance
  or evidence for the installed TestFlight build. Most other changed layouts still
  need phone review; no new physical-device passes are claimed.
- Chat deployment dependency: apply the pending `20260915000000_support_delivery`
  migration before `20260916000000_support_files_audio`, then publish reviewed
  `support-send` and `crisp-events` together. Files support PDF/UTF-8 text; audio
  supports M4A/AAC/MP3/WAV, with a 10 MB cap and two-minute recorded voice notes.
  Images retain JPEG sanitization. Outbound video is not offered. Deployment and
  authorized end-to-end delivery/playback testing remain pending; unit tests do
  not prove the live service contract. No live support messages were sent.
- Physical retests: haptics; both focus header states and reward of 15 coins for
  15 minutes; keyboard visibility; real app token sizing; Dynamic Island; camera
  permission/scrim; full/limited photo library; notification delivery; avatar
  persistence; win close/delete confirmation and attachment round trips. Preserve
  the user's photos and existing device evidence.
- Local test limitation: the simulated Deep Focus session's ten-second hold could
  not be completed through the available semantic target (the exposed target was
  its caption). No device settings were changed; the local simulator session was
  left running. This does not change the earlier physical-device Hard Mode note.

## Owners

| Lane | Assigned agent | Model / effort | Scope |
| --- | --- | --- | --- |
| A — app shell and shared visuals | `device_execution` | Luna medium | Home, timers, Dynamic Island, app icons, Stats loading, store and shared visual primitives |
| B — profile, identity and chat | `fix_execution` | Luna medium | Profile, avatar, wins, authentication, chat and Settings composition |
| C — habits, permissions and reminders | `habits_implementation` | Luna medium (inventory previously Luna low) | Photo proof, habit creation, help sheets, consent state and notification inventory |
| Coordinator | Root | Astra low | Coverage, priorities, shared-file leases, design review, integration and one build/upload owner |

Assignments below identify implementation ownership; workers have returned their patches. C implementation uses
`habits_implementation` (Luna medium); the prior Luna-low inventory is complete.
Root owns HabitStore, backend attachment support, project settings and integration.
Do not treat this checklist as permission to upload the existing build 4.

Read-only assignment preparation completed for all three lanes. Starting points:
A: HomeView, RatingAskSheet, HabitSessionSheet, timer widget, Stats views, Apps
views and store views; B: WallOfWins, ProfileScreen, ProfileAvatarCircle,
CustomPhotoLibraryPicker, ProfileEditScreen, SetupScreens and SupportChatView;
C: PhotoProofCameraView, AddHabitFlowRoot, QuestExplainers, AppleHealthView and
NotificationService. Notification inventory must also cover Shield Monitor usage
events, not just routine reminders. Attachment work includes Supabase/Crisp
delivery and storage support. These are entry points, not permission to edit every
listed file; shared-file leases below still apply.

## A — app shell and shared visuals

- [ ] **A01 · Haptics throughout navigation.** Every tappable control opening a
  view, sheet, screen or equivalent destination gets a consistent haptic. Audit
  all entry points, including tabs, icons and cards; avoid duplicate firing.
  A owns the common pattern; B/C apply it within their own files.
- [ ] **A02 · Home focus header overlap.** During both a Focus Habit and Deep
  Focus, hide the Frozen Apps pill and let “Until focus session ends” plus its
  timer occupy that space without overlapping the Aura logo or fox. Restore the
  pill correctly when the session ends or is canceled.
- [ ] **A03 · Enjoying Aura sheet — visual review.** Review the apparently small
  fox and high placement of “Not really” / “Yes, I love it!” against DESIGN.md.
  Capture before/after; the user's spacing concern is tentative, not a prescribed
  pixel adjustment.
- [ ] **A04 · Dynamic Island clipping.** Move/inset the icon to the right so its
  left edge is intact; verify relevant compact/expanded timer presentations on
  the physical phone.
- [ ] **A05 · Home timer sheet.** Replace the incongruous black presentation with
  the existing DESIGN.md sheet system and correct the overly high buttons.
  Check the timer states/routes that open it.
- [ ] **A06 · Stats loading state.** Keep the screen-time, most-used-apps, pickups
  and bar-chart structure/labels visible while values load. Use deliberate
  placeholders instead of an empty white region; handle empty/error states too.
- [ ] **A07 · App icon sizing and frames.** Enlarge and correctly fit icons in
  Apps-screen ice frames, “Your apps” cards and Frozen Apps sheet ice frames.
  Match the card's white square and use the white outline seen in the Home frozen
  pill. Preserve the already-correct Stats icons; verify real device token icons,
  not only simulator placeholders.
- [ ] **A08 · Emergency copy.** Change the screen title “Emergency Pass” to
  “Emergency Unfreeze”; preserve its behavior.
- [ ] **A09 · Consistent button drop edges.** Normalize shared button geometry;
  specifically correct Passive Income's different drop edge. Coordinate C's
  screen usage rather than editing its files concurrently.
- [ ] **A10 · Corner controls.** Increase the visibly undersized circular/icon
  buttons at screen top-left/top-right using shared design tokens; verify visual
  size, hit area, safe-area clearance and alignment across screens.
- [ ] **A11 · Store balance style.** Give Screen Time store's coin and number the
  same treatment as Home's coin balance, slightly larger than the current store
  version. Confirm the intended Home reference during visual comparison.
- [ ] **A12 · Insufficient-coin copy.** In “How long we scrolling?” show
  “You have 0 coins” at zero; “You only have 1 coin” at one; and
  “You only have N coins” at two or more. Check singular/plural and affordability
  transitions without changing the one-coin-per-minute spending rule.

## B — profile, identity and chat

- [ ] **B01 · Wall of Wins detail exits — functional priority.** Restore the
  top-left X and top-right red delete/trash control. Verify dismiss/navigation and
  existing deletion confirmation; do not delete real user photos for testing.
- [ ] **B02 · Profile stats truncation.** Reduce/adapt the stats line sizing so
  all content fits, including long values and smaller supported screens.
- [ ] **B03 · Required display name and initials.** Ensure users reaching the
  app have a nonempty name, including existing/migrated or unnamed accounts.
  With no photo, show two letters: first two first-name letters or first/last
  initials. Eliminate “?”. Define and review single-character/blank-name recovery
  instead of inventing a person's name or using a misleading placeholder.
  September 17: use the existing onboarding name input and preserve its value;
  no added post-setup name screen. Existing unnamed-account recovery needs
  design review and must not introduce a new gate without Hayden’s approval.
- [ ] **B04 · Avatar in bottom navigation.** Once set, show the user's actual
  profile photo in the Profile tab with the white sticker outline used in Profile.
  Update immediately and preserve it on relaunch/account changes.
- [ ] **B05 · Settings privacy section.** Remove “Privacy — Choose what you share
  with Aura” as requested. Coordinate the separate AI photo-verification toggle
  in C02. Record existing analytics/permission behavior before removal; removing
  this UI must not silently opt existing users into data sharing.
- [ ] **B06 · Sign-in copy.** Remove the “and talk to the founders” wording from
  sign-in surfaces. Keep the existing sign-in prompt when an unauthenticated user
  enters chat. Implemented as removal of founder marketing copy from sign-in.
- [ ] **B07 · Consistent white sign-in design.** Inventory every sign-in entry
  point and make purple variants match the established white version, preserving
  Apple/Google/email behavior and account-state handling.
- [ ] **B08 · Chat composer shape.** Reduce the overly tall message field and
  make it a proper rounded pill; maintain usable multiline expansion.
- [ ] **B09 · Chat keyboard — functional priority.** Keep the plus button,
  composer and typed text visible when the keyboard opens; verify typing,
  multiline text, scrolling and keyboard dismissal on device.
- [ ] **B10 · Chat attachments.** Restore/add Files and Audio/voice notes beside
  Camera and Photos. First identify what exists versus is missing; cover record,
  preview, cancel, upload, send, playback/download, permissions and errors. Check
  backend/storage MIME limits and delivery compatibility; do not promise working
  attachments by adding menu entries alone. No live messages or backend deploys
  during this checklist pass.
- [ ] **B11 · Avatar library and layout.** Show the full library the user has
  authorized, offer system recovery/expanded access when permission is limited,
  and use four columns rather than three. Scrolling should move the selected
  avatar preview up to expose more photos; selecting one restores the default
  view. Replace the washed-out white crop scrim with a darker black scrim outside
  the focus circle. Verify selection/cropping and limited/full permission states.
- [ ] **B12 · Wall of Wins empty copy.** Set subtext below “No wins yet” to:
  “Complete a healthy habit with photo-verification and you'll see it here.”

## C — habits, permissions and reminders

- [ ] **C01 · AI verification first-open prompt.** Simplify “Allow AI photo
  verification” to a clear, short permission request on first camera entry.
  Remove excessive implementation detail; preserve explicit opt-in, a decline
  path, and access to the privacy policy.
- [ ] **C02 · AI verification Settings toggle.** Add a persistent on/off control
  outside the removed generic Privacy section. Turning it off must prevent AI
  photo submission; reopening, account changes and re-enabling must behave
  predictably. C owns consent behavior; B exclusively edits SettingsScreen.swift
  using C's agreed interface/copy.
- [ ] **C03 · Photo camera scrim alignment.** Align the dark rectangular scrim's
  opening with the already-correct camera brackets/viewfinder. Preserve bracket
  placement and verify safe areas/device aspect ratios.
- [x] **C04 · Routine notification review inventory.** Show Hayden/cofounder
  every possible notification for each earn method, including exact title/body,
  variables/examples, trigger/schedule and tap destination. Map reminder creation,
  edits, completion, disable/cancel, permission denial and daily reset. See
  [the exact notification inventory](ROUTINE_NOTIFICATION_REVIEW.md). Identify
  missing/incorrect cases before changing copy; provide a browsable inventory,
  not just a list of notification code files. Delivery still needs device proof.
- [ ] **C05 · Help-sheet family.** Put the fox illustration at the top and a
  subtitle under the title in all five sheets, using the existing Daily Exercises
  and Healthy Habits camera “How this works” sheets as the reference. Titles:
  “How Aura Coins Work”; “How Healthy Habits Work” (was “How Photo Proof Works”);
  “How Deep Focus Works” (was “How Lock In Works”); “How Passive Income Works”;
  “How Daily Exercises Work” (was “How Camera Reps Work”). Ensure each gets
  appropriate subtitle copy and consistent spacing.
- [ ] **C06 · Custom-habit photo hint keyboard — functional priority.** Keep the
  hint input and current typed text visible above the keyboard in “Create your
  own habit”; check scrolling, multiline entry and dismissal.

## Integration and completion rules

1. Start with B01/B09/C06, then A02 and the identity/consent/attachment functional
   work; group visual changes around shared components to avoid repeated edits.
2. Read AGENTS.md, ENGINEERING_PLAYBOOK.md and the relevant DESIGN.md sections.
   Inspect current dirty files; do not overwrite earlier fixes. Each worker owns
   only assigned files. Root leases shared HabitStore/RootTabView/design primitives
   before edits; B owns SettingsScreen, C supplies consent requirements.
3. A owns shared haptic/button/icon patterns. B/C consume them in their lanes.
   Root reviews identity, permissions, data sharing and attachment dependencies.
   Do not equate agreeing to terms/privacy with silently changing stored consent.
4. Reuse these three workers; no nested agents, repeated whole-repo audits or
   duplicate builds. Return IDs, changed files, screenshots/checks and blockers.
   Root maintains this checklist; do not copy it into AGENTS.md or create competing
   status documents. Promote only a reusable, evidenced lesson into coding rules.
5. Check off an item only after implementation and its required verification.
   Record build ID and physical-device evidence for haptics, camera, keyboard,
   Live Activities, Screen Time tokens, permissions and notifications. Simulator
   layout/build checks support the work; they do not replace phone acceptance.
6. Keep the existing one-coin-per-focus-minute correction. Build 4 is an unuploaded
   earlier snapshot, not the candidate containing this review batch. After review
   additions and integration, prepare one new identified candidate and affected
   retests; no upload until Hayden's review is finished and upload is authorized.

## Second review batch — September 16

Local implementation authorized under the existing review workflow. Root owns
reward/timer state and Home; Luna medium workers retain the ownership below.
Checkboxes remain open until their acceptance is verified. No upload/deploy.

- [ ] **D01 · Rewards must not unlock apps.** Root: earning/claiming only credits
  coins; “Until your apps lock” starts only after a deliberate Screen Time purchase.
- [ ] **D02 · Purchase copy.** B: use “Buy Screen Time” everywhere.
- [ ] **D03 · Hours Saved.** B + Root data contract: replace truncated “Screen Ti…”
  with Hours Saved and verify the real calculation; never substitute fabricated data.
- [ ] **D04 · Empty-state stickers.** A: inventory every empty state; replace fox
  illustrations with stickers and choose a suitable non-lock “All apps are open” sticker.
- [ ] **D05 · Animated habit art.** A (Luna medium): replace static PNG fox art on
  Healthy Habits, Daily Exercise, Deep Focus and Passive Income with the shared
  sequence specified below. Hayden reports the five source clips are on his
  computer; located all five MP4 originals in `/Users/haydenberio/Downloads`.
- [ ] **D06 · Outcome haptics.** A inventories success/failure states; Root coordinates
  success/error feedback at the actual result, once per outcome, including async errors.
- [ ] **D07 · Push-up skeleton.** C: correct body-line orientation, mirroring,
  aspect-fill crop and low-confidence joints; confirm on real moving bodies later.
- [ ] **D08 · Daily progress survives spending.** Root: progress/power-up thresholds
  use daily earnings; spending changes only available coins, not earned progress.
- [ ] **D09 · Sticker chooser.** A: remove coin/nonstickers, deduplicate imagery,
  normalize visible height, exclude obsolete unused art; plan category tabs/filters.
- [ ] **D10 · Splash fox shadow.** A: match Home's actual displayed contact shadow.
  Correction: previous implementation applied Home's full-frame ratios to Splash's
  smaller visible-body width, shrinking the oval too far; do not reuse that basis.
- [ ] **D11 · Frozen-app labels.** A: center names in the Frozen Apps sheet.
- [ ] **D12 · Power-up sticker replacement.** Deferred by Hayden; preserve current
  assets until replacements arrive, without blocking the progress logic fix.
- [ ] **D13 · Progress-track scrim.** Root: give the Home progress track a visible
  dark scrim underneath the fill.
- [ ] **D14 · Recent transactions clipping.** B: fix first card's top clearance.
- [ ] **D15 · End-session sticker.** A: copy/rename the Delete Account sticker and
  use a larger version on the end-session confirmation.
- [ ] **D16 · Subscription Plan cards.** B: separate Your plan and Account cards.
- [ ] **D17 · Photo-proof false positives.** C + Root integration: reject unrelated
  photos and black frames; audit mocks, fallback and production configuration.
  Failed/unavailable verification must not award a successful habit or coins.
  **Deferred by Hayden while D05 is implemented:** review the current permissive
  “being done or about to be done” rule and define
  adequate visible evidence per habit. Send the photo, habit name and proof hint;
  use Gemini's pretrained image understanding, not a custom training project.
  Test actual model decisions with known pass/fail/ambiguous photos, including
  water bottle versus instrument, black frames, screenshots and relevant evidence.
  Handler tests with stubbed responses do not validate model accuracy. A still
  photo cannot establish activity duration; do not claim that it does. Keep
  acceptance-policy changes distinct from error-path fixes and record any policy
  decisions needing product input. Exact failure path for Hayden's attempts is
  still unconfirmed; deployment and physical retests remain pending.
- [ ] **D18 · Timer exclusivity and correctness.** Root: one active earning session;
  reject overlapping/replacing habits, preserve pause/relaunch state and settle once.
- [ ] **D19 · Coin accounting.** Root: trace all credit/debit paths, prevent duplicate
  payouts, retain one coin per focus minute, test balance/progress/purchase separation.
- [ ] **D20 · Avatar crop responsiveness.** B: correct zoom/pan bounds and final
  crop coordinates; reduce unnecessary rendering and verify rapid selection changes.

### Second-batch implementation notes

Verification: final Debug build/run and Release compilation passed. All 28 targeted
iOS tests passed; 2 new actual-handler backend tests passed with local stubs and
no outbound requests. Prior 22 shared backend tests remain valid. Evidence and
source hashes: `../../device-testing-evidence/2026-09-16/review-batch2/`.
Local screenshots cover Home, sticker grid/filter, and Profile labels. Simulator
checks do not complete physical-device checkboxes. No upload, backend deployment,
phone install or live support message occurred. Existing concurrency warnings and
two camera-orientation API deprecation warnings remain.

- D01/D08/D18/D19: earning no longer calls unlock; daily progress and power-up
  eligibility use daily earnings; store and UI reject overlapping earning timers;
  photo/exercise claims are guarded against repeated callbacks. Existing balances
  were not reset or retroactively changed. Deep Focus remains one coin/minute;
  whether timed photo habits should share that rate is awaiting Hayden's reply.
- D03: Hours Saved is a weekly estimate rendered inside Apple's report extension:
  max(0, previous seven complete days minus latest seven complete days), in hours.
  Caption states the comparison; missing days show unavailable, not invented zero.
  This is not an all-time causal measurement. Requires physical Screen Time data.
- D07: Vision sees upright, unmirrored portrait buffers; overlay uses actual buffer
  dimensions, centered aspect-fill crop and one front-camera mirror. Low-confidence
  joints are excluded. Math tests pass; real push-up tracking remains unverified.
- D17: client outages and mock verifier reject; server kill switch returns 503;
  model verdict must contain a boolean; prompt rejects black/unrelated evidence.
  The updated `verify-proof` function still needs deployment. The installed phone
  and currently deployed backend do not yet contain this fix.
- D09: 38 active stickers, coin removed; unused Settings art excluded; duplicate
  bell images collapse to one. Decoded images and normalized alpha bounds were
  compared, not filenames alone. Visible-height geometry is measured once, not
  computed while scrolling. Tabs: All, Focus, Exercise, Wellness, Social, Creative,
  Home, More. The import script now preserves the curated list.
- D20: crop image uses explicit aspect-fill dimensions; pan bounds include the
  original image aspect ratio, zoom-out reclamps offsets, and export matches the
  preview circle. Full/limited library and large-image performance need phone QA.

Empty-state artwork selection is on hold for Hayden. Current unapproved swaps
and per-state options are tracked in `EMPTY_STATE_ART_OPTIONS.md`, including
text-only/blank states. Make selected stickers a little smaller (proposed 10–15%
visible height), after selection. No new replacements or size changes in this pass.

September 17 follow-up: Profile Hours Saved now uses `0` rather than a dash when
unavailable or zero (host and report extension). Earn/Coins and Photo Proof/Exercise
camera explainers no longer show the fox hero; titles, copy, steps and actions stay.
Apps Blocking's unrelated explainer retains its existing art. Debug build passed;
physical-device Screen Time report acceptance remains pending.

Outcome-haptic inventory:

| Outcome | Feedback owner |
| --- | --- |
| Photo accepted / rejected / unavailable | Shared Sunburst success / ProofFailureView error; duplicate camera success removed |
| Exercise and Deep Focus success | Shared Sunburst success; exercise finish/claim guarded once |
| Exercise finishes below reward threshold | ExerciseFlowRoot error |
| Streak and generic earn celebration | Shared StreakCelebrationView / EarnSuccessView success |
| Store checkout success / insufficient balance | Existing checkout success/error path |
| Apple, Google, email sign-in; password reset | SetupScreens success/error, auth cancellation excluded |
| Health connection result / collected reward | AppleHealthView result / shared celebration |
| Support send acknowledgement / failure / retry | Delivery-state transitions, not polling refresh |
| Subscription purchase/restore / paywall presentation failure | Gate result handlers; ambiguous legacy Bool cancellation stays silent |

D05 animation acceptance (all four screens; A implements, Root integrates):

- September 17 entry-line correction: reproduced a full-width seam at the clipped
  background band, not the video. MethodScreenBackground now subtracts the ellipse
  from one band path, eliminating the internal clip boundary. Debug build passed;
  four recorded simulator entries passed the seam detector (1,248 frames, zero
  candidates; before recording detects the reported seam). Fox assets unchanged.
  Evidence: `../../device-testing-evidence/2026-09-17/earn-entry-seam/`.
  Phone acceptance remains pending.

- Locate the five supplied originals: `Earn_Idle A`, `Earn_Idle B`, `Earn_Sneeze`,
  `Earn_Brush Shoulders`, and `Earn_Check Watch`. Preserve source files.
- Play this exact continuous loop: **Earn_Idle A → Earn_Sneeze → Earn_Idle B →
  Earn_Check Watch → Earn_Idle A → Earn_Brush Shoulders → Earn_Idle B → repeat**.
  The final “Earn idle B” in Hayden's sequence refers to `Earn_Idle B`.
- Remove the blue background to transparency using the existing
  `tools/chromakey.swift` approach; inspect fur/edge halos and preserve fox colors.
- Match the fox's visible size to the fox on the **streak screen**, accounting for
  transparent asset padding. Add the same shadow treatment beneath him as that
  screen; keep placement and scale stable between clips. This reference is
  separate from D10's Splash/Home shadow correction.
- Reuse shared transparent-frame playback across Healthy Habits, Daily Exercise,
  Deep Focus and Passive Income. Preserve clip timing and seamless transitions,
  respect Reduce Motion, pause offscreen, and avoid duplicate animation engines.
- Verify the full loop, all four layouts and shadow against the streak screen;
  inspect transparency on light/dark backgrounds and check physical-device
  memory, playback and scroll responsiveness. Record evidence before completion.

D12 power-up artwork remains deferred. D05 shares playback across the four actual
entry routes, with the streak shadow, Reduce Motion poster and offscreen pause.
September 17 correction: the first facial-alpha fix left a thin head outline and
was rejected after an authorized simulator run. The final local 780×780 export
adds a blue-contamination guard and a 1px alpha-boundary trim before normalization
(about 0.3pt on screen), without blurring interior colors. Across all 713 decoded
frames, 3,135,990 sampled interior dark source points remain alpha 255. Sequential
frames 30/142/332/546 were reviewed on light and dark backgrounds; the head outline
is absent in those samples. Poster and bundled video are updated together.
Current evidence: `../../device-testing-evidence/2026-09-17/edge-and-onboarding/`.
D10 matches Home's actual 132.6×35.36pt shadow. The post-setup name gate is removed;
B03 uses the existing onboarding field, consistent validation and a setup-scoped
name handoff through sign-in/resume without replacing valid target-account names.
**No app build, launch, install or upload after these latest corrections.** Older
build/simulator evidence predates them. D05/B03 remain unchecked pending runtime
acceptance; Gemini acceptance/photo testing stays deferred.

## Earlier findings retained separately

See `../../device-testing-checklist.md` for prior acceptance gaps, Settings legal
navigation, support migration/deployment compatibility, and the manual ten-second
hold needed to restore Hard Mode OFF after testing. This checklist adds the new
review requests; it does not erase or mark earlier blockers resolved.
