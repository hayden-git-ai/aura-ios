//
//  NavChrome.swift
//  Aura iOS
//

import SwiftUI

/// How far the floating nav bar has shrunk, as the content scrolls.
///
/// Continuous, not a switch. The first version flipped a Bool and animated
/// between two sizes, which reads as a thing snapping shut no matter how the
/// animation is tuned — the timing belongs to the animation rather than to the
/// hand. This tracks the offset directly, so the bar moves with the finger and
/// stops the instant the finger does.
///
/// Lives in one object rather than per screen so the bar cannot end up shrunk on
/// one tab and full on another. Any scrolling screen reports its offset and the
/// bar reads the answer.
@Observable
final class NavChrome {
    /// 0 is full size, 1 is fully shrunk.
    private(set) var shrink: CGFloat = 0

    private var last: CGFloat = 0
    /// The first report after appearing is an absolute position, not a
    /// movement. Without this a screen restored partway down would take its
    /// whole offset as one delta and slam the bar shut.
    private var seen = false

    /// How far you have to scroll to take it all the way down. Roughly a
    /// thumb's travel: long enough to feel gradual, short enough that it has
    /// finished by the time you're reading.
    private static let travel: CGFloat = 150
    /// Always full size near the top, whichever way the content is moving.
    private static let topGuard: CGFloat = 40

    func track(_ y: CGFloat) {
        defer { last = y; seen = true }
        guard seen else { return }

        guard y > Self.topGuard else {
            // Coming back to the top is the one place an animation belongs:
            // a bounce can land here in a single frame, and following that
            // exactly would be a jump rather than a return.
            if shrink != 0 { withAnimation(.snappy(duration: 0.22)) { shrink = 0 } }
            return
        }
        // No animation. The offset IS the timing.
        shrink = min(1, max(0, shrink + (y - last) / Self.travel))
    }

    /// Called on a tab change, so a screen that doesn't scroll can't inherit a
    /// shrunken bar from one that does.
    func reset() {
        last = 0
        seen = false
        if shrink != 0 { withAnimation(.snappy(duration: 0.22)) { shrink = 0 } }
    }
}
