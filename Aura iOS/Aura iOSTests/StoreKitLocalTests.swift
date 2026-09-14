import StoreKit
import StoreKitTest
import XCTest

/// Native StoreKit 2 regression coverage backed only by Aura.storekit.
/// These tests never configure RevenueCat or Superwall and never contact App Store Connect.
@MainActor
final class StoreKitLocalTests: XCTestCase {
    private static let optInEnvironmentVariable = "AURA_RUN_LOCAL_STOREKIT_TESTS"
    private static let annualID = "aura_annual"
    private static let weeklyID = "aura_weekly"
    private static let productIDs: Set<String> = [annualID, weeklyID]

    private var session: SKTestSession!

    override func setUpWithError() throws {
        try super.setUpWithError()

        guard ProcessInfo.processInfo.environment[Self.optInEnvironmentVariable] == "1" else {
            throw XCTSkip(
                "Local StoreKit tests are opt-in. Set \(Self.optInEnvironmentVariable)=1 and run on a simulator runtime where SKTestSession is available."
            )
        }

        // XCTest rounds this to one minute. The opted-in command must also enable
        // test timeouts so an unexpected StoreKit framework hang cannot stall CI.
        executionTimeAllowance = 60

        let configurationURL = try XCTUnwrap(
            Bundle(for: StoreKitLocalTests.self).url(forResource: "Aura", withExtension: "storekit"),
            "Add the existing Aura.storekit file to the Aura iOSTests target's Copy Bundle Resources phase."
        )
        session = try SKTestSession(contentsOf: configurationURL)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        session.timeRate = .realTime

        try requireActiveLocalStoreKitSession()
    }

    /// Exercise a throwing StoreKitTest mutation without creating an entitlement.
    /// An active session reports the expected "no transaction" error. If Xcode did
    /// not connect the configuration to storekitd, this instead surfaces the
    /// underlying SKInternalErrorDomain failure before a purchase can hang.
    private func requireActiveLocalStoreKitSession() throws {
        do {
            try session.deleteTransaction(identifier: 0)
            throw NSError(
                domain: "Aura.StoreKitLocalTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "StoreKitTest unexpectedly deleted transaction 0 during its availability probe."]
            )
        } catch {
            let nsError = error as NSError
            if nsError.domain == SKTestErrorDomain,
               nsError.code == 6 { // SKTestErrorCode.noTransactionFound
                return
            }

            throw NSError(
                domain: "Aura.StoreKitLocalTests",
                code: 2,
                userInfo: [
                    NSLocalizedDescriptionKey: "Local StoreKit session is unavailable; refusing to call a purchase API that may fall through to the App Store.",
                    NSUnderlyingErrorKey: error,
                ]
            )
        }
    }

    override func tearDownWithError() throws {
        session?.clearTransactions()
        session?.resetToDefaultState()
        session = nil
        try super.tearDownWithError()
    }

    func testProductsLoadWithLaunchPricingAndNoIntroductoryOffer() async throws {
        let products = try await Product.products(for: Self.productIDs)
        XCTAssertEqual(Set(products.map(\.id)), Self.productIDs)

        let annual = try XCTUnwrap(products.first { $0.id == Self.annualID })
        XCTAssertEqual(annual.type, .autoRenewable)
        XCTAssertEqual(annual.price, Decimal(string: "69.99"))
        XCTAssertEqual(annual.subscription?.subscriptionPeriod.unit, .year)
        XCTAssertEqual(annual.subscription?.subscriptionPeriod.value, 1)
        XCTAssertNil(annual.subscription?.introductoryOffer)

        let weekly = try XCTUnwrap(products.first { $0.id == Self.weeklyID })
        XCTAssertEqual(weekly.type, .autoRenewable)
        XCTAssertEqual(weekly.price, Decimal(string: "9.99"))
        XCTAssertEqual(weekly.subscription?.subscriptionPeriod.unit, .week)
        XCTAssertEqual(weekly.subscription?.subscriptionPeriod.value, 1)
        XCTAssertNil(weekly.subscription?.introductoryOffer)
    }

    func testProductPurchaseCreatesVerifiedCurrentEntitlement() async throws {
        let annual = try await product(Self.annualID)
        let result = try await annual.purchase()

        let transaction: Transaction
        switch result {
        case .success(let verification):
            transaction = try verified(verification)
        case .pending:
            return XCTFail("Local purchase unexpectedly became pending")
        case .userCancelled:
            return XCTFail("Local purchase unexpectedly reported cancellation")
        @unknown default:
            return XCTFail("Unknown purchase result")
        }

        XCTAssertEqual(transaction.productID, Self.annualID)
        await transaction.finish()
        let isEntitled = await eventuallyEntitled(to: Self.annualID)
        XCTAssertTrue(isEntitled)
    }

    func testUserCancelledPurchaseCreatesNoTransactionOrEntitlement() async throws {
        try await session.setSimulatedError(
            SKTestFailures.Purchase.generic(StoreKitError.userCancelled),
            forAPI: StoreKitPurchaseAPI()
        )

        let weekly = try await product(Self.weeklyID)
        do {
            switch try await weekly.purchase() {
            case .userCancelled:
                break
            case .pending:
                XCTFail("Cancellation simulation unexpectedly became pending")
            case .success:
                XCTFail("Cancellation simulation unexpectedly purchased")
            @unknown default:
                XCTFail("Unknown purchase result")
            }
        } catch StoreKitError.userCancelled {
            // Some StoreKit versions surface the injected cancellation as an error
            // while others return Product.PurchaseResult.userCancelled.
        }

        XCTAssertTrue(session.allTransactions().isEmpty)
        let isEntitled = await isCurrentlyEntitled(to: Self.weeklyID)
        XCTAssertFalse(isEntitled)
    }

    func testCancellingRenewalKeepsAccessUntilExpiration() async throws {
        let transaction = try await session.buyProduct(identifier: Self.weeklyID)
        let testTransaction = try localTransaction(id: transaction.id)

        try session.disableAutoRenewForTransaction(identifier: testTransaction.identifier)

        let updated = try XCTUnwrap(
            session.allTransactions().first { UInt64($0.identifier) == transaction.id }
        )
        XCTAssertFalse(updated.autoRenewingEnabled)
        let isEntitled = await eventuallyEntitled(to: Self.weeklyID)
        XCTAssertTrue(isEntitled)
    }

    func testExpiredSubscriptionLeavesCurrentEntitlements() async throws {
        let transaction = try await session.buyProduct(identifier: Self.weeklyID)
        let testTransaction = try localTransaction(id: transaction.id)
        try session.disableAutoRenewForTransaction(identifier: testTransaction.identifier)
        try session.expireSubscription(productIdentifier: Self.weeklyID)

        let isExpired = await eventuallyNotEntitled(to: Self.weeklyID)
        XCTAssertTrue(isExpired)
    }

    func testAppStoreSyncPreservesOriginalPurchasedEntitlement() async throws {
        let purchased = try await session.buyProduct(identifier: Self.annualID)
        await purchased.finish()

        try await AppStore.sync()

        let restored = try await currentEntitlement(for: Self.annualID)
        XCTAssertEqual(restored?.originalID, purchased.originalID)
        XCTAssertEqual(restored?.productID, Self.annualID)
    }

    private func product(_ id: String) async throws -> Product {
        let products = try await Product.products(for: [id])
        return try XCTUnwrap(products.first)
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): return value
        case .unverified(_, let error): throw error
        }
    }

    private func localTransaction(id: UInt64) throws -> SKTestTransaction {
        try XCTUnwrap(session.allTransactions().first { UInt64($0.identifier) == id })
    }

    private func currentEntitlement(for productID: String) async throws -> Transaction? {
        for await result in Transaction.currentEntitlements(for: productID) {
            return try verified(result)
        }
        return nil
    }

    private func isCurrentlyEntitled(to productID: String) async -> Bool {
        (try? await currentEntitlement(for: productID)) != nil
    }

    private func eventuallyEntitled(to productID: String) async -> Bool {
        await eventually { await self.isCurrentlyEntitled(to: productID) }
    }

    private func eventuallyNotEntitled(to productID: String) async -> Bool {
        await eventually { !(await self.isCurrentlyEntitled(to: productID)) }
    }

    private func eventually(
        timeout: Duration = .seconds(3),
        condition: () async -> Bool
    ) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            if await condition() { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return await condition()
    }
}
