//
//  InterventionNotificationRouting.swift
//  Aura iOS
//

import Foundation
import Combine
import UIKit
import UserNotifications

/// Bridges a shield-action notification response into SwiftUI navigation.
/// The published token is retained, so a cold-launch response is not lost if
/// SwiftUI subscribes after the notification delegate callback.
final class AuraNotificationDelegate: NSObject, UIApplicationDelegate, ObservableObject,
                                      UNUserNotificationCenterDelegate {
    @Published private(set) var interventionRequestID: UUID?

    private enum Route {
        static let key = "aura.route"
        static let intervention = "intervention"
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
            self?.interventionRequestID = UUID()
        }
    }
}
