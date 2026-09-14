//
//  EntitlementService.swift
//  Aura iOS
//
//  Whether the signed-in user has an active subscription, from whichever way they
//  paid: App Store in-app purchase via RevenueCat, or the web funnel (Paddle)
//  via web2wave. Views never touch RevenueCat directly, only this seam, exactly
//  like ScreenTimeService and ProofVerifier.
//
//  The Live implementation is written behind `#if canImport(RevenueCat)`, so this
//  file compiles now and the real calls switch on automatically the moment the
//  RevenueCat Swift package is added to the target. Until then Live reports
//  not-subscribed (honest: there is nothing to check yet).
//
//  Two sources, OR'd: RevenueCat for App Store IAP, and the `web-entitlement`
//  Supabase function for web (Paddle/web2wave) subscriptions. Web revenue is
//  deliberately kept OUT of RevenueCat (no forwarding), so it never counts toward
//  RevenueCat's tracked revenue. The web result is cached so a transient network
//  failure doesn't re-gate a paying web subscriber.
//

import Foundation

@MainActor
protocol EntitlementService: AnyObject {
    /// Ties entitlement to the Aura account, so one identity resolves its
    /// subscription however it was bought. Call once the Supabase user id is known.
    func configure(userID: String)
    /// Pre-sign-in onboarding can purchase using a verified anonymous SDK identity.
    func configureAnonymous()
    /// Clears account-scoped SDK identity and cached entitlement state.
    func resetIdentity() async
    /// The current entitlement, read fresh. Called on launch, on foreground, and
    /// after a purchase. Best-effort; returns false on any failure.
    func currentlySubscribed() async -> Bool
    /// Buys the default plan. Returns true if the user is subscribed afterward.
    func purchaseDefault() async -> Bool
    /// Restores prior purchases. Returns true if a subscription was restored.
    func restore() async -> Bool
}

/// Deterministic entitlement for the Simulator and previews. Defaults to
/// subscribed so development isn't blocked by the gate; construct with
/// `subscribed: false` to exercise the paywall.
final class MockEntitlementService: EntitlementService {
    private var subscribed: Bool
    init(subscribed: Bool = true) { self.subscribed = subscribed }
    func configure(userID: String) {}
    func configureAnonymous() {}
    func resetIdentity() async {}
    func currentlySubscribed() async -> Bool { subscribed }
    func purchaseDefault() async -> Bool { subscribed = true; return true }
    func restore() async -> Bool { subscribed }
}

/// Two-source entitlement: RevenueCat (`aura_pro`) for App Store IAP, OR'd with the
/// web (Paddle) check via the `web-entitlement` function. A subscribed App Store
/// user never triggers the web call.
@MainActor
final class LiveEntitlementService: EntitlementService {
    static let entitlementID = "aura_pro"

    /// Injectable SDK boundaries allow account-switch races to be tested without
    /// contacting billing services or making purchases.
    struct Dependencies {
        var logIn: (String) async -> Bool
        var logOut: () async -> Void
        var prepareAnonymous: () async -> Bool
        var appStoreActive: () async -> Bool
        var purchase: () async -> Bool
        var restore: () async -> Bool
        var webActive: () async -> Bool?
        var currentUserID: () -> String?
        var identify: (String) -> Void
        var reset: () -> Void

        static var live: Self {
            Self(
                logIn: { userID in
                    #if canImport(RevenueCat)
                    guard Purchases.isConfigured else { return false }
                    do {
                        _ = try await Purchases.shared.logIn(userID)
                        return Purchases.shared.appUserID == userID
                    } catch { return false }
                    #else
                    return false
                    #endif
                },
                logOut: {
                    #if canImport(RevenueCat)
                    if Purchases.isConfigured, !Purchases.shared.isAnonymous {
                        _ = try? await Purchases.shared.logOut()
                    }
                    #endif
                },
                prepareAnonymous: {
                    #if canImport(RevenueCat)
                    guard Purchases.isConfigured else { return false }
                    if !Purchases.shared.isAnonymous {
                        _ = try? await Purchases.shared.logOut()
                    }
                    return Purchases.shared.isAnonymous
                    #else
                    return false
                    #endif
                },
                appStoreActive: {
                    #if canImport(RevenueCat)
                    guard Purchases.isConfigured,
                          let info = try? await Purchases.shared.customerInfo() else { return false }
                    return info.entitlements[entitlementID]?.isActive == true
                    #else
                    return false
                    #endif
                },
                purchase: {
                    #if canImport(RevenueCat)
                    let identity = SubscriptionIdentityState.shared
                    let revision = identity.revision
                    guard identity.ready,
                          let offerings = try? await Purchases.shared.offerings(),
                          let package = offerings.current?.availablePackages.first,
                          identity.matches(revision), identity.ready,
                          identity.matchesBillingIdentity(),
                          identity.userID == SupabaseManager.shared.currentUserID?.uuidString else { return false }
                    let result = try? await Purchases.shared.purchase(package: package)
                    return result?.customerInfo.entitlements[entitlementID]?.isActive == true
                    #else
                    return false
                    #endif
                },
                restore: {
                    #if canImport(RevenueCat)
                    let info = try? await Purchases.shared.restorePurchases()
                    return info?.entitlements[entitlementID]?.isActive == true
                    #else
                    return false
                    #endif
                },
                webActive: {
                    guard let reply = await SupabaseManager.shared.webEntitlement(),
                          reply.error?.isEmpty != false else { return nil }
                    return reply.active
                },
                currentUserID: { SupabaseManager.shared.currentUserID?.uuidString },
                identify: { userID in
                    #if canImport(SuperwallKit)
                    Superwall.shared.identify(userId: userID)
                    #endif
                },
                reset: {
                    #if canImport(SuperwallKit)
                    Superwall.shared.reset()
                    Superwall.shared.subscriptionStatus = .inactive
                    #endif
                }
            )
        }
    }

    private let dependencies: Dependencies
    private let cache: WebEntitlementCache
    private let identity: SubscriptionIdentityState
    private var transition: Task<Bool, Never>?
    private var transitionPending = false

    init(dependencies: Dependencies? = nil,
         defaults: UserDefaults = .standard,
         identity: SubscriptionIdentityState? = nil) {
        self.dependencies = dependencies ?? .live
        self.cache = WebEntitlementCache(defaults: defaults)
        self.identity = identity ?? .shared
    }

    func configure(userID: String) {
        guard !userID.isEmpty else { return }
        configureIdentity(userID: userID)
    }

    func configureAnonymous() {
        configureIdentity(userID: nil)
    }

    private func configureIdentity(userID: String?) {
        if identity.revision > 0, identity.userID == userID, identity.ready || transitionPending { return }
        let previous = transition
        let revision = identity.begin(userID: userID)
        dependencies.reset()
        transitionPending = true
        transition = Task { [self, dependencies, identity] in
            _ = await previous?.value
            guard identity.matches(revision) else { return false }
            let success: Bool
            if let userID {
                success = await dependencies.logIn(userID)
            } else {
                success = await dependencies.prepareAnonymous()
            }
            guard identity.matches(revision) else { return false }
            identity.ready = success
            transitionPending = false
            if let userID { dependencies.identify(userID) }
            return success
        }
    }

    func resetIdentity() async {
        let previous = transition
        _ = identity.begin(userID: nil)
        transitionPending = false
        cache.clear()
        dependencies.reset()
        // Queue logout behind any in-flight login. Local access is already
        // revoked, even when the billing SDK cannot log out over the network.
        let logout = Task { [dependencies] in
            _ = await previous?.value
            await dependencies.logOut()
            return false
        }
        transition = logout
        _ = await logout.value
    }

    func currentlySubscribed() async -> Bool {
        await resolve(operation: dependencies.appStoreActive)
    }

    func purchaseDefault() async -> Bool {
        await resolve(operation: dependencies.purchase)
    }

    func restore() async -> Bool {
        await resolve(operation: dependencies.restore)
    }

    private func resolve(operation: () async -> Bool) async -> Bool {
        let revision = identity.revision
        let userID = identity.userID
        guard identity.revision > 0 else { return false }
        let billingReady = await transition?.value == true
        guard isCurrent(revision, userID: userID) else { return false }
        if billingReady {
            let active = await operation()
            guard isCurrent(revision, userID: userID) else { return false }
            if active { return true }
        }
        // A billing login failure must not prevent a verified web subscriber
        // from retaining access through the independent Paddle source.
        guard let userID else { return false }
        let webReply = await dependencies.webActive()
        guard isCurrent(revision, userID: userID) else { return false }
        if let active = webReply {
            cache.record(active: active, userID: userID)
            return active
        }
        return cache.fallback(userID: userID)
    }

    private func isCurrent(_ revision: UInt, userID: String?) -> Bool {
        identity.matches(revision) && dependencies.currentUserID() == userID
    }
}

/// Shared with the purchase bridge so late SDK events cannot re-enable a signed
/// out or different account. Mutations are confined to the main actor.
@MainActor
final class SubscriptionIdentityState {
    static let shared = SubscriptionIdentityState()
    private(set) var revision: UInt = 0
    private(set) var userID: String?
    var ready = false

    @discardableResult
    func begin(userID: String?) -> UInt {
        revision &+= 1
        self.userID = userID
        ready = false
        return revision
    }

    func matches(_ revision: UInt) -> Bool { self.revision == revision }

    func matchesBillingIdentity() -> Bool {
        #if canImport(RevenueCat)
        guard Purchases.isConfigured else { return false }
        if let userID { return Purchases.shared.appUserID == userID }
        return Purchases.shared.isAnonymous
        #else
        return false
        #endif
    }
}

/// Cache entries carry their account owner. Legacy ownerless entries are never
/// trusted, and future timestamps do not extend the 24-hour grace period.
@MainActor
struct WebEntitlementCache {
    let defaults: UserDefaults
    private let activeKey = "aura.web.entitlement.active.v1"
    private let atKey = "aura.web.entitlement.checkedAt.v1"
    private let ownerKey = "aura.web.entitlement.user.v2"
    private let ttl: TimeInterval = 60 * 60 * 24

    func record(active: Bool, userID: String, now: Date = Date()) {
        defaults.set(active, forKey: activeKey)
        defaults.set(now, forKey: atKey)
        defaults.set(userID, forKey: ownerKey)
    }

    func fallback(userID: String, now: Date = Date()) -> Bool {
        guard defaults.string(forKey: ownerKey) == userID,
              let at = defaults.object(forKey: atKey) as? Date,
              (0..<ttl).contains(now.timeIntervalSince(at)) else { return false }
        return defaults.bool(forKey: activeKey)
    }

    func clear() {
        [activeKey, atKey, ownerKey].forEach { defaults.removeObject(forKey: $0) }
    }
}

/// One-time RevenueCat SDK init. Call from the app entry point at launch.
enum RevenueCatBootstrap {
    /// Paste the RevenueCat public SDK key (safe to ship; it is a publishable key).
    static let apiKey = "appl_nAWamrjRkjrzJMNPufRKNCUEEQu"

    static func start() {
        #if canImport(RevenueCat)
        guard !apiKey.isEmpty else { return }
        Purchases.configure(withAPIKey: apiKey)
        #endif
    }
}

#if canImport(RevenueCat)
import RevenueCat
#endif
#if canImport(SuperwallKit)
import SuperwallKit
#endif
