//
//  ScreenTimeService.swift
//  Aura iOS
//
//  Screen Time / Family Controls seam. The Live impl (FamilyControls
//  AuthorizationCenter + FamilyActivityPicker + ManagedSettings shield) lands
//  once the DeviceActivityMonitor extension exists. Until then the Mock drives
//  the whole flow deterministically. Views never touch FamilyControls directly —
//  only this protocol.
//
//  Selections are carried as opaque `Data` tokens (encoded
//  FamilyActivitySelection in production), never as readable app names.
//

import Foundation
import SwiftUI

/// Result of the system app picker: the opaque selection + counts for display.
struct AppSelectionResult: Equatable {
    var token: Data?
    var appCount: Int
    var categoryCount: Int
    /// Catalogue stand-ins, from the Simulator's picker. Always empty on a
    /// device, where the token is the selection and nothing here is readable.
    var mockIconNames: [String] = []

    var isEmpty: Bool { appCount == 0 && categoryCount == 0 }
    static let empty = AppSelectionResult(token: nil, appCount: 0, categoryCount: 0)
}

/// Everything that should be shielded right now, already decided.
///
/// No policy lives in here — the engine resolves rules, unlock sessions and
/// focus sessions into this, and the service just applies it. That's what keeps
/// the shield from being computed differently in three places, which is how the
/// Home pill and the block set came to disagree in the first place.
struct ShieldPlan: Equatable {
    /// Always Blocked. Present in every plan.
    var hardTokens: Data?
    /// Distracting. `nil` while an unlock session is running.
    var softTokens: Data?
    /// Always Allowed. Only used when `blockEverything` is on.
    var exceptTokens: Data?
    var blockEverything = false
    var blockAdultWebsites = false
    /// Hard Mode: iOS refuses to delete Aura while this is set.
    ///
    /// Part of the plan rather than written separately, so it is applied and
    /// cleared by the same call as everything else. A restriction with its own
    /// write path is one that can be left behind, and this is the single worst
    /// setting to leave behind: it would strand someone with an app they can't
    /// remove.
    var denyAppRemoval = false

    /// Nothing to shield and nothing to restrict.
    var isEmpty: Bool {
        hardTokens == nil && softTokens == nil && !blockEverything && !blockAdultWebsites
    }

    static let empty = ShieldPlan()
}

protocol ScreenTimeService: AnyObject {
    var authorizationStatus: PermissionStatus { get }
    func requestAuthorization() async -> PermissionStatus

    /// Presents the picker, opened on what the rule already holds, and returns
    /// what came back. Takes the whole selection rather than just its token so
    /// the Simulator's stand-in has something readable to pre-tick.
    func presentAppPicker(current: AppSelection) async -> AppSelectionResult

    /// Applies the plan. Throws if the shield can't be written.
    ///
    /// The live implementation writes the hard and soft rules into two *named*
    /// `ManagedSettingsStore`s. Named stores union their settings, so clearing
    /// the soft store when time is bought physically cannot touch the hard one —
    /// no conditional shield-building, and no bug that unshields the wrong rule.
    func apply(_ plan: ShieldPlan) async throws

    /// Lifts everything. Used when blocking is turned off entirely.
    func clearAll() async

    /// Arranges for the Distracting shield to go back on at `date`, whether or
    /// not the app is running then. Without this, force-quitting Aura during
    /// bought time keeps the apps open indefinitely.
    func scheduleReshield(at date: Date)
    func cancelScheduledReshield()

    /// Copies the Distracting selection into the shared container, which is the
    /// only thing the monitor extension can read when it wakes.
    func mirrorDistractingSelection(_ token: Data?)

    /// (Re)schedules the day-long usage monitoring that fires the screen-time
    /// reminders as distracting-app time crosses each threshold. Pass the toggle
    /// state: `false` (or an empty selection) stops the monitoring.
    func rescheduleUsageReminders(enabled: Bool)
}

/// Deterministic Screen Time for previews/tests and everything before the
/// entitlement. Configurable to exercise grant / deny / restricted /
/// empty-picker / shield-failure paths.
final class MockScreenTimeService: ScreenTimeService {
    enum Behavior { case grant, deny, restricted }

    var authBehavior: Behavior
    var pickerResult: AppSelectionResult
    var shieldShouldFail: Bool

    private(set) var status: PermissionStatus = .notDetermined
    /// The last plan applied, so the UI and tests can assert on what the engine
    /// decided rather than on what a view happened to render.
    private(set) var lastPlan: ShieldPlan?

    init(authBehavior: Behavior = .grant,
         pickerResult: AppSelectionResult = AppSelectionResult(token: Data([0x1]), appCount: 3, categoryCount: 1),
         shieldShouldFail: Bool = false) {
        self.authBehavior = authBehavior
        self.pickerResult = pickerResult
        self.shieldShouldFail = shieldShouldFail
    }

    var authorizationStatus: PermissionStatus { status }

    func requestAuthorization() async -> PermissionStatus {
        switch authBehavior {
        case .grant:      status = .authorized
        case .deny:       status = .denied
        case .restricted: status = .restricted
        }
        return status
    }

    /// Presents the stand-in picker for real, rather than returning a canned
    /// answer. The flow being identical in both places is the whole point of
    /// having a seam — a mock that silently succeeds tests nothing.
    @MainActor
    func presentAppPicker(current: AppSelection) async -> AppSelectionResult {
        await withCheckedContinuation { continuation in
            guard let host = MockAppPickerPresenter.top() else {
                continuation.resume(returning: pickerResult)
                return
            }

            var didFinish = false
            let finish: ([String]?) -> Void = { names in
                guard !didFinish else { return }
                didFinish = true
                host.presentedViewController?.dismiss(animated: true)
                guard let names else {
                    continuation.resume(returning: .empty)
                    return
                }
                continuation.resume(returning: AppSelectionResult(
                    // Derived from the picked apps, not a constant sentinel:
                    // `setSelection` clears any other lane whose token matches,
                    // so a shared fixed token made every non-empty lane look
                    // identical and clobber the others. A content token only
                    // collides when two lanes truly hold the same set — which is
                    // exactly when one should displace the other.
                    token: names.isEmpty ? nil : Self.mockToken(for: names),
                    appCount: names.count,
                    categoryCount: 0,
                    mockIconNames: names
                ))
            }

            let sheet = MockAppPickerSheet(alreadyPicked: current.mockIconNames,
                                           onDone: { finish($0) },
                                           onCancel: { finish(nil) })
            let controller = UIHostingController(rootView: sheet)
            controller.overrideUserInterfaceStyle = .light
            host.present(controller, animated: true)
        }
    }

    /// A deterministic, order-independent token for a set of mock app names, so
    /// two lanes match only when they hold the same apps.
    private static func mockToken(for names: [String]) -> Data {
        Data(names.sorted().joined(separator: "\u{0}").utf8)
    }


    struct ShieldError: Error {}

    func apply(_ plan: ShieldPlan) async throws {
        if shieldShouldFail { throw ShieldError() }
        lastPlan = plan
    }

    func clearAll() async { lastPlan = .empty }

    private(set) var scheduledReshield: Date?
    func scheduleReshield(at date: Date) { scheduledReshield = date }
    func cancelScheduledReshield() { scheduledReshield = nil }
    func mirrorDistractingSelection(_ token: Data?) {}
    func rescheduleUsageReminders(enabled: Bool) {}
}
