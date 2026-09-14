import XCTest
@testable import Aura_iOS

@MainActor
final class SubscriptionIdentityTests: XCTestCase {
    @MainActor private final class Signal {
        private var opened = false
        private var waiters: [CheckedContinuation<Void, Never>] = []
        func wait() async {
            if opened { return }
            await withCheckedContinuation { waiters.append($0) }
        }
        func open() {
            opened = true
            let pending = waiters
            waiters.removeAll()
            pending.forEach { $0.resume() }
        }
    }

    @MainActor private final class Fixture {
        var userID: String? = "A"
        var billingActive = false
        var anonymousReady = true
        var purchased = false
        var purchaseAction: (() async -> Bool)?
        var restoreAction: (() async -> Bool)?
        var webReply: Bool? = false
        var billingReads = 0
        var webReads = 0
        var login: (String) async -> Bool = { _ in true }
        var logout: () async -> Void = {}
        var web: (() async -> Bool?)?
        let identity = SubscriptionIdentityState()
        let suite = "SubscriptionIdentityTests.\(UUID().uuidString)"
        lazy var defaults = UserDefaults(suiteName: suite)!
        lazy var service = LiveEntitlementService(
            dependencies: .init(
                logIn: { [unowned self] in await login($0) },
                logOut: { [unowned self] in await logout() },
                prepareAnonymous: { [unowned self] in anonymousReady },
                appStoreActive: { [unowned self] in billingReads += 1; return billingActive },
                purchase: { [unowned self] in
                    if let purchaseAction { return await purchaseAction() }
                    purchased = true; return true
                },
                restore: { [unowned self] in await restoreAction?() ?? false },
                webActive: { [unowned self] in
                    webReads += 1
                    if let web { return await web() }
                    return webReply
                },
                currentUserID: { [unowned self] in userID },
                identify: { _ in }, reset: {}
            ), defaults: defaults, identity: identity
        )
        func clean() { defaults.removePersistentDomain(forName: suite) }
    }

    func testFirstRunAnonymousPurchaseAndNamedLoginLinking() async {
        let f = Fixture(); defer { f.clean() }
        f.userID = nil
        f.service.configureAnonymous()
        let purchased = await f.service.purchaseDefault()
        XCTAssertTrue(purchased)
        XCTAssertTrue(f.purchased)
        XCTAssertEqual(f.webReads, 0)
        var linked = false
        f.login = { userID in linked = userID == "A" && f.purchased; return true }
        f.userID = "A"
        f.billingActive = true
        f.service.configure(userID: "A")
        let active = await f.service.currentlySubscribed()
        XCTAssertTrue(active)
        XCTAssertTrue(linked)
    }

    func testFailedLogoutCannotEnableAnonymousPurchaseWithNamedSDKIdentity() async {
        let f = Fixture(); defer { f.clean() }
        f.service.configure(userID: "A")
        _ = await f.service.currentlySubscribed()
        f.userID = nil
        await f.service.resetIdentity()
        f.anonymousReady = false
        f.service.configureAnonymous()
        let purchased = await f.service.purchaseDefault()
        XCTAssertFalse(purchased)
        XCTAssertFalse(f.purchased)
        XCTAssertEqual(f.webReads, 1)
    }

    func testRefreshWaitsForBillingLogin() async {
        let f = Fixture(); defer { f.clean() }
        let entered = Signal(), release = Signal()
        f.login = { _ in entered.open(); await release.wait(); return true }
        f.billingActive = true
        f.service.configure(userID: "A")
        let refresh = Task { await f.service.currentlySubscribed() }
        await entered.wait()
        XCTAssertEqual(f.billingReads, 0)
        release.open()
        let active = await refresh.value
        XCTAssertTrue(active)
        XCTAssertEqual(f.billingReads, 1)
        XCTAssertEqual(f.webReads, 0)
    }

    func testAccountSwitchSerializesLoginAndDiscardsOldRefresh() async {
        let f = Fixture(); defer { f.clean() }
        let entered = Signal(), release = Signal()
        var logins: [String] = []
        f.login = { user in
            logins.append(user)
            if user == "A" { entered.open(); await release.wait() }
            return true
        }
        f.billingActive = true
        f.service.configure(userID: "A")
        let readStarted = Signal()
        let oldRefresh = Task {
            readStarted.open()
            return await f.service.currentlySubscribed()
        }
        await entered.wait()
        await readStarted.wait()
        f.userID = "B"
        f.service.configure(userID: "B")
        XCTAssertEqual(logins, ["A"])
        release.open()
        let oldActive = await oldRefresh.value
        let newActive = await f.service.currentlySubscribed()
        XCTAssertFalse(oldActive)
        XCTAssertTrue(newActive)
        XCTAssertEqual(logins, ["A", "B"])
    }

    func testLateWebResponseCannotGrantOrCacheForAnotherAccount() async {
        let f = Fixture(); defer { f.clean() }
        let entered = Signal(), release = Signal()
        f.web = { entered.open(); await release.wait(); return true }
        f.service.configure(userID: "A")
        let oldRefresh = Task { await f.service.currentlySubscribed() }
        await entered.wait()
        f.userID = "B"
        f.service.configure(userID: "B")
        f.web = nil
        f.webReply = nil
        release.open()
        let oldActive = await oldRefresh.value
        let newActive = await f.service.currentlySubscribed()
        XCTAssertFalse(oldActive)
        XCTAssertFalse(newActive)
        XCTAssertFalse(WebEntitlementCache(defaults: f.defaults).fallback(userID: "A"))
    }

    func testLogoutFailureCannotReusePreviousBillingIdentity() async {
        let f = Fixture(); defer { f.clean() }
        f.billingActive = true
        f.service.configure(userID: "A")
        let before = await f.service.currentlySubscribed()
        XCTAssertTrue(before)
        // A failed SDK logout leaves its cached active customer intact.
        f.logout = {}
        f.userID = nil
        await f.service.resetIdentity()
        let signedOut = await f.service.currentlySubscribed()
        XCTAssertFalse(signedOut)
        f.login = { _ in false }
        f.userID = "B"
        f.service.configure(userID: "B")
        let switched = await f.service.currentlySubscribed()
        XCTAssertFalse(switched)
        XCTAssertEqual(f.billingReads, 1)
    }

    func testLatePurchaseAndRestoreCannotGrantAnotherAccount() async {
        for restoring in [false, true] {
            let f = Fixture(); defer { f.clean() }
            let entered = Signal(), release = Signal()
            let operation = { entered.open(); await release.wait(); return true }
            if restoring { f.restoreAction = operation } else { f.purchaseAction = operation }
            f.service.configure(userID: "A")
            let pending = Task {
                if restoring { return await f.service.restore() }
                return await f.service.purchaseDefault()
            }
            await entered.wait()
            f.userID = "B"
            f.service.configure(userID: "B")
            release.open()
            let active = await pending.value
            XCTAssertFalse(active)
        }
    }

    func testWebSubscriberSurvivesBillingFailureAndTransientWebFailure() async {
        let f = Fixture(); defer { f.clean() }
        f.login = { _ in false }
        f.webReply = true
        f.service.configure(userID: "A")
        let confirmed = await f.service.currentlySubscribed()
        f.webReply = nil
        let cached = await f.service.currentlySubscribed()
        XCTAssertTrue(confirmed)
        XCTAssertTrue(cached)
        XCTAssertEqual(f.billingReads, 0)
    }

    func testFailedLoginCanRetryForSameAccount() async {
        let f = Fixture(); defer { f.clean() }
        f.login = { _ in false }
        f.service.configure(userID: "A")
        let failed = await f.service.currentlySubscribed()
        XCTAssertFalse(failed)
        f.login = { _ in true }
        f.billingActive = true
        f.service.configure(userID: "A")
        let retried = await f.service.currentlySubscribed()
        XCTAssertTrue(retried)
    }

    func testWebCacheRequiresOwnerAndUnexpiredConfirmedResult() {
        let f = Fixture(); defer { f.clean() }
        let cache = WebEntitlementCache(defaults: f.defaults)
        let now = Date()
        f.defaults.set(true, forKey: "aura.web.entitlement.active.v1")
        f.defaults.set(now, forKey: "aura.web.entitlement.checkedAt.v1")
        XCTAssertFalse(cache.fallback(userID: "A", now: now))
        cache.record(active: true, userID: "A", now: now)
        XCTAssertTrue(cache.fallback(userID: "A", now: now))
        XCTAssertFalse(cache.fallback(userID: "B", now: now))
        XCTAssertFalse(cache.fallback(userID: "A", now: now.addingTimeInterval(86_400)))
        XCTAssertFalse(cache.fallback(userID: "A", now: now.addingTimeInterval(-1)))
        cache.record(active: false, userID: "A", now: now)
        XCTAssertFalse(cache.fallback(userID: "A", now: now))
        cache.clear()
        XCTAssertNil(f.defaults.object(forKey: "aura.web.entitlement.user.v2"))
    }
}
