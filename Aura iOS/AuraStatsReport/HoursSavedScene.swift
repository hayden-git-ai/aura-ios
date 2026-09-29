import DeviceActivity
import SwiftUI

/// Computes a weekly estimate entirely inside the report extension. Usage never
/// crosses back into the host app.
struct HoursSavedScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .hoursSaved
    let content: ([TimeInterval]?) -> HoursSavedSceneView = { HoursSavedSceneView(hours: $0) }

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> [TimeInterval]? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let start = calendar.date(byAdding: .day, value: -14, to: today) else { return nil }
        let dates = (0..<14).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        var totals = Dictionary(uniqueKeysWithValues: dates.map { (calendar.startOfDay(for: $0), 0.0) })
        var seen = Set<Date>()
        for await result in data {
            for await segment in result.activitySegments {
                let day = calendar.startOfDay(for: segment.dateInterval.start)
                guard totals[day] != nil else { continue }
                totals[day, default: 0] += max(0, segment.totalActivityDuration)
                seen.insert(day)
            }
        }
        // Do not compare incomplete seven-day blocks. Keep unavailable data
        // separate from measured zero; the view displays a zero placeholder.
        guard seen.count == 14 else { return nil }
        return dates.map { totals[calendar.startOfDay(for: $0)] ?? 0 }
    }
}

struct HoursSavedSceneView: View {
    let hours: [TimeInterval]?
    private static let fontsReady: Bool = {
        FontRegistration.registerBundledFonts()
        return true
    }()
    var body: some View {
        let _ = Self.fontsReady
        Group {
            if let hours, hours.count == 14 {
                let previous = hours.prefix(7).reduce(0, +)
                let recent = hours.suffix(7).reduce(0, +)
                let saved = max(0, previous - recent) / 3600
                StrokedNumber(text: saved > 0 ? String(format: "%.1fh", saved) : "0",
                              font: Typography.displayUIFont(size: 22, weight: .black, tabular: true),
                              fill: .black, stroke: .white, outlineWidth: 2.2)
                    .fixedSize()
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(format: "%.1f hours saved versus the previous 7 days", saved))
            } else {
                StrokedNumber(text: "0", font: Typography.displayUIFont(size: 22, weight: .black, tabular: true),
                              fill: .black, stroke: .white, outlineWidth: 2.2).fixedSize()
                    .accessibilityLabel("Hours saved unavailable")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        // Once the report extension arrives, cover the host's fallback zero so
        // a real non-zero value never double-renders over it.
        .background(LightSheet.ground)
    }
}
