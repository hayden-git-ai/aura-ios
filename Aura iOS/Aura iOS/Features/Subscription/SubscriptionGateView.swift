//
//  SubscriptionGateView.swift
//  Aura iOS
//
//  Shown by AppGate when onboarding is done but the account has no active
//  subscription. Superwall presents the paywall (built and A/B-tested in the
//  Superwall dashboard); RevenueCat still transacts the purchase and owns the
//  `aura_pro` entitlement the app checks.
//
//  The paywall is presented by registering `Placement.paywall`. Its campaign must
//  be set to **Gated** in Superwall, so the feature closure runs only once the user
//  actually has access — that closure refreshes the entitlement, which flips
//  `store.isSubscribed` and lets AppGate advance past this gate.
//
//  Behind this view sits a branded holding screen: it shows for the instant before
//  the paywall presents, and again if the user dismisses the paywall without
//  buying (with a button to bring it back). The `#else` branch is a self-contained
//  fallback that drives the same entitlement seam directly, so the app still
//  compiles and gates correctly before the SuperwallKit package is added.
//

import SwiftUI
#if canImport(SuperwallKit)
import SuperwallKit
#endif

struct SubscriptionGateView: View {
    @Environment(HabitStore.self) private var store
    @State private var working = false
    @State private var presentationPending = false
    private let analytics = PaywallAnalytics()

    var body: some View {
        #if canImport(SuperwallKit)
        holding
            .onAppear {
                analytics.gateViewed(source: "subscription_gate")
            }
            .task {
                await store.refreshEntitlement()
                guard !Task.isCancelled, !store.isSubscribed else { return }
                presentPaywall()
            }
        #else
        fallback
            .onAppear { analytics.gateViewed(source: "fallback_subscription_gate") }
        #endif
    }

    #if canImport(SuperwallKit)
    /// Registers the paywall placement. On a Gated campaign the feature closure
    /// fires only after the user gains access, so refreshing the entitlement here
    /// advances the gate; if they dismiss without buying, nothing fires and the
    /// holding screen's button can call this again.
    private func presentPaywall() {
        guard !presentationPending, !working else { return }
        presentationPending = true
        let placement = SuperwallBootstrap.Placement.paywall
        let handler = PaywallPresentationHandler()
        handler.onPresent { _ in
            analytics.paywallPresented(placement: placement)
        }
        handler.onDismiss { _, _ in presentationPending = false }
        handler.onError { _ in presentationPending = false }
        handler.onSkip { _ in presentationPending = false }
        Superwall.shared.register(placement: placement, handler: handler) {
            presentationPending = false
            Task { await store.refreshEntitlement() }
        }
    }

    private var holding: some View {
        ZStack {
            LightSheet.bg.ignoresSafeArea()
            VStack(spacing: Theme.Spacing.xl) {
                Spacer()
                VStack(spacing: Theme.Spacing.m) {
                    Text("Unlock Aura")
                        .auraFont(.display, SheetType.hero, .bold)
                        .foregroundStyle(LightSheet.title)
                    Text("Keep every app earned, not given. 🦊")
                        .auraFont(.body, SheetType.cardTitle, .regular)
                        .foregroundStyle(LightSheet.subtitleDark)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, Theme.Spacing.xl)
                Spacer()
                VStack(spacing: Theme.Spacing.m) {
                    LightPrimaryButton(title: "See plans", enabled: !working && !presentationPending) {
                        presentPaywall()
                    }
                    Button("Restore purchase") {
                        guard !working else { return }
                        working = true
                        analytics.restoreStarted(source: "subscription_gate")
                        Task {
                            let restored = await store.restorePurchase()
                            analytics.restoreResult(restored ? .restored : .failed, source: "subscription_gate")
                            working = false
                        }
                    }
                    .auraFont(.body, SheetType.cardTitle, .semibold)
                    .foregroundStyle(LightSheet.title)
                    .buttonStyle(.plain)
                    .disabled(working || presentationPending)
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.l)
            }
        }
    }
    #endif

    // MARK: - Fallback (no SuperwallKit)

    private var fallback: some View {
        ZStack {
            LightSheet.bg.ignoresSafeArea()
            VStack(spacing: Theme.Spacing.xl) {
                Spacer()
                VStack(spacing: Theme.Spacing.m) {
                    Text("Unlock Aura")
                        .auraFont(.display, SheetType.hero, .bold)
                        .foregroundStyle(LightSheet.title)
                    Text("Choose your plan to keep every app earned, not given.")
                        .auraFont(.body, SheetType.cardTitle, .regular)
                        .foregroundStyle(LightSheet.subtitleDark)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, Theme.Spacing.xl)
                Spacer()
                VStack(spacing: Theme.Spacing.m) {
                    LightPrimaryButton(title: working ? "…" : "See plans", enabled: !working) {
                        analytics.purchaseStarted(productID: "default")
                        Task {
                            working = true
                            let subscribed = await store.subscribe()
                            analytics.purchaseResult(subscribed ? .success : .failed, productID: "default")
                            working = false
                        }
                    }
                    Button("Restore purchase") {
                        analytics.restoreStarted(source: "fallback_subscription_gate")
                        Task {
                            working = true
                            let restored = await store.restorePurchase()
                            analytics.restoreResult(restored ? .restored : .failed, source: "fallback_subscription_gate")
                            working = false
                        }
                    }
                    .auraFont(.body, SheetType.cardTitle, .semibold)
                    .foregroundStyle(LightSheet.title)
                    .buttonStyle(.plain)
                    .disabled(working || presentationPending)
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.l)
            }
        }
    }
}
