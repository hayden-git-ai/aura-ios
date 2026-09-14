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

    /// The handoff steps, in order. `rawValue` drives forward/back navigation.
    /// The interactive "how to use Aura" walkthrough is NOT a step here — it's a
    /// first-run coach-mark tour over the real Home screen, shown after setup.
    enum Step: Int, CaseIterable {
        case welcome, signIn, notifications, screenTime, appPicker, allSet
    }

    var step: Step = .welcome

    /// True while the most recent navigation was a "back". Drives the slide
    /// direction so the push transition moves the correct way.
    private(set) var goingBack = false

    /// Called when the last step finishes; the gate flips its completion flag.
    var onFinish: () -> Void = {}

    // Captured results. Best-effort: the two permission statuses only become
    // real on a device; in the Simulator the Mock resolves them deterministically.
    var notifStatus: PermissionStatus = .notDetermined
    var screenTimeStatus: PermissionStatus = .notDetermined
    var selection: AppSelectionResult = .empty

    let notifications: NotificationService
    let screenTime: ScreenTimeService

    init() {
        notifications = LiveNotificationService()
        #if targetEnvironment(simulator)
        screenTime = MockScreenTimeService()
        #else
        screenTime = LiveScreenTimeService()
        #endif
    }

    // MARK: - Navigation

    func advance() {
        if let next = Step(rawValue: step.rawValue + 1) {
            goingBack = false
            withAnimation(.easeInOut(duration: 0.3)) { step = next }
        } else {
            onFinish()
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
