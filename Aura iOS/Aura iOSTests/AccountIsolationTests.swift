import Foundation
import XCTest
@testable import Aura_iOS

@MainActor
final class AccountIsolationTests: XCTestCase {
    private enum RemoteDeleteError: Error { case unavailable }

    /// Every test gets a private directory, defaults suite, identity, and
    /// failure switch. Nothing here reads Application Support, .standard, or a
    /// live account/network service.
    private final class Fixture {
        let ownerA = UUID()
        let ownerB = UUID()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AccountIsolationTests-\(UUID().uuidString)", isDirectory: true)
        let defaultsSuite = "AccountIsolationTests.\(UUID().uuidString)"
        lazy var defaults = UserDefaults(suiteName: defaultsSuite)!

        var currentUserID: UUID?
        var failedOperations: [HabitStore.AccountStorageOperation] = []
        var deleteError: Error?
        private(set) var deletedOwners: [UUID] = []

        init(currentUserID: UUID? = nil) {
            self.currentUserID = currentUserID
        }

        @MainActor
        func store() -> HabitStore {
            HabitStore(
                accountDependencies: .init(
                    rootURL: root,
                    defaults: defaults,
                    currentUserID: { [unowned self] in currentUserID },
                    deleteRemote: { [unowned self] owner in
                        if let deleteError { throw deleteError }
                        deletedOwners.append(owner)
                    },
                    shouldFail: { [unowned self] operation in
                        failedOperations.contains(operation)
                    }
                ),
                startRuntimeServices: false
            )
        }

        func clean() {
            defaults.removePersistentDomain(forName: defaultsSuite)
            try? FileManager.default.removeItem(at: root)
        }
    }

    func testFocusHoursCombineTimersPersistAndNeverCountQuickProofsTwice() {
        let fixture = Fixture(); defer { fixture.clean() }
        let store = fixture.store()
        XCTAssertEqual(store.lifetimeFocusHours, 0)
        store.addDeepFocusSession(durationMinutes: 35, earnedMinutes: 35)
        XCTAssertEqual(store.lifetimeFocusHours, 0)
        store.activeHabitSession = ActiveHabitSession(
            habitName: "Read", habitId: nil, rewardMinutes: 5,
            totalSeconds: 25 * 60, endsAt: .now.addingTimeInterval(-1))
        store.refreshClock()
        XCTAssertEqual(store.lifetimeFocusMinutes, 60)
        XCTAssertEqual(store.lifetimeFocusHours, 1)
        store.refreshClock()
        store.grantScreenTime(minutes: 7, method: .photoTask)
        XCTAssertEqual(store.lifetimeFocusMinutes, 60)
        let restored = fixture.store()
        XCTAssertEqual(restored.lifetimeFocusHours, 1)
        restored.addDeepFocusSession(durationMinutes: 59, earnedMinutes: 59)
        XCTAssertEqual(restored.lifetimeFocusHours, 1)
        restored.addDeepFocusSession(durationMinutes: 1, earnedMinutes: 1)
        XCTAssertEqual(restored.lifetimeFocusHours, 2)
    }

    private let watermarkDay = Date(timeIntervalSince1970: 1_700_000_000)

    func testPendingPurchaseSurvivesRelaunchAndActivatesOnlyOnce() {
        let fixture = Fixture(); defer { fixture.clean() }
        let store = fixture.store()
        store.grantScreenTime(minutes: 30)
        XCTAssertFalse(store.beginPendingScreenTimePurchase(minutes: 31))
        XCTAssertTrue(store.beginPendingScreenTimePurchase(minutes: 10))
        let purchase = try! XCTUnwrap(store.pendingScreenTimePurchase)
        XCTAssertEqual(store.coinBalance, 20)
        XCTAssertFalse(store.isUnlocked)
        XCTAssertFalse(store.beginPendingScreenTimePurchase(minutes: 5))

        let restored = fixture.store()
        XCTAssertEqual(restored.pendingScreenTimePurchase?.id, purchase.id)
        XCTAssertEqual(restored.coinBalance, 20)
        XCTAssertTrue(restored.activatePendingScreenTimePurchase(id: purchase.id))
        let deadline = restored.unlockEndsAt
        XCTAssertNil(restored.pendingScreenTimePurchase)
        XCTAssertFalse(restored.activatePendingScreenTimePurchase(id: purchase.id))
        XCTAssertEqual(restored.unlockEndsAt, deadline)

        let restarted = fixture.store()
        XCTAssertNil(restarted.pendingScreenTimePurchase)
        // Account snapshots use ISO8601 dates with whole-second precision.
        let restoredDeadline = try! XCTUnwrap(restarted.unlockEndsAt)
        let activatedDeadline = try! XCTUnwrap(deadline)
        XCTAssertLessThan(abs(restoredDeadline.timeIntervalSince(activatedDeadline)), 1)
        XCTAssertFalse(restarted.activatePendingScreenTimePurchase(id: purchase.id))
    }

    func testPendingPurchaseAddsToExistingTimeAfterHandoff() {
        let fixture = Fixture(); defer { fixture.clean() }
        let store = fixture.store()
        store.grantScreenTime(minutes: 30)
        store.startPurchasedScreenTime(minutes: 5)
        let oldDeadline = try! XCTUnwrap(store.unlockEndsAt)
        XCTAssertTrue(store.beginPendingScreenTimePurchase(minutes: 10))
        XCTAssertEqual(store.unlockEndsAt, oldDeadline)
        XCTAssertTrue(store.activatePendingScreenTimePurchase(id: store.pendingScreenTimePurchase!.id))
        XCTAssertEqual(store.unlockEndsAt, oldDeadline.addingTimeInterval(600))
        XCTAssertEqual(store.coinBalance, 20)
    }

    func testPreviewClockRestartsAfterIdleWhenTimeIsPurchased() async throws {
        let fixture = Fixture(); defer { fixture.clean() }
        let store = fixture.store()
        store.startPreviewClock()
        try await Task.sleep(for: .milliseconds(1200))
        store.grantScreenTime(minutes: 5)
        XCTAssertTrue(store.beginPendingScreenTimePurchase(minutes: 5))
        XCTAssertTrue(store.activatePendingScreenTimePurchase(id: store.pendingScreenTimePurchase!.id))
        let clockAtActivation = store.now
        try await Task.sleep(for: .milliseconds(1200))
        XCTAssertGreaterThan(store.now, clockAtActivation)
        XCTAssertLessThan(store.secondsRemaining, 300)
        store.debugClearScreenTime()
        XCTAssertFalse(store.isUnlocked)
        XCTAssertNil(store.gateCountdown)
    }

    func testFourPendingPurchasesPreserveEveryPurchasedMinute() {
        let fixture = Fixture(); defer { fixture.clean() }
        let store = fixture.store()
        store.grantScreenTime(minutes: 30)
        var firstDeadline: Date?
        for index in 0..<4 {
            XCTAssertTrue(store.beginPendingScreenTimePurchase(minutes: 5))
            let purchase = try! XCTUnwrap(store.pendingScreenTimePurchase)
            XCTAssertTrue(store.activatePendingScreenTimePurchase(id: purchase.id))
            let deadline = try! XCTUnwrap(store.unlockEndsAt)
            if index == 0 { firstDeadline = deadline }
            XCTAssertEqual(deadline, firstDeadline!.addingTimeInterval(Double(index * 300)))
            XCTAssertFalse(store.activatePendingScreenTimePurchase(id: purchase.id))
        }
        XCTAssertEqual(store.coinBalance, 10)
        XCTAssertEqual(store.purchases.count, 4)
        let restored = fixture.store()
        XCTAssertNil(restored.pendingScreenTimePurchase)
        XCTAssertLessThan(abs(restored.unlockEndsAt!.timeIntervalSince(firstDeadline!.addingTimeInterval(900))), 1)
    }

    func testPendingPurchaseWriteFailureDoesNotChargeOrLoseActivation() {
        let fixture = Fixture(); defer { fixture.clean() }
        let store = fixture.store()
        store.grantScreenTime(minutes: 20)
        fixture.failedOperations = [.writeSnapshot]
        XCTAssertFalse(store.beginPendingScreenTimePurchase(minutes: 10))
        XCTAssertEqual(store.coinBalance, 20)
        XCTAssertNil(store.pendingScreenTimePurchase)
        fixture.failedOperations = []
        XCTAssertTrue(store.beginPendingScreenTimePurchase(minutes: 10))
        let id = store.pendingScreenTimePurchase!.id
        fixture.failedOperations = [.writeSnapshot]
        XCTAssertFalse(store.activatePendingScreenTimePurchase(id: id))
        XCTAssertFalse(store.isUnlocked)
        XCTAssertEqual(store.pendingScreenTimePurchase?.id, id)
        fixture.failedOperations = []
        XCTAssertTrue(store.activatePendingScreenTimePurchase(id: id))
    }

    func testEarningAndPowerUpsNeverStartScreenTime() {
        let fixture = Fixture(); defer { fixture.clean() }
        let store = fixture.store()
        store.grantScreenTime(minutes: 25)
        XCTAssertEqual(store.coinBalance, 25)
        XCTAssertEqual(store.todayEarnedCoins, 25)
        XCTAssertFalse(store.isUnlocked)
        XCTAssertNil(store.gateCountdown)
        XCTAssertEqual(store.claimReachedPowerUps(), 5)
        XCTAssertEqual(store.coinBalance, 30)
        XCTAssertFalse(store.isUnlocked)
        XCTAssertNil(store.claimReachedPowerUps())
    }

    func testSpendingDoesNotReduceDailyProgressOrLosePowerUpEligibility() {
        let fixture = Fixture(); defer { fixture.clean() }
        let store = fixture.store()
        store.grantScreenTime(minutes: 50)
        let progress = store.dailyGoalProgress
        XCTAssertTrue(store.chargeForScreenTime(minutes: 40))
        XCTAssertEqual(store.coinBalance, 10)
        XCTAssertEqual(store.todayEarnedCoins, 50)
        XCTAssertEqual(store.dailyGoalProgress, progress)
        XCTAssertFalse(store.isUnlocked)
        XCTAssertEqual(store.claimReachedPowerUps(), 10)
        XCTAssertEqual(store.claimedPowerUps, [25, 50])
        XCTAssertFalse(store.chargeForScreenTime(minutes: 21))
        store.startPurchasedScreenTime(minutes: 40)
        XCTAssertTrue(store.isUnlocked)
        XCTAssertEqual(store.coinBalance, 20)
        store.grantScreenTime(minutes: 5)
        XCTAssertLessThanOrEqual(store.secondsRemaining, 2400)
    }

    func testHabitAndFocusSessionsCannotReplaceOrOverlap() {
        let fixture = Fixture(); defer { fixture.clean() }
        let store = fixture.store()
        XCTAssertTrue(store.startHabitSession(habitName: "Read", rewardMinutes: 15, sessionMinutes: 15))
        let end = store.activeHabitSession?.endsAt
        XCTAssertFalse(store.startHabitSession(habitName: "Music", rewardMinutes: 30, sessionMinutes: 30))
        XCTAssertFalse(store.startFocusSession(lengthMinutes: 15, isUntimed: false, earnRate: 60))
        XCTAssertEqual(store.activeHabitSession?.habitName, "Read")
        XCTAssertEqual(store.activeHabitSession?.endsAt, end)
        store.toggleHabitSessionPause()
        XCTAssertFalse(store.startFocusSession(lengthMinutes: 15, isUntimed: false, earnRate: 60))
        store.endHabitSession()
        XCTAssertTrue(store.startFocusSession(lengthMinutes: 15, isUntimed: false, earnRate: 60))
        XCTAssertFalse(store.startHabitSession(habitName: "Music", rewardMinutes: 30, sessionMinutes: 30))
        XCTAssertEqual(store.finishFocusSession(banking: false), 0)
        XCTAssertEqual(store.finishFocusSession(banking: true), 0)
        XCTAssertEqual(store.coinBalance, 0)
    }

    func testExtremeFocusStartsWithNoTargetLength() {
        let fixture = Fixture(); defer { fixture.clean() }
        let store = fixture.store()

        XCTAssertTrue(store.startFocusSession(lengthMinutes: 0, isUntimed: true, earnRate: 60))
        XCTAssertTrue(store.activeFocusSession?.isOpenEnded == true)
        XCTAssertEqual(store.activeFocusSession?.lengthMinutes, 0)
        XCTAssertEqual(store.finishFocusSession(banking: true), 0)
        XCTAssertFalse(store.startFocusSession(lengthMinutes: 0, isUntimed: false, earnRate: 60))
        XCTAssertNil(store.activeFocusSession)
    }

    func testCompletedHabitPaysOnceWithoutUnlockingAfterRelaunch() {
        let fixture = Fixture(); defer { fixture.clean() }
        let store = fixture.store()
        XCTAssertTrue(store.startHabitSession(habitName: "Read", rewardMinutes: 15, sessionMinutes: 15))
        store.activeHabitSession?.endsAt = Date().addingTimeInterval(-1)
        store.refreshClock()
        store.refreshClock()
        XCTAssertNil(store.activeHabitSession)
        XCTAssertEqual(store.coinBalance, 15)
        XCTAssertFalse(store.isUnlocked)
        let relaunched = fixture.store()
        relaunched.refreshClock()
        XCTAssertNil(relaunched.activeHabitSession)
        XCTAssertEqual(relaunched.coinBalance, 15)
        XCTAssertFalse(relaunched.isUnlocked)
    }

    private func persist(_ store: HabitStore, purchaseMinutes: Int, watermark: Double) {
        store.purchases = [.init(minutes: purchaseMinutes, date: watermarkDay)]
        store.setAccountHealthWatermarkForTesting(["steps": watermark], day: watermarkDay)
    }

    private func assertAccount(_ store: HabitStore, purchaseMinutes: Int, watermark: Double,
                               file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(store.purchases.map(\.minutes), [purchaseMinutes], file: file, line: line)
        let (amounts, day) = store.accountHealthWatermarkForTesting
        XCTAssertEqual(amounts, ["steps": watermark], file: file, line: line)
        XCTAssertEqual(day, watermarkDay, file: file, line: line)
    }

    func testAccountSwitchRestoresDistinctPurchasesAndHealthWatermarks() {
        let fixture = Fixture(currentUserID: nil); defer { fixture.clean() }
        let store = fixture.store()

        fixture.currentUserID = fixture.ownerA
        XCTAssertTrue(store.activateAccount(fixture.ownerA))
        persist(store, purchaseMinutes: 11, watermark: 125)

        fixture.currentUserID = fixture.ownerB
        XCTAssertTrue(store.activateAccount(fixture.ownerB))
        persist(store, purchaseMinutes: 29, watermark: 640)

        fixture.currentUserID = fixture.ownerA
        XCTAssertTrue(store.activateAccount(fixture.ownerA))
        assertAccount(store, purchaseMinutes: 11, watermark: 125)

        fixture.currentUserID = fixture.ownerB
        XCTAssertTrue(store.activateAccount(fixture.ownerB))
        assertAccount(store, purchaseMinutes: 29, watermark: 640)
    }

    func testAccountRoundTripRestoresProfilePhotoStreakStatsAndCoinBalance() {
        let fixture = Fixture(currentUserID: nil); defer { fixture.clean() }
        let store = fixture.store()
        fixture.currentUserID = fixture.ownerA
        XCTAssertTrue(store.activateAccount(fixture.ownerA))

        store.profileImageData = Data("Jesse-avatar".utf8)
        let habit = try! XCTUnwrap(store.proofHabits.first)
        XCTAssertTrue(store.completeHabitToday(habit: habit))
        store.grantScreenTime(minutes: 25, method: .focus)
        XCTAssertEqual(store.coinBalance, 25)
        XCTAssertEqual(store.lifetimeHealthyHabits, 1)
        XCTAssertEqual(store.streak.currentStreak, 1)

        // This is the same local handoff used by sign-out: activate the signed-
        // out scope, then restore the authenticated owner. It must not use the
        // empty signed-out snapshot as the source for the next login.
        XCTAssertTrue(store.activateAccount(nil))
        XCTAssertEqual(store.coinBalance, 0)
        XCTAssertTrue(store.activateAccount(fixture.ownerA))

        XCTAssertEqual(store.profileImageData, Data("Jesse-avatar".utf8))
        XCTAssertEqual(store.coinBalance, 25)
        XCTAssertEqual(store.lifetimeHealthyHabits, 1)
        XCTAssertEqual(store.streak.currentStreak, 1)
    }

    func testRelaunchRestoresPersistedAccountState() {
        let fixture = Fixture(); defer { fixture.clean() }
        fixture.currentUserID = fixture.ownerA
        let first = fixture.store()
        persist(first, purchaseMinutes: 42, watermark: 900)

        let relaunched = fixture.store()
        assertAccount(relaunched, purchaseMinutes: 42, watermark: 900)
    }

    func testUnreadableSnapshotIsUntouchedUntilExplicitRetryQuarantinesIt() throws {
        let fixture = Fixture(currentUserID: nil); defer { fixture.clean() }
        let original = fixture.store()
        fixture.currentUserID = fixture.ownerA
        XCTAssertTrue(original.activateAccount(fixture.ownerA))
        persist(original, purchaseMinutes: 17, watermark: 300)
        let snapshotURL = try XCTUnwrap(original.accountSnapshotURLForTesting(ownerID: fixture.ownerA))
        let corrupt = Data("not a snapshot".utf8)
        try corrupt.write(to: snapshotURL, options: .atomic)

        let recovered = fixture.store()
        XCTAssertTrue(recovered.accountPersistenceFailed)
        XCTAssertTrue(recovered.purchases.isEmpty)
        XCTAssertEqual(try Data(contentsOf: snapshotURL), corrupt)

        XCTAssertTrue(recovered.retryPendingAccountTransition())
        XCTAssertFalse(recovered.accountPersistenceFailed)
        let directory = snapshotURL.deletingLastPathComponent()
        let archived = try FileManager.default.contentsOfDirectory(at: directory,
                                                                    includingPropertiesForKeys: nil)
        XCTAssertTrue(archived.contains { $0.lastPathComponent.hasPrefix("snapshot-corrupt-") })
        XCTAssertNotEqual(try Data(contentsOf: snapshotURL), corrupt)
    }

    func testFailedSnapshotWriteKeepsRecoveryUntilRetryAndOriginalAccountRestores() {
        let fixture = Fixture(currentUserID: nil); defer { fixture.clean() }
        let store = fixture.store()
        fixture.currentUserID = fixture.ownerA
        XCTAssertTrue(store.activateAccount(fixture.ownerA))
        persist(store, purchaseMinutes: 23, watermark: 450)

        fixture.failedOperations = [.writeSnapshot]
        fixture.currentUserID = fixture.ownerB
        XCTAssertFalse(store.activateAccount(fixture.ownerB))
        XCTAssertTrue(store.accountPersistenceFailed)
        XCTAssertTrue(store.purchases.isEmpty)

        fixture.failedOperations = []
        XCTAssertTrue(store.retryPendingAccountTransition())
        XCTAssertFalse(store.accountPersistenceFailed)
        XCTAssertTrue(store.purchases.isEmpty)

        fixture.currentUserID = fixture.ownerA
        XCTAssertTrue(store.activateAccount(fixture.ownerA))
        assertAccount(store, purchaseMinutes: 23, watermark: 450)
    }

    func testFailedLegacyQuarantinePreservesOriginalFilesUntilRetry() throws {
        let fixture = Fixture(currentUserID: nil); defer { fixture.clean() }
        try FileManager.default.createDirectory(at: fixture.root, withIntermediateDirectories: true)
        let legacy = fixture.root.appendingPathComponent("habits.json")
        let original = Data("legacy habits".utf8)
        try original.write(to: legacy, options: .atomic)
        fixture.failedOperations = [.copyLegacy]
        fixture.currentUserID = fixture.ownerA

        let store = fixture.store()
        XCTAssertTrue(store.accountPersistenceFailed)
        XCTAssertEqual(try Data(contentsOf: legacy), original)

        fixture.failedOperations = []
        XCTAssertTrue(store.retryPendingAccountTransition())
        XCTAssertEqual(try Data(contentsOf: legacy), original)
        let quarantine = fixture.root
            .appendingPathComponent("AuraAccountState", isDirectory: true)
            .appendingPathComponent("legacy-unowned", isDirectory: true)
            .appendingPathComponent("habits.json")
        XCTAssertEqual(try Data(contentsOf: quarantine), original)
    }

    func testFailedRemoteDeleteKeepsOwnerSnapshotAndSuccessfulDeleteLeavesOtherOwner() async throws {
        let fixture = Fixture(currentUserID: nil); defer { fixture.clean() }
        let store = fixture.store()

        fixture.currentUserID = fixture.ownerA
        XCTAssertTrue(store.activateAccount(fixture.ownerA))
        persist(store, purchaseMinutes: 31, watermark: 310)
        let snapshotA = try XCTUnwrap(store.accountSnapshotURLForTesting(ownerID: fixture.ownerA))

        fixture.currentUserID = fixture.ownerB
        XCTAssertTrue(store.activateAccount(fixture.ownerB))
        persist(store, purchaseMinutes: 57, watermark: 570)
        let snapshotB = try XCTUnwrap(store.accountSnapshotURLForTesting(ownerID: fixture.ownerB))

        fixture.currentUserID = fixture.ownerA
        XCTAssertTrue(store.activateAccount(fixture.ownerA))
        fixture.deleteError = RemoteDeleteError.unavailable
        do {
            try await store.deleteAccount()
            XCTFail("A failed remote deletion must be surfaced")
        } catch RemoteDeleteError.unavailable {
            // Expected: the local account is intentionally retained for retry.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: snapshotA.path))
        assertAccount(store, purchaseMinutes: 31, watermark: 310)

        fixture.deleteError = nil
        try await store.deleteAccount()
        XCTAssertEqual(fixture.deletedOwners, [fixture.ownerA])
        XCTAssertFalse(FileManager.default.fileExists(atPath: snapshotA.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: snapshotB.path))

        fixture.currentUserID = fixture.ownerB
        XCTAssertTrue(store.activateAccount(fixture.ownerB))
        assertAccount(store, purchaseMinutes: 57, watermark: 570)
    }

    func testStaleAccountRequestIsRejectedAfterOwnerSwitch() throws {
        let fixture = Fixture(currentUserID: nil); defer { fixture.clean() }
        let store = fixture.store()

        fixture.currentUserID = fixture.ownerA
        XCTAssertTrue(store.activateAccount(fixture.ownerA))
        let request = try XCTUnwrap(store.accountRequest())

        fixture.currentUserID = fixture.ownerB
        XCTAssertTrue(store.activateAccount(fixture.ownerB))
        XCTAssertFalse(store.requestIsCurrent(request))
    }

    func testPhotoRestoreFailureKeepsPreviousActivePhotosUntilRetry() throws {
        let fixture = Fixture(currentUserID: nil); defer { fixture.clean() }
        let store = fixture.store()
        let aFilename = "a-proof.jpg"
        let bFilename = "b-proof.jpg"
        let aData = Data("owner A proof".utf8)
        let bData = Data("owner B proof".utf8)
        let aWin = Win(photo: .captured(aFilename), icon: "FoxHabitRead",
                       habit: "Read", date: watermarkDay)
        let bWin = Win(photo: .captured(bFilename), icon: "FoxHabitGym",
                       habit: "Exercise", date: watermarkDay)

        fixture.currentUserID = fixture.ownerA
        XCTAssertTrue(store.activateAccount(fixture.ownerA))
        XCTAssertTrue(store.setWinsForTesting([aWin], capturedPhotos: [aFilename: aData]))

        fixture.currentUserID = fixture.ownerB
        XCTAssertTrue(store.activateAccount(fixture.ownerB))
        XCTAssertTrue(store.setWinsForTesting([bWin], capturedPhotos: [bFilename: bData]))

        fixture.currentUserID = fixture.ownerA
        XCTAssertTrue(store.activateAccount(fixture.ownerA))
        let activeA = try XCTUnwrap(store.activeWinPhotoURLForTesting(filename: aFilename))
        XCTAssertEqual(try Data(contentsOf: activeA), aData)

        fixture.failedOperations = [.readPhoto]
        fixture.currentUserID = fixture.ownerB
        XCTAssertFalse(store.activateAccount(fixture.ownerB))
        XCTAssertTrue(store.accountPersistenceFailed)
        XCTAssertTrue(store.wins.isEmpty)
        XCTAssertEqual(try Data(contentsOf: activeA), aData)

        fixture.failedOperations = []
        XCTAssertTrue(store.retryPendingAccountTransition())
        XCTAssertEqual(store.wins, [bWin])
        let activeB = try XCTUnwrap(store.activeWinPhotoURLForTesting(filename: bFilename))
        XCTAssertEqual(try Data(contentsOf: activeB), bData)
    }
}
