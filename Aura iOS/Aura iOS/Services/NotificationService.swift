//
//  NotificationService.swift
//  Aura iOS
//
//  Notification authorization seam. Live wraps UNUserNotificationCenter (Phase D).
//  Notifications are optional and never block onboarding — a denial soft-continues
//  (Branch B03). The Mock drives grant/deny deterministically.
//

import Foundation
import UserNotifications

protocol NotificationService: AnyObject {
    var authorizationStatus: PermissionStatus { get }
    func requestAuthorization() async -> PermissionStatus
    /// Schedules the reminder set implied by the plan (best-effort; no-op if denied).
    func scheduleReminders(choice: ReminderChoice, vulnerableTime: VulnerableTime?) async
}

/// Wraps the real system prompt — this is what actually shows iOS's native
/// "Aura Would Like to Send You Notifications" alert.
final class LiveNotificationService: NotificationService {
    private(set) var authorizationStatus: PermissionStatus = .notDetermined

    func requestAuthorization() async -> PermissionStatus {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            authorizationStatus = granted ? .authorized : .denied
        } catch {
            authorizationStatus = .denied
        }
        return authorizationStatus
    }

    func scheduleReminders(choice: ReminderChoice, vulnerableTime: VulnerableTime?) async {
        // Reminder content/timing design comes later (Phase E) — scheduling
        // is a no-op until then, but authorization itself is real.
        guard authorizationStatus == .authorized, choice != .off else { return }
    }
}

/// Schedules the daily HABIT reminders that Settings → Reminders (and the setup
/// Notifications screen) toggle. Best-effort: clears its own pending requests
/// first, then re-adds only what applies, and only if permission is granted.
///
/// The 8am nudge always fires when reminders are on. The 2pm and 8pm nags only
/// arm on a day with no quest done yet — call `reschedule` again when a quest is
/// completed and they're pulled for the day (they re-arm next morning, when
/// `todayEarnedCoins` has reset).
enum ReminderScheduler {
    private static let at8am = "aura.reminder.habit.8am"
    private static let at2pm = "aura.reminder.habit.2pm"
    private static let at8pm = "aura.reminder.habit.8pm"

    static func reschedule(habitReminders: Bool, questsDoneToday: Bool) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            center.removePendingNotificationRequests(withIdentifiers: [at8am, at2pm, at8pm])
            let granted = settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
            guard granted, habitReminders else { return }

            add(id: at8am, hour: 8,
                title: "Earn your scroll today!",
                body: "Your apps are locked. Complete quests to earn them back.", center: center)

            // The nags only if nothing's been earned yet today.
            guard !questsDoneToday else { return }
            add(id: at2pm, hour: 14,
                title: "It's 2pm",
                body: "And you've done zero quests. Not judging. Okay, a little.", center: center)
            add(id: at8pm, hour: 20,
                title: "C'mon, don't do this",
                body: "One quest keeps the streak alive. You've still got a few hours.", center: center)
        }
    }

    private static func add(id: String, hour: Int, title: String, body: String,
                            center: UNUserNotificationCenter) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        var comps = DateComponents()
        comps.hour = hour
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}

// `ScreenTimeReminder` (the event-driven screen-time reminder copy + bounds) now
// lives in `SharedBlocking.swift` so the monitor extension can read it too.
