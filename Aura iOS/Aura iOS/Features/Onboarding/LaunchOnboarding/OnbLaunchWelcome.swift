//
//  OnbLaunchWelcome.swift
//  Aura iOS
//
//  Launch-flow copy of OnbWelcomeView (screen 1). Independent so the launch
//  onboarding can be redesigned without touching the v2 original.
//

import SwiftUI

struct OnbLaunchWelcome: View {
    @Environment(OnboardingFlow.self) private var flow
    var body: some View {
        ZStack {
            // Illustrated sky + mountains background (full bleed). Drawn via a
            // Color.clear overlay + clip so the oversized scaledToFill image
            // never widens the layout.
            Color.clear
                .overlay {
                    Image("Onboarding_Welcome Screen (1)")
                        .resizable().interpolation(.high).scaledToFill()
                        .scaleEffect(1.03)
                        .blur(radius: 1.5)
                }
                .clipped()
                .ignoresSafeArea()

            Color.black.opacity(0.18).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: Theme.Spacing.xl)

                Image("PhoneMockupDark")
                    .resizable().interpolation(.high).scaledToFit()
                    .frame(height: 440)
                    .shadow(color: .black.opacity(0.22), radius: 22, y: 14)
                    .overlay(alignment: .top) {
                        Image("Aura Fox_Peeking (2)")
                            .resizable().interpolation(.high).scaledToFit()
                            .frame(width: 104)
                            .foxShadow()
                            .offset(y: -63)
                    }
                    .padding(.top, 59.4)

                Spacer().frame(height: 33)

                VStack(spacing: Theme.Spacing.s) {
                    StrokedNumber(
                        text: "Live More. Scroll Less.",
                        font: Typography.displayUIFont(size: SheetType.heroCompact, weight: .heavy),
                        fill: UIColor(LightSheet.title),
                        stroke: .white,
                        outlineWidth: SheetType.heroCompact * StrokedNumeral.outlineRatio
                    )
                    .fixedSize()
                    .shadow(color: .black.opacity(0.18), radius: 3, y: 1)

                    Text("Replace doomscrolling with healthy habits.")
                        .auraFont(.body, SheetType.cardTitle, .bold)
                        .foregroundStyle(LightSheet.title)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Theme.Spacing.xl)

                Spacer(minLength: Theme.Spacing.l)

                VStack(spacing: Theme.Spacing.m) {
                    LightPrimaryButton(title: "Get started",
                                       face: .white, textColor: LightSheet.title, shade: LightSheet.whiteShadeOnColour) { flow.advance() }
                    Button { flow.onSignInRequested() } label: {
                        Text("Already have an account? \(Text("Sign in").font(Typography.body(size: 15, weight: .bold)).foregroundStyle(.white).underline())")
                            .font(Typography.body(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.22), radius: 3, y: 1)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Theme.Spacing.xl)
                Spacer().frame(height: Theme.Spacing.xl)
            }
        }
    }
}
