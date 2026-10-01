//
//  SubscriptionGateView.swift
//  Aura iOS
//
//  The subscription gate presents the real Superwall paywall directly.
//  Dismissal, skip, and presentation errors return to onboarding.
//

import SwiftUI
#if canImport(SuperwallKit)
import SuperwallKit
#endif

struct SubscriptionGateView: View {
    @Environment(HabitStore.self) private var store
    let onExit: () -> Void
    @State private var presentationPending = false
    private let analytics = PaywallAnalytics()

    init(onExit: @escaping () -> Void = {}) {
        self.onExit = onExit
    }

    var body: some View {
        #if canImport(SuperwallKit)
        Color.clear
            .onAppear { analytics.gateViewed(source: "subscription_gate") }
            .task {
                await store.refreshEntitlement()
                guard !Task.isCancelled, !store.isSubscribed else { return }
                presentPaywall()
            }
        #else
        Color.clear
            .task { onExit() }
        #endif
    }

    #if canImport(SuperwallKit)
    private func presentPaywall() {
        guard !presentationPending else { return }
        presentationPending = true
        let placement = SuperwallBootstrap.Placement.paywall
        let handler = PaywallPresentationHandler()
        handler.onPresent { _ in
            analytics.paywallPresented(placement: placement)
        }
        handler.onDismiss { _, _ in
            presentationPending = false
            Task { @MainActor in
                await store.refreshEntitlement()
                if !store.isSubscribed { onExit() }
            }
        }
        handler.onError { _ in
            presentationPending = false
            Haptics.notify(.error)
            onExit()
        }
        handler.onSkip { _ in
            presentationPending = false
            onExit()
        }
        Superwall.shared.register(placement: placement, handler: handler) {
            presentationPending = false
            Haptics.notify(.success)
            Task { await store.refreshEntitlement() }
        }
    }
    #endif
}
