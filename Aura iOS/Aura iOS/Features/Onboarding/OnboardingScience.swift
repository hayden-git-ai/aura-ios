//
//  OnboardingScience.swift
//  Aura iOS
//
//  Screen 29 (locked flow): "The science." Proof beat after the Wrapped payoff.
//  Solid-blue: fox + claim + subtext up top, two citation cards down by the button
//  backing the replace-don't-resist method. Honesty gate: cards cite real work the
//  method draws on, never claim the sources endorse Aura.
//

import SwiftUI

struct OnbScienceView: View {
    @Environment(OnboardingFlow.self) private var flow

    private static let foxHeight: CGFloat = 138

    var body: some View {
        ZStack {
            LightSheet.blue.ignoresSafeArea()

            VStack(spacing: 0) {
                // One connected column: fox -> headline -> subtext -> the two proof
                // cards that back it. Equal flexible space above the column and below
                // it (above the pinned button) centers the whole argument, so the
                // empty screen sits at the edges, not as a canyon in the middle.
                Spacer(minLength: Theme.Spacing.l)

                Image("FoxLockInHero")
                    .resizable().interpolation(.high).scaledToFit()
                    .frame(height: Self.foxHeight)
                    .foxShadow()

                Spacer().frame(height: Theme.Spacing.l)

                Text("Resisting doesn't work. Replacing does.")
                    .auraFont(.display, SheetType.heroCompact, .heavy)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Theme.Spacing.xl)

                Spacer().frame(height: Theme.Spacing.l)

                Text("Your distracting apps stay locked. Finish a habit to earn them back.")
                    .auraFont(.body, SheetType.cardTitle, .semibold)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Theme.Spacing.xl)

                // Fixed gap: the cards are the evidence for the headline, so they stay
                // attached to the claim as one group rather than drifting to the bottom.
                Spacer().frame(height: Theme.Spacing.xxl)

                VStack(spacing: Theme.Spacing.m) {
                    citationCard(logo: "LogoAPA",
                                 claim: "Swap in a planned habit and you're about 2x more likely to follow through.",
                                 source: "American Psychological Association")
                    citationCard(logo: "CoverAtomicHabits",
                                 claim: "You don't break a habit by resisting it. You replace it with a better one.",
                                 source: "Atomic Habits, James Clear")
                }
                .padding(.horizontal, Theme.Spacing.xl)

                Spacer(minLength: Theme.Spacing.l)

                LightPrimaryButton(title: "Continue",
                                   face: .white, textColor: LightSheet.title, shade: LightSheet.whiteShadeOnColour) {
                    flow.advance()
                }
                .padding(.horizontal, Theme.Spacing.xl)
                Spacer().frame(height: Theme.Spacing.xl)
            }
        }
    }

    private func citationCard(logo: String, claim: String, source: String) -> some View {
        HStack(alignment: .center, spacing: Theme.Spacing.m) {
            Image(logo)
                .resizable().interpolation(.high).scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(claim)
                    .auraFont(.body, SheetType.cardTitle, .semibold)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(source)
                    .auraFont(.body, SheetType.subtitle, .medium)
                    .foregroundStyle(.white.opacity(0.7))
                    .italic()
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, minHeight: 108, maxHeight: 108, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.16))
        )
    }
}
