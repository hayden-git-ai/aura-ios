//
//  OnboardingReviewDrop.swift
//  Aura iOS
//
//  Screen 20 (locked flow): the review drop-in. A single tester quote woven into
//  the question stretch, right after `qSkip`, as a quick jab of social proof
//  before the "why nothing worked" phase. The full wall lives later (screen 30).
//  Honesty gate: the quote is a PLACEHOLDER, swapped for a real tester at launch.
//

import SwiftUI

struct OnbReviewDropView: View {
    @Environment(OnboardingFlow.self) private var flow
    @State private var shown = false

    var body: some View {
        ZStack {
            LightSheet.blue.ignoresSafeArea()

            VStack(spacing: 0) {
                OnbTopBar(showBack: true, progress: 0.64, onSky: true)

                Spacer()

                Text("Someone who was right where you are.")
                    .auraFont(.display, SheetType.heroCompact, .heavy)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Theme.Spacing.xl)

                Spacer().frame(height: Theme.Spacing.xl)

                // The single quote card, dropping in.
                VStack(spacing: Theme.Spacing.m) {
                    HStack(spacing: 3) {
                        ForEach(0..<5, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(LightSheet.starGold)
                        }
                    }

                    Text("i've tried every blocker out there. this is the first one that actually stuck.")
                        .auraFont(.display, SheetType.title, .bold)
                        .foregroundStyle(LightSheet.title)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Alex, 3 weeks in")
                        .auraFont(.body, SheetType.cardTitle, .medium)
                        .foregroundStyle(LightSheet.subtitleDark)
                }
                .padding(Theme.Spacing.xl)
                .frame(maxWidth: .infinity)
                .background(Color.white, in: RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous))
                .modalShadow()
                .padding(.horizontal, Theme.Spacing.xl)
                .scaleEffect(shown ? 1 : 0.92)
                .opacity(shown ? 1 : 0)

                Spacer()

                LightPrimaryButton(title: "Continue",
                                   face: .white, textColor: LightSheet.title, shade: LightSheet.whiteShadeOnColour) {
                    flow.advance()
                }
                .padding(.horizontal, Theme.Spacing.xl)
                Spacer().frame(height: Theme.Spacing.l)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.15)) { shown = true }
        }
    }
}
