//
//  OnboardingDemo.swift
//  Aura iOS
//
//  Phase 3: the "how it works in 3 simple steps" demo (block -> earn -> spend),
//  the earn-first reframe, and the setup bridge. The demo screens are a big
//  phone mockup + title + subtext + CTA on the sky/white-hill ground (mockup art
//  is a placeholder for now). The reframe and bridge are fox statements.
//

import SwiftUI

// MARK: - Demo step (phone mockup + title + subtext)

struct OnbDemoScreen: View {
    @Environment(OnboardingFlow.self) private var flow
    var showBack: Bool = true
    let title: String
    let subtext: String
    var cta: String = "Continue"

    // Brand blue (same as the button) over a white hill that meets at the middle.
    private let sky = LightSheet.blue

    var body: some View {
        ZStack {
            ZStack {
                sky
                HillShape(topRatio: 0.5, curveDepth: 0.05).fill(Color.white)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                OnbTopBar(showBack: showBack, progress: nil, onSky: true)

                // Lower than before so the peeking fox has room over the top.
                Spacer().frame(height: Theme.Spacing.xxxl)

                // Phone sits in the blue top half, overlapping the hill's crest, with
                // the fox peeking over its top edge (same treatment as the loop demo).
                ZStack(alignment: .top) {
                    Image("PhoneMockupDark")
                        .resizable().interpolation(.high).scaledToFit()
                        .frame(maxHeight: 470)
                        .shadow(color: .black.opacity(0.22), radius: 22, y: 14)

                    Image("Aura Fox_Peeking (2)")
                        .resizable().interpolation(.high).scaledToFit()
                        .frame(width: 104)
                        .foxShadow()
                        .offset(y: -63)
                        .allowsHitTesting(false)
                }

                Spacer()

                VStack(spacing: Theme.Spacing.s) {
                    Text(title)
                        .auraFont(.display, SheetType.title, .heavy)
                        .foregroundStyle(LightSheet.title)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtext)
                        .auraFont(.body, SheetType.cardTitle, .semibold)
                        .foregroundStyle(LightSheet.subtitleDark)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Theme.Spacing.xl)

                // Flexible gap so the copy sits well clear of the button.
                Spacer()

                // Blue button, white text (default LightPrimaryButton).
                LightPrimaryButton(title: cta) { flow.advance() }
                    .padding(.horizontal, Theme.Spacing.xl)
                Spacer().frame(height: Theme.Spacing.xl)
            }
        }
    }
}

// MARK: - Earn-first reframe (fox statement)

struct OnbReframeView: View {
    @Environment(OnboardingFlow.self) private var flow
    @State private var ready = false

    var body: some View {
        CompanionScaffold(
            showBack: false,
            progress: nil,
            lines: [
                "one thing before we get the app set up for you",
                "i'm not here to confiscate your phone",
                "you just earn it back",
                "do the important stuff first, then scroll all you want",
            ],
            onAllDone: { ready = true },
            content: { EmptyView() },
            bottom: {
                LightPrimaryButton(title: "Sounds good!",
                                   face: .white, textColor: LightSheet.title, shade: LightSheet.whiteShadeOnColour,
                                   enabled: ready) { flow.advance() }
            }
        )
    }
}

// MARK: - Setup bridge (fox statement -> the question stretch)

struct OnbBridgeView: View {
    @Environment(OnboardingFlow.self) private var flow
    @State private var ready = false

    var body: some View {
        CompanionScaffold(
            showBack: false,
            progress: nil,
            lines: [
                "alright, my turn to learn about you",
                "answer a few things honestly for me",
                "no wrong answers here",
            ],
            onAllDone: { ready = true },
            content: { EmptyView() },
            bottom: {
                LightPrimaryButton(title: "Let's go!",
                                   face: .white, textColor: LightSheet.title, shade: LightSheet.whiteShadeOnColour,
                                   enabled: ready) { flow.advance() }
            }
        )
    }
}
