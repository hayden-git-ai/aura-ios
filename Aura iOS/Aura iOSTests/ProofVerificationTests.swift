import Foundation
import XCTest
@testable import Aura_iOS

final class ProofVerificationTests: XCTestCase {
    func testOnlyBooleanPassIsAccepted() throws {
        let passed = try LiveProofVerifier.decodeVerdict(from: Data(#"{"passed":true,"reason":"Visible evidence"}"#.utf8))
        XCTAssertTrue(passed.passed)
        for json in [#"{"passed":"true","reason":""}"#, #"{"passed":1,"reason":""}"#, #"{"reason":""}"#] {
            XCTAssertThrowsError(try LiveProofVerifier.decodeVerdict(from: Data(json.utf8)))
        }
    }

    func testRejectedAndBlockedPhotosCannotPass() throws {
        let rejected = try LiveProofVerifier.decodeVerdict(from: Data(#"{"passed":false,"reason":"Unrelated object","fix":"Show your instrument"}"#.utf8))
        XCTAssertFalse(rejected.passed)
        let blocked = try LiveProofVerifier.decodeVerdict(from: Data(#"{"passed":true,"reason":"","blocked":true}"#.utf8))
        XCTAssertFalse(blocked.passed)
        XCTAssertTrue(blocked.isBlocked)
    }
}
