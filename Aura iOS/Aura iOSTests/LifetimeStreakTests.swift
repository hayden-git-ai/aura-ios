import Foundation
import XCTest
@testable import Aura_iOS

@MainActor
final class LifetimeStreakTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_726_400)
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }
    private func record(_ daysAgo: Int, completions: Int = 1) -> DayRecord {
        DayRecord(date: calendar.date(byAdding: .day, value: -daysAgo,
                                     to: calendar.startOfDay(for: now))!,
                  habitsCompleted: completions)
    }
    func testOldCompletedRecordSurvivesBeyondNinetyDays() {
        let history = (150..<162).map { record($0) } + [record(1), record(0)]
        XCTAssertEqual(HabitStore.lifetimeBestStreak(in: history, now: now, calendar: calendar), 12)
    }
    func testFreezeBridgesGapWithoutCountingMissedDay() {
        let history = [record(200, completions: 2), record(198), record(197)]
        XCTAssertEqual(HabitStore.lifetimeBestStreak(in: history, now: now, calendar: calendar), 3)
    }
    func testGapBeyondFreezeBalanceBreaksRun() {
        let history = [record(200, completions: 2), record(197), record(196)]
        XCTAssertEqual(HabitStore.lifetimeBestStreak(in: history, now: now, calendar: calendar), 2)
    }
    func testEmptyHistoryHasZeroBestStreak() {
        XCTAssertEqual(HabitStore.lifetimeBestStreak(in: [], now: now, calendar: calendar), 0)
    }
}
