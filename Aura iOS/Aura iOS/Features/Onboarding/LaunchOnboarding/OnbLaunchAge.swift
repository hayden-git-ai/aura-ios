//
//  OnbLaunchAge.swift
//  Aura iOS
//  Age uses the same question shell with an Aura-styled centered wheel.
//

import SwiftUI

struct OnbLaunchAge: View {
    @Environment(OnboardingFlow.self) private var flow
    private let wheelWidth: CGFloat = 272
    private let wheelHeight: CGFloat = 320
    private let rowHeight: CGFloat = 64
    private let selectionHeight: CGFloat = 72
    private let valueSize: CGFloat = 54

    var body: some View {
        @Bindable var flow = flow
        OnbLaunchQuestionLayout(progress: flow.progress, question: "How old are you?") {
            ZStack {
                Capsule()
                    .fill(LightSheet.track)
                    .frame(width: wheelWidth, height: selectionHeight)

                AuraWheelColumn(
                    values: Array(13...99),
                    selection: Binding(get: { flow.age ?? 18 }, set: { flow.age = $0 }),
                    fontSize: valueSize,
                    rowHeight: rowHeight,
                    wheelHeight: wheelHeight,
                    selectedColor: LightSheet.title,
                    idleColor: LightSheet.controlIdle,
                    label: { "\($0)" }
                )
                .frame(width: wheelWidth, height: wheelHeight)
            }
            .frame(maxWidth: .infinity)
            .frame(height: wheelHeight)
            .padding(.top, Theme.Spacing.l)
        } bottom: {
            onbLaunchContinue { flow.advance() }
        }
    }
}
