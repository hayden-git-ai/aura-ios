//
//  FocusLengthScrubber.swift
//  Aura iOS
//

import SwiftUI

/// Replaces both the old segmented "15m/30m/45m/60m/Custom" capsule and the
/// separate Custom Focus Length sheet with one drag-to-scrub control — every
/// value from 5 to 240 minutes is reachable directly by dragging, no modal.
///
/// One glass pill morphs between two states:
/// - Collapsed (default): `-` / value-pill / `+` — a centered, content-hugging
///   cluster of Liquid Glass shapes with roomy gaps, so they read as clean
///   round shapes (Opal-style) rather than a stretched, edge-to-edge bar. The
///   `-`/`+` circles do fine ±5 adjustments.
/// - Expanded (tap or drag the pill): the `-`/`+` melt into the pill as it
///   grows to fill the row and becomes a tape-measure ruler — ticks hug the
///   top and bottom edges (majors every 30m longer, the centered current-value
///   tick brightest and matching the length of the mark it sits on), round
///   gridline labels and the live value in the clear middle band, all fading
///   toward the two ends.
///
/// After a scrub is released it auto-collapses back to the compact cluster
/// after a short beat.
struct FocusLengthScrubber: View {
    @Binding var lengthMinutes: Int
    /// Colors the value text, +/- icons, and ruler ticks/labels. Defaults to
    /// white for the dark screens; pass an accent (e.g. blue) for light sheets.
    var tint: Color = .white

    @State private var isScrubbing = false
    @State private var gestureActive = false
    @State private var wasExpandedAtGestureStart = false
    @State private var dragAccumulator: CGFloat = 0
    @State private var lastTranslation: CGFloat = 0
    @State private var collapseWork: DispatchWorkItem?

    private let range = 5...240
    private let step5 = 5
    private let pointsPerTick: CGFloat = 14
    private let majorTickEveryMinutes = 30
    private let expandedHeight: CGFloat = 72
    private let collapsedHeight: CGFloat = 48
    private let collapsedPillWidth: CGFloat = 200
    /// How far each `-`/`+` tucks inward (under the pill) when expanded — the
    /// distance it slides back out to its edge when collapsing.
    private let buttonTuck: CGFloat = 40

    // A low-damping spring so the single glass morph overshoots: the `-`/`+`
    // slide out of the pill, past their idle edge position, then settle back —
    // one animation, no separate offset fighting the morph.
    private var morphAnimation: Animation { .spring(response: 0.42, dampingFraction: 0.55) }

    /// Soft outline derived from the tint so the pill reads as a gentle field
    /// rather than a hard hairline (dark) line on a light sheet.
    private var strokeColor: Color { tint.opacity(0.3) }

    var body: some View {
        pillRow
    }

    // MARK: - Pill row (buttons neck into the pill as it expands)

    private var pillRow: some View {
        // Buttons are standalone glass (NOT in a container with the pill) and
        // always present. That's deliberate: the `GlassEffectContainer` +
        // `glassEffectID` coupling kept making the `-`/`+` inherit the pill's
        // morph geometry — one side flew off-screen, the other didn't move.
        // Plain glass respects `.opacity`, so we hide them cleanly, and a
        // mirrored persistent offset gives a fully symmetric slide: tucked in
        // toward the pill (faded) when expanded, out at the edge when
        // collapsed. The low-damping spring overshoots past the edge and
        // settles. This runs identically for tap-collapse and auto-collapse.
        ZStack {
            pillContent
                // Clear fill + hairline border, matching the Edit Focus Reward
                // card (`FocusCard(fillColor: .clear)`) rather than glass.
                .overlay(Capsule().strokeBorder(strokeColor, lineWidth: 1.5))
                // The whole capsule scales up uniformly and glows while a drag
                // is in flight, settling back on release (Opal's scroll
                // feedback). Interactive glass brightens under the finger; the
                // shadow reinforces the glow on the dark backdrop.
                .scaleEffect(gestureActive ? 1.06 : 1.0)
                .shadow(color: .white.opacity(gestureActive ? 0.22 : 0),
                        radius: gestureActive ? 18 : 0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: gestureActive)

            HStack(spacing: 0) {
                stepButton(systemImage: "minus") { bump(-step5) }
                    .overlay(Circle().strokeBorder(strokeColor, lineWidth: 1.5))
                    .offset(x: isScrubbing ? buttonTuck : 0)
                    .opacity(isScrubbing ? 0 : 1)
                    .allowsHitTesting(!isScrubbing)

                Spacer()

                stepButton(systemImage: "plus") { bump(step5) }
                    .overlay(Circle().strokeBorder(strokeColor, lineWidth: 1.5))
                    .offset(x: isScrubbing ? -buttonTuck : 0)
                    .opacity(isScrubbing ? 0 : 1)
                    .allowsHitTesting(!isScrubbing)
            }
            .frame(maxWidth: .infinity)
            .animation(morphAnimation, value: isScrubbing)
        }
        .frame(maxWidth: .infinity)
    }

    private var pillContent: some View {
        ZStack {
            // Only in the layout when expanded — a `Canvas` greedily fills its
            // width. Collapsed, the pill is a fixed width so it reads as a
            // substantial, stable shape rather than growing with the value.
            if isScrubbing {
                rulerCanvas
            }

            Text(FocusDuration.label(lengthMinutes))
                .auraFont(.body, 22, .bold)
                .foregroundStyle(tint)
                // Odometer roll when the value changes inside an animation —
                // i.e. on a `-`/`+` tap (see `bump`). Drag changes are not
                // animated, so scrubbing stays instant.
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .frame(maxWidth: isScrubbing ? .infinity : nil)
        .frame(width: isScrubbing ? nil : collapsedPillWidth)
        .frame(height: isScrubbing ? expandedHeight : collapsedHeight)
        .contentShape(Capsule())
        .gesture(dragGesture)
    }

    /// Matches the back button's glass circle. Interactive glass (glow under
    /// touch) + a uniform scale-up on press, via the shared button style.
    private func stepButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    // MARK: - Ruler

    /// Tape-measure ruler: ticks anchored to the pill's top and bottom edges
    /// (majors every 30m longer than the 5m minors; the centered current-value
    /// tick is brightest and takes the length of the mark it's on), round
    /// gridline labels + the live value in the clear middle band, everything
    /// fading toward the two ends so the eye lands on the center.
    private var rulerCanvas: some View {
        Canvas { context, size in
            let centerX = size.width / 2
            let half = centerX
            let topInset: CGFloat = 9
            let bottomInset: CGFloat = 9
            let minorLen: CGFloat = 7
            let majorLen: CGFloat = 13
            let visibleTicks = Int(centerX / pointsPerTick) + 2

            func tickFade(_ x: CGFloat) -> Double {
                guard half > 0 else { return 1 }
                let ratio = min(1, abs(x - centerX) / half)
                return pow(1 - ratio, 1.5)
            }
            // Labels now fall off toward the ends like the ticks do, instead
            // of holding a flat floor.
            func labelFade(_ x: CGFloat) -> Double {
                guard half > 0 else { return 1 }
                let ratio = min(1, abs(x - centerX) / half)
                return max(0.1, pow(1 - ratio, 1.3))
            }

            // Ticks — every 5m, hugging top and bottom. The center tick takes
            // its own mark's length (long on 30m marks, short between), so it
            // grows and shrinks as you scrub across the ruler.
            for i in -visibleTicks...visibleTicks {
                let tickMinutes = lengthMinutes + i * step5
                guard range.contains(tickMinutes) else { continue }

                let x = centerX + CGFloat(i) * pointsPerTick
                let isMajor = tickMinutes % majorTickEveryMinutes == 0
                let isCenter = i == 0
                let length: CGFloat = isMajor ? majorLen : minorLen
                let opacity = isCenter ? 1.0 : tickFade(x) * (isMajor ? 0.7 : 0.5)

                var top = Path()
                top.move(to: CGPoint(x: x, y: topInset))
                top.addLine(to: CGPoint(x: x, y: topInset + length))
                context.stroke(top, with: .color(tint.opacity(opacity)), lineWidth: 1.5)

                var bottom = Path()
                bottom.move(to: CGPoint(x: x, y: size.height - bottomInset - length))
                bottom.addLine(to: CGPoint(x: x, y: size.height - bottomInset))
                context.stroke(bottom, with: .color(tint.opacity(opacity)), lineWidth: 1.5)
            }

            // Gridline labels at the round 30m marks, up to 2 either side of
            // center. Skipped if they'd collide with the big live value in the
            // middle, or run past the pill's ends — so nothing ever overlaps.
            let clearance: CGFloat = 40   // keep clear of the center value
            let edgeLimit = half - 16     // keep inside the pill's rounded ends

            func drawSide(_ marks: [Int]) {
                var shown = 0
                for minutes in marks {
                    guard shown < 2 else { break }
                    let x = centerX + CGFloat(minutes - lengthMinutes) / CGFloat(step5) * pointsPerTick
                    let dx = abs(x - centerX)
                    guard dx >= clearance, dx <= edgeLimit else { continue }
                    context.draw(
                        Text(FocusDuration.label(minutes))
                            .font(Typography.body(size: 12, weight: .semibold))
                            .foregroundStyle(tint.opacity(labelFade(x))),
                        at: CGPoint(x: x, y: size.height / 2)
                    )
                    shown += 1
                }
            }

            let firstBelow = ((lengthMinutes - 1) / majorTickEveryMinutes) * majorTickEveryMinutes
            let lefts = stride(from: firstBelow, through: firstBelow - 90, by: -majorTickEveryMinutes)
                .filter { range.contains($0) }
            let firstAbove = (lengthMinutes / majorTickEveryMinutes + 1) * majorTickEveryMinutes
            let rights = stride(from: firstAbove, through: firstAbove + 90, by: majorTickEveryMinutes)
                .filter { range.contains($0) }
            drawSide(Array(lefts))
            drawSide(Array(rights))
        }
    }

    // MARK: - Value changes

    private func adjust(_ delta: Int) {
        lengthMinutes = min(range.upperBound, max(range.lowerBound, lengthMinutes + delta))
    }

    /// A `-`/`+` tap — animated so the center value and the earn text roll like
    /// an odometer (`.numericText`). Drag steps call `adjust` directly (no
    /// animation) so scrubbing stays instant.
    private func bump(_ delta: Int) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            adjust(delta)
        }
    }

    // MARK: - Auto-collapse

    private func scheduleCollapse() {
        collapseWork?.cancel()
        let work = DispatchWorkItem {
            withAnimation(morphAnimation) { isScrubbing = false }
        }
        collapseWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }

    private func cancelCollapse() {
        collapseWork?.cancel()
        collapseWork = nil
    }

    // MARK: - Drag

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !gestureActive {
                    gestureActive = true
                    wasExpandedAtGestureStart = isScrubbing
                    lastTranslation = 0
                    dragAccumulator = 0
                }
                cancelCollapse()
                if !isScrubbing {
                    withAnimation(morphAnimation) { isScrubbing = true }
                }

                let delta = value.translation.width - lastTranslation
                lastTranslation = value.translation.width
                dragAccumulator += delta

                while dragAccumulator <= -pointsPerTick {
                    adjust(step5)
                    dragAccumulator += pointsPerTick
                }
                while dragAccumulator >= pointsPerTick {
                    adjust(-step5)
                    dragAccumulator -= pointsPerTick
                }
            }
            .onEnded { value in
                gestureActive = false
                lastTranslation = 0
                dragAccumulator = 0

                let distance = max(abs(value.translation.width), abs(value.translation.height))
                if distance < 6 {
                    // A tap, not a scrub: toggle. Opening leaves it open until
                    // the user acts; tapping an already-open pill closes it.
                    if wasExpandedAtGestureStart {
                        cancelCollapse()
                        withAnimation(morphAnimation) { isScrubbing = false }
                    }
                } else {
                    // Real scrub — tidy away after a short beat.
                    scheduleCollapse()
                }
            }
    }
}

/// Uniform scale-up on press, paired with the button's interactive glass glow.
private struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.12 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var minutes = 45
        var body: some View {
            ZStack {
                Theme.Color.background.ignoresSafeArea()
                FocusLengthScrubber(lengthMinutes: $minutes)
                    .padding(.horizontal, Theme.Spacing.xl)
            }
        }
    }
    return PreviewWrapper()
        .preferredColorScheme(.dark)
}
