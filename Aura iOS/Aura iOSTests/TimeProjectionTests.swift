//
//  TimeProjectionTests.swift
//  Aura iOSTests
//
//  The projection formulas + rounding are user-facing claims. They must be exact.
//

import XCTest
@testable import Aura_iOS

final class TimeProjectionTests: XCTestCase {

    func testAnnualDaysFormula() {
        // 5 h/day → 5 * 365 / 24 = 76.04 → 76 days.
        let p = TimeProjection(hoursPerDay: 5)
        XCTAssertEqual(p.annualDaysRaw, 5 * 365.0 / 24, accuracy: 0.0001)
        XCTAssertEqual(p.annualDays, 76)
    }

    func testTenYearDaysAndYears() {
        let p = TimeProjection(hoursPerDay: 5)
        // 76.04 * 10 = 760.4 → 760 days.
        XCTAssertEqual(p.tenYearDays, 760)
        // 760.4 / 365 = 2.083 → 2.1 years (one decimal).
        XCTAssertEqual(p.tenYearYears, 2.1, accuracy: 0.0001)
    }

    func testWakingShare() {
        // 4 h of 16 waking h = 25%.
        let p = TimeProjection(hoursPerDay: 4)
        XCTAssertEqual(p.wakingShareRaw, 0.25, accuracy: 0.0001)
        XCTAssertEqual(p.wakingSharePercent, 25)
    }

    func testReclaimedAnnualDays() {
        // Reclaiming 2 h/day → 2 * 365 / 24 = 30.4 → 30 days.
        XCTAssertEqual(TimeProjection.reclaimedAnnualDays(reductionHoursPerDay: 2), 30)
    }

    func testHalfHourRounding() {
        XCTAssertEqual(TimeProjection.roundedHalfHour(3.2), 3.0, accuracy: 0.0001)
        XCTAssertEqual(TimeProjection.roundedHalfHour(3.3), 3.5, accuracy: 0.0001)
        XCTAssertEqual(TimeProjection.roundedHalfHour(3.75), 4.0, accuracy: 0.0001)
    }

    func testNegativeInputClampsToZero() {
        let p = TimeProjection(hoursPerDay: -3)
        XCTAssertEqual(p.annualDays, 0)
        XCTAssertEqual(p.wakingSharePercent, 0)
    }

    func testHighUsageProjection() {
        // 8 h/day → 8 * 365 / 24 = 121.7 → 122 days; ten-year ≈ 1216.7 → 1217; 3.3 yrs.
        let p = TimeProjection(hoursPerDay: 8)
        XCTAssertEqual(p.annualDays, 122)
        XCTAssertEqual(p.tenYearDays, 1217)
        XCTAssertEqual(p.tenYearYears, 3.3, accuracy: 0.0001)
    }

    func testMerchandisingMathMatchesFounderNumbers() {
        // Annual: $69.99 → $1.34/wk, Save 87%.
        XCTAssertEqual(SubscriptionCatalog.annualPerWeek, Decimal(string: "1.34")!)
        XCTAssertEqual(SubscriptionCatalog.annualSavePercent, 87)
        // Exit: $34.99 → $0.67/wk, 93% off.
        XCTAssertEqual(SubscriptionCatalog.exitPerWeek, Decimal(string: "0.67")!)
        XCTAssertEqual(SubscriptionCatalog.exitSavePercent, 93)
    }
}
