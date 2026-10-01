import Foundation
import XCTest
@testable import Aura_iOS

final class LifetimeHoursSavedTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }
    private let start = Date(timeIntervalSince1970: 1_700_006_400)

    private func fixture(_ dailyHours: [Double]) -> (totals: [Date: TimeInterval], window: DateInterval) {
        let first = calendar.startOfDay(for: start)
        let totals = Dictionary(uniqueKeysWithValues: dailyHours.enumerated().map { index, hours in
            (calendar.date(byAdding: .day, value: index, to: first)!, hours * 3600)
        })
        return (totals, DateInterval(start: first, end: calendar.date(byAdding: .day, value: dailyHours.count, to: first)!))
    }
    func testUsesEveryLifetimeDayRatherThanLatestWeek() {
        let data = fixture(Array(repeating: 4, count: 7) + Array(repeating: 2, count: 14) + Array(repeating: 4, count: 7))
        let value = LifetimeHoursSaved.averageHoursPerDay(totals: data.totals, window: data.window, calendar: calendar)
        XCTAssertEqual(value!, 4.0 / 3.0, accuracy: 0.00001)
    }
    func testMissingHistoricalDayIsUnavailableRatherThanZeroUsage() {
        var data = fixture(Array(repeating: 4, count: 7) + Array(repeating: 2, count: 30))
        data.totals.removeValue(forKey: calendar.date(byAdding: .day, value: 12, to: data.window.start)!)
        XCTAssertNil(LifetimeHoursSaved.averageHoursPerDay(totals: data.totals, window: data.window, calendar: calendar))
    }
    func testMeasuredZeroDaysAreIncluded() {
        let data = fixture(Array(repeating: 4, count: 7) + [0, 2])
        XCTAssertEqual(LifetimeHoursSaved.averageHoursPerDay(totals: data.totals, window: data.window, calendar: calendar), 3)
    }
    func testIncreasedUsageHasZeroSavings() {
        let data = fixture(Array(repeating: 2, count: 7) + [4, 5])
        XCTAssertEqual(LifetimeHoursSaved.averageHoursPerDay(totals: data.totals, window: data.window, calendar: calendar), 0)
    }
    func testNoCompletedAccountDaysIsUnavailable() {
        let data = fixture(Array(repeating: 4, count: 7))
        XCTAssertNil(LifetimeHoursSaved.averageHoursPerDay(totals: data.totals, window: data.window, calendar: calendar))
    }
    func testRequestedWindowStartsSevenDaysBeforeJoiningAndExcludesToday() {
        let joined = calendar.startOfDay(for: start)
        let now = calendar.date(byAdding: .day, value: 30, to: joined)!.addingTimeInterval(4000)
        let window = LifetimeHoursSaved.window(accountStart: joined, now: now, calendar: calendar)
        XCTAssertEqual(calendar.dateComponents([.day], from: window.start, to: joined).day, 7)
        XCTAssertEqual(window.end, calendar.startOfDay(for: now))
    }
}
