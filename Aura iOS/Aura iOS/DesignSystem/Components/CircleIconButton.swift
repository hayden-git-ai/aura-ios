//
//  CircleIconButton.swift
//  Aura iOS
//

import SwiftUI

/// A glyph on a circular face — every X, back arrow, gear, trash and edit
/// pencil in the app.
///
/// There were fourteen of these written out by hand, which is how one 44pt
/// frame ended up carrying 16 bold, 17 semibold and 18 heavy glyphs at the same
/// time. The three sizes that exist are grades here, so a new button picks one
/// rather than inventing a fourth.
struct CircleIconButton: View {
    enum Grade {
        /// A remove badge pinned to a grid tile.
        case mini
        /// A badge on an avatar — the sticker picker's pencil.
        case badge
        /// Every button in a screen's top corner: an X, a back arrow, the
        /// Profile gear, the Stats refresh, the Wall's trash. There used to be
        /// a second grade at 44 for "floating on a screen rather than in a
        /// sheet header", which turned out to describe the same corner, in the
        /// same position, doing the same thing — so eleven corner buttons were
        /// 36 and eleven were 44 with nothing to tell you which you'd get.
        case chrome
        /// A 44pt +/− stepper. Not chrome — it's a control you aim at
        /// repeatedly, so the face is the tap target rather than smaller than
        /// it.
        case stepper

        var diameter: CGFloat {
            switch self {
            case .mini: 26
            case .badge: 32
            case .chrome: 36
            case .stepper: 44
            }
        }

        var glyph: CGFloat {
            switch self {
            case .mini: 13
            case .badge: 13
            case .chrome: 15
            case .stepper: 16
            }
        }
    }

    var symbol: String = ""
    /// An Aura sticker in place of the SF glyph, sitting inside the same disc the
    /// glyph did (its own colours, so `glyphColor` no longer applies).
    var sticker: String? = nil
    /// A flat glyph image (the custom plus / X / reload art) in place of the SF
    /// symbol — sized to the glyph slot rather than filling the disc like a
    /// sticker, and carrying its own colour (so `glyphColor` no longer applies).
    var glyphImage: String? = nil
    var grade: Grade = .chrome
    /// Four treatments, by what's behind the button:
    ///   • a light surface — white sheet or the lavender screens — takes this
    ///     translucent dark disc with a dark glyph;
    ///   • the flat blue field takes `chromeOnBlue` and white;
    ///   • a photo, or a bright ground we own like the streak orange, takes
    ///     `chromeOnPhoto` and white. An opaque disc was tried here and read as
    ///     a black hole punched in the photo — translucent wins on looks, at
    ///     the cost of a coloured glyph (the Wall's red trash) being weak
    ///     against an unusually bright frame.
    ///
    /// Translucent rather than a fixed grey because both light surfaces are in
    /// play: `track` matched white but sat 1.05:1 against the lavender, which
    /// is what forced the solid-white-plus-shadow variant this replaces.
    var fill: Color = LightSheet.chromeOnLight
    /// One neutral per treatment — `controlIdle` on light, white on dark — and
    /// `danger` where the action is destructive.
    ///
    /// `controlIdle` #767676 sits at 3.81:1 on the disc: clear of the 3:1 an
    /// icon control needs, and far quieter than `title`'s 14:1, which was
    /// title-weight on a button you should only notice when you want it. The
    /// old #8A8A8A default failed at 2.90.
    var glyphColor: Color = LightSheet.controlIdle
    /// When set, the SF `symbol` is drawn outlined (in this colour) with a soft
    /// shadow — `glyphColor` becomes the fill. The sticker look, from a glyph.
    var glyphOutline: Color? = nil
    /// Bounces on press. Off for the ones that sit inside another button.
    var bounces = true
    /// Spins the glyph — a refresh that turns as it reloads.
    var rotation: Double = 0
    /// Nudges a sticker within the disc, for art that sits off-centre in its
    /// own canvas (the routine bell rides high in its frame).
    var stickerNudge: CGFloat = 0
    var action: () -> Void

    @ViewBuilder
    var body: some View {
        if bounces {
            button.buttonStyle(PressBounceStyle())
        } else {
            button.buttonStyle(.plain)
        }
    }

    private var button: some View {
        Button(action: action) {
            glyph
                // The face keeps its designed size; the tap area doesn't. A
                // 36pt X is right visually and 8pt short of Apple's minimum,
                // and `contentShape` costs nothing to fix that.
                .frame(width: CircleIconButton.minimumTarget,
                       height: CircleIconButton.minimumTarget)
                .contentShape(Circle())
        }
    }

    @ViewBuilder
    private var glyph: some View {
        if let glyphImage {
            // A flat glyph image at roughly the SF glyph's size, centred on the
            // disc. Its own colour, so `glyphColor` is not applied.
            Image(glyphImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .rotationEffect(.degrees(rotation))
                .frame(width: grade.diameter * 0.55, height: grade.diameter * 0.55)
                .frame(width: grade.diameter, height: grade.diameter)
                .background(fill, in: Circle())
        } else if let sticker {
            // A sticker on the disc, sized to a WHOLE number of points, then
            // centred. A fractional size (36 × 0.68 = 24.48pt → 73.44px at 3x)
            // straddled pixel boundaries and read as pixelated; rounding lands it
            // on them so the artwork stays crisp.
            Image(sticker)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .rotationEffect(.degrees(rotation))
                .offset(y: stickerNudge)
                .frame(width: (grade.diameter * 0.68).rounded(),
                       height: (grade.diameter * 0.68).rounded())
                .frame(width: grade.diameter, height: grade.diameter)
                .background(fill, in: Circle())
        } else if let glyphOutline {
            OutlinedGlyph(systemName: symbol, size: grade.glyph,
                          fill: glyphColor, outline: glyphOutline)
                .rotationEffect(.degrees(rotation))
                .frame(width: grade.diameter, height: grade.diameter)
                .background(fill, in: Circle())
        } else {
            Image(systemName: symbol)
                .font(.system(size: grade.glyph, weight: .bold))
                .foregroundStyle(glyphColor)
                .rotationEffect(.degrees(rotation))
                .frame(width: grade.diameter, height: grade.diameter)
                .background(fill, in: Circle())
        }
    }

    /// Apple's minimum tap target.
    static let minimumTarget: CGFloat = 44
}

/// An SF Symbol with a solid outline and a soft shadow — the sticker look drawn
/// from a glyph rather than baked into a PNG, which kept the thin strokes crisp.
///
/// The outline is eight offset copies of the glyph behind the fill, so the edge
/// is uniform on any shape (an X's diagonals, a plus, a reload arrow) rather than
/// the uneven ring a scale-up would give.
struct OutlinedGlyph: View {
    let systemName: String
    var size: CGFloat
    var weight: Font.Weight = .bold
    var fill: Color
    var outline: Color
    /// Outline thickness in points.
    var outlineWidth: CGFloat = 2
    /// Drop-shadow opacity; 0 draws none.
    var shadow: Double = 0.28

    /// Eight unit directions, so the outline copies ring the glyph evenly.
    private static let ring: [(CGFloat, CGFloat)] = [
        (1, 0), (0.707, 0.707), (0, 1), (-0.707, 0.707),
        (-1, 0), (-0.707, -0.707), (0, -1), (0.707, -0.707),
    ]

    private var glyph: some View {
        Image(systemName: systemName).font(.system(size: size, weight: weight))
    }

    var body: some View {
        ZStack {
            ForEach(0..<Self.ring.count, id: \.self) { i in
                glyph
                    .foregroundStyle(outline)
                    .offset(x: Self.ring[i].0 * outlineWidth,
                            y: Self.ring[i].1 * outlineWidth)
            }
            glyph.foregroundStyle(fill)
        }
        // One shadow for the whole composited glyph, not one per copy.
        .compositingGroup()
        .shadow(color: .black.opacity(shadow), radius: max(0.5, outlineWidth * 0.9), y: 1)
    }
}
