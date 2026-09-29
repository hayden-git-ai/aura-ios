//
//  OnboardingCost.swift
//  Aura iOS
//
//  Phase 5: the cost + the flip, adapted from Blank. Two dark, full-drama screens
//  driven by the slider's [hours]:
//   1. "this is your life in weeks" - a life grid builds top-down, then the weeks
//      the phone steals fill from the bottom (red -> purple) while a counter rolls
//      up to [X] years. CTA "Fix This".
//   2. "over a lifetime, i can give you back" - "+[X] years" counts up behind a
//      growing sunburst, with a "+[hours]h / day of focus" pill. CTA "Continue".
//  Both keep the fox (compact, no ground shadow) on a black ground.
//

import SwiftUI

// MARK: - Reclaim their time as real things

struct OnbReclaimView: View {
    @Environment(OnboardingFlow.self) private var flow
    @State private var hourCounter = 0
    @State private var revealed = 0          // how many of the 3 cards have dropped in
    @State private var started = false
    @State private var ready = false

    // MARK: - Numbers from their real slider input

    /// Reclaim just a quarter of their daily habit over the next 3 months.
    private var reclaimedHours: Int { Int((flow.hours * 0.25 * 90).rounded()) }
    private var things: [ReclaimThing] {
        [ReclaimThing(sticker: "FoxHabitRead",  count: max(1, reclaimedHours / 6),
                      label: "Books you could read."),
         ReclaimThing(sticker: "FoxHabitStudy", count: max(1, reclaimedHours / 15),
                      label: "Online courses finished."),
         ReclaimThing(sticker: "FoxHabitGym",   count: max(1, Int((Double(reclaimedHours) / 1.5).rounded())),
                      label: "Workouts crushed.")]
    }

    var body: some View {
        ZStack {
            LightSheet.blue.ignoresSafeArea()

            VStack(spacing: 0) {
                OnbTopBar(showBack: true, progress: 0.78, onSky: true)

                Spacer(minLength: Theme.Spacing.l)

                Text("Take back just 25% of your screen time.")
                    .auraFont(.display, SheetType.title, .bold)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Theme.Spacing.xl)

                Text("+\(hourCounter)h")
                    .auraFont(.body, 76, .heavy)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(.white)
                    .padding(.top, Theme.Spacing.xs)

                Text("back over the next 3 months. that's...")
                    .auraFont(.body, SheetType.cardTitle, .semibold)
                    .foregroundStyle(.white.opacity(0.8))

                Spacer(minLength: Theme.Spacing.xl)

                VStack(spacing: Theme.Spacing.m) {
                    ForEach(Array(things.enumerated()), id: \.offset) { i, thing in
                        ReclaimThingCard(thing: thing)
                            .opacity(revealed > i ? 1 : 0)
                            .offset(y: revealed > i ? 0 : 18)
                            .scaleEffect(revealed > i ? 1 : 0.96)
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)

                Spacer(minLength: Theme.Spacing.xl)

                LightPrimaryButton(title: "Continue",
                                   face: .white, textColor: LightSheet.title, shade: LightSheet.whiteShadeOnColour,
                                   enabled: ready) { flow.advance() }
                    .padding(.horizontal, Theme.Spacing.xl)
                Spacer().frame(height: Theme.Spacing.l)
            }
        }
        .onAppear { startReveal() }
    }

    private func startReveal() {
        guard !started else { return }
        started = true
        Task { @MainActor in
            // Count the hours up.
            let target = max(0, reclaimedHours)
            if target > 0 {
                let per = min(0.03, 1.0 / Double(target))
                for v in stride(from: 1, through: target, by: max(1, target / 40)) {
                    withAnimation(.snappy(duration: per)) { hourCounter = v }
                    try? await Task.sleep(for: .seconds(per))
                }
                withAnimation(.snappy(duration: 0.15)) { hourCounter = target }
            }
            Haptics.impact(.light)
            // Then drop the three things in, one at a time.
            for _ in 0..<3 {
                try? await Task.sleep(for: .seconds(0.35))
                withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { revealed += 1 }
                Haptics.impact(.light)
            }
            ready = true
        }
    }
}

// MARK: - Reclaim thing

private struct ReclaimThing {
    let sticker: String
    let count: Int
    let label: String
}

private struct ReclaimThingCard: View {
    let thing: ReclaimThing

    var body: some View {
        HStack(spacing: Theme.Spacing.l) {
            Image(thing.sticker)
                .resizable().interpolation(.high).scaledToFit()
                .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(thing.count)+")
                    .auraFont(.body, SheetType.heroCompact, .heavy)
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text(thing.label)
                    .auraFont(.body, SheetType.cardTitle, .semibold)
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous)
                .fill(Color.black.opacity(0.16))
        )
    }
}
