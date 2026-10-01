import DeviceActivity
import SwiftUI

/// Computes the lifetime daily average reduction entirely inside the extension.
/// The requested interval carries the account's date boundary without a shared
/// storage channel. Missing historical coverage must never become invented use.
struct HoursSavedScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .hoursSaved
    let content: (Double?) -> HoursSavedSceneView = { HoursSavedSceneView(hours: $0) }

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> Double? {
        let calendar = Calendar.current
        var requestedWindow: DateInterval?
        var totals: [Date: TimeInterval] = [:]
        for await result in data {
            guard case let .daily(during: interval) = result.segmentInterval else { return nil }
            if let requestedWindow, requestedWindow != interval { return nil }
            requestedWindow = interval
            for await segment in result.activitySegments {
                let day = calendar.startOfDay(for: segment.dateInterval.start)
                guard day >= interval.start, day < interval.end else { continue }
                guard segment.totalActivityDuration.isFinite,
                      segment.totalActivityDuration >= 0 else { return nil }
                totals[day, default: 0] += segment.totalActivityDuration
            }
        }
        guard let requestedWindow else { return nil }
        return LifetimeHoursSaved.averageHoursPerDay(totals: totals, window: requestedWindow,
                                                    calendar: calendar)
    }
}

struct HoursSavedSceneView: View {
    let hours: Double?
    private static let fontsReady: Bool = {
        FontRegistration.registerBundledFonts()
        return true
    }()
    private var savedHours: String {
        guard let hours, hours > 0 else { return "0" }
        if hours < 0.05 { return "<0.1" }
        return hours.formatted(.number.precision(.fractionLength(1)))
    }

    var body: some View {
        let _ = Self.fontsReady
        // DeviceActivityReport is a remotely rendered SwiftUI scene. Use
        // native Text here instead of the host app's UIKit-backed UILabel.
        Text("\(savedHours)")
            .font(Typography.display(size: 22, weight: .black))
            .monospacedDigit()
            .foregroundStyle(.black)
            .shadow(color: .white, radius: 0, x: -2, y: 0)
            .shadow(color: .white, radius: 0, x: 2, y: 0)
            .shadow(color: .white, radius: 0, x: 0, y: -2)
            .shadow(color: .white, radius: 0, x: 0, y: 2)
            // A compact opaque backing replaces the host zero only when this
            // scene exists, without covering the full clock sticker.
            .padding(.horizontal, Theme.Spacing.xs)
            .background(LightSheet.ground)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .accessibilityLabel(hours == nil ? "0 hours saved per day. Lifetime average unavailable until complete history is available." : "\(savedHours) average hours saved per day over your Aura lifetime, compared with the seven days before joining.")
    }
}
