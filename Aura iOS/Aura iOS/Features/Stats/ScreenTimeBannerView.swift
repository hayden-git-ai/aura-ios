//
//  ScreenTimeBannerView.swift
//  Aura iOS
//
//  Pulled out of StatsView so it can render inside the report extension. On a
//  device the whole screen-time page is drawn over there, and a banner left
//  behind in the app would have had no numbers to show.
//

import SwiftUI

/// What the phone cost this week, under the chart.
struct ScreenTimeBanner: View {
    let week: [ScreenTimeDay]

    var body: some View {
    
        let total = week.reduce(0) { $0 + $1.totalMinutes }
        // 16 waking hours a day is an assumption, and the only one on this
        // screen — swap for a measured comparison if it ever reads as invented.
        let wakingShare = Int((Double(total) / (16 * 60 * 7) * 100).rounded())

        return VStack(spacing: 0) {
            Image("StatsScreenTime")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                // Same size as the Home screen fox (220).
                .frame(height: 220)
                .measuringMiddle()
                // The Home screen's contact shadow — the same solid oval under his
                // feet. Fixed opacity (the stats field is one blue, not day/night).
                .background(alignment: .bottom) {
                    Ellipse()
                        .fill(Color.black.opacity(0.10))
                        .frame(width: 112, height: 30)
                        .offset(y: -11)
                }

            Text(StatsBannerText.emphasised("You gave ", ScreenTimeSample.durationLabel(total),
                                 " to your phone this week."))
                .auraFont(.display, SheetType.banner, .semibold)
            // The curve now lands on the icon's middle, so everything from the
            // sentence down is on the light surface. The emphasis went from
            // white-heavier to blue: white had full contrast on the blue field
            // and none at all here.
            .foregroundStyle(LightSheet.title)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, StatsBannerText.objectToHeadline)

            HStack(spacing: 4) {
                // The phone, to match the coin on the other banner. 15 against
                // the coin's 16: its art fills more of its canvas, so an equal
                // frame would render it larger.
                Image("ScrollCardIcon")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: SummaryChart.statIcon, height: SummaryChart.statIcon)
                // The figure carries the weight, the rest of the line doesn't —
                // same split as "312 coins earned all time".
                Text("\(wakingShare)%")
                    .auraFont(.body, RowType.label, .bold)
                    .foregroundStyle(LightSheet.title)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("of your waking week")
                    .auraFont(.body, RowType.label, .regular)
                    .foregroundStyle(LightSheet.subtitle)
            }
            .padding(.top, StatsBannerText.headlineToCaption)
        }
    }
}

/// Shared by both banners: the figure separates by weight and colour at the
/// same size, rather than by growing.
enum StatsBannerText {
    /// Inside a banner: object → sentence → caption. The object leads, so these
    /// aren't one even gap.
    ///
    /// Shared by both banners rather than held twice. They're built to come to
    /// the same height, and two copies of the numbers that guarantee it is two
    /// chances to break it.
    static let objectToHeadline: CGFloat = 20
    /// Was 10, which is off the four-grid every other gap in the app sits on.
    /// 12 is the nearest step that keeps it tighter than the 20 above it.
    static let headlineToCaption = Theme.Spacing.m

    static func emphasised(_ lead: String, _ figure: String, _ tail: String) -> AttributedString {
        var sentence = AttributedString(lead)
        var emphasis = AttributedString(figure)
        emphasis.font = Typography.display(size: SheetType.banner, weight: .bold)
        emphasis.foregroundColor = LightSheet.blue
        sentence.append(emphasis)
        sentence.append(AttributedString(tail))
        return sentence
    }
}

/// Where the icon's middle sits, so the blue curve can land on it. Only the
/// app reads this; in the extension it's set and ignored.
struct StatsIconMidKey: PreferenceKey {
    static let space = "statsContent"
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

extension View {
    func measuringMiddle() -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: StatsIconMidKey.self,
                    value: proxy.frame(in: .named(StatsIconMidKey.space)).midY
                )
            }
        )
    }
}

