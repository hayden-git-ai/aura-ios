//
//  StreakBlock.swift
//  Aura iOS
//

import SwiftUI

// MARK: - Shared streak block

/// The looping streak fox with its contact shadow. Factored out so the post-quest
/// celebration shows the same mascot the same way.
struct StreakFoxHero: View {
    /// One looping animation for every streak count: the fox with his tail on
    /// fire, keyed off a blue screen and stitched into a seamless loop.
    var height: CGFloat = 260

    var body: some View {
        LoopingVideoView(resource: "StreakFox")
            .frame(width: height, height: height)
            // The Home fox's contact shadow, so it grounds him the same way.
            // Centred under his feet (dead-centre, 0.50), nudged up 2px.
            .background(alignment: .bottom) {
                Ellipse()
                    .fill(Color.black.opacity(0.12))
                    .frame(width: height * 0.51, height: height * 0.136)
                    .offset(y: -height * 0.05 - 2)
            }
    }
}

/// The stroked streak count and its "day streak!" line, in the shared streak
/// styling. `count` is a parameter so the celebration can roll it up while the
/// destination shows it static.
struct StreakCount: View {
    let count: Int

    var body: some View {
        VStack(spacing: 0) {
            StrokedNumber(
                text: "\(count)",
                font: Typography.displayUIFont(size: 84, weight: .black, tabular: true),
                fill: .black,
                stroke: .white,
                outlineWidth: 6
            )
            .fixedSize()
            // The 84pt font reserves line-height above the caps and below the
            // baseline with no ink in it. Crop that slack (a token each side) so
            // the spacing acts on the visible digits, not the font box.
            .padding(.top, -Theme.Spacing.xs)
            .padding(.bottom, -Theme.Spacing.xxl)
            // Matches the dumbbell sticker's baked drop shadow (dark + soft).
            .shadow(color: .black.opacity(0.28), radius: 8, y: 3)

            Text("day streak!")
                .auraFont(.display, 28, .bold)
                .foregroundStyle(.black)
                // number → line.
                .padding(.top, Theme.Spacing.xxl)
        }
        .frame(maxWidth: .infinity)
    }
}

/// The streak-goal progress card: a bar between the milestone just cleared and
/// the next one, with a calendar at each end, on the success screens' frost.
struct StreakGoalCard: View {
    let streak: Int

    /// The milestones a streak climbs through.
    private static let goalThresholds = [1, 3, 7, 14, 21, 30, 45, 60, 90, 120, 180, 270, 365, 1000]

    /// The milestone at or below today's streak, and the next one above — the two
    /// ends of the bar (e.g. 60 → 90 while the streak sits at 64).
    private var segment: (from: Int, to: Int) {
        let from = Self.goalThresholds.last { $0 <= streak } ?? 0
        let to = Self.goalThresholds.first { $0 > streak } ?? Self.goalThresholds.last!
        return (from, to)
    }

    private var goal: Int { segment.to }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            HStack {
                Text("Streak goal")
                    .auraFont(.display, 20, .bold)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.22), radius: 4, y: 1)
                Spacer(minLength: Theme.Spacing.m)
                Text("\(streak)/\(goal)")
                    .auraFont(.display, 16, .semibold)
                    .foregroundStyle(.white.opacity(0.85))
                    .shadow(color: .black.opacity(0.22), radius: 4, y: 1)
            }

            goalBar
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.top, Theme.Spacing.l)
        // 4pt less than the top: the calendars leave a little transparent space
        // below them inside the bar, which would otherwise read as extra padding.
        .padding(.bottom, Theme.Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                // The success frost, lightened a couple stops so it's less muddy
                // on the peach — still a translucent panel, not a white card.
                .fill(Color.black.opacity(0.17))
        )
    }

    private var goalBar: some View {
        let seg = segment
        let span = max(1, seg.to - seg.from)
        let frac = min(max(Double(streak - seg.from) / Double(span), 0), 1)
        let markerSize: CGFloat = Theme.Spacing.xxxl   // 48
        return GeometryReader { g in
            let w = g.size.width
            let half = markerSize / 2
            let cy = g.size.height / 2
            // The track lives between the two calendar centres, so no bar peeks
            // out past a calendar at either end.
            let trackW = max(0, w - markerSize)
            let fillW = CGFloat(frac) * trackW
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: trackW, height: 12)
                    .offset(x: half)
                Capsule()
                    .fill(LightSheet.orange)
                    .frame(width: fillW, height: 12)
                    .offset(x: half)

                calendarMarker(seg.from)
                    .frame(width: markerSize, height: markerSize)
                    .position(x: half, y: cy)
                calendarMarker(seg.to)
                    .frame(width: markerSize, height: markerSize)
                    .position(x: w - half, y: cy)
            }
        }
        .frame(height: markerSize)
    }

    /// A calendar sticker with the day number centred on its white body.
    private func calendarMarker(_ n: Int) -> some View {
        Image("Stats90DayCalendar")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .overlay(alignment: .center) {
                Text("\(n)")
                    .auraFont(.display, 15, .bold)
                    .foregroundStyle(.black)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .frame(width: 30)
                    // Centred on the white body, clear of both the red header and
                    // the black bottom border.
                    .offset(y: 3)
            }
    }
}
