//
//  StreakScreen.swift
//  Aura iOS
//

import SwiftUI

/// The streak destination, opened by tapping the Home badge: the fox, the count,
/// the streak line, and the goal bar, over a slowly rotating orange sunburst.
///
/// The fox, count, line and goal card are shared components (`StreakFoxHero`,
/// `StreakCount`, `StreakGoalCard`) so the post-quest celebration shows the exact
/// same block.
struct StreakScreen: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private var streak: Int { store.streak.currentStreak }

    var body: some View {
        GeometryReader { screen in
            let topClear = screen.safeAreaInsets.top + Theme.Spacing.l
            ZStack(alignment: .top) {
                SunburstBackground().ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        StreakFoxHero()
                            // Pushed down so the fox and everything under it sit
                            // lower, over the sunburst's centre.
                            .padding(.top, Theme.Spacing.xxxl * 2)

                        StreakCount(count: streak)
                            // fox → number.
                            .padding(.top, Theme.Spacing.l)

                        StreakGoalCard(streak: streak)
                            .padding(.horizontal, Theme.Spacing.xl)
                            // line → card.
                            .padding(.top, Theme.Spacing.xxl)
                    }
                    // Clears the floating controls row. The freeze pill expands as
                    // an overlay above this, so opening it never shifts the content.
                    .padding(.top, topClear + CircleIconButton.minimumTarget)
                    .padding(.bottom, Theme.Spacing.xxxl)
                }
                .ignoresSafeArea(edges: .top)

                // Already inside the safe area (unlike the scroll, which ignores
                // it), so only the `l` gap — not the full inset — goes here.
                controls
                    .padding(.top, Theme.Spacing.l)
            }
        }
    }

    // MARK: - Controls

    /// X left, freezes right — the same corner pairing every other screen uses.
    private var controls: some View {
        HStack(alignment: .top) {
            CircleIconButton(symbol: "xmark", fill: LightSheet.chromeOnBlue, glyphColor: .white) { dismiss() }
            Spacer(minLength: Theme.Spacing.m)
            StreakFreezeCard(freezes: store.streakFreezes)
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }
}

#Preview {
    StreakScreen()
        .environment(HabitStore())
}
