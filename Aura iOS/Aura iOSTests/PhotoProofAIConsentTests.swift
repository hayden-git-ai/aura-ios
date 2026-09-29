import Foundation
import XCTest
@testable import Aura_iOS

final class PhotoProofAIConsentTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        suiteName = "PhotoProofAIConsentTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
    }

    func testExistingUserWithoutConsentIsNotGranted() {
        XCTAssertFalse(PhotoProofAIConsent.isGranted(for: UUID(), defaults: defaults))
    }

    func testGrantIsScopedToCurrentUserAndDoesNotTransferToAnotherUser() {
        let grantingUser = UUID()

        PhotoProofAIConsent.grant(for: grantingUser, defaults: defaults)

        XCTAssertTrue(PhotoProofAIConsent.isGranted(for: grantingUser, defaults: defaults))
        XCTAssertFalse(PhotoProofAIConsent.isGranted(for: UUID(), defaults: defaults))
        XCTAssertFalse(PhotoProofAIConsent.isGranted(for: nil, defaults: defaults))
    }

    func testSignedOutGrantDoesNotTransferToSignedInUser() {
        PhotoProofAIConsent.grant(for: nil, defaults: defaults)

        XCTAssertTrue(PhotoProofAIConsent.isGranted(for: nil, defaults: defaults))
        XCTAssertFalse(PhotoProofAIConsent.isGranted(for: UUID(), defaults: defaults))
    }

    func testRevocationPersistsAndDoesNotRevokeAnotherAccount() {
        let user = UUID()
        let otherUser = UUID()
        PhotoProofAIConsent.grant(for: user, defaults: defaults)
        PhotoProofAIConsent.grant(for: otherUser, defaults: defaults)

        PhotoProofAIConsent.revoke(for: user, defaults: defaults)

        let reloaded = UserDefaults(suiteName: suiteName)!
        XCTAssertFalse(PhotoProofAIConsent.isGranted(for: user, defaults: reloaded))
        XCTAssertTrue(PhotoProofAIConsent.isGranted(for: otherUser, defaults: reloaded))
    }
}
