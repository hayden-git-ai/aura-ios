# Aura notification inventory

Code review snapshot: 2026-09-16. This inventory records notification requests
currently created by the app and Device Activity monitor before copy changes.
There is no live reminder or device change in this review.

## Daily habit nudges

Source: `Services/NotificationService.swift`, `ReminderScheduler`.

| ID | Title | Body | Trigger | Example | Tap destination |
| --- | --- | --- | --- | --- | --- |
| `aura.reminder.habit.8am` | Earn your scroll today! | Your apps are locked. Complete quests to earn them back. | Repeating calendar trigger at 8:00 AM when reminders and authorization are on. | Every day at 8:00 AM | Default app launch; no response handler or deep link. |
| `aura.reminder.habit.2pm` | It's 2pm | And you've done zero quests. Not judging. Okay, a little. | Repeating calendar trigger at 2:00 PM, added only when no quest is done at reschedule time. | A day with `questsDoneToday == false` | Default app launch; no explicit destination. |
| `aura.reminder.habit.8pm` | C'mon, don't do this | One quest keeps the streak alive. You've still got a few hours. | Repeating calendar trigger at 8:00 PM, with the same no-quest gate. | A day with `questsDoneToday == false` | Default app launch; no explicit destination. |

The scheduler removes all three IDs before each rewrite. Turning reminders off
removes them. Completing a quest reschedules and removes the 2 PM and 8 PM nags
for that day. Permission denial prevents adding requests; the store turns its
toggles off after observing revoked access. The next daily reschedule can arm
them again after the progress reset.

## Earn-method coverage

The four earn methods do not have separate completion notifications in the
current code. A routine can be attached to a habit from any method, so its
notification uses the same title and body regardless of method.

| Earn method | Routine notification example | Method-specific notification currently present | Completion or tap destination |
| --- | --- | --- | --- |
| Healthy Habits / Photo Proof | **Read**: “You said now. I'm holding you to it.” at Monday 8:00 AM | None. Photo capture, AI verification pass/fail, and Wall of Wins save do not post a notification. | No method route; a tap opens Aura's default launch surface. |
| Daily Exercises / Camera Reps | **Morning push-ups**: “You said now. I'm holding you to it.” at weekdays 7:30 AM | None. Exercise target completion does not post a notification. | No method route; a tap opens Aura's default launch surface. |
| Deep Focus / Lock In | **Focus block**: “You said now. I'm holding you to it.” at Tuesday 9:00 AM | None. Session completion or early exit does not post a notification. | No method route; a tap opens Aura's default launch surface. |
| Passive Income / Apple Health | **Walk**: “You said now. I'm holding you to it.” at Sunday 10:00 AM | None. Health refresh and Collect do not post a notification. | No method route; a tap opens Aura's default launch surface. |

The three daily habit nudges are also method-neutral. Their body says “quests”
and does not identify which earn method to open.

## Per-habit routines

Source: `Models/HabitRoutine.swift`, `RoutineStore`, and
`RoutineNotificationCoordinator`.

| ID pattern | Title | Body | Trigger | Example | Tap destination |
| --- | --- | --- | --- | --- | --- |
| `aura.routine.<owner>.r<revision>.<habitName>.<weekday>` | The exact habit name | You said now. I'm holding you to it. | Repeating calendar trigger for the selected weekday and minute from midnight. One request per weekday. | `Read`, Monday and Wednesday, `minuteOfDay = 480` gives 8:00 AM on both days. | Default app launch; no habit-specific route. |

Saving replaces the named routine and refreshes requests. Removing it, saving an
empty weekday set, replacing all routines, switching accounts, or deleting an
account removes pending `aura.routine.` requests before rebuilding the current
set. Revision guards prevent stale async refreshes from restoring old requests.
Permission denial leaves routines stored but creates no request; `rescheduleAll`
can retry after permission is granted.

## Screen Time usage events

Source: `Services/SharedBlocking.swift`, `LiveScreenTimeService`, and the
`AuraShieldMonitor` extension. These post immediately when a monitored threshold
is crossed, rather than using calendar requests.

| Event | Title | Body | Trigger | Example | Tap destination |
| --- | --- | --- | --- | --- | --- |
| `min15` | Quick check in | 15 minutes of screen time so far. Pacing yourself, right? | 15 minutes of distracting-app usage in the all-day `auraUsage` monitor. | Threshold crossed at 11:22 AM. | Default app launch; no explicit route. |
| `min45` | 45 minutes of scrolling | That's a real chunk of your day. Just noticing out loud. | 45 minutes of distracting-app usage. | Cumulative usage reaches 45 minutes. | Default app launch; no explicit route. |
| `hour2` | Two hours deep | Two hours of screen time. This is the part where I sigh. | 120 minutes of distracting-app usage. | Cumulative usage reaches 2 hours. | Default app launch; no explicit route. |
| `hour4` | We need to talk | Four hours of screen time today. I'm a little worried about us. | 240 minutes of distracting-app usage. | Cumulative usage reaches 4 hours. | Default app launch; no explicit route. |
| `hour8` | Please | Eight hours today. I'm begging you. Put the phone down and go touch grass. | 480 minutes of distracting-app usage. | Cumulative usage reaches 8 hours. | Default app launch; no explicit route. |

The extension checks the shared `screenTimeRemindersEnabled` gate before posting.
Changing the toggle or app selection rebuilds monitoring. Disabling the toggle
stops future events; delivered notifications are not withdrawn.

## Purchased screen-time expiry

Source: `Services/InterventionNotifier.swift`, called by intervention purchase.

| ID | Title | Body | Trigger | Example | Tap destination |
| --- | --- | --- | --- | --- | --- |
| `aura.screentime.timeUp` | Time's up | Your apps are blocked again. | One-shot interval after the purchased minutes; time-sensitive. | `minutes = 10` delivers about 10 minutes after purchase. | Default app launch; no explicit route. |

Scheduling removes the previous expiry first. Returning time early cancels it;
zero or negative durations create nothing. Shield reapplication and Live
Activity expiry have no separate notification.

## Uncovered or incorrect cases

- No category, action, response delegate, or deep link maps a tap to a habit,
  quest, store, routine editor, or Screen Time screen.
- The 2 PM and 8 PM requests repeat even though their no-quest condition is
  evaluated only at scheduling time, so stale intent is possible without a
  reschedule.
- Routine IDs include owner and revision, while `HabitRoutine.requestIDs`
  describes the older `aura.routine.<habitName>.<weekday>` shape. Prefix cleanup
  works, but the helper is not an exact inventory of live IDs.
- Provisional authorization, Focus suppression, time-sensitive settings, and
  turning notifications back on in Settings have no dedicated UX or evidence.
- Account switching rebuilds routines, while daily IDs are device-wide. Verify
  expected behavior when switching accounts on one device.
- Deleting a custom habit has no visible hook that removes a same-named routine.
- No notification is emitted for quest success, photo failure, exercise target,
  Deep Focus completion, Apple Health collection, or routine edits. These are
  uncovered cases, not a request to add them during inventory review.
