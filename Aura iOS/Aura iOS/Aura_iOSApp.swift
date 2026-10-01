//
//  Aura_iOSApp.swift
//  Aura iOS
//
//  Created by Hayden Berio on 7/4/26.
//

import GoogleSignIn
import Combine
import SwiftUI
#if canImport(SuperwallKit)
import SuperwallKit
#endif

@main
struct Aura_iOSApp: App {
    @UIApplicationDelegateAdaptor(AuraNotificationDelegate.self) private var notificationDelegate
    // Single shared store for the whole app — see HabitStore's doc comment.
    // In-memory for now; SwiftData persistence gets added here later, driven
    // by the finalized Habit/StreakInfo types instead of the template's Item.
    @State private var store = HabitStore()
    @Environment(\.scenePhase) private var scenePhase

    /// Shown once per cold launch: the splash video plays, then irises open onto
    /// whichever screen `RootGate` chose. False for the rest of the process.
    @State private var showSplash = true
    @State private var showNotificationIntervention = false
    @State private var notificationInterventionStyle: InterventionStyle = .dialogue

    init() {
        FontRegistration.registerBundledFonts()
        #if DEBUG
        let isHostedUnitTest = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        #else
        let isHostedUnitTest = false
        #endif
        // Keep local StoreKit transactions away from provider SDKs in hosted tests.
        if !isHostedUnitTest {
            // First, so it captures crashes during the rest of startup. No-op until the
            // Sentry package + DSN are added. Crashes are deliberately anonymous.
            SentryBootstrap.start()
            // No-op until the RevenueCat package is added and its key is set.
            // RevenueCat must come first: it is the billing backbone, and Superwall's
            // status sync reads Purchases.shared.
            RevenueCatBootstrap.start()
            // No-op until the SuperwallKit package is added. Superwall presents the
            // paywall; RevenueCat (above) still transacts and owns the entitlement.
            SuperwallBootstrap.start()
            // Optional analytics starts only after explicit Settings consent.
            // Session replay is disabled; no account identity is attached.
            PostHogBootstrap.start()
        }
        #if DEBUG && targetEnvironment(simulator)
        // A fresh simulator has no history, and an empty Stats screen isn't
        // what we're trying to look at. Release builds start empty, correctly.
        DayLogFile.seedIfEmpty()
        WinLibrary.seedIfEmpty()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // AppGate decides setup-handoff vs. app and owns the active color
                // scheme. Mounted from launch so it's
                // ready to show through the splash's opening circle. (Onboarding +
                // paywall get inserted ahead of setup as they're rebuilt; the old
                // RootGate/Part1/Part2 flow is being retired.)
                AppGate()
                    .environment(store)
                    .environment(\.notificationInterventionPresented, showNotificationIntervention)
                    // Applied at the true top of the hierarchy so it reliably cancels
                    // SwiftUI's automatic keyboard-avoidance reflow everywhere (a
                    // modifier on RootGate's inner Group did not take effect).
                    .ignoresSafeArea(.keyboard, edges: .bottom)
                    // One guarantee for the whole app: tap outside or scroll always
                    // closes the keyboard. Return/Done is handled per field.
                    .dismissesKeyboardGlobally()

                if showSplash {
                    SplashOverlay { showSplash = false }
                        .zIndex(10)
                }
            }
            // Give each SDK its own URL family; a handler safely ignores URLs that
            // do not belong to it.
            .onOpenURL { url in
                _ = GIDSignIn.sharedInstance.handle(url)
                #if canImport(SuperwallKit)
                _ = Superwall.handleDeepLink(url)
                #endif
            }
            .onReceive(notificationDelegate.$interventionRequestID.compactMap { $0 }) { _ in
                showSplash = false
                notificationInterventionStyle = store.interventionStyle
                showNotificationIntervention = true
            }
            .background {
                PriorityInterventionPresenter(isPresented: $showNotificationIntervention) {
                    InterventionView(appName: notificationDelegate.interventionAppName,
                                     appToken: notificationDelegate.interventionAppToken,
                                     style: notificationInterventionStyle) {
                        showNotificationIntervention = false
                    }
                    .environment(store)
                    .id(notificationDelegate.interventionRequestID)
                }
            }
        }
        // Nothing ticks while the app is away, so every countdown is stale on
        // return and a session that finished in the meantime is sitting there
        // unclaimed. One read of the clock settles both.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.refreshClock()
                // The user may have revoked notifications in iOS Settings while
                // away — fall the reminder toggles back to off if so.
                store.reconcileReminderPermission()
                // A subscription can start, lapse, or be restored elsewhere.
                Task { await store.refreshEntitlement() }
            }
        }
    }
}

private struct NotificationInterventionPresentedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var notificationInterventionPresented: Bool {
        get { self[NotificationInterventionPresentedKey.self] }
        set { self[NotificationInterventionPresentedKey.self] = newValue }
    }
}

/// Notification routes must be able to appear above an existing Settings or
/// habit cover. Present from the current controller in this window, preserving
/// the user's underlying screen and its unsaved state.
private struct PriorityInterventionPresenter<Content: View>: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    @ViewBuilder var content: () -> Content

    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }
    func makeCoordinator() -> Coordinator { Coordinator() }

    func updateUIViewController(_ controller: UIViewController, context: Context) {
        context.coordinator.update(controller: controller, presented: isPresented, content: content)
    }

    static func dismantleUIViewController(_ controller: UIViewController, coordinator: Coordinator) {
        coordinator.cancel()
    }

    final class Coordinator {
        private var task: Task<Void, Never>?
        private var host: UIHostingController<Content>?
        private weak var window: UIWindow?

        func update(controller: UIViewController, presented: Bool, content: @escaping () -> Content) {
            // A full-screen cover can detach the underlying view from its
            // window. Retain the window identity before that happens.
            if let currentWindow = controller.view.window { window = currentWindow }
            guard presented else { cancel(); return }
            if let host {
                host.rootView = content()
                return
            }
            guard task == nil else { return }
            task = Task { @MainActor [weak self, weak controller] in
                defer { self?.task = nil }
                while !Task.isCancelled {
                    guard let self, let controller else { return }
                    if let currentWindow = controller.view.window { self.window = currentWindow }
                    if let window = self.window,
                       let root = window.rootViewController,
                       window.windowScene?.activationState == .foregroundActive {
                        var top = root
                        while let presented = top.presentedViewController { top = presented }
                        if !top.isBeingPresented && !top.isBeingDismissed && top.transitionCoordinator == nil {
                            let host = UIHostingController(rootView: content())
                            host.modalPresentationStyle = .overFullScreen
                            host.modalPresentationCapturesStatusBarAppearance = true
                            host.isModalInPresentation = true
                            self.host = host
                            top.present(host, animated: true)
                            return
                        }
                    }
                    try? await Task.sleep(for: .milliseconds(100))
                }
            }
        }

        func cancel() {
            task?.cancel()
            task = nil
            host?.dismiss(animated: true)
            host = nil
        }
    }
}
