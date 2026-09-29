//
//  OnboardingReviews.swift
//  Aura iOS
//
//  Screen 30 (locked flow): the reviews wall. Modeled on the Unrot reviews beat
//  but rebuilt in Aura's world: blue sky + white hill scene, the fox on the
//  crest, a two-tone headline, and soft App Store style review cards (stars +
//  handle + flag + quote). Honesty gate: the testimonials are PLACEHOLDERS,
//  swapped for real App Store reviews at launch. No fabricated rating, laurels,
//  user count, or face photos, and no native rating popup.
//

import SwiftUI

struct OnbReviewsView: View {
    @Environment(OnboardingFlow.self) private var flow

    private static let foxHeight: CGFloat = 160

    // Placeholder reviews. Replace with real App Store reviews at launch.
    private let reviews: [OnbReview] = [
        OnbReview(handle: "mattr_dev",
                  quote: "earning my screen time is the only thing that's ever worked for me."),
        OnbReview(handle: "sleeplessinSD",
                  quote: "got my mornings back. i actually make breakfast now instead of scrolling in bed."),
        OnbReview(handle: "priya.reads",
                  quote: "down from 7 hours a day to under 2. i genuinely didn't think i could."),
        OnbReview(handle: "cantcheatthis",
                  quote: "i have adhd and every other blocker i could just turn off. this one i actually can't cheat."),
        OnbReview(handle: "jords",
                  quote: "i stopped grabbing my phone the second i wake up. that alone was worth it."),
    ]

    var body: some View {
        ZStack {
            OnbSkyBackground(hillTop: 0.22, curveDepth: 0.05)

            VStack(spacing: 0) {
                OnbTopBar(showBack: true, onSky: true)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Image("FoxPhotoProofHero")
                            .resizable().interpolation(.high).scaledToFit()
                            .frame(height: Self.foxHeight)
                            .padding(.top, Theme.Spacing.xs)

                        headline
                            .padding(.top, Theme.Spacing.l)
                            .padding(.horizontal, Theme.Spacing.xl)

                        VStack(spacing: Theme.Spacing.l) {
                            ForEach(reviews) { OnbReviewCardRich(review: $0) }
                        }
                        .padding(.horizontal, Theme.Spacing.xl)
                        .padding(.top, Theme.Spacing.xxl)

                        Spacer().frame(height: Theme.Spacing.l)
                    }
                }

                LightPrimaryButton(title: "Continue") { flow.advance() }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.s)
                    .padding(.bottom, Theme.Spacing.l)
            }
        }
    }

    // Two-tone headline: dark with the payoff words in Aura blue.
    private var headline: some View {
        Text("Aura users get things \(Text("done").foregroundStyle(LightSheet.blue)), then scroll \(Text("guilt free").foregroundStyle(LightSheet.blue)).")
            .font(Typography.display(size: 28, weight: .heavy))
            .foregroundStyle(LightSheet.title)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Model

private struct OnbReview: Identifiable {
    let id = UUID()
    let handle: String
    let quote: String
}

// MARK: - Review card (soft grey: stars, handle + flag, quote)

private struct OnbReviewCardRich: View {
    let review: OnbReview

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(LightSheet.starGold)
                }
            }

            Text(review.handle)
                .auraFont(.body, SheetType.cardTitle, .bold)
                .foregroundStyle(LightSheet.title)

            Text("“\(review.quote)”")
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
