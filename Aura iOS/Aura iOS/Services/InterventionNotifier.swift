//
//  InterventionNotifier.swift
//  Aura iOS
//

import Foundation
import UserNotifications

/// The notification that closes the loop: your time is up and the apps went
/// back behind the block.
///
/// Local and self-contained, so it needs no extension and no server. It is the
/// The shield-button handoff is handled separately by `AuraShieldAction` and
/// `AuraNotificationDelegate`; this notifier owns only purchased-time expiry.
enum InterventionNotifier {
    private static let timeUpID = "aura.screentime.timeUp"

    /// Fires when purchased time runs out. Any previous one is cancelled first:
    /// buying twice in a row should leave one notification, at the later time,
    /// rather than two saying different things.
    static func scheduleTimeUp(minutes: Int) {
        guard minutes > 0 else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [timeUpID])

        let content = UNMutableNotificationContent()
        content.title = "Time's up"
        content.body = "Your apps are blocked again."
        content.sound = .default
        // Time Sensitive so it breaks through a Focus mode. The moment it
        // describes is the moment it matters; an hour later it's noise.
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(minutes) * 60,
                                                        repeats: false)
        center.add(UNNotificationRequest(identifier: timeUpID, content: content, trigger: trigger))
    }

    /// Called when time is handed back early, so the notification doesn't
    /// arrive after the apps have already locked.
    static func cancelTimeUp() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [timeUpID])
    }
}
