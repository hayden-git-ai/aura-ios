//
//  StreakBadge.swift
//  Aura iOS
//

import SwiftUI
import UIKit

/// A compact streak indicator for the Home header's top-right: the fire icon
/// in a soft circle with its day count stacked directly beneath, in the same
/// white General Sans display face as the screen-time readout.
struct StreakBadge: View {
    let count: Int

    /// One value type driving the breathing keyframes, so the flame + number
    /// stay perfectly in sync.
    private struct Breathe { var scale: CGFloat = 1; var brightness: Double = 0 }

    /// `sectionHeader`, up from a loose 14 — a size on the scale, and a step
    /// bigger under a 44pt disc.
    /// 18, up from `sectionHeader` (15). Its own number now rather than a
    /// borrowed token: this is a numeral on a badge, not a section title.
    private static let numeralSize: CGFloat = 18
    /// The ratio the outline was tuned at (2.2 on 14).

    /// How far the numeral tucks under the flame disc, as a share of its own
    /// size. Derived rather than fixed: a constant gap makes the tuck shrink in
    /// proportion every time the numeral grows, which is what happened when it
    /// went 14 → 15 and the overlap visibly loosened.
    /// Re-derived for the larger numeral. The tuck is `-numeralSize * ratio`,
    /// so at 0.8 growing the glyph from 15 to 18 would have deepened the
    /// overlap from 12pt to 14.4 and buried the numeral's top under the flame.
    /// 12/18 keeps the overlap exactly where it was tuned.
    /// 10/18, not 12/18. The tuck is `-numeralSize * ratio`, so shrinking the
    /// ratio by 2/18 moves the numeral down by exactly 2pt.
    private static let tuckRatio: CGFloat = 10.0 / 18.0
    @State private var breatheTrigger = 0

    var body: some View {
        // Negative spacing lets the numeral's top tuck slightly under the
        // circle — the number renders after the circle, so it sits on top.
        // Scales with the numeral: -12 was tuned at 19pt and pulled the smaller
        // glyph proportionally further under the flame.
        VStack(spacing: -Self.numeralSize * Self.tuckRatio) {
            ZStack {
                // Same translucent option-card material as the Home cards, no
                // border.
                // Faint see-through disc in daylight, dark translucent at night —
                // so it never reads as a heavy dark spot on the bright sky.
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image("StreakFireIcon")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 32, height: 34)
            }
            // Two sticker-outline versions of the numeral (drawn via UIKit;
            // SwiftUI Text has no outline). Day: white fill + dark outline, like
            // the AURA logo. Night: inverted to black fill + white outline so it
            // stays legible against the dark sky.
            StrokedNumber(
                text: "\(count)",
                font: Typography.displayUIFont(size: Self.numeralSize, weight: .black, tabular: true),
                fill: HomeDaylight.isDay() ? .white : .black,
                stroke: HomeDaylight.isDay() ? UIColor(Theme.Color.background) : .white,
                // Scaled to the glyph, not fixed: a constant width closes the
                // counters as the numeral grows.
                outlineWidth: Self.numeralSize * StrokedNumeral.outlineRatio
            )
            .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
        }
        // One-time "breath" the moment Home appears: the whole badge (circle,
        // flame, and number together) scales 100 → 110 → 100 and brightens
        // slightly at the peak, over 1000ms with a smooth ease. Fires once per
        // appearance — no loop, no bounce, never blocks input.
        .keyframeAnimator(initialValue: Breathe(), trigger: breatheTrigger) { content, value in
            content
                .scaleEffect(value.scale)
                .brightness(value.brightness)
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                CubicKeyframe(1.10, duration: 0.5)
                CubicKeyframe(1.0, duration: 0.5)
            }
            KeyframeTrack(\.brightness) {
                CubicKeyframe(0.12, duration: 0.5)
                CubicKeyframe(0.0, duration: 0.5)
            }
        }
        .onAppear { breatheTrigger += 1 }
    }
}
