//
//  LiveScreenTimeService.swift
//  Aura iOS
//
//  The real Screen Time. Needs the `com.apple.developer.family-controls`
//  entitlement, and needs a physical device — FamilyControls authorization
//  always fails in the Simulator, which is why `HabitStore` still picks the
//  Mock there.
//

import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import SwiftUI

/// Family Controls behind the app's own seam.
///
/// Nothing here decides policy. `BlockingEngine` resolves the three rules and
/// the session state into a `ShieldPlan`, and this applies it verbatim. Keeping
/// that split is what stops "why is this app blocked?" from having three
/// possible answers.
final class LiveScreenTimeService: ScreenTimeService {

    /// Mirrors `AuthorizationCenter`, which is main-actor bound, so the rest of
    /// the app can read a status synchronously from anywhere.
    private var cachedStatus: PermissionStatus = .notDetermined

    init() {
        Task { @MainActor in cachedStatus = Self.read() }
    }

    var authorizationStatus: PermissionStatus { cachedStatus }

    @MainActor
    private static func read() -> PermissionStatus {
        switch AuthorizationCenter.shared.authorizationStatus {
        case .approved: return .authorized
        case .denied: return .denied
        case .notDetermined: return .notDetermined
        // Any other / future status (a new SDK case, or an unknown one) is
        // treated as not-yet-granted, the safe default.
        default: return .notDetermined
        }
    }

    func requestAuthorization() async -> PermissionStatus {
        do {
            // `.individual`, not `.child`: this is someone choosing to limit
            // their own phone, with no parent on the other end.
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            cachedStatus = Self.read()
        } catch {
            // The user declined, or the device is managed and can't grant it.
            cachedStatus = Self.read() == .notDetermined ? .denied : Self.read()
        }
        return cachedStatus
    }

    // MARK: - Picking apps

    /// Presents the system picker and waits for it to close.
    ///
    /// The picker is a SwiftUI view with no completion handler, so it gets
    /// hosted and bridged into the protocol's async shape. There is no
    /// alternative API: the tokens it produces are the only way to name an app,
    /// and only the system may hand them out.
    @MainActor
    func presentAppPicker(current: AppSelection) async -> AppSelectionResult {
        // Asked for here rather than at launch: the system prompt makes sense
        // at the moment somebody reaches for the app list, and nowhere else in
        // the app was requesting it at all. Without it the picker comes up
        // empty and every `apply` throws.
        if authorizationStatus != .authorized {
            guard await requestAuthorization() == .authorized else { return .empty }
        }

        return await withCheckedContinuation { continuation in
            guard let host = Self.topViewController() else {
                continuation.resume(returning: .empty)
                return
            }

            var selection = Self.decode(current.token) ?? FamilyActivitySelection()
            var didFinish = false

            let finish: (FamilyActivitySelection?) -> Void = { result in
                guard !didFinish else { return }   // dismiss can fire twice
                didFinish = true
                host.presentedViewController?.dismiss(animated: true)
                continuation.resume(returning: result.map(Self.summarise) ?? .empty)
            }

            let picker = FamilyActivityPickerHost(
                selection: Binding(get: { selection }, set: { selection = $0 }),
                onDone: { finish(selection) },
                onCancel: { finish(nil) }
            )
            let controller = UIHostingController(rootView: picker)
            controller.overrideUserInterfaceStyle = .light
            host.present(controller, animated: true)
        }
    }

    private static func summarise(_ selection: FamilyActivitySelection) -> AppSelectionResult {
        AppSelectionResult(
            token: try? JSONEncoder().encode(selection),
            appCount: selection.applicationTokens.count + selection.webDomainTokens.count,
            categoryCount: selection.categoryTokens.count
        )
    }

    private static func decode(_ data: Data?) -> FamilyActivitySelection? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    // MARK: - Shielding

    func apply(_ plan: ShieldPlan) async throws {
        await MainActor.run {
            let hard = ManagedSettingsStore(named: .auraHard)
            let soft = ManagedSettingsStore(named: .auraSoft)

            let blocked = Self.decode(plan.hardTokens)
            let distracting = Self.decode(plan.softTokens)
            let allowed = Self.decode(plan.exceptTokens)

            // Refresh explicit websites in both modes so old selections cannot linger.
            hard.shield.webDomains = blocked?.webDomainTokens

            if plan.blockEverything {
                // Everything except the allow list. This is the only state in
                // which Always Allowed means anything — with an explicit
                // distracting list you'd simply not add the app.
                hard.shield.applicationCategories = .all(except: allowed?.applicationTokens ?? [])
                hard.shield.webDomainCategories = .all(except: allowed?.webDomainTokens ?? [])
                hard.shield.applications = blocked?.applicationTokens
            } else {
                hard.shield.applications = blocked?.applicationTokens
                hard.shield.applicationCategories = blocked.map {
                    .specific($0.categoryTokens)
                }
                hard.shield.webDomainCategories = blocked.map { .specific($0.categoryTokens) }
            }

            // Cleared, not rebuilt, when time is bought. Because this is its own
            // named store, clearing it cannot reach the hard rule — no
            // conditional shield-building, and no chance of unshielding the
            // wrong thing.
            soft.shield.applications = distracting?.applicationTokens
            soft.shield.applicationCategories = distracting.map { .specific($0.categoryTokens) }
            soft.shield.webDomains = distracting?.webDomainTokens
            soft.shield.webDomainCategories = distracting.map { .specific($0.categoryTokens) }

            // Apple's own adult-content filter rather than a domain list of
            // ours, which would be endless and out of date the day it shipped.
            hard.webContent.blockedByFilter = plan.blockAdultWebsites ? .auto() : nil

            // Hard Mode. iOS greys out Delete App on the Home Screen and in
            // Settings while this is set.
            //
            // Written as an explicit false rather than nil when off, so leaving
            // Hard Mode lifts the restriction on the same write that rebuilds
            // the shield. Anything that can only be cleared by a separate call
            // is something that survives a crash between the two.
            hard.application.denyAppRemoval = plan.denyAppRemoval ? true : false
        }
    }

    func scheduleReshield(at date: Date) {
        let center = DeviceActivityCenter()
        center.stopMonitoring([.auraReshield])

        // A window that *starts* at expiry, because a schedule can't be shorter
        // than fifteen minutes and plenty of unlocks are. Starting at expiry
        // means the length of the window doesn't matter — only its start does.
        let calendar = Calendar.current
        let start = calendar.dateComponents([.hour, .minute, .second], from: date)
        let end = calendar.dateComponents([.hour, .minute, .second],
                                          from: date.addingTimeInterval(20 * 60))
        let schedule = DeviceActivitySchedule(intervalStart: start,
                                              intervalEnd: end,
                                              repeats: false)
        // Failure here is survivable: the app re-shields on its own the moment
        // it's next opened. This is the safety net for when it isn't.
        try? center.startMonitoring(.auraReshield, during: schedule)
    }

    func cancelScheduledReshield() {
        DeviceActivityCenter().stopMonitoring([.auraReshield])
    }

    func mirrorDistractingSelection(_ token: Data?) {
        AuraShared.setDistracting(token)
    }

    /// Schedules a day-long, repeating DeviceActivity window whose events trip at
    /// each `ScreenTimeReminder` threshold of distracting-app time. The monitor
    /// extension turns those events into notifications. Rebuilt whenever the
    /// distracting selection or the toggle changes; stopped when off or empty.
    ///
    /// NOTE: every threshold is measured against the Distracting selection (the
    /// only token set shared with the extension). "Total device time" would need a
    /// separate all-apps selection, which the app doesn't hold.
    func rescheduleUsageReminders(enabled: Bool) {
        let center = DeviceActivityCenter()
        center.stopMonitoring([.auraUsage])

        // Keep the extension's copy of the toggle in step so it honours it even if
        // this reschedule is a no-op (off / empty selection).
        AuraShared.screenTimeRemindersEnabled = enabled

        guard enabled, let selection = AuraShared.distractingSelection() else { return }
        let apps = selection.applicationTokens
        let categories = selection.categoryTokens
        let webDomains = selection.webDomainTokens
        guard !(apps.isEmpty && categories.isEmpty && webDomains.isEmpty) else { return }

        // A window that spans the whole day and repeats, so the thresholds reset
        // each morning with the day's usage.
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true)

        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for reminder in ScreenTimeReminder.allCases {
            events[reminder.eventName] = DeviceActivityEvent(
                applications: apps,
                categories: categories,
                webDomains: webDomains,
                threshold: DateComponents(minute: reminder.minutes))
        }

        // Survivable on failure: the reminders are a nudge, not a guarantee.
        try? center.startMonitoring(.auraUsage, during: schedule, events: events)
    }

    func clearAll() async {
        await MainActor.run {
            for name in [ManagedSettingsStore.Name.auraHard, .auraSoft] {
                ManagedSettingsStore(named: name).clearAllSettings()
            }
        }
    }

    // MARK: -

    @MainActor
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

/// Chrome around the system picker, which ships without any of its own.
///
/// Apple supplies the list, the categories and the search field, and nothing
/// else — no title, no count, no way to finish. Every app that uses this builds
/// the same wrapper around it; this one is built out of Aura's, so the only
/// part that looks like the system is the part the system draws.
private struct FamilyActivityPickerHost: View {
    @Binding var selection: FamilyActivitySelection
    var onDone: () -> Void
    var onCancel: () -> Void

    private var count: Int {
        selection.applicationTokens.count
            + selection.categoryTokens.count
            + selection.webDomainTokens.count
    }

    var body: some View {
        ZStack(alignment: .top) {
            LightSheet.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                LightSubSheetHeader(title: "Choose apps",
                                    subtitle: "Pick apps, whole categories, or websites.")

                FamilyActivityPicker(selection: $selection)

                VStack(spacing: Theme.Spacing.m) {
                    Text(count == 1 ? "1 item selected" : "\(count) items selected")
                        .auraFont(.body, RowType.value, .medium)
                        .foregroundStyle(LightSheet.subtitle)

                    LightPrimaryButton(title: "Save", enabled: count > 0) {
                        onDone()
                    }

                    Button("Cancel", action: onCancel)
                        .auraFont(.body, RowType.label, .semibold)
                        .foregroundStyle(LightSheet.subtitle)
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.l)
                .padding(.bottom, Theme.Spacing.xl)
            }
        }
    }
}
