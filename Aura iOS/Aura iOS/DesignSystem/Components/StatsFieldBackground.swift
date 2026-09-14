//
//  StatsFieldBackground.swift
//  Aura iOS
//

import SwiftUI

/// `MethodScreenBackground` turned upside down: blue at the top, the light
/// surface below, and the arc hanging *down* out of the blue instead of rising
/// into it. Same 620×170 ellipse, so the curve reads as the same shape the
/// method screens use, just inverted.
///
/// Unlike the method screens, where the break sits at a fixed distance down the
/// screen, this one has to land under a particular line of text — so `height` is
/// measured by the caller and passed in.
struct StatsFieldBackground: View {
    /// Where the blue ends, measured from the top of the scroll content to the
    /// band's straight edge. The dome hangs `domeDrop` below this.
    var height: CGFloat
    var color: Color = LightSheet.blue
    var arcSize: CGSize = CGSize(width: 620, height: 170)

    /// How far the dome's lowest point falls below the band's edge — the same
    /// 0.435 offset the method screens use. Callers need this to place the
    /// break relative to content, since the dome, not the band, is the lowest
    /// blue on the screen.
    static let domeDrop: CGFloat = 170 * 0.435

    /// Covers rubber-band overscroll at the top, which would otherwise pull the
    /// light surface into view above the blue.
    private let overscroll: CGFloat = 800

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(color)
                .frame(height: max(0, height) + overscroll)
                // An overlay, never a sized child: at 620 wide the ellipse
                // would otherwise stretch this past the screen.
                .overlay(alignment: .bottom) {
                    Ellipse()
                        .fill(color)
                        .frame(width: arcSize.width, height: arcSize.height)
                        .offset(y: arcSize.height * 0.435)
                }
                // Draw-time only, so the band's bottom edge still lands on
                // `height` while the fill runs far off the top.
                .offset(y: -overscroll)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }
}
