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
        static let applicationTokenKey = "aura.applicationToken"
    }

    override func handle(action: ShieldAction,
                         for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handle(action: action, application: application, completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction,
                         for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handle(action: action, application: nil, completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction,
                         for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handle(action: action, application: nil, completionHandler: completionHandler)
    }

    private func handle(action: ShieldAction,
                        application: ApplicationToken?,
                        completionHandler: @escaping (ShieldActionResponse) -> Void) {
        guard action == .primaryButtonPressed else {
            completionHandler(.close)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "This app is blocked"
        content.body = "Tap here to ask Aura for permission"
        content.sound = .default
        var userInfo: [String: Any] = [
            InterventionNotification.routeKey: InterventionNotification.routeValue
        ]
        // The containing app can render Apple's own Label(token) after a cold
        // or warm launch. ApplicationToken has no display-name API here.
        if let application, let tokenData = try? JSONEncoder().encode(application) {
            userInfo[InterventionNotification.applicationTokenKey] = tokenData
            let names = UserDefaults(suiteName: "group.Aura-App.Aura-iOS")?
                .dictionary(forKey: "aura.intervention.applicationNames") as? [String: String] ?? [:]
            if let name = names.first(where: { entry in
                guard let bytes = Data(base64Encoded: entry.key),
                      let cached = try? JSONDecoder().decode(ApplicationToken.self, from: bytes)
                else { return false }
                return cached == application
            })?.value {
                userInfo["aura.applicationName"] = name
            }
        }
        content.userInfo = userInfo

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
