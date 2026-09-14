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

    func testDisclosureNamesBothPossibleVerificationProviders() {
        XCTAssertTrue(PhotoProofAIConsent.disclosure.contains("Google Gemini"))
        XCTAssertTrue(PhotoProofAIConsent.disclosure.contains("OpenAI"))
    }
}
