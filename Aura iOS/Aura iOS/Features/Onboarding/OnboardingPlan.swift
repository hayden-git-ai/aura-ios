//
//  OnboardingPlan.swift
//  Aura iOS
//
//  Phase 7: the single loading beat (the only loader in the funnel), which builds
//  into the custom plan reveal. Title + fox + three sequential steps, each with a
//  progress bar that fills in turn, then it advances.
//

import SwiftUI

struct OnbLoadingView: View {
    @Environment(OnboardingFlow.self) private var flow

    private let steps = ["analyzing your habits", "calculating your profile", "building your plan"]
    @State private var active = -1
    @State private var fills: [CGFloat] = [0, 0, 0]

    var body: some View {
        ZStack {
            LightSheet.blue.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image("FoxEmptyState")
                    .resizable().interpolation(.high).scaledToFit()
                    .frame(height: 150)
                    .background(alignment: .bottom) {
                        Ellipse().fill(Color.black.opacity(0.13))
                            .frame(width: 150 * 0.51, height: 150 * 0.136)
                            .offset(y: -8)
                    }

                Text("personalizing your experience")
                    .auraFont(.display, SheetType.heroCompact, .heavy)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.xl)

                VStack(spacing: Theme.Spacing.xl) {
                    ForEach(steps.indices, id: \.self) { i in
                        stepRow(i)
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.xxl)

                Spacer()
            }
        }
        .task { await run() }
    }

    @ViewBuilder private func stepRow(_ i: Int) -> some View {
        VStack(spacing: Theme.Spacing.s) {
            Capsule()
                .fill(Color.white.opacity(0.22))
                .frame(height: 6)
                .overlay(alignment: .leading) {
                    GeometryReader { g in
                        Capsule().fill(Color.white)
                            .frame(width: g.size.width * fills[i])
                    }
                }
            Text(steps[i])
                .auraFont(.body, SheetType.cardTitle, .bold)
                .foregroundStyle(.white.opacity(i <= active ? 1 : 0.45))
        }
    }

    private func run() async {
        for i in steps.indices {
            active = i
            Haptics.impact(.light)
            withAnimation(.easeInOut(duration: 0.9)) { fills[i] = 1 }
            try? await Task.sleep(for: .seconds(1.0))
        }
        try? await Task.sleep(for: .seconds(0.4))
        flow.advance()
    }
}
