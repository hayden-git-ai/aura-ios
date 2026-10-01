//
//  ScreenTimeStats.swift
//  Aura iOS
//

import DeviceActivity
import Foundation
import ManagedSettings
import SwiftUI

extension DeviceActivityReport.Context {
    /// The screen-time page of Stats. Declared on both sides — the app asks for
    /// it by name, the extension answers to it.
    static let screenTimeWeek = Self("screenTimeWeek")
    static let hoursSaved = Self("hoursSaved")
}

/// The fixed window requested by the app and reconstructed by the report
/// extension. The report data stays in the extension process; sharing the
/// calendar window only ensures both sides mean the same week.
enum ScreenTimeReportWindow {
    static func currentWeek(containing date: Date = .now, calendar: Calendar = .current) -> DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: date)
            ?? DateInterval(start: calendar.startOfDay(for: date), duration: 7 * 24 * 60 * 60)
    }

    static func days(in interval: DateInterval, calendar: Calendar = .current) -> [Date] {
        let start = calendar.startOfDay(for: interval.start)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
}

/// One app's share of a day.
struct AppUsage: Identifiable, Hashable {
    var id: String { icon }
    /// Asset name for the sample data; a bundle id for real results, where it's
    /// only ever an identity — the artwork comes from `token`.
    let icon: String
    let name: String
    let category: String
    let minutes: Int
    let pickups: Int
    /// Set only by the report extension. The app never has one of these,
    /// because the app never has real usage.
    var token: ApplicationToken? = nil
    /// Whether this app is in the user's Distracting rule.
    ///
    /// Decided where both facts are available at once. The sample data has icon
    /// names to match on; real results have tokens, and the rule they'd be
    /// matched against is only readable inside the extension — so the answer
    /// travels rather than the inputs.
    var isDistracting: Bool? = nil
}

/// A day of Screen Time, as the Stats screen needs it.
///
/// Entirely sample data for now — real figures come from `DeviceActivityReport`
/// once Family Controls is entitled, and Apple only hands those to a report
/// extension, so this shape is what that extension will have to produce.
/// One hour of usage, split into the three bands the Hourly Breakdown draws.
struct HourBands: Hashable {
    var social: Int = 0
    var games: Int = 0
    var other: Int = 0
    var total: Int { social + games + other }
    static let zero = HourBands()
}

struct ScreenTimeDay {
    let date: Date
    /// 24 buckets, each hour split into social / games / other. The report
    /// extension is the only place that can bucket usage by hour AND category,
    /// so the real values arrive here from it; the app only ever has the sample.
    let hourlyBands: [HourBands]
    let apps: [AppUsage]

    /// 24 buckets, minutes per hour — the band totals.
    var hourly: [Int] { hourlyBands.map(\.total) }
    var totalMinutes: Int { hourlyBands.reduce(0) { $0 + $1.total } }

    // Derived from the same bands the bars draw, so the chart and its legend
    // can never disagree.
    var socialMinutes: Int { hourlyBands.reduce(0) { $0 + $1.social } }
    var gamesMinutes: Int { hourlyBands.reduce(0) { $0 + $1.games } }
    var otherMinutes: Int { hourlyBands.reduce(0) { $0 + $1.other } }

    /// Splits the day by the user's own App Lists rather than by a stock
    /// taxonomy — the apps someone chose to block are the ones they consider
    /// the problem, which beats anyone else's idea of "productive".
    func split(brainrot icons: Set<String>) -> (brainrot: Int, rest: Int) {
        let bad = apps
            .filter { $0.isDistracting ?? icons.contains($0.icon) }
            .reduce(0) { $0 + $1.minutes }
        return (bad, max(0, totalMinutes - bad))
    }
}

/// Where a week of screen time comes from.
///
/// The seam Apple's data has to arrive through. `DeviceActivityReport` renders
/// only inside a report extension and never hands its numbers back to the host
/// app, so the real implementation of this lives in that extension and maps
/// `DeviceActivityResults` into the same `ScreenTimeDay` the sample produces.
/// Every view downstream is written against the shape, not the source.
protocol ScreenTimeProviding {
    func week(now: Date) -> [ScreenTimeDay]
}

extension ScreenTimeProviding {
    func week() -> [ScreenTimeDay] { week(now: .now) }
}

/// Sample usage is strictly for Debug builds and previews. Apple does not make
/// real DeviceActivity results available to the app process, so Release must
/// never present this as a person's usage.
enum ScreenTimeDataAvailability {
    static var displaysSampleData: Bool {
#if DEBUG
        true
#else
        false
#endif
    }
}

/// Today's preview implementation. Swapping it is one line at the call site
/// rather than a hunt through the views.
struct SampleScreenTimeProvider: ScreenTimeProviding {
    func week(now: Date) -> [ScreenTimeDay] {
#if DEBUG
        ScreenTimeSample.week(now: now)
#else
        []
#endif
    }
}

enum ScreenTimeSample {
    /// The hour with the most screen time, summed across the week rather than
    /// taken from one day — a single late night shouldn't move it.
    static func peakHour(now: Date = .now) -> Int {
        let totals = week(now: now).reduce(into: Array(repeating: 0, count: 24)) { sum, day in
            for hour in 0..<24 { sum[hour] += day.hourly[hour] }
        }
        return totals.enumerated().max { $0.element < $1.element }?.offset ?? 0
    }

    /// The current week, Sunday first, so the strip lines up with `Calendar`'s
    /// weekday numbering. Days after today come back empty.
    static func week(now: Date = .now) -> [ScreenTimeDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.dateInterval(of: .weekOfYear, for: today)?.start else { return [] }

        return (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: start) ?? start
            let future = date > today
            return ScreenTimeDay(
                date: date,
                hourlyBands: future ? Array(repeating: .zero, count: 24) : hourlyBands(seed: offset),
                apps: future ? [] : apps(seed: offset)
            )
        }
    }

    /// Deterministic from the seed, so the chart doesn't reshuffle on every
    /// redraw the way `random()` would. Each hour's total is split into the three
    /// bands — evenings skew social with some games, work hours skew other — a
    /// stand-in until the report extension emits real per-hour categories.
    private static func hourlyBands(seed: Int) -> [HourBands] {
        // Weighted late: a phone-heavy day builds through the evening.
        let shape: [Int] = [1, 1, 0, 0, 0, 1, 3, 6, 8, 7, 5, 4, 7, 5, 6, 4, 7, 9, 10, 12, 14, 16, 19, 11]
        return shape.enumerated().map { hour, raw in
            let t = max(0, raw - seed % 3)
            guard t > 0 else { return .zero }
            let socialW = (hour >= 18 || (11...13).contains(hour)) ? 0.58 : 0.28
            let gamesW = hour >= 19 ? 0.22 : 0.08
            let social = Int((Double(t) * socialW).rounded())
            let games = Int((Double(t) * gamesW).rounded())
            return HourBands(social: social, games: games, other: max(0, t - social - games))
        }
    }

    private static func apps(seed: Int) -> [AppUsage] {
        let base: [AppUsage] = [
            AppUsage(icon: "AppIconTikTok", name: "TikTok", category: "Social", minutes: 41, pickups: 38),
            AppUsage(icon: "AppIconInstagram", name: "Instagram", category: "Social", minutes: 24, pickups: 19),
            AppUsage(icon: "MessagesIcon", name: "Messages", category: "Utilities", minutes: 16, pickups: 12),
            AppUsage(icon: "AppIconYouTube", name: "YouTube", category: "Entertainment", minutes: 12, pickups: 9),
            AppUsage(icon: "MusicIcon", name: "Music", category: "Entertainment", minutes: 7, pickups: 2),
        ]
        return base.map {
            AppUsage(icon: $0.icon, name: $0.name, category: $0.category,
                     minutes: max(1, $0.minutes - seed * 2),
                     pickups: max(1, $0.pickups - seed))
        }
    }

    /// Stand-in for the previous week's total, so the trend badge has
    /// something to measure against. TODO: real once a per-day log exists —
    /// nothing in the store records history yet.
    static func previousWeekTotal(_ week: [ScreenTimeDay]) -> Int {
        Int(Double(week.reduce(0) { $0 + $1.totalMinutes }) * 0.82)
    }

    /// Stand-in for last week's brainrot share, so the split card can show
    /// whether the mix is improving. TODO: real with a per-day log.
    static func previousBrainrotShare(_ current: Int) -> Int { current + 4 }

    /// Percentage change, rounded, guarding the divide.
    static func delta(current: Int, previous: Int) -> Int {
        guard previous > 0 else { return current > 0 ? 100 : 0 }
        return Int((Double(current - previous) / Double(previous) * 100).rounded())
    }

    static func durationLabel(_ minutes: Int) -> String {
        minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
}

/// Lifetime average daily reduction. Usage is evaluated only inside the report;
/// the host shares the requested dates, never reads or persists usage totals.
enum LifetimeHoursSaved {
    static func window(accountStart: Date, now: Date = .now,
                       calendar: Calendar = .current) -> DateInterval {
        let joined = calendar.startOfDay(for: accountStart)
        let baselineStart = calendar.date(byAdding: .day, value: -7, to: joined) ?? joined
        return DateInterval(start: baselineStart, end: max(joined, calendar.startOfDay(for: now)))
    }

    /// The first seven requested days are the pre-Aura baseline. Every remaining
    /// completed day is part of the lifetime average, including measured zero.
    /// Missing dates are not zero usage: incomplete history returns unavailable.
    static func averageHoursPerDay(totals: [Date: TimeInterval], window: DateInterval,
                                   calendar: Calendar = .current) -> Double? {
        let start = calendar.startOfDay(for: window.start)
        let end = calendar.startOfDay(for: window.end)
        let count = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        guard count > 7 else { return nil }
        var baseline = 0.0, lifetime = 0.0
        for index in 0..<count {
            guard let day = calendar.date(byAdding: .day, value: index, to: start),
                  let total = totals[day], total.isFinite, total >= 0 else { return nil }
            if index < 7 { baseline += total }
            else { lifetime += total }
        }
        return max(0, baseline / 7 - lifetime / Double(count - 7)) / 3600
    }
}
