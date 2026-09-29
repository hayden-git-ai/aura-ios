import XCTest
@testable import Aura_iOS

@MainActor
final class SetupFlowTests: XCTestCase {
    func testScreenTimeGrantAdvancesToPicker() async {
        let screenTime = MockScreenTimeService(authBehavior: .grant)
        let flow = SetupFlow(notifications: NotificationStub(), screenTime: screenTime)
        flow.step = .screenTime

        await flow.requestScreenTime()

        XCTAssertEqual(flow.screenTimeStatus, .authorized)
        XCTAssertEqual(flow.step, .appPicker)
    }

    func testScreenTimeDenialStaysOnRecoveryScreen() async {
        let screenTime = MockScreenTimeService(authBehavior: .deny)
        let flow = SetupFlow(notifications: NotificationStub(), screenTime: screenTime)
        flow.step = .screenTime

        await flow.requestScreenTime()

        XCTAssertEqual(flow.screenTimeStatus, .denied)
        XCTAssertEqual(flow.step, .screenTime)
    }

    func testCompletionHandsSelectedAppsToGate() {
        let flow = SetupFlow(notifications: NotificationStub(),
                             screenTime: MockScreenTimeService())
        let token = Data([0xA, 0xB])
        flow.step = .allSet
        flow.selection = AppSelectionResult(token: token, appCount: 2,
                                             categoryCount: 1,
                                             mockIconNames: ["Instagram", "TikTok"])
        var completed: AppSelection?
        flow.onFinish = { completed = $0 }

        flow.advance()

        XCTAssertEqual(completed?.token, token)
        XCTAssertEqual(completed?.appCount, 2)
        XCTAssertEqual(completed?.categoryCount, 1)
        XCTAssertEqual(completed?.mockIconNames, ["Instagram", "TikTok"])
    }

    func testCompletionRefusesAnEmptySelection() {
        let flow = SetupFlow(notifications: NotificationStub(),
                             screenTime: MockScreenTimeService())
        flow.step = .allSet
        var completed = false
        flow.onFinish = { _ in completed = true }

        flow.advance()

        XCTAssertFalse(completed)
    }

    func testDeepFocusPaysOneCoinPerFocusedMinute() {
        let config = DeepFocusConfig(lengthMinutes: 15)
        XCTAssertEqual(config.earnedMinutes, 15)
        XCTAssertEqual(config.earnedMinutes(forElapsedSeconds: 15 * 60), 15)
    }

    func testLegacyActiveFocusRateCannotUnderpay() {
        let started = Date(timeIntervalSince1970: 1_000)
        let session = ActiveFocusSession(startedAt: started,
                                         endsAt: started.addingTimeInterval(15 * 60),
                                         lengthMinutes: 15,
                                         earnRate: 10)
        XCTAssertEqual(session.earnedMinutes(at: started.addingTimeInterval(15 * 60)), 15)
    }

    func testProfileNamesAllowSingleNamesAndNormalizeWhitespace() {
        XCTAssertTrue(ProfileIdentity.isValidName("Hayden"))
        XCTAssertTrue(ProfileIdentity.isValidName("李明"))
        XCTAssertFalse(ProfileIdentity.isValidName("  ?  "))
        XCTAssertFalse(ProfileIdentity.isValidName("A"))
        XCTAssertEqual(ProfileIdentity.normalizedName("  Hayden\n  Berio  "), "Hayden Berio")
    }

    func testProfileInitialsUseFirstAndLastOrTwoFirstNameLetters() {
        XCTAssertEqual(ProfileIdentity.initials(for: "Hayden Middle Berio"), "HB")
        XCTAssertEqual(ProfileIdentity.initials(for: "Hayden"), "HA")
        XCTAssertEqual(ProfileIdentity.initials(for: "李明"), "李明")
        XCTAssertEqual(ProfileIdentity.initials(for: ""), "AU")
    }
}

private final class NotificationStub: NotificationService {
    var authorizationStatus: PermissionStatus = .notDetermined

    func requestAuthorization() async -> PermissionStatus {
        authorizationStatus
    }

    func scheduleReminders(choice: ReminderChoice, vulnerableTime: VulnerableTime?) async {}
}
