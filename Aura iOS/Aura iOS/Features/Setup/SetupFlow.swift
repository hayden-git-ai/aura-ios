//
//  SetupFlow.swift
//  Aura iOS
//
//  The post-paywall setup handoff: the real first-run configuration the
//  onboarding funnel intentionally skips (permissions, app selection, the
//  how-to walkthrough). Runs once, after purchase, then hands to the app.
//
//  Sign-in is a STUB for now — the account backend (Supabase) is not wired yet,
//  so the provider buttons just advance. Screen Time + the app picker are
//  device-only; in the Simulator they run against the Mock service.
//

import SwiftUI

@Observable
final class SetupFlow {

    private static let pendingOnboardingNameKey = "aura.setup.pendingOnboardingName"

    /// The handoff steps, in order. `rawValue` drives forward/back navigation.
    /// The interactive "how to use Aura" walkthrough is NOT a step here — it's a
    /// first-run coach-mark tour over the real Home screen, shown after setup.
    enum Step: Int, CaseIterable {
        case signIn, notifications, screenTime, appPicker, allSet
    }

    var step: Step = .signIn

    /// Explicitly carries the name entered in onboarding across the setup
    /// account handoff. It is consumed after sign-in only when the target
    /// account still has no valid profile name.
    var pendingOnboardingName: String? = UserDefaults.standard.string(forKey: SetupFlow.pendingOnboardingNameKey) {
        didSet {
            if let pendingOnboardingName, !pendingOnboardingName.isEmpty {
                UserDefaults.standard.set(pendingOnboardingName, forKey: Self.pendingOnboardingNameKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.pendingOnboardingNameKey)
            }
        }
    }

    /// True while the most recent navigation was a "back". Drives the slide
    /// direction so the push transition moves the correct way.
    private(set) var goingBack = false

    /// Called when the last step finishes. Passing the selection makes saving it
    /// part of setup completion instead of leaving it in this temporary flow.
    var onFinish: (AppSelection) -> Void = { _ in }

    // Captured results. Best-effort: the two permission statuses only become
    // real on a device; in the Simulator the Mock resolves them deterministically.
    var notifStatus: PermissionStatus = .notDetermined
    var screenTimeStatus: PermissionStatus = .notDetermined
    var selection: AppSelectionResult = .empty

    @MainActor
    func restorePendingOnboardingNameIfNeeded(in store: HabitStore) {
        guard !store.accountPersistenceFailed else { return }
        defer { pendingOnboardingName = nil }
        guard let name = pendingOnboardingName,
              ProfileIdentity.isValidName(name),
              !store.hasCompleteDisplayName else { return }
        _ = store.saveProfileName(firstName: name, lastName: "")
    }

    let notifications: NotificationService
    let screenTime: ScreenTimeService

    init(notifications: NotificationService, screenTime: ScreenTimeService) {
        self.notifications = notifications
        self.screenTime = screenTime
    }

    convenience init() {
        #if targetEnvironment(simulator)
        self.init(notifications: LiveNotificationService(), screenTime: MockScreenTimeService())
        #else
        self.init(notifications: LiveNotificationService(), screenTime: LiveScreenTimeService())
        #endif
    }

    // MARK: - Navigation

    func advance() {
        if let next = Step(rawValue: step.rawValue + 1) {
            goingBack = false
            withAnimation(.easeInOut(duration: 0.3)) { step = next }
        } else {
            guard !selection.isEmpty else { return }
            onFinish(AppSelection(token: selection.token,
                                  appCount: selection.appCount,
                                  categoryCount: selection.categoryCount,
                                  mockIconNames: selection.mockIconNames))
        }
    }

    func back() {
        guard let prev = Step(rawValue: step.rawValue - 1) else { return }
        goingBack = true
        withAnimation(.easeInOut(duration: 0.3)) { step = prev }
    }

    // MARK: - Real work (each request advances when it resolves)

    @MainActor func requestNotifications() async {
        notifStatus = await notifications.requestAuthorization()
        advance()
    }

    @MainActor func requestScreenTime() async {
        screenTimeStatus = await screenTime.requestAuthorization()
        guard screenTimeStatus == .authorized else { return }
        advance()
    }

    /// Presents the system app picker (Mock in the Simulator), pre-opened on
    /// what's already chosen so "Add more apps" keeps the previous selection.
    @MainActor func pickApps() async {
        let current = AppSelection(token: selection.token,
                                   appCount: selection.appCount,
                                   categoryCount: selection.categoryCount,
                                   mockIconNames: selection.mockIconNames)
        selection = await screenTime.presentAppPicker(current: current)
    }
}
