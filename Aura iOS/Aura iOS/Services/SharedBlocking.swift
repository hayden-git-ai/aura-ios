//
//  SharedBlocking.swift
//  Aura iOS
//
//  Shared between the app and the DeviceActivityMonitor extension. Add this
//  file to BOTH targets — keep it small, because everything in it has to
//  compile inside an extension with no app around it.
//

import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

extension ManagedSettingsStore.Name {
    /// Always Blocked. Never cleared by anything the app does day to day.
    static let auraHard = Self("auraHard")
    /// Distracting. Cleared while time is bought or earned, and only ever this
    /// one — which is the whole reason there are two stores.
    static let auraSoft = Self("auraSoft")
}

extension DeviceActivityName {
    /// The window that begins the moment bought time runs out.
    static let auraReshield = Self("auraReshield")
    /// A full-day window that watches distracting-app usage and fires the
    /// screen-time reminders as it crosses each threshold.
    static let auraUsage = Self("auraUsage")
}

/// The screen-time reminders, keyed by the usage bound that fires them. These are
/// EVENT-DRIVEN: the DeviceActivity monitor posts them when usage crosses each
/// threshold (see `AuraShieldMonitor.eventDidReachThreshold`). Lives in the shared
/// file so both the app (which schedules the events) and the extension (which
/// posts the notification) see the same copy + bounds. Gated by
/// `AuraShared.screenTimeRemindersEnabled`.
enum ScreenTimeReminder: String, CaseIterable {
    case min15, min45, hour2, hour4, hour8

    /// Minutes of usage that trips this reminder.
    var minutes: Int {
        switch self {
        case .min15: return 15
        case .min45: return 45
        case .hour2: return 120
        case .hour4: return 240
        case .hour8: return 480
        }
    }

    var title: String {
        switch self {
        case .min15: return "Quick check in"
        case .min45: return "45 minutes of scrolling"
        case .hour2: return "Two hours deep"
        case .hour4: return "We need to talk"
        case .hour8: return "Please"
        }
    }

    var body: String {
        switch self {
        case .min15: return "15 minutes of screen time so far. Pacing yourself, right?"
        case .min45: return "That's a real chunk of your day. Just noticing out loud."
        case .hour2: return "Two hours of screen time. This is the part where I sigh."
        case .hour4: return "Four hours of screen time today. I'm a little worried about us."
        case .hour8: return "Eight hours today. I'm begging you. Put the phone down and go touch grass."
        }
    }

    /// The DeviceActivity event name that carries this reminder across the app /
    /// extension boundary.
    var eventName: DeviceActivityEvent.Name { .init(rawValue) }

    init?(eventName: DeviceActivityEvent.Name) {
        self.init(rawValue: eventName.rawValue)
    }
}

/// The handful of things the monitor extension needs to know.
///
/// It runs in its own process, minutes or hours after the app was last open and
/// quite possibly while the app is dead, so it can't ask the app anything. What
/// it needs has to be sitting in the shared container before it wakes up.
enum AuraShared {
    static let appGroup = "group.Aura-App.Aura-iOS"

    private static let distractingKey = "distractingSelection"
    private static let screenTimeRemindersKey = "screenTimeRemindersEnabled"

    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    /// Whether the screen-time reminders may fire. Mirrored out of the app so the
    /// monitor extension (a separate process) can honour the toggle without the
    /// app being alive. Defaults to off if never written.
    static var screenTimeRemindersEnabled: Bool {
        get { defaults?.bool(forKey: screenTimeRemindersKey) ?? false }
        set { defaults?.set(newValue, forKey: screenTimeRemindersKey) }
    }

    /// The Distracting rule's selection, mirrored out of `BlockConfig`.
    ///
    /// Only this one rule is shared. Always Blocked never needs re-applying —
    /// it's never lifted in the first place — and Always Allowed only matters
    /// while the app is deciding a plan.
    static func setDistracting(_ token: Data?) {
        guard let defaults else { return }
        if let token {
            defaults.set(token, forKey: distractingKey)
        } else {
            defaults.removeObject(forKey: distractingKey)
        }
    }

    static func distractingSelection() -> FamilyActivitySelection? {
        guard let data = defaults?.data(forKey: distractingKey) else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    /// Puts the Distracting shield back.
    ///
    /// The one thing the monitor exists to do. Writes only the soft store, so a
    /// mistake here can't reach Always Blocked.
    static func reapplyDistractingShield() {
        let soft = ManagedSettingsStore(named: .auraSoft)
        guard let selection = distractingSelection() else {
            soft.clearAllSettings()
            return
        }
        soft.shield.applications = selection.applicationTokens
        soft.shield.applicationCategories = .specific(selection.categoryTokens)
        soft.shield.webDomains = selection.webDomainTokens
        soft.shield.webDomainCategories = .specific(selection.categoryTokens)
    }
}
