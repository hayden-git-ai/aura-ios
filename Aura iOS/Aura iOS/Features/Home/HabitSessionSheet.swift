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

    private var remaining: Int { session.remainingSeconds(at: now) }
    private var progress: Double { session.progress(at: now) }

    private var clock: String {
        String(format: "%d:%02d", remaining / 60, remaining % 60)
    }

    var body: some View {
        VStack(spacing: 0) {
            LightDragCapsule()

            ring
                .padding(.top, Theme.Spacing.xl)

            Spacer(minLength: Theme.Spacing.xl)

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
                    .foregroundStyle(LightSheet.title)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(.white, in: Capsule())
                    .bottomDrop(Capsule(), face: .white, shade: LightSheet.whiteShade)
                }
                .buttonStyle(.plain)

                Button {
                    Haptics.impact(.light)
                    onEnd()
                } label: {
                    HStack(spacing: Theme.Spacing.s) {
                        Image(systemName: "xmark")
                        Text("End")
                    }
                    .font(SheetType.ctaFont)
                    .foregroundStyle(LightSheet.danger)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        Capsule().strokeBorder(LightSheet.danger.opacity(0.5), lineWidth: 1)
                    )
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
                .stroke(LightSheet.track, lineWidth: 4)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(LightSheet.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)

            VStack(spacing: Theme.Spacing.xs) {
                Text(clock)
                    .auraFont(.body, 46, .bold)
                    .foregroundStyle(LightSheet.title)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                // Sentence case and untracked, like every other caption. This
                // was the last all-caps label left after the stat row.
                Text("Until focus session ends")
                    .auraFont(.body, RowType.subLabel, .medium)
                    .foregroundStyle(LightSheet.subtitle)
            }
        }
        .frame(width: 208, height: 208)
    }
}
