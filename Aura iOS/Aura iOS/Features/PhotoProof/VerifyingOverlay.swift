//
//  VerifyingOverlay.swift
//  Aura iOS
//

import SwiftUI

/// What you watch while Aura looks at your photo.
///
/// The photo stays exactly as you took it, undimmed. Anything laid over it
/// reads as the app covering up the thing it's meant to be examining, which is
/// the opposite of what this moment should feel like: the picture is the
/// evidence, and the app is going over it.
///
/// The wait is real but short, around a second against the live endpoint, so
/// this never becomes a loading screen you sit in. It exists to make the second
/// legible rather than to fill it.
struct VerifyingOverlay: View {
    let habit: Habit

    var body: some View {
        ZStack(alignment: .top) {
            ScanMotes()

            pill
                .padding(.top, Theme.Spacing.m)
        }
    }

    /// The habit, and what's happening to it. The sticker rather than a spinner:
    /// you're told which habit is being checked, which is the one thing a
    /// spinner can't say.
    private var pill: some View {
        HStack(spacing: Theme.Spacing.s) {
            habitSticker

            Text("Verifying habit...")
                .auraFont(.body, SheetType.cardTitle, .bold)
                .foregroundStyle(.white)
        }
        .padding(.leading, Theme.Spacing.s)
        .padding(.trailing, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.s)
        .background(LightSheet.chromeOnPhoto, in: Capsule())
    }

    @ViewBuilder
    private var habitSticker: some View {
        if let asset = habit.iconAsset {
            Image(asset)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 30, height: 30)
        } else {
            Text(habit.emoji.isEmpty ? "📸" : habit.emoji)
                .font(.system(size: 22))
                .frame(width: 30, height: 30)
        }
    }
}

/// A field of small lights over the photo, each pinging a ring outward.
///
/// The dots hold still. What moves is a ring expanding out of each one and
/// fading as it goes, on its own phase, so the field reads as a scan touching
/// points across the picture rather than anything travelling through it.
///
/// The dot fades with its own ring rather than burning steadily. A permanent
/// dot is a mark left on the photo; a dot that comes up, throws a ring and goes
/// out is a point being checked and released, which is what's actually
/// happening.
///
/// Driven by one `TimelineView` clock: every radius is a function of elapsed
/// time, so nothing accumulates, nothing needs restarting, and the whole field
/// costs one redraw per frame.
///
/// The seeds are fixed rather than random. A field that looks different on
/// every run is a field nobody can tune, and this one wants deliberate
/// placement: weighted toward the middle, where the viewfinder had the user put
/// their habit, and thinner out at the edges, which are floor and wall.
private struct ScanMotes: View {
    private struct Mote {
        let x: CGFloat      // 0...1 across the width
        let y: CGFloat      // 0...1 down the height
        let size: CGFloat   // the dot's diameter
        let period: Double  // seconds per ping
        let phase: Double   // 0...1 head start, so they never ping in unison
    }

    /// Roughly where the viewfinder frame sat: x 0.12...0.88, y 0.22...0.72.
    /// Two thirds of these live inside it.
    private static let motes: [Mote] = [
        // Outside the frame, sparse.
        Mote(x: 0.14, y: 0.15, size: 7, period: 1.5, phase: 0.00),
        Mote(x: 0.62, y: 0.11, size: 6, period: 1.6, phase: 0.60),
        Mote(x: 0.86, y: 0.17, size: 7, period: 1.4, phase: 0.28),
        Mote(x: 0.20, y: 0.83, size: 6, period: 1.7, phase: 0.78),
        Mote(x: 0.55, y: 0.89, size: 8, period: 1.5, phase: 0.48),

        // Inside the frame, where the habit is.
        Mote(x: 0.24, y: 0.30, size: 9, period: 1.6, phase: 0.71),
        Mote(x: 0.52, y: 0.25, size: 7, period: 1.9, phase: 0.18),
        Mote(x: 0.78, y: 0.33, size: 8, period: 1.4, phase: 0.05),
        Mote(x: 0.38, y: 0.40, size: 6, period: 1.7, phase: 0.36),
        Mote(x: 0.63, y: 0.45, size: 8, period: 1.5, phase: 0.83),
        Mote(x: 0.17, y: 0.48, size: 7, period: 1.8, phase: 0.51),
        Mote(x: 0.45, y: 0.53, size: 9, period: 1.6, phase: 0.22),
        Mote(x: 0.84, y: 0.56, size: 6, period: 1.9, phase: 0.63),
        Mote(x: 0.28, y: 0.62, size: 8, period: 1.4, phase: 0.09),
        Mote(x: 0.58, y: 0.68, size: 7, period: 1.7, phase: 0.45),
        Mote(x: 0.76, y: 0.74, size: 6, period: 1.5, phase: 0.88),
    ]

    /// How far a ring gets before it's gone, as a multiple of its dot.
    ///
    /// Pulled in from 5 when the dots grew: a multiple keeps the ring in
    /// proportion to its dot, but at 5 the bigger dots were throwing rings wide
    /// enough to overlap their neighbours and the field read as noise.
    private static let ringReach: CGFloat = 4

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate

                for mote in Self.motes {
                    let x = size.width * mote.x
                    let y = size.height * mote.y

                    // 0...1 through this dot's own cycle.
                    let ping = ((t / mote.period) + mote.phase).truncatingRemainder(dividingBy: 1)
                    let fade = 1 - ping

                    context.fill(
                        Path(ellipseIn: CGRect(x: x - mote.size / 2, y: y - mote.size / 2,
                                               width: mote.size, height: mote.size)),
                        with: .color(.white.opacity(0.9 * fade))
                    )

                    // Eased out: the ring leaves quickly and slows as it fades,
                    // which is what a ping looks like. Linear growth reads
                    // mechanical.
                    let eased = 1 - pow(fade, 2)
                    let radius = mote.size / 2 + (mote.size * Self.ringReach - mote.size / 2) * eased
                    let ring = CGRect(x: x - radius, y: y - radius,
                                      width: radius * 2, height: radius * 2)

                    // The ring lets go faster than its dot does: squared rather
                    // than linear, so it's most of the way gone by the time it
                    // reaches full reach and never lingers as a faint outline.
                    context.stroke(Path(ellipseIn: ring),
                                   with: .color(.white.opacity(0.6 * fade * fade)),
                                   lineWidth: 3)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
