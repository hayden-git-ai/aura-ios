//
//  PrimaryButtonStyle.swift
//  Aura iOS
//

import SwiftUI

/// The one button style that means "primary action" anywhere in Aura —
/// white/bone fill, dark text, 15pt corner radius. Don't let secondary
/// actions borrow this weight.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .auraFont(.body, 15, .semibold)
            .foregroundStyle(Theme.Color.ctaText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.l)
            .background(Theme.Color.ctaFill)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { Haptics.impact(.light) }
            }
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var auraPrimary: PrimaryButtonStyle { PrimaryButtonStyle() }
}
