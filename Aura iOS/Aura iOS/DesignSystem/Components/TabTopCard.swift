//
//  TabTopCard.swift
//  Aura iOS
//

import SwiftUI

/// Every number that sets the header slab's height, in one place.
///
/// Blocks and Stats have to be identical to the point — switching tabs runs the
/// eye straight down the card's bottom edge, and a few points of difference
/// reads as the screen jumping. Kept apart from the view so a caller can line
/// something up against the card without instantiating one.
enum TabTopCardMetrics {
    /// Clears the status bar, which the scroll view draws under.
    static let topInset: CGFloat = 64
    /// The control row. Fixed, so a tab with nothing to put there — Stats in
    /// Daily Habits, which has no report to re-pull — doesn't collapse it and
    /// change the card's height.
    static let controlHeight: CGFloat = 40
    /// What the body gets. Its floor is the Stats summary's intrinsic height:
    /// day strip, readout, 92pt bars and the trend line come to roughly 290, so
    /// this can't come down much further without shortening the chart.
    static let bodyHeight: CGFloat = 300
    static let gap = Theme.Spacing.l
    static let bottomInset = Theme.Spacing.xl
    static let corner: CGFloat = Theme.Radius.sheet
}

/// The white slab at the top of Blocks and Stats: a control row, then a body on
/// a fixed height it fills.
///
/// Full-bleed, with only its bottom corners rounded — it runs off both edges
/// and up under the status bar, so the field only meets it along one line.
///
/// The height comes entirely from `TabTopCardMetrics` — nothing a caller passes
/// in can change it, which is the point.
struct TabTopCard<Control: View, Content: View>: View {
    /// A full-bleed backdrop illustration filling the card, or nil for the plain
    /// white slab. Blocks passes a day/night scene; Stats stays white.
    var backdrop: String? = nil
    /// The row along the top: a mode pill, an Add button, whatever the tab needs.
    @ViewBuilder var control: Control
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: TabTopCardMetrics.gap) {
            control
                .frame(maxWidth: .infinity)
                .frame(height: TabTopCardMetrics.controlHeight)

            content
                .frame(maxWidth: .infinity)
                .frame(height: TabTopCardMetrics.bodyHeight)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, TabTopCardMetrics.topInset)
        .padding(.bottom, TabTopCardMetrics.bottomInset)
        .frame(maxWidth: .infinity)
        .background {
            // A scene fills the card; nil leaves the plain white slab (Stats).
            // scaledToFill overflows the frame, so the clip has to be applied to
            // the whole card below — clipping the image's own bounds rounds a
            // rectangle far off-screen and leaves the visible corners square.
            if let backdrop {
                Image(backdrop)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else {
                Color.white
            }
        }
        .clipShape(
            UnevenRoundedRectangle(
                bottomLeadingRadius: TabTopCardMetrics.corner,
                bottomTrailingRadius: TabTopCardMetrics.corner,
                style: .continuous
            )
        )
    }
}
