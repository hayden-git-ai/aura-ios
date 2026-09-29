//
//  OnbLaunchComparison.swift
//  Aura iOS
//
//  Personalized comparison beat for the launch flow.
//

import SwiftUI

struct OnbLaunchComparison: View {
    @Environment(OnboardingFlow.self) private var flow

    var body: some View {
        OnbLaunchQuestionLayout(
            progress: flow.progress,
            contentTopSpacing: Theme.Spacing.s,
            question: "Build habits before you scroll"
        ) {
            VStack(spacing: Theme.Spacing.xxl) {
                Text("Turn screen time into a reward for completing a habit.")
                    .auraFont(.body, SheetType.cardTitle, .medium)
                    .foregroundStyle(LightSheet.subtitleDark)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                comparisonChart
            }
        } bottom: {
            onbLaunchContinue { flow.advance() }
        }
    }

    private var comparisonChart: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.xxl) {
            comparisonBar(
                label: "Without Aura",
                detail: "Scroll first",
                supporting: "No habit needed",
                height: 64,
                color: LightSheet.field,
                textColor: LightSheet.title
            )
            comparisonBar(
                label: "With Aura",
                detail: "Habit first",
                supporting: "Then earn time",
                height: 216,
                color: LightSheet.blue,
                textColor: Color.white
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: 304, alignment: .bottom)
    }

    private func comparisonBar(label: String, detail: String, supporting: String, height: CGFloat,
                               color: Color, textColor: Color) -> some View {
        VStack(spacing: Theme.Spacing.s) {
            Text(label)
                .auraFont(.body, SheetType.cardTitle, .bold)
                .foregroundStyle(LightSheet.title)
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(color)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .overlay(alignment: .bottom) {
                    Text(detail)
                        .auraFont(.body, SheetType.cardTitle, .bold)
                        .foregroundStyle(textColor)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.s)
                        .padding(.bottom, Theme.Spacing.l)
                }

            Text(supporting)
                .auraFont(.body, SheetType.cardBlurb, .bold)
                .foregroundStyle(LightSheet.subtitleDark)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity, alignment: .bottom)
    }
}
