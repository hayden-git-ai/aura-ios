# Empty-state artwork choices — awaiting Hayden

No replacements or size changes applied in this pass. Prior unapproved replacements
remain identifiable below, not accepted. Choose artwork before implementation.
Use stickers, not fox illustrations. Make chosen stickers a little smaller:
proposed 10–15% reduction in visible artwork height, accounting for transparent
padding; preserve text, spacing and touch targets. Do not use raw pixel dimensions
to compare perceived size. Apply only after artwork selection.

Preview: ../../device-testing-evidence/2026-09-17/empty-state-options/existing-sticker-options.png

Existing choices: A Phone, B Check badge, C Camera, D Journal, E Bell,
F Calendar, G Heart, H Chat bubble, I Clock, J Flame, K Flexed arm,
L Question mark. New concepts below are proposals, not existing assets.

## Dedicated empty-state artwork

| State | Current artwork | Options | Source |
|---|---|---|---|
| All apps are open | A Phone (unapproved replacement) | A Phone / B Check badge / new open-app grid | Features/Apps/AppsView.swift, emptyState |
| Nothing frozen yet | Same shared A Phone | A Phone / new app grid with plus / new ice cube with plus | Features/Apps/AppsView.swift, emptyState |
| No custom habits | E Bell (unapproved replacement) | D Journal / E Bell / G Heart | Features/AddHabit/AddHabitFlowRoot.swift, filtered habitList |
| Healthy Habits filter has no matches | Shares custom-habit state and copy | D Journal / L Question mark / new magnifying glass | Features/AddHabit/AddHabitFlowRoot.swift, habits.isEmpty |
| No wins yet (Stats and Wall of Wins sheet) | J Flame (unapproved replacement) | B Check badge / C Camera / J Flame | Features/Stats/WallOfWins.swift, WinsEmptyState; StatsView.swift |
| No purchases today (transaction history) | A Phone | I Clock / A Phone / D Journal | Features/Store/ScreentimeStoreView.swift, todaysPurchases.isEmpty |

## Text-only or currently blank content states

These options do not authorize adding art. Preserve the present lightweight
presentation unless Hayden selects an illustration for the state.

| State | Current behavior | Options if artwork is wanted | Source |
|---|---|---|---|
| No apps assigned to a rule | Rule Apps section hidden; lane summary says No apps yet | A Phone / new app grid with plus | Features/Apps/RuleSheet.swift; LaneCard.swift; Models/BlockConfig.swift |
| No photos available in library | Empty grid; authorization/limited-access path separate | C Camera / new photo stack | Features/Profile/CustomPhotoLibraryPicker.swift; SupportChatView.swift, photo grid |
| No albums | Text No albums yet | C Camera / new photo stack / new album folder | Features/Profile/SupportChatView.swift, collections.isEmpty |
| No Screen Time results/app usage | Report placeholders/empty chart, not a dedicated sticker panel | I Clock / F Calendar / new bar-chart sticker | Features/Stats/StatsView.swift; ScreenTimeStatsView.swift; AuraStatsReport |
| No Health activity | Inline No activity and Nothing to Collect | G Heart / K Flexed arm / F Calendar | Features/AddHabit/AppleHealthView.swift |
| Chat before conversation | Welcome message; no actual blank thread | H Chat bubble / new paper plane | Features/Profile/SupportChatView.swift |

## Status states kept separate from empty content

| State | Current behavior | Options only if requested |
|---|---|---|
| Zero coins/no affordable duration | Explanatory text and CTA in InterventionView | I Clock / new empty wallet |
| Camera unavailable/no body detected | Camera guidance/permission status in ExerciseCameraView | C Camera / K Flexed arm / new person-in-frame sticker |

Missing profile fields, initials, empty input fields, loading spinners, error/
verification outcomes and disabled Save with no routine weekdays are not content
empty states. No dedicated empty routines list or global search-results screen
exists in the current routes. Empty filtered Healthy Habits already uses the
shared custom-habit branch; do not create an extra screen.

## Asset mapping

A ScrollCardIcon; B ProfileStatHabits; C FoxPhotoProof; D FoxHabitJournal;
E FoxCreateRoutine; F AuraNavCalendar; G FavoriteHeart; H Profile_Chat Bubble;
I ProfileStatTimeSaved; J StreakFireIconLarge; K FoxCameraReps; L FoxSettingsHelp.
All twelve were visually inspected as stickers; Fox-prefixed filenames do not
necessarily depict a fox. Do not reuse Blocks_Empty State or feedback illustrations
as sticker options, and do not treat source-resolution variants as different art.
