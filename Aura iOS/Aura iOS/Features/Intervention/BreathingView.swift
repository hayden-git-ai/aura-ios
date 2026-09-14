//
//  BreathingView.swift
//  Aura iOS
//

import SwiftUI

/// One breath before the conversation starts.
///
/// A preamble, not its own intervention: it hands off to the same challenge,
/// duration and pay beats every style ends in. All a style changes is how the
/// moment opens.
///
/// It happens on the **same day/night mountain scene** as every other
/// intervention screen, with the fox in the same place and at the same size —
/// so the breath dissolves straight into the challenge with only the fox and
/// the words changing, and the mascot never jumps. The breath itself is carried
/// by the fox's animation (baked to swell over the inhale, hold, and settle
/// over the exhale) and the countdown; the tempo is 4 in, 2 hold, 3 out.
struct BreathingView: View {
    var onFinish: () -> Void

    @State private var phase: Phase = .inhale
    @State private var remaining = Phase.inhale.seconds

    private enum Phase: CaseIterable {
        case inhale, hold, exhale

        var seconds: Int {
            switch self {
            case .inhale: return 4
            case .hold: return 2
            case .exhale: return 3
            }
        }

        var caption: String {
            switch self {
            case .inhale: return "Breathe in."
            case .hold: return "Hold. Relax."
            case .exhale: return "Breathe out."
            }
        }
    }

    var body: some View {
        ZStack {
            // No background of its own — the InterventionView holds one
            // persistent HomeBackground behind the whole flow, so the breath
            // dissolves into the challenge with no flash. This view is just the
            // fox + words that fade over that shared scene.

            // The fox is centred on the screen and the words hang below it — the
            // same arrangement the conversation uses, so the mascot holds its
            // position through the hand-off.
            ZStack {
                fox

                VStack(spacing: Theme.Spacing.m) {
                    Text(phase.caption)
                        .auraFont(.display, 24, .bold)

                    // Always "seconds". Dropping the s at one made the whole line
                    // re-layout on the last tick, which read as a stutter right
                    // where the roll should be smoothest.
                    Text("\(remaining) seconds")
                        .auraFont(.body, SheetType.cardTitle, .semibold)
                        .contentTransition(.numericText(countsDown: true))
                }
                // White over the mountain scene, with the same layered shadow the
                // conversation line uses so it holds against the bright day sky
                // and the dark night alike.
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.55), radius: 4, y: 1)
                .shadow(color: .black.opacity(0.5), radius: 16, y: 3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Theme.Spacing.xl)
                .offset(y: InterventionLayout.foxHeight / 2 + Theme.Spacing.xxxl)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Lifted off dead-centre so his feet land on the rock ledge at the
            // same screen height as the Home and conversation foxes (~49pt up).
            .offset(y: Self.foxLedgeLift)
            .ignoresSafeArea()
        }
        .preferredColorScheme(.light)
        .task { await breathe() }
    }

    /// The mascot, breathing with the exercise. The swell is baked into the clip
    /// (feet planted, body grows over the inhale, settles over the exhale) and
    /// keyed to the standard fox geometry, so this is the exact conversation fox
    /// setup — same 220pt size, same day/night contact shadow, same nudge — and
    /// he reads as the same mascot in the same spot.
    private var fox: some View {
        LoopingVideoView(resource: "InterventionBreathingFox")
            .frame(height: InterventionLayout.foxHeight)
            .frame(maxWidth: .infinity)
            // The Home fox's contact shadow — stronger at night, as there.
            .background(alignment: .bottom) {
                Ellipse()
                    .fill(Color.black.opacity(HomeDaylight.isDay() ? 0.12 : 0.30))
                    .frame(width: 112, height: 30)
                    .offset(y: -11)
            }
            .offset(x: 4)
    }

    /// Matches the conversation fox's lift, so his feet meet the ledge at the
    /// same screen height and the hand-off doesn't move him.
    private static let foxLedgeLift: CGFloat = -49

    private func breathe() async {
        for step in Phase.allCases {
            phase = step
            remaining = step.seconds

            for tick in stride(from: step.seconds, to: 0, by: -1) {
                withAnimation(.snappy(duration: 0.28)) { remaining = tick }
                try? await Task.sleep(for: .seconds(1))
            }
        }

        onFinish()
    }
}

#Preview {
    BreathingView {}
}
