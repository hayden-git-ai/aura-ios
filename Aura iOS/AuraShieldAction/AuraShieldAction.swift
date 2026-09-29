//
//  AuraShieldAction.swift
//  AuraShieldAction
//

import FamilyControls
import ManagedSettings
import UserNotifications

/// Handles the button on Apple's shield without weakening the active block.
///
/// A shield extension cannot open its containing app directly. The supported
/// handoff is an immediate local notification; tapping it launches Aura, where
/// `AuraNotificationDelegate` consumes the route and presents the intervention.
final class AuraShieldActionDelegate: ShieldActionDelegate {
    private enum InterventionNotification {
        static let identifier = "aura.intervention.request"
        static let routeKey = "aura.route"
        static let routeValue = "intervention"
    }

    override func handle(action: ShieldAction,
                         for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handle(action: action, completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction,
                         for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handle(action: action, completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction,
                         for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handle(action: action, completionHandler: completionHandler)
    }

    private func handle(action: ShieldAction,
                        completionHandler: @escaping (ShieldActionResponse) -> Void) {
        guard action == .primaryButtonPressed else {
            completionHandler(.defer)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "This app is blocked"
        content.body = "Tap here to ask Aura for permission"
        content.sound = .default
        content.userInfo = [InterventionNotification.routeKey: InterventionNotification.routeValue]

        let request = UNNotificationRequest(
            identifier: InterventionNotification.identifier,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
        // Keep the app shielded whether delivery succeeds or notification
        // permission has been revoked. Aura never silently unlocks here.
        completionHandler(.defer)
    }
}
