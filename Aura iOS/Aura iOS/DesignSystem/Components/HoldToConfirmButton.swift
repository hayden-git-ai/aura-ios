//
//  HoldToConfirmButton.swift
//  Aura iOS
//

import SwiftUI

/// A circular press-and-hold commit: a tinted disc with a lock glyph, ringed by
/// a track that fills as the finger stays down. Letting go early rewinds the
/// ring and nothing happens.
///
/// The reference this follows also floods the whole screen with the tint as the
/// ring completes; that part is deliberately left out, so the animation stays
/// inside the button.
struct HoldToConfirmButton: View {
    var tint: Color
    var idleCaption: String
    var holdingCaption: String
    var doneCaption: String
    /// The idle caption's colour. Defaults to the light-surface grey; screens on
    /// a dark or coloured ground pass white so it still reads.
    var idleCaptionColor: Color = LightSheet.controlIdle
    /// Caption weight and an optional drop shadow, for captions sitting on a
    /// busy photo that need more presence.
    var captionWeight: Font.Weight = .medium
    var captionShadow: Bool = false
    /// The unfilled track ring. Defaults to the opaque light track; on a photo
    /// a translucent white reads softer.
    var trackColor: Color = LightSheet.track
    /// Shown after the idle caption as a coin and a number, for holds that
    /// spend. Nil for the ones that only confirm.
    var coins: Int? = nil
    /// How long the finger has to stay down.
    var duration: Double = 5
    var action: () -> Void

    private enum Phase { case idle, holding, done }
    @State private var phase: Phase = .idle
    @State private var progress: CGFloat = 0
    @State private var commit: DispatchWorkItem?
    @State private var dots = 0
    @State private var dotTimer: Timer?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let size: CGFloat = 80
    private let ringWidth: CGFloat = 6
    /// Clear space between the disc's edge and the track's inner edge.
    private let ringGap: CGFloat = 6
    /// Measured to the stroke's centerline, so the gap lands where it's set.
    private var ringDiameter: CGFloat { size + 2 * ringGap + ringWidth }

    private var caption: String {
        switch phase {
        case .idle:    return idleCaption
        // The trailing ellipsis is drawn as animated dots instead.
        case .holding: return holdingCaption.trimmingCharacters(in: CharacterSet(charactersIn: ".…"))
        case .done:    return doneCaption
        }
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            ZStack {
                // The groove is always visible, with the tinted sweep filling it
                // as the finger stays down.
                ZStack {
                    Circle()
                        .stroke(trackColor, lineWidth: ringWidth)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(tint, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: ringDiameter, height: ringDiameter)

                Circle()
                    .fill(tint)
                    .frame(width: size, height: size)

                // A white Touch ID print that fills from the bottom as the hold
                // progresses — the fingerprint scan metaphor.
                fingerprint
            }
            .scaleEffect(phase == .holding ? 0.96 : 1)
            .animation(.snappy(duration: 0.2), value: phase)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in begin() }
                    .onEnded { _ in cancel() }
            )

            HStack(spacing: 0) {
                Text(caption)

                if let coins, phase == .idle {
                    Image("AuraCoinIcon")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 15, height: 15)
                        .padding(.leading, Theme.Spacing.xs)
                    Text(" \(coins)")
                }

                if phase == .holding {
                    // All three dots hold their space so the caption doesn't
                    // shuffle sideways as they light up one at a time.
                    HStack(spacing: 0) {
                        ForEach(0..<3, id: \.self) { i in
                            Text(".").opacity(dots > i ? 1 : 0)
                        }
                    }
                    .animation(.easeInOut(duration: 0.15), value: dots)
                }
            }
            .auraFont(.body, 13, captionWeight)
            .foregroundStyle(phase == .idle ? idleCaptionColor : tint)
            .shadow(color: .black.opacity(captionShadow ? 0.35 : 0),
                    radius: captionShadow ? 3 : 0, y: captionShadow ? 1 : 0)
            .animation(.easeInOut(duration: 0.2), value: phase)
        }
    }

    /// The white fingerprint: a faint base print with a solid-white print over
    /// it, masked to reveal from the bottom up in step with `progress`.
    private var fingerprint: some View {
        let s: CGFloat = 48
        return Image(systemName: "touchid")
            .resizable()
            .scaledToFit()
            .frame(width: s, height: s)
            .foregroundStyle(.white.opacity(0.30))
            .overlay {
                Image(systemName: "touchid")
                    .resizable()
                    .scaledToFit()
                    .frame(width: s, height: s)
                    .foregroundStyle(.white)
                    .mask {
                        VStack(spacing: 0) {
                            Color.clear
                            Color.black.frame(height: s * progress)
                        }
                        .frame(width: s, height: s)
                    }
            }
    }

    private func begin() {
        guard phase == .idle else { return }
        phase = .holding

        // Reduced motion still has to be holdable, so the ring jumps to full
        // rather than sweeping.
        withAnimation(reduceMotion ? nil : .linear(duration: duration)) { progress = 1 }

        dots = 0
        dotTimer?.invalidate()
        dotTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { _ in
            dots = (dots + 1) % 4
        }

        let work = DispatchWorkItem {
            stopDots()
            phase = .done
            // A beat on the check before handing back, so the commit lands
            // and is read before the sheet closes out from under it.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { action() }
        }
        commit = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    private func stopDots() {
        dotTimer?.invalidate()
        dotTimer = nil
    }

    private func cancel() {
        guard phase == .holding else { return }
        commit?.cancel()
        commit = nil
        stopDots()
        phase = .idle
        withAnimation(.easeOut(duration: 0.25)) { progress = 0 }
    }
}

#Preview {
    ZStack {
        LightSheet.bg
        HoldToConfirmButton(
            tint: LightSheet.danger,
            idleCaption: "Press and hold to end",
            holdingCaption: "Keep holding…",
            doneCaption: "Session ended"
        ) {}
    }
}
