//
//  OnbLaunchDemoScreen.swift
//  Aura iOS
//
//  Launch-flow copy of OnbDemoScreen (screens 7-9: block / earn / spend). Reuses
//  the shared HillShape + top bar chrome; the copy exists so the launch demo copy
//  can change without touching the v2 original.
//

import SwiftUI

struct OnbLaunchDemoScreen: View {
    @Environment(OnboardingFlow.self) private var flow
    var showBack: Bool = true
    let title: String
    let subtext: String
    var cta: String = "Continue"

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

                Spacer().frame(height: Theme.Spacing.xxxl)

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

                Spacer()

                LightPrimaryButton(title: cta) { flow.advance() }
                    .padding(.horizontal, Theme.Spacing.xl)
                Spacer().frame(height: Theme.Spacing.xl)
            }
        }
    }
}
