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

    private let watermarkDay = Date(timeIntervalSince1970: 1_700_000_000)

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
