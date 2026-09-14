//
//  ReloadGlyph.swift
//  Aura iOS
//

import SwiftUI

/// Where a reload has got to.
enum ReloadPhase { case idle, running, done, failed }

/// The glyph for a reload control: the reload arrow, which spins while the work
/// runs and rests when it's done. No spinner, no tick — the result is announced
/// by a toast, not by the control changing shape.
///
/// Shared because there are two of these — the Blocks explainer's "Reload Aura"
/// and the reload on the Passive Income status line — so they stay identical.
struct ReloadGlyph: View {
    let phase: ReloadPhase
    var tint: Color = LightSheet.blue
    var size: CGFloat = RowType.label
    /// When set, the arrow is drawn outlined in this colour with a soft shadow —
    /// the sticker look, `tint` as the fill.
    var outline: Color? = nil

    @State private var angle: Double = 0

    @ViewBuilder
    private var glyph: some View {
        if let outline {
            OutlinedGlyph(systemName: "arrow.clockwise", size: size,
                          fill: tint, outline: outline)
        } else {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(tint)
        }
    }

    var body: some View {
        glyph
            .rotationEffect(.degrees(angle))
            .onChange(of: phase) { _, newPhase in
                if newPhase == .running {
                    angle = 0
                    // One turn, not a continuous spin.
                    withAnimation(.easeInOut(duration: 0.75)) {
                        angle = 360
                    }
                } else {
                    // Hard stop back to upright — no reverse-spin, no lingering
                    // repeat once the reload has resolved.
                    withAnimation(.linear(duration: 0)) { angle = 0 }
                }
            }
    }
}

extension ReloadPhase {
    /// Runs the work, holds the result long enough to be read, then resets.
    ///
    /// The floor matters: both callers can return in a single frame — the
    /// shield against the mock, a HealthKit query with nothing to sum — and a
    /// control that flashes through three states instantly reads as broken
    /// rather than fast.
    /// - Parameter onFinish: called once the spinner has resolved, not when the
    ///   work returns. Anything a caller wants to show *about* the result —
    ///   a toast, a banner — belongs here, or it lands while the control is
    ///   still spinning and the two contradict each other.
    @MainActor
    static func run(_ phase: Binding<ReloadPhase>,
                    work: @escaping () async -> Bool,
                    onFinish: ((Bool) -> Void)? = nil) {
        guard phase.wrappedValue == .idle else { return }
        Haptics.impact(.light)
        withAnimation(.easeInOut(duration: 0.2)) { phase.wrappedValue = .running }
        Task { @MainActor in
            async let result = work()
            try? await Task.sleep(for: .milliseconds(900))
            let succeeded = await result
            withAnimation(.easeInOut(duration: 0.2)) {
                phase.wrappedValue = succeeded ? .done : .failed
            }
            onFinish?(succeeded)
            try? await Task.sleep(for: .milliseconds(1600))
            withAnimation(.easeInOut(duration: 0.2)) { phase.wrappedValue = .idle }
        }
    }
}
