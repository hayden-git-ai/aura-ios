//
//  InterventionNotificationRouting.swift
//  Aura iOS
//

import Foundation
import Combine
import FamilyControls
import ManagedSettings
import UIKit
import UserNotifications

/// Bridges a shield-action notification response into SwiftUI navigation.
/// The published token is retained, so a cold-launch response is not lost if
/// SwiftUI subscribes after the notification delegate callback.
final class AuraNotificationDelegate: NSObject, UIApplicationDelegate, ObservableObject,
                                      UNUserNotificationCenterDelegate {
    @Published private(set) var interventionRequestID: UUID?
    /// The opaque token for the app that invoked the shield action. The
    /// Shield Configuration extension records the localized name separately.
    @Published private(set) var interventionAppToken: ApplicationToken?
    /// Localized title captured by AuraShieldConfiguration when available.
    @Published private(set) var interventionAppName: String?

    private enum Route {
        static let key = "aura.route"
        static let intervention = "intervention"
        static let applicationToken = "aura.applicationToken"
        static let applicationNames = "aura.intervention.applicationNames"
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        defer { completionHandler() }
        guard response.notification.request.content.userInfo[Route.key] as? String == Route.intervention else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            if let data = response.notification.request.content.userInfo[Route.applicationToken] as? Data {
                self?.interventionAppToken = try? JSONDecoder().decode(ApplicationToken.self, from: data)
                let payload = response.notification.request.content.userInfo
                let names = UserDefaults(suiteName: AuraNotificationDelegate.appGroup)?.dictionary(forKey: Route.applicationNames) as? [String: String] ?? [:]
                // Codable JSON object key order is not an identity. Compare the
                // decoded opaque tokens, including entries from earlier builds.
                self?.interventionAppName = payload["aura.applicationName"] as? String
                    ?? names.first(where: { entry in
                        guard let bytes = Data(base64Encoded: entry.key),
                              let cached = try? JSONDecoder().decode(ApplicationToken.self, from: bytes)
                        else { return false }
                        return cached == self?.interventionAppToken
                    })?.value
            } else {
                self?.interventionAppToken = nil
                self?.interventionAppName = nil
            }
            self?.interventionRequestID = UUID()
        }
    }

    fileprivate static let appGroup = "group.Aura-App.Aura-iOS"
}
