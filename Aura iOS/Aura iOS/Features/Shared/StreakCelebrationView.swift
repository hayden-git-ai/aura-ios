//
//  StreakCelebrationView.swift
//  Aura iOS
//

import SwiftUI

/// The first habit of the day, and the streak it just kept alive.
///
/// Shared by every earn flow (Photo Proof, Exercise, Deep Focus, Apple Health);
/// only the button's label and action differ. On Photo Proof it lands straight
/// after `ProofSuccessView`, so the run shows two screens back to back on the
/// first habit of a day: this photo worked, and then the streak it fed.
///
/// It shows the exact same block as the Home streak screen — `StreakFoxHero`,
/// `StreakCount`, `StreakGoalCard`, over the same peach `SunburstBackground` —
/// plus this screen's own button and footnote. The two screens are the same
/// subject seen twice and should not look like they came from different apps.
///
/// The count is the event: it rolls up from zero to where the streak now stands
/// rather than printing the answer. Landing it instantly would say "here is a
/// number"; ticking up says "look what you did". The fox just plays its loop.
struct StreakCelebrationView: View {
    let currentStreak: Int
    /// Kept for call-site compatibility; the streak block anchors on the count.
    var today: Date = .now
    var buttonTitle: String = "Continue"
    var footnote: String? = nil
    var onButton: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Counts up to `currentStreak` rather than starting there. The number
    /// climbing is the whole event; printing the answer is a receipt.
    @State private var shownStreak = 0

    var body: some View {
        VStack(spacing: 0) {
            // Four above, one below. SwiftUI has no way to weight a Spacer, so
            // the weight is the count: most of the slack sits above the fox,
            // which pulls the block down against the button.
            Spacer(minLength: 0)
            Spacer(minLength: 0)
            Spacer(minLength: 0)
            Spacer(minLength: 0)

            StreakFoxHero()

            StreakCount(count: shownStreak)
                // fox → number.
                .padding(.top, Theme.Spacing.l)

            StreakGoalCard(streak: currentStreak)
                // line → card.
                .padding(.top, Theme.Spacing.xxl)

            Spacer(minLength: Theme.Spacing.xl)

            LightPrimaryButton(title: buttonTitle,
                               face: .white,
                               textColor: LightSheet.title,
                               shade: LightSheet.whiteShadeOnColour,
                               action: onButton)

            // The footnote's line box is reserved whether or not there is one,
            // so the button lands in the same place on all five flows.
            Text(footnote ?? " ")
                .auraFont(.body, SheetType.subtitle, .regular)
                .foregroundStyle(.black.opacity(0.55))
                .multilineTextAlignment(.center)
                .opacity(footnote == nil ? 0 : 1)
                .accessibilityHidden(footnote == nil)
                .padding(.top, Theme.Spacing.m)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.bottom, Theme.Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The same rotating peach sunburst as the Home streak screen, so the
        // post-quest celebration and the streak destination read as one place.
        .background(SunburstBackground().ignoresSafeArea())
        .onAppear(perform: animateIn)
    }

    /// The count rolls up to where it now stands, ticking through the numbers and
    /// decelerating onto the final one — a real count, not a snap.
    private func animateIn() {
        guard !reduceMotion else {
            shownStreak = currentStreak
            return
        }

        Task { @MainActor in
            // A short settle, then tick up. Capped at 28 frames so a 1000-day
            // streak rolls just as quickly as a 12-day one.
            try? await Task.sleep(for: .seconds(0.25))
            let steps = max(1, min(currentStreak, 28))
            let total = 1.0
            for i in 0...steps {
                let t = Double(i) / Double(steps)
                let eased = 1 - pow(1 - t, 3)   // ease-out: fast, then settling
                shownStreak = Int((Double(currentStreak) * eased).rounded())
                try? await Task.sleep(for: .seconds(total / Double(steps)))
            }
            shownStreak = currentStreak
            Haptics.notify(.success)
        }
    }
}

#Preview {
    StreakCelebrationView(
        currentStreak: 64,
        buttonTitle: "Start Habit Timer",
        footnote: "Your apps will unlock once the timer ends.",
        onButton: {}
    )
}
