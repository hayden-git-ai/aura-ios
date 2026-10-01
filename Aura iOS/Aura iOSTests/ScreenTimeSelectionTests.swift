import XCTest
@testable import Aura_iOS

final class ScreenTimeSelectionTests: XCTestCase {
    private let names = ["AppIconInstagram", "AppIconTikTok", "AppIconX", "AppIconReddit"]

    private func selection(_ names: [String] = [
        "AppIconInstagram", "AppIconTikTok", "AppIconX", "AppIconReddit"
    ]) -> AppSelection {
        AppSelection(token: Data([0xFF]), appCount: names.count,
                     categoryCount: 0, mockIconNames: names)
    }

    func testRemovingEachPositionRemovesExactlyTappedAsset() {
        for name in names {
            let source = AppIconSource.asset(name)
            let remaining = selection().removing(source)

            XCTAssertFalse(remaining.mockIconNames.contains(name), "removed \(name)")
            XCTAssertEqual(remaining.mockIconNames.count, names.count - 1)
            XCTAssertEqual(Set(remaining.mockIconNames), Set(names).subtracting([name]))
        }
    }

    func testRepeatedMutationsPreserveStableIdentityAndOrderOfSurvivors() {
        var current = selection()
        let tapped = [names[0], names[2], names[1]]

        for name in tapped {
            current = current.removing(.asset(name))
        }

        XCTAssertEqual(current.mockIconNames, [names[3]])
        XCTAssertEqual(AppIconSource.asset(names[3]).stableID, "asset:\(names[3])")
    }
}
