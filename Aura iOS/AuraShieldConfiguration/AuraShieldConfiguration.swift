//
//  AuraShieldConfiguration.swift
//  AuraShieldConfiguration
//

import Foundation
import FamilyControls
import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Supplies the system shield and records the localized app title for the
/// intervention route. The action extension receives only an opaque token;
/// this is the Screen Time extension that can see `localizedDisplayName`.
final class AuraShieldConfigurationDataSource: ShieldConfigurationDataSource {
    private let namesKey = "aura.intervention.applicationNames"
    private let appGroup = "group.Aura-App.Aura-iOS"

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        return configuration(for: application)
    }

    override func configuration(shielding application: Application,
                                in category: ActivityCategory) -> ShieldConfiguration {
        configuration(for: application)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        configuration(for: nil)
    }

    override func configuration(shielding webDomain: WebDomain,
                                in category: ActivityCategory) -> ShieldConfiguration {
        configuration(for: nil)
    }

    private func configuration(for application: Application?) -> ShieldConfiguration {
        if let application {
            record(name: application.localizedDisplayName, token: application.token)
        }

        let title = application?.localizedDisplayName ?? "This app is paused"
        return ShieldConfiguration(
            backgroundBlurStyle: .systemMaterialDark,
            backgroundColor: UIColor(white: 0.08, alpha: 1),
            title: .init(text: title, color: .white),
            subtitle: .init(text: "Aura is keeping this one out of reach.", color: .white.withAlphaComponent(0.78)),
            primaryButtonLabel: .init(text: "Talk to Aura", color: .white),
            // Extension-safe equivalent of LightSheet.blue (#2586FF).
            primaryButtonBackgroundColor: UIColor(red: 37.0 / 255, green: 134.0 / 255, blue: 1, alpha: 1),
            secondaryButtonLabel: .init(text: "Close", color: .white.withAlphaComponent(0.86))
        )
    }

    private func record(name: String?, token: ApplicationToken?) {
        guard let name, !name.isEmpty, let token,
              let data = try? JSONEncoder().encode(token) else { return }
        let key = data.base64EncodedString()
        let defaults = UserDefaults(suiteName: appGroup)
        var names = defaults?.dictionary(forKey: namesKey) as? [String: String] ?? [:]
        names[key] = name
        defaults?.set(names, forKey: namesKey)
    }
}
