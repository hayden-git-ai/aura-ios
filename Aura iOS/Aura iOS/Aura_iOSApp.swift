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
        #if DEBUG
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
                showNotificationIntervention = true
            }
            .fullScreenCover(isPresented: $showNotificationIntervention) {
                InterventionView(appName: "your blocked app",
                                 style: store.interventionStyle) {}
                    .environment(store)
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
