//
//  MethodScreenBackground.swift
//  Aura iOS
//

import SwiftUI

/// The method screens' field: `HabitDetailScaffold`'s header with the colours
/// swapped. Light behind the hero mascot down to just above the title, then blue
/// the rest of the way, so the list of habits and the habit you land on read as
/// two sides of the same screen.
///
/// Laid out in the stack rather than measured, the same way the habit header is
/// — `height` is the distance from the screen's top to just above the title.
struct MethodScreenBackground: View {
    /// One height for all four method screens, so their fields are identical.
    ///
    /// The arc is attached with `.overlay(alignment: .bottom)`, so its *bottom
    /// edge* lands on the band's bottom edge before the offset. Its peak is
    /// therefore `height - arcHeight + 0.435 * arcHeight`, i.e. `0.565 *
    /// arcHeight` above this number.
    ///
    /// The sticker spans 114–248 from the screen top, so the break belongs at
    /// its midpoint, 181. At the 170-tall arc that's 181 + 96. If the arc ever
    /// changes, this has to move with it or the break slides off the sticker.
    static let standard: CGFloat = 277

    /// The band height that puts the arc's peak through the middle of a quest
    /// screen's hero mascot, whatever height that mascot is drawn at.
    ///
    /// This is the number `standard` was hand-fitted to, written out as the
    /// arithmetic instead of the answer. Photo Proof's mascot is 156 tall where
    /// the other three are 134, and hand-fitting was never going to survive one
    /// screen wanting a different number — every new piece of art would have
    /// meant re-measuring a constant nothing explains.
    ///
    /// `heroTop` is where the mascot's own frame begins, and the layout above
    /// it is the same on all four screens: the safe-area inset, the scroll
    /// view's 8, and `FocusHero`'s chrome clearance.
    static func heroCentred(stickerHeight: CGFloat,
                            arcHeight: CGFloat = 170) -> CGFloat {
        heroTop + stickerHeight / 2 + arcHeight * arcPeakRatio
    }

    /// Measured off the running screen rather than assumed: the mascot's frame
    /// starts 118 down. That is 62 of safe-area inset on the phones this is
    /// laid out for, plus the scroll view's 8, plus 48 of chrome clearance.
    /// Hard-coded like the 277 it replaces — a shorter status bar moves the
    /// break by the difference, on every one of these screens equally.
    private static let heroTop: CGFloat = 118

    /// The arc is attached by its bottom edge and then pushed down 43.5% of its
    /// own height, so its peak ends up this far above the band's bottom.
    private static let arcPeakRatio: CGFloat = 0.565

    var height: CGFloat = standard
    /// The method's colour. Everything below the arc is filled with it.
    var color: Color = LightSheet.blue
    /// The app's off-white ground, not pure white: the band is the same surface
    /// as every other screen, so the white cards on it stay the raised element
    /// and nothing reads as a whiter third surface.
    var band: Color = LightSheet.ground
    /// How far the arc bulges above the band's edge. Scaled down on a card.
    var arcSize: CGSize = CGSize(width: 620, height: 170)
    /// Off for the card-sized version, which lives inside a clipped tile.
    var fullBleed: Bool = true

    var body: some View {
        ZStack(alignment: .top) {
            color

            VStack(spacing: 0) {
                Rectangle()
                    .fill(band)
                    .frame(height: height)
                    // The arc is an overlay, never a sized child: at 620 wide it
                    // would otherwise stretch this past the screen.
                    .overlay(alignment: .bottom) {
                        Ellipse()
                            .fill(color)
                            .frame(width: arcSize.width, height: arcSize.height)
                            .offset(y: arcSize.height * 0.435)
                    }
                    .clipped()

                Spacer(minLength: 0)
            }
        }
        .ignoresSafeArea(fullBleed ? .all : [], edges: .all)
    }
}

#Preview {
    MethodScreenBackground()
}
