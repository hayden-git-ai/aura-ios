//
//  SubscriptionCatalog.swift
//  Aura iOS
//
//  Single source of truth for subscription product identifiers and merchandising
//  math. Prices are fetched from StoreKit at runtime (localized price is
//  authoritative); the values here are the acceptance-test / fallback figures and
//  the intended merchandising, per the founder-final decisions.
//
//  Founder-final (master implementation prompt):
//   • Annual:  $69.99/year  → $1.34/week, "Save 87%"
//   • Weekly:  $9.99/week
//   • Exit:    93% off → $0.67/week, billed $34.99/year
//
//  "Save 87%" and "93% off" compare annual pricing against paying $9.99/week for
//  52 weeks. That comparison is kept explicit here so the displayed percentages
//  stay mathematically valid if products change.
//

import Foundation

/// Merchandising figures + savings math. All percentages derive from the
/// weekly-for-52-weeks reference so they never drift from the prices.
enum SubscriptionCatalog {

    // Acceptance-test / fallback prices (USD). StoreKit overrides at runtime.
    static let annualPrice: Decimal = 69.99
    static let weeklyPrice: Decimal = 9.99
    static let exitAnnualPrice: Decimal = 34.99
    static let weeksPerYear: Decimal = 52

    /// Reference cost of a year paid weekly — the anchor both savings claims use.
    static var weeklyYearReference: Decimal { weeklyPrice * weeksPerYear }

    /// Per-week equivalent of an annual price, truncated to cents for display.
    /// Truncation (not rounding) matches the founder figures: 69.99/52 = 1.3459 →
    /// $1.34, and 34.99/52 = 0.6729 → $0.67.
    static func perWeek(annual: Decimal) -> Decimal {
        truncatedCents(annual / weeksPerYear)
    }

    /// Whole-percent savings of an annual price vs paying weekly for a year.
    static func savePercent(annual: Decimal) -> Int {
        let ratio = (annual as NSDecimalNumber).doubleValue
            / (weeklyYearReference as NSDecimalNumber).doubleValue
        return Int(((1 - ratio) * 100).rounded())
    }

    // Convenience derived values for the primary + exit offers.
    static var annualPerWeek: Decimal { perWeek(annual: annualPrice) }        // 1.34
    static var annualSavePercent: Int { savePercent(annual: annualPrice) }    // 87
    static var exitPerWeek: Decimal { perWeek(annual: exitAnnualPrice) }      // 0.67
    static var exitSavePercent: Int { savePercent(annual: exitAnnualPrice) }  // 93

    private static func truncatedCents(_ value: Decimal) -> Decimal {
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, 2, .down)
        return result
    }
}

/// A subscription product surfaced to the paywall. In production the price strings
/// come from StoreKit's localized `displayPrice`; the Mock supplies the fallback
/// figures above.
struct SubscriptionProduct: Identifiable, Hashable {
    let id: String
    let plan: SelectedPlan
    /// Localized price string (StoreKit `displayPrice` in production).
    let displayPrice: String
    let perWeekDisplay: String
    let isExitOffer: Bool
}
