//
//  TimeProjection.swift
//  Aura iOS
//
//  Pure, testable projection math for the time-cost phase (Screens 16–21).
//  Formulas and rounding are fixed by the master implementation prompt's
//  "Calculation rules". Projections are framed as projections; every consuming
//  screen shows the assumptions line. No side effects — unit-tested directly.
//

import Foundation

struct TimeProjection: Equatable {

    /// Assumed waking hours per day (the daily-share denominator). Labeled on-screen.
    static let wakingHoursPerDay: Double = 16
    static let daysPerYear: Double = 365

    let hoursPerDay: Double

    init(hoursPerDay: Double) {
        // Guard against negative input; upstream clamps to the estimate range.
        self.hoursPerDay = max(0, hoursPerDay)
    }

    // MARK: - Raw formulas (Double; the tested core)

    /// Full 24-hour days spent scrolling in a year: H × 365 ÷ 24.
    var annualDaysRaw: Double { hoursPerDay * Self.daysPerYear / 24 }

    /// Ten-year full days: annual days × 10.
    var tenYearDaysRaw: Double { annualDaysRaw * 10 }

    /// Ten-year equivalent in years: ten-year days ÷ 365.
    var tenYearYearsRaw: Double { tenYearDaysRaw / Self.daysPerYear }

    /// Share of waking time, assuming 16 waking hours: H ÷ 16 (0…1+).
    var wakingShareRaw: Double { hoursPerDay / Self.wakingHoursPerDay }

    /// Reclaimed full days per year for a reduction of `reductionHoursPerDay`.
    static func reclaimedAnnualDaysRaw(reductionHoursPerDay: Double) -> Double {
        max(0, reductionHoursPerDay) * daysPerYear / 24
    }

    // MARK: - Rounded display values

    /// Days rounded to the nearest whole day.
    var annualDays: Int { Int(annualDaysRaw.rounded()) }
    var tenYearDays: Int { Int(tenYearDaysRaw.rounded()) }

    /// Years to one decimal place (max).
    var tenYearYears: Double { (tenYearYearsRaw * 10).rounded() / 10 }

    /// Whole-percent share of waking time.
    var wakingSharePercent: Int { Int((wakingShareRaw * 100).rounded()) }

    /// Hours rounded to the nearest half hour (for values derived from a range).
    static func roundedHalfHour(_ hours: Double) -> Double {
        (hours * 2).rounded() / 2
    }

    static func reclaimedAnnualDays(reductionHoursPerDay: Double) -> Int {
        Int(reclaimedAnnualDaysRaw(reductionHoursPerDay: reductionHoursPerDay).rounded())
    }

    // MARK: - Disclosure copy

    /// The "How this is calculated" plain-language line for the annual/ten-year
    /// projections.
    var assumptionsText: String {
        let h = Self.roundedHalfHour(hoursPerDay)
        let hStr = h == h.rounded() ? String(Int(h)) : String(format: "%.1f", h)
        return "Projection based on \(hStr) hours a day, every day, across \(Int(Self.daysPerYear)) days. It assumes \(Int(Self.wakingHoursPerDay)) waking hours. It's a projection, not a prediction."
    }
}
