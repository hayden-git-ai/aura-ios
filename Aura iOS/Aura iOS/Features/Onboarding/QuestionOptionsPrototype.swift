//
//  QuestionOptionsPrototype.swift
//  Aura iOS
//
//  Throwaway prototype: the worst-case 6-option question ("how you feel after")
//  rendered two ways — wrapping chips vs a 2-column icon grid — inside the real
//  question layout, so we can pick the option pattern that fits with NO scroll
//  and without moving the fox / progress / question / CTA. Launch with -proto.
//

import SwiftUI

// MARK: - Flow layout (chips that wrap into rows)

struct FlowLayout: Layout {
    var spacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > maxW, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
        return CGSize(width: maxW, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let maxW = bounds.width
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > maxW, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            v.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
    }
}

// MARK: - Prototype screen

struct QuestionOptionsPrototype: View {
    @State private var flow = OnboardingFlow()
    @State private var grid = true
    @State private var picked: Set<Int> = [0, 4]

    private let feelings: [(label: String, icon: String)] = [
        ("Guilty", "exclamationmark.bubble.fill"),
        ("Empty", "circle.bottomhalf.filled"),
        ("Anxious", "wind"),
        ("Low energy", "battery.25percent"),
        ("Foggy thoughts", "cloud.fog.fill"),
        ("Regretful", "arrow.uturn.backward.circle.fill"),
    ]

    var body: some View {
        OnbQuestionScreen(
            showBack: false,
            progress: 0.7,
            title: "how do you feel after doomscrolling?",
            content: {
                if grid { gridOptions } else { chipOptions }
            },
            bottom: {
                LightPrimaryButton(title: "Continue",
                                   face: .white, textColor: LightSheet.title, shade: LightSheet.whiteShadeOnColour) {}
            }
        )
        .environment(flow)
        .overlay(alignment: .bottom) { toggle }
    }

    // Wrapping chips
    private var chipOptions: some View {
        FlowLayout(spacing: 10) {
            ForEach(Array(feelings.enumerated()), id: \.offset) { i, f in
                let on = picked.contains(i)
                Button { toggle(i) } label: {
                    Text(f.label)
                        .auraFont(.body, 16, .semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Theme.Spacing.l)
                        .padding(.vertical, Theme.Spacing.m)
                        .background(on ? LightSheet.blue : Color.black.opacity(0.42), in: Capsule())
                        .overlay(Capsule().strokeBorder(on ? Color.white.opacity(0.6) : Color.white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(PressBounceStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // 2-column icon grid
    private var gridOptions: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(Array(feelings.enumerated()), id: \.offset) { i, f in
                let on = picked.contains(i)
                Button { toggle(i) } label: {
                    VStack(spacing: 6) {
                        Image(systemName: f.icon)
                            .font(.system(size: 22, weight: .semibold))
                        Text(f.label)
                            .auraFont(.body, 15, .semibold)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }
                    // Selected: same dark card, white text/icon, just a blue border.
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 84)
                    .background(Color.black.opacity(0.42),
                                in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .strokeBorder(on ? LightSheet.blue : Color.white.opacity(0.12), lineWidth: on ? 2.5 : 1))
                }
                .buttonStyle(PressBounceStyle())
            }
        }
    }

    private func toggle(_ i: Int) {
        if picked.contains(i) { picked.remove(i) } else { picked.insert(i) }
    }

    // Debug: flip chips <-> grid
    private var toggle: some View {
        Button { grid.toggle() } label: {
            Text(grid ? "grid ▸ chips" : "chips ▸ grid")
                .auraFont(.body, 13, .bold)
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color.red.opacity(0.8), in: Capsule())
        }
        .padding(.bottom, 2)
    }
}
