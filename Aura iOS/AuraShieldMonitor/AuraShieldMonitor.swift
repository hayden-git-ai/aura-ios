//
//  AuraShieldMonitor.swift
//  AuraShieldMonitor
//
//  Belongs to the DeviceActivityMonitor extension target. `SharedBlocking.swift`
//  and `AuraTimerAttributes.swift` must be members of BOTH this target and the
//  app.
//

import ActivityKit
import DeviceActivity
import Dispatch
import UserNotifications

/// Puts the shield back — and clears the Live Activity — when bought time runs
/// out.
///
/// This exists because the app can't be relied on to be alive at the moment it
/// matters. Expiry is handled in `HabitStore.tick` while Aura is running, but
/// someone who buys ten minutes and force-quits the app would otherwise stay
/// unblocked for good — the one hole that would make the whole bargain
/// meaningless.
///
/// The work is deliberately tiny. This process is woken by the system, gets no
/// warning and very little time, and anything it can't do in a moment it won't
/// get to do at all.
class AuraShieldMonitor: DeviceActivityMonitor {

    /// Fires the instant bought time runs out.
    ///
    /// The window is scheduled to *begin* at expiry rather than end there, and
    /// that's not arbitrary: `DeviceActivitySchedule` refuses intervals shorter
    /// than fifteen minutes, and plenty of unlocks are shorter than that. A
    /// window that starts at expiry sidesteps the limit completely and fires at
    /// the exact moment, however little time was bought.
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard activity == .auraReshield else { return }
        AuraShared.reapplyDistractingShield()
        endBoughtTimeLiveActivity()
    }

    /// Belt and braces. If the start was missed — the device was off, the
    /// system was busy — the shield still goes back at the end of the window
    /// rather than never.
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity == .auraReshield else { return }
        AuraShared.reapplyDistractingShield()
        endBoughtTimeLiveActivity()
    }

    /// Takes the countdown banner off the Lock Screen and Dynamic Island.
    ///
    /// The widget draws the clock itself, so it reaches 0:00 on its own — but
    /// reaching zero isn't the same as being *ended*, and only an `end()` call
    /// removes it. In the app that call comes from `HabitStore.tick`; when the
    /// app is dead at expiry, this is the one place left to make it. The same
    /// wake-up that re-locks the apps clears the banner, so the two never
    /// disagree.
    ///
    /// `end` is async and this process is about to be suspended, so the work is
    /// held open with a semaphore until it finishes — a short, bounded wait, the
    /// same shape everything else in this extension has to take.
    /// A distracting-usage threshold was crossed. Posts the matching screen-time
    /// reminder, if the user still has them on. The gate is read from the shared
    /// container because this process can't ask the app.
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name,
                                         activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        guard activity == .auraUsage,
              AuraShared.screenTimeRemindersEnabled,
              let reminder = ScreenTimeReminder(eventName: event) else { return }

        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = .default
        // nil trigger delivers immediately.
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "aura.screentime.\(reminder.rawValue)",
                                  content: content, trigger: nil))
    }

    private func endBoughtTimeLiveActivity() {
        let done = DispatchSemaphore(value: 0)
        Task {
            for activity in Activity<AuraTimerAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            done.signal()
        }
        _ = done.wait(timeout: .now() + 3)
    }
}
