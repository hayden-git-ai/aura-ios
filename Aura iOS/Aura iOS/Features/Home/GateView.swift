//
//  GateView.swift
//  Aura iOS
//

import SwiftUI

/// Home tab root. Three states: an active habit timer (Photo Proof session
/// counting down until apps unlock), the unlocked countdown, or the locked
/// "earn time" prompt.
struct GateView: View {
    @Environment(HabitStore.self) private var store

    /// Opens the earn-method popover (presented up in RootTabView so it can dim
    /// the nav) — triggered by the Earn action card.
    var onEarn: () -> Void = {}

    var body: some View {
        ZStack {
            HomeBackground()

            VStack(spacing: 0) {
                Image("AuraLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 44)
                    .padding(.top, Theme.Spacing.m)

                if let session = store.activeHabitSession {
                    VStack(spacing: 0) {
                        Spacer()
                        HabitSessionTimerView(
                            session: session,
                            onTogglePause: { store.toggleHabitSessionPause() },
                            onEnd: { store.endHabitSession() }
                        )
                        Spacer()
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.bottom, Theme.Layout.navBarClearance)
                } else {
                    VStack(spacing: 0) {
                        Spacer()
                        focal
                        Spacer()
                    }
                    .padding(.bottom, Theme.Layout.navBarClearance)
                }
            }
            // Streak badge pinned to the screen's top-right, level with the
            // centered logo — flame over its count.
            .overlay(alignment: .topTrailing) {
                StreakBadge(count: store.streak.currentStreak)
                    .padding(.top, Theme.Spacing.m)
                    .padding(.trailing, Theme.Spacing.xl)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The centered focal — a big "time left" number, one status line, and the
    /// stats pill right beneath. The mascot drops in around this later.
    private var focal: some View {
        let minutesRemaining = max(0, store.secondsRemaining / 60)
        return VStack(spacing: Theme.Spacing.l) {
            VStack(spacing: Theme.Spacing.s) {
                // With nothing earned, the tired-fox flipbook takes the focal
                // slot in place of a lifeless "0m" — the mascot embodies the
                // drained state and invites the user to earn time back.
                if minutesRemaining == 0 {
                    TiredFoxFrameAnimation(fps: 30)
                        .frame(height: 220)
                        .frame(maxWidth: .infinity)
                        // Soft contact ellipse under the fox's feet to ground
                        // it. On the black background a dark shadow wouldn't
                        // read, so this is a faint light "platform" glow.
                        .background(alignment: .bottom) {
                            Ellipse()
                                .fill(Color.white.opacity(0.22))
                                .frame(width: 130, height: 26)
                                .blur(radius: 10)
                                .offset(y: -6)
                        }
                } else {
                    Text(ScreenTimeSnapshot.minutesLabel(minutesRemaining))
                        .font(Typography.display(size: 72, weight: .heavy))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                }
            }
            earnGoalBar
            actionCards
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }

    /// Today's earn progress as a card: the coin in a green-tinted circle, a
    /// "Earned Today" title with an X/Y readout, and an apple-green progress bar
    /// beneath. Flips to a celebratory readout once the goal is hit.
    private var earnGoalBar: some View {
        let earned = store.todayEarnedMinutes
        let goal = store.dailyGoalMinutes
        let hitGoal = earned >= goal
        let green = Theme.Color.signalGood

        return HStack(spacing: Theme.Spacing.m) {
            Image("AuraCoinIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                HStack(spacing: Theme.Spacing.s) {
                    Text("Earned Today")
                        .font(Typography.body(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer(minLength: 0)
                    if hitGoal {
                        Text("Goal hit 🎉")
                            .font(Typography.body(size: 13, weight: .bold))
                            .foregroundStyle(green)
                    } else {
                        Text("\(earned)/\(goal) min")
                            .font(Typography.body(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.Color.textSecondary)
                            .contentTransition(.numericText())
                    }
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.10))
                        Capsule()
                            .fill(green)
                            .frame(width: max(0, proxy.size.width * store.dailyGoalProgress))
                            .shadow(color: green.opacity(0.5), radius: 5)
                    }
                }
                .frame(height: 8)
                .animation(.snappy(duration: 0.35), value: store.dailyGoalProgress)
            }
        }
        .padding(Theme.Spacing.m)
        .background(cardMaterial)
    }

    /// The onboarding-option surface material — a diagonal surface→recessed
    /// gradient with a hairline border. Shared by the stat card and the action
    /// tiles so they read as one family.
    private var cardMaterial: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Theme.Color.surface, Theme.Color.surfaceRecessed],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
    }

    /// The two 16:9 action tiles beneath the prompt — Earn / Scroll — using the
    /// same surface material as the onboarding option cards. Icons are SF Symbol
    /// placeholders for now.
    private var actionCards: some View {
        HStack(spacing: Theme.Spacing.m) {
            // Earn opens the method popover, which grows from this card — its
            // frame is published via EarnAnchorKey for RootTabView to read.
            Button(action: onEarn) {
                // The coin is round, so it reads smaller than the tall phone at
                // an equal frame — size it up to balance them visually.
                actionCard(title: "Earn", iconAsset: "EarnCardIcon", iconSize: 48)
            }
            .buttonStyle(PressBounceStyle())
            .anchorPreference(key: EarnAnchorKey.self, value: .bounds) { $0 }

            // Scroll is a placeholder for spending earned time (wired later).
            actionCard(title: "Scroll", iconAsset: "ScrollCardIcon", iconSize: 44)
        }
    }

    /// Shared height of the icon slot across both cards. Each icon sizes itself
    /// within this fixed slot, so a larger/smaller icon never shifts the label
    /// or breaks alignment between the two cards.
    private let actionIconSlot: CGFloat = 52

    private func actionCard(title: String, iconAsset: String, iconSize: CGFloat) -> some View {
        // Material drives the 16:9 box; the icon+label are overlaid dead-center
        // so they never drift with the content's own intrinsic size.
        cardMaterial
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .overlay {
                VStack(spacing: Theme.Spacing.xs) {
                    Image(iconAsset)
                        .resizable()
                        .scaledToFit()
                        .frame(width: iconSize, height: iconSize)
                        // Fixed-height slot keeps both labels at the same Y
                        // regardless of each icon's visual size.
                        .frame(height: actionIconSlot)
                    Text(title)
                        .font(Typography.body(size: 17, weight: .heavy))
                        .foregroundStyle(.white)
                }
            }
    }

}

/// A compact streak indicator for the Home header's top-right: the fire icon
/// in a soft circle with its day count stacked directly beneath, in the same
/// white General Sans display face as the screen-time readout.
private struct StreakBadge: View {
    let count: Int

    var body: some View {
        // Negative spacing lets the numeral's top tuck slightly under the
        // circle — the number renders after the circle, so it sits on top.
        VStack(spacing: -8) {
            ZStack {
                // Same circle treatment as the onboarding back button.
                Circle()
                    .fill(Color.white.opacity(0.14))
                    .frame(width: 44, height: 44)
                Image("StreakFireIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 30)
            }
            // Plain white numeral, same display face as the screen-time readout.
            Text("\(count)")
                .font(Typography.display(size: 22))
                .foregroundStyle(.white)
        }
    }
}

/// Home background — a flat black surface. (The looping video background was
/// removed; the focal fox and controls sit directly on black.)
private struct HomeBackground: View {
    var body: some View {
        Color.black
            .ignoresSafeArea()
    }
}

/// The Home-screen ring timer for an active Photo Proof habit session — counts
/// down "until apps unlock", with Pause/Resume and End controls.
private struct HabitSessionTimerView: View {
    let session: ActiveHabitSession
    var onTogglePause: () -> Void
    var onEnd: () -> Void

    private var clock: String {
        String(format: "%d:%02d", session.remainingSeconds / 60, session.remainingSeconds % 60)
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
                    .font(Typography.body(size: 17, weight: .bold))
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
                    .font(Typography.body(size: 17, weight: .bold))
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
                .trim(from: 0, to: session.progress)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: session.progress)

            VStack(spacing: Theme.Spacing.xs) {
                Text(clock)
                    .font(Typography.display(size: 46, weight: .heavy))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text("UNTIL APPS UNLOCKED")
                    .font(Typography.body(size: 11, weight: .bold))
                    .foregroundStyle(Theme.Color.textSecondary)
                    .tracking(1)
            }
        }
        .frame(width: 240, height: 240)
    }
}

#Preview {
    GateView()
        .environment(HabitStore())
        .preferredColorScheme(.dark)
}
