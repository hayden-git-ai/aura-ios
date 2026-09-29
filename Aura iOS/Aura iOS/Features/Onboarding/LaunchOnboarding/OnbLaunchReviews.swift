//
//  OnbLaunchReviews.swift
//  Aura iOS
//
//  Static social proof beat using Aura's existing review-wall language and
//  card treatment. Testimonials remain the same approved placeholders as the
//  full onboarding review wall until real launch reviews are supplied.
//

import SwiftUI

struct OnbLaunchReviews: View {
    @Environment(OnboardingFlow.self) private var flow

    private let reviews: [(String, String)] = [
        ("mattr_dev", "earning my screen time is the only thing that's ever worked for me."),
        ("sleeplessinSD", "got my mornings back. i actually make breakfast now instead of scrolling in bed."),
        ("priya.reads", "down from 7 hours a day to under 2. i genuinely didn't think i could.")
    ]

    var body: some View {
        ZStack {
            OnbSkyBackground(hillTop: 0.22, curveDepth: 0.05)

            VStack(spacing: 0) {
                OnbTopBar(showBack: true, progress: flow.progress, onSky: true)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Theme.Spacing.l) {
                        Image("FoxPhotoProofHero")
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(height: 140)
                            .padding(.top, Theme.Spacing.s)

                        Text("people are getting their time back")
                            .auraFont(.display, SheetType.heroCompact, .heavy)
                            .foregroundStyle(LightSheet.title)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Theme.Spacing.xl)

                        ForEach(Array(reviews.enumerated()), id: \.offset) { _, review in
                            reviewCard(handle: review.0, quote: review.1)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.bottom, Theme.Spacing.l)
                }

                LightPrimaryButton(title: "Continue") { flow.advance() }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.bottom, Theme.Spacing.l)
            }
        }
    }

    private func reviewCard(handle: String, quote: String) -> some View {
        VStack(spacing: Theme.Spacing.s) {
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(LightSheet.starGold)
                }
            }
            Text(handle)
                .auraFont(.body, SheetType.cardTitle, .bold)
                .foregroundStyle(LightSheet.title)
            Text("“\(quote)”")
                .auraFont(.body, SheetType.cardTitle, .medium)
                .foregroundStyle(LightSheet.subtitleDark.opacity(0.85))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity)
        .background(LightSheet.cardGrey, in: RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous))
        .cardShadow()
    }
}
