//
//  HabitSessionSheet.swift
//  Aura iOS
//

import SwiftUI

/// The session's ring and controls, opened by tapping the Home countdown. Home
/// itself no longer hands the whole screen over to a running session, so this is
/// where Pause/Resume and End live.
struct HabitSessionSheet: View {
    let session: ActiveHabitSession
    let now: Date
    var onTogglePause: () -> Void
    var onEnd: () -> Void

    var body: some View {
        ZStack {
            LightSheet.bg.ignoresSafeArea()

            HabitSessionTimerView(session: session, now: now,
                                  onTogglePause: onTogglePause, onEnd: onEnd)
                .padding(.horizontal, Theme.Spacing.xl)
        }
        .presentationDetents([.height(560)])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.light)
    }
}

/// The ring timer for an active Photo Proof habit session — counts down "until
/// the session ends", with Pause/Resume and End controls.
private struct HabitSessionTimerView: View {
    let session: ActiveHabitSession
    /// The store's clock. The session holds an end date now, so what's left is
    /// measured against a moving `now` rather than stored on the session.
    let now: Date
    var onTogglePause: () -> Void
    var onEnd: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var endpointExpanded = false
    private static let ringSide: CGFloat = 280
    private static let ringWidth: CGFloat = 10
    private static let endpointSide: CGFloat = 16
    private static let timerSize: CGFloat = 56

    private var remaining: Int { session.remainingSeconds(at: now) }
    private var progress: Double { session.progress(at: now) }

    private var clock: String {
        String(format: "%d:%02d", remaining / 60, remaining % 60)
    }

    var body: some View {
        VStack(spacing: 0) {
            LightDragCapsule()

            ring
                // This flexible region is exactly the space between the drag
                // indicator and the controls, so the ring is centered between
                // those two anchors instead of being pinned near the top.
                .frame(maxHeight: .infinity, alignment: .center)
                .padding(.vertical, Theme.Spacing.xl)

            VStack(spacing: Theme.Spacing.m) {
                Button {
                    Haptics.impact(.light)
                    onTogglePause()
                } label: {
                    HStack(spacing: Theme.Spacing.s) {
                        Image(systemName: session.isPaused ? "play.fill" : "pause.fill")
                        Text(session.isPaused ? "Resume" : "Pause")
                    }
                    .font(SheetType.ctaFont)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(HabitCategory.focus.accent, in: Capsule())
                    .bottomDrop(Capsule(), face: HabitCategory.focus.accent, shade: HabitCategory.focus.accentShade)
                }
                .buttonStyle(.plain)

                Button {
                    Haptics.impact(.light)
                    onEnd()
                } label: {
                    Text("End session")
                    .font(SheetType.ctaFont)
                    .foregroundStyle(LightSheet.danger)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, Theme.Spacing.xl)
        }
        .frame(maxHeight: .infinity)
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(LightSheet.track, lineWidth: Self.ringWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(HabitCategory.focus.accent, style: StrokeStyle(lineWidth: Self.ringWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)

            Circle()
                .fill(HabitCategory.focus.accent)
                .frame(width: Self.endpointSide, height: Self.endpointSide)
                .scaleEffect(endpointExpanded && !session.isPaused && !reduceMotion ? 1.3 : 1)
                .shadow(color: HabitCategory.focus.accent.opacity(endpointExpanded && !session.isPaused && !reduceMotion ? 0.4 : 0),
                        radius: endpointExpanded ? 6 : 0)
                .offset(y: -Self.ringSide / 2)
                .rotationEffect(.degrees(progress * 360))
                .animation(.linear(duration: 1), value: progress)
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: true)) {
                        endpointExpanded = true
                    }
                }

            VStack(spacing: Theme.Spacing.xs) {
                Text(clock)
                    .font(Font(Typography.displayUIFont(
                        size: Self.timerSize,
                        weight: .black,
                        tabular: true
                    )))
                    .foregroundStyle(Color.black)
                    .monospacedDigit()
                    .fixedSize()
                    .accessibilityLabel(clock)
                // Sentence case and untracked, like every other caption. This
                // was the last all-caps label left after the stat row.
                Text("Until focus session ends")
                    .auraFont(.body, RowType.subLabel, .medium)
                    .foregroundStyle(LightSheet.subtitle)
            }
        }
        .frame(width: Self.ringSide, height: Self.ringSide)
    }
}
