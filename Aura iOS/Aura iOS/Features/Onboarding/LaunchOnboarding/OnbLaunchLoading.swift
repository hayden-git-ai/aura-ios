//
//  OnbLaunchLoading.swift
//  Aura iOS
//
//  Deliberate loading beat for the launch flow. Progress is the only motion;
//  the Aura fox remains a still asset on this screen.
//

import SwiftUI

struct OnbLaunchLoading: View {
    @Environment(OnboardingFlow.self) private var flow

    private let steps = ["Reading your answers", "Matching your habits", "Building your plan"]
    private let stageDurations: [Double] = [1.5, 2.75, 4.25]
    @State private var activeStep = -1
    @State private var fills: [CGFloat] = [0, 0, 0]
    @State private var dotCount = 1

    var body: some View {
        ZStack {
            LightSheet.blue.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                ZStack(alignment: .bottom) {
                    Ellipse()
                        .fill(Color.black.opacity(0.14))
                        .frame(width: 92, height: 18)
                        .offset(y: -3)

                    Image("FoxEmptyState")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(height: 150)
                }
                .frame(height: 150)

                Text("Building your Aura plan")
                    .auraFont(.display, SheetType.heroCompact, .heavy)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.xl)

                VStack(spacing: Theme.Spacing.xl) {
                    ForEach(steps.indices, id: \.self) { index in
                        VStack(spacing: Theme.Spacing.s) {
                            Capsule()
                                .fill(Color.white.opacity(0.22))
                                .frame(height: 6)
                                .overlay(alignment: .leading) {
                                    GeometryReader { geometry in
                                        Capsule()
                                            .fill(Color.white)
                                            .frame(width: geometry.size.width * fills[index])
                                    }
                                }
                            Text(stepLabel(at: index))
                                .auraFont(.body, SheetType.cardTitle, .bold)
                                .foregroundStyle(.white.opacity(index <= activeStep ? 1 : 0.48))
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.xxl)

                Spacer()
            }
        }
        .task { await buildPlan() }
        .task { await animateEllipsis() }
    }

    private func stepLabel(at index: Int) -> String {
        guard index == activeStep else { return steps[index] }
        return steps[index] + String(repeating: ".", count: dotCount)
    }

    private func animateEllipsis() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            dotCount = dotCount == 3 ? 1 : dotCount + 1
        }
    }

    private func buildPlan() async {
        guard activeStep < 0 else { return }
        for index in steps.indices {
            activeStep = index
            let duration = stageDurations[index]
            withAnimation(.linear(duration: duration)) { fills[index] = 1 }
            try? await Task.sleep(for: .seconds(duration + 0.25))
        }
        try? await Task.sleep(for: .seconds(0.4))
        guard !Task.isCancelled else { return }
        flow.advance()
    }
}
