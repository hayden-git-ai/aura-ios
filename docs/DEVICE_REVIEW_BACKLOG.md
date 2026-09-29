# Cofounder device-review checklist

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
