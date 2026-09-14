//
//  SuperwallBootstrap.swift
//  Aura iOS
//
//  Superwall presents and A/B-tests the paywall; RevenueCat still transacts the
//  purchase and owns the entitlement the app checks (`aura_pro`). The bridge is a
//  RevenueCat-backed `PurchaseController`: Superwall shows the paywall, but the
//  buy/restore calls it makes are handed straight to RevenueCat, so there is one
//  billing backbone and no double receipt handling.
//
//  Everything is written behind `#if canImport(SuperwallKit)`, so this file
//  compiles now and switches on the moment the SuperwallKit Swift package is
//  added to the target (the same pattern as EntitlementService/RevenueCat).
//
//  Placement: the paywall is presented by registering `Placement.paywall`. Create
//  a Campaign in the Superwall dashboard whose placement name matches this string
//  exactly, attach the Aura paywall, and set its Feature Gating to **Gated** so the
//  gate only advances after a real purchase.
//
//  Order of init matters: RevenueCat must be configured before Superwall, because
//  `syncSubscriptionStatus()` reads `Purchases.shared`. Call `RevenueCatBootstrap
//  .start()` first, then `SuperwallBootstrap.start()` (see Aura_iOSApp).
//

import Foundation

enum SuperwallBootstrap {
    /// Superwall public SDK key (publishable, safe to ship — like RevenueCat's).
    static let apiKey = "pk_W-JAT5VAMg6sac6J0urnQ"

    /// The placement the subscription gate registers to present the paywall. Must
    /// match a placement on a Superwall campaign exactly.
    enum Placement {
        static let paywall = "paywall"
    }

    static func start() {
        #if canImport(SuperwallKit)
        guard !apiKey.isEmpty else { return }
        let controller = RCPurchaseController()
        Superwall.configure(apiKey: apiKey, purchaseController: controller)
        // Begin mirroring RevenueCat's entitlement state into Superwall so its
        // paywalls know whether the user is already subscribed. RevenueCat is
        // configured first (RevenueCatBootstrap.start), so this is safe here.
        controller.syncSubscriptionStatus()
        #endif
    }
}

#if canImport(SuperwallKit)
import SuperwallKit
import RevenueCat
import StoreKit

/// Bridges Superwall's purchase flow to RevenueCat. Superwall calls these when the
/// user taps buy/restore on a paywall; the work is delegated to RevenueCat, which
/// remains the source of truth for `aura_pro`.
final class RCPurchaseController: PurchaseController {
    private enum PurchasingError: Error { case sk2ProductNotFound, identityNotReady }
    private let analytics = PaywallAnalytics()

    /// Streams RevenueCat's active entitlements into Superwall's subscription
    /// status for the life of the process. Started once, right after configure.
    func syncSubscriptionStatus() {
        assert(Purchases.isConfigured, "Configure RevenueCat before Superwall.")
        Task { @MainActor in
            for await _ in Purchases.shared.customerInfoStream {
                let identity = SubscriptionIdentityState.shared
                let revision = identity.revision
                guard identity.ready, identity.matchesBillingIdentity(),
                      SupabaseManager.shared.currentUserID?.uuidString == identity.userID else { continue }
                // Stream payloads can arrive after account transitions. Fetch
                // for the settled SDK identity and validate again on completion.
                guard let info = try? await Purchases.shared.customerInfo(),
                      identity.matches(revision), identity.ready,
                      identity.matchesBillingIdentity(),
                      SupabaseManager.shared.currentUserID?.uuidString == identity.userID else { continue }
                Superwall.shared.subscriptionStatus =
                    info.entitlements[LiveEntitlementService.entitlementID]?.isActive == true
                    ? .active([Entitlement(id: LiveEntitlementService.entitlementID)])
                    : .inactive
            }
        }
    }

    func purchase(product: SuperwallKit.StoreProduct) async -> PurchaseResult {
        let identity = SubscriptionIdentityState.shared
        let revision = identity.revision
        guard identity.ready, identity.matchesBillingIdentity(),
              identity.userID == SupabaseManager.shared.currentUserID?.uuidString else {
            return .failed(PurchasingError.identityNotReady)
        }
        let productID = product.productIdentifier
        analytics.purchaseStarted(productID: productID)
        do {
            guard let sk2Product = product.sk2Product else {
                throw PurchasingError.sk2ProductNotFound
            }
            let rcProduct = RevenueCat.StoreProduct(sk2Product: sk2Product)
            let result = try await Purchases.shared.purchase(product: rcProduct)
            guard identity.matches(revision), identity.ready,
                  identity.matchesBillingIdentity(),
                  identity.userID == SupabaseManager.shared.currentUserID?.uuidString else {
                return .failed(PurchasingError.identityNotReady)
            }
            if result.userCancelled {
                analytics.purchaseResult(.cancelled, productID: productID)
                return .cancelled
            }
            analytics.purchaseResult(.success, productID: productID)
            return .purchased
        } catch let error as ErrorCode {
            if error == .paymentPendingError {
                analytics.purchaseResult(.pending, productID: productID)
                return .pending
            }
            analytics.purchaseResult(.failed, productID: productID)
            return .failed(error)
        } catch {
            analytics.purchaseResult(.failed, productID: productID)
            return .failed(error)
        }
    }

    func restorePurchases() async -> RestorationResult {
        let identity = SubscriptionIdentityState.shared
        let revision = identity.revision
        guard identity.ready, identity.matchesBillingIdentity(),
              identity.userID == SupabaseManager.shared.currentUserID?.uuidString else {
            return .failed(PurchasingError.identityNotReady)
        }
        analytics.restoreStarted(source: "superwall")
        do {
            _ = try await Purchases.shared.restorePurchases()
            guard identity.matches(revision), identity.ready,
                  identity.matchesBillingIdentity(),
                  identity.userID == SupabaseManager.shared.currentUserID?.uuidString else {
                return .failed(PurchasingError.identityNotReady)
            }
            analytics.restoreResult(.restored, source: "superwall")
            return .restored
        } catch {
            analytics.restoreResult(.failed, source: "superwall")
            return .failed(error)
        }
    }
}
#endif
