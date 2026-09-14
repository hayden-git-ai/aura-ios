//
//  AuraBankCard.swift
//  Aura iOS
//

import SwiftUI

/// The Aura Bank card — artwork clipped to the card shape, with the logo, chip,
/// cardholder, and number laid over it. Shared by the Screentime Store, where it
/// sits at rest, and Tap to Pay, where it's the thing you swipe.
struct AuraBankCard: View {
    var cardholder: String
    var number: String = "****2094"
    /// Coordinate space to publish this card's frame into, for callers that
    /// need to animate it somewhere precise. The measurement lives here rather
    /// than on a wrapper outside: padding and aspect-ratio fitting mean the
    /// wrapper's rect isn't the same rect as the drawn card.
    var measureIn: String? = nil

    var body: some View {
        ZStack {
            Image("ScreentimeCardBackground")
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous))

            // Subtle dark scrim so the white text reads over any artwork.
            RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous)
                .fill(Color.black.opacity(0.22))

            // Specular sheen: light falling across the top-left and dying
            // before the middle, which is what makes a flat fill read as a
            // surface rather than a colour.
            RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.18), location: 0),
                            .init(color: .white.opacity(0.04), location: 0.38),
                            .init(color: .clear, location: 0.55)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Image("AuraBankCardLogo")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(height: 26)
                    Spacer()
                    chip
                }

                Spacer(minLength: 0)

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: RowType.labelGap) {
                        Text("Cardholder name")
                            .auraFont(.body, 11, .medium)
                            .foregroundStyle(LightSheet.onColour)
                        Text(cardholder)
                            .auraFont(.display, 16, .bold)
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Text(number)
                        .auraFont(.display, 15, .bold)
                        .foregroundStyle(LightSheet.onColour)
                }
            }
            .padding(Theme.Spacing.l)
        }
        .aspectRatio(1.586, contentMode: .fit)
        .background {
            if let measureIn {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: AuraCardFrameKey.self,
                        value: proxy.frame(in: .named(measureIn))
                    )
                }
            }
        }
        // A lit edge on the top-left rolling to a dark one bottom-right. This
        // is the bit that reads as thickness.
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.45), .white.opacity(0.06), .black.opacity(0.28)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        // Two shadows, not one: a tight contact shadow that sits the card on
        // the surface, and a wide ambient one that gives it height. A single
        // mid-radius shadow reads as neither.
        .shadow(color: .black.opacity(0.28), radius: 5, y: 3)
        .shadow(color: .black.opacity(0.22), radius: 26, y: 16)
    }

    private var chip: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.micro, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(hex: "F4D06F"), Color(hex: "D9A94E")],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .frame(width: 40, height: 28)
    }
}

/// Ignores empty values: every sibling that doesn't set the key still
/// contributes `defaultValue`, which would otherwise wipe out the measurement.
struct AuraCardFrameKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

#Preview {
    AuraBankCard(cardholder: "Hayden Berio")
        .padding()
        .background(LightSheet.surface)
}
