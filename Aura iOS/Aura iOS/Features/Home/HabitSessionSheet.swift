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
            Theme.Color.background.ignoresSafeArea()

            HabitSessionTimerView(session: session, now: now,
                                  onTogglePause: onTogglePause, onEnd: onEnd)
                .padding(.horizontal, Theme.Spacing.xl)
        }
        .presentationDetents([.height(560)])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }
}

/// The ring timer for an active Photo Proof habit session — counts down "until
/// apps unlock", with Pause/Resume and End controls.
private struct HabitSessionTimerView: View {
    let session: ActiveHabitSession
    /// The store's clock. The session holds an end date now, so what's left is
    /// measured against a moving `now` rather than stored on the session.
    let now: Date
    var onTogglePause: () -> Void
    var onEnd: () -> Void

    private var remaining: Int { session.remainingSeconds(at: now) }
    private var progress: Double { session.progress(at: now) }

    private var clock: String {
        String(format: "%d:%02d", remaining / 60, remaining % 60)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            ring

            VStack(spacing: Theme.Spacing.m) {
                Button(action: onTogglePause) {
                    HStack(spacing: Theme.Spacing.s) {
                        Image(systemName: session.isPaused ? "play.fill" : "pause.fill")
                        Text(session.isPaused ? "Resume" : "Pause")
                    }
                    .font(SheetType.ctaFont)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .glassEffect(.regular.interactive(), in: Capsule())
                }
                .buttonStyle(.plain)

                Button(action: onEnd) {
                    HStack(spacing: Theme.Spacing.s) {
                        Image(systemName: "xmark")
                        Text("End")
                    }
                    .font(SheetType.ctaFont)
                    .foregroundStyle(Theme.Color.signalWarning)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        Capsule().strokeBorder(Theme.Color.signalWarning.opacity(0.5), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 4)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)

            VStack(spacing: Theme.Spacing.xs) {
                Text(clock)
                    .auraFont(.display, 46, .bold)
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                // Sentence case and untracked, like every other caption. This
                // was the last all-caps label left after the stat row.
                Text("Until apps unlocked")
                    .auraFont(.body, RowType.subLabel, .medium)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
        }
        .frame(width: 240, height: 240)
    }
}
