//
//  ScreenTimeWeekScene.swift
//  AuraStatsReport
//

import DeviceActivity
import ManagedSettings
import SwiftUI

/// A week of real Screen Time, drawn with the app's own charts.
///
/// `ScreenTimeSummary` and `ScreenTimeDetail` are the same source files the app
/// uses — shared into this target rather than copied, so the two can't drift.
/// All that changes is where the numbers come from: `ScreenTimeSample` in the
/// Simulator, `DeviceActivityResults` here.
///
/// The day selection lives in this process. It has to: state can't cross the
/// extension boundary, so a picker in the app couldn't drive these charts and
/// these charts couldn't drive anything in the app.
struct ScreenTimeWeekScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .screenTimeWeek

    /// Reduces Apple's hourly segments into one real total for each calendar
    /// day. Report data can arrive for more than one device, so it must be
    /// accumulated by date rather than treated as one already-ordered week.
    let content: ([ScreenTimeDay]) -> ScreenTimeWeekView = { ScreenTimeWeekView(week: $0) }

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> [ScreenTimeDay] {
        let calendar = Calendar.current
        let interval = ScreenTimeReportWindow.currentWeek(calendar: calendar)
        let dates = ScreenTimeReportWindow.days(in: interval, calendar: calendar)
        var usage = Dictionary(uniqueKeysWithValues: dates.map {
            (calendar.startOfDay(for: $0), DailyUsage())
        })

        // Read here rather than passed in: a report takes only a context and a
        // filter, so the app has no way to hand this over. It goes through the
        // App Group, same as the monitor's copy.
        let distracting = AuraShared.distractingSelection()?.applicationTokens ?? []

        for await result in data {
            for await segment in result.activitySegments {
                let day = calendar.startOfDay(for: segment.dateInterval.start)
                guard var daily = usage[day] else { continue }
                let hour = min(23, max(0, calendar.component(.hour, from: segment.dateInterval.start)))

                // This is the authoritative total. Application and web rows
                // can be absent or redacted, so they must not be summed to
                // invent the day's headline number.
                daily.hourlySeconds[hour] += segment.totalActivityDuration

                for await category in segment.categories {
                    let categoryName = category.category.localizedDisplayName ?? "Other"

                    for await app in category.applications {
                        let name = app.application.localizedDisplayName ?? "App"
                        let key = app.application.bundleIdentifier ?? name
                        var aggregate = daily.apps[key] ?? DailyUsage.App(
                            icon: key,
                            name: name,
                            category: categoryName,
                            token: app.application.token,
                            isDistracting: app.application.token.map(distracting.contains) ?? false
                        )
                        aggregate.seconds += app.totalActivityDuration
                        aggregate.pickups += app.numberOfPickups
                        daily.apps[key] = aggregate
                    }
                }
                usage[day] = daily
            }
        }

        return dates.map { date in
            let daily = usage[calendar.startOfDay(for: date)] ?? DailyUsage()
            let minutes = DailyUsage.roundedMinuteBuckets(daily.hourlySeconds)
            return ScreenTimeDay(
                date: date,
                // These buckets preserve the real hourly totals. We do not
                // label them with inferred Social/Games categories or expose
                // a category breakdown in the shipping report.
                hourlyBands: minutes.map { HourBands(other: $0) },
                apps: daily.apps.values.map {
                    AppUsage(
                        icon: $0.icon,
                        name: $0.name,
                        category: $0.category,
                        minutes: Int(($0.seconds / 60).rounded()),
                        pickups: $0.pickups,
                        token: $0.token,
                        isDistracting: $0.isDistracting
                    )
                }.sorted { $0.minutes > $1.minutes }
            )
        }
    }
}

private struct DailyUsage {
    struct App {
        let icon: String
        let name: String
        let category: String
        let token: ApplicationToken?
        let isDistracting: Bool
        var seconds: TimeInterval = 0
        var pickups = 0
    }

    var hourlySeconds = [TimeInterval](repeating: 0, count: 24)
    var apps: [String: App] = [:]

    /// Keep the displayed day total faithful to the sum of Apple's segment
    /// durations while still fitting the chart's integer-minute model.
    static func roundedMinuteBuckets(_ seconds: [TimeInterval]) -> [Int] {
        let exact = seconds.map { max(0, $0 / 60) }
        var minutes = exact.map { Int($0.rounded(.down)) }
        let target = Int(exact.reduce(0, +).rounded())
        let extra = max(0, target - minutes.reduce(0, +))
        for index in exact.indices.sorted(by: { exact[$0].truncatingRemainder(dividingBy: 1) > exact[$1].truncatingRemainder(dividingBy: 1) }).prefix(extra) {
            minutes[index] += 1
        }
        return minutes
    }
}

/// The report's real daily totals. Unsupported category and cumulative-detail
/// widgets are intentionally absent rather than filled with estimates.
struct ScreenTimeWeekView: View {
    let week: [ScreenTimeDay]

    @State private var selected = 0

    /// A report extension has no launch hook, and `Typography` reads its faces
    /// out of `Bundle.main` — which here is the appex. Without this the whole
    /// page silently falls back to system type.
    private static let fontsReady: Bool = {
        FontRegistration.registerBundledFonts()
        return true
    }()

    var body: some View {
        let _ = Self.fontsReady

        if week.allSatisfy({ $0.totalMinutes == 0 }) {
            // Authorization not granted, or no data for the window yet. Says so
            // rather than drawing an empty chart that looks like a zero.
            Text("No Screen Time data yet.")
                .auraFont(.body, RowType.label, .medium)
                .foregroundStyle(LightSheet.subtitle)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, Theme.Spacing.xxl)
        } else {
            ScreenTimeSummary(week: week, selected: $selected, plain: true)
                .onAppear {
                    selected = week.firstIndex { Calendar.current.isDateInToday($0.date) }
                        ?? week.indices.last
                        ?? 0
                }
        }
    }
}
