//
//  CardBackground.swift
//  Aura iOS
//

import SwiftUI

/// The one card language used everywhere: flat surface fill, hairline
/// border, consistent corner radius. Reach for `.auraCard()` instead of
/// hand-rolling a background locally.
private struct CardBackgroundModifier: ViewModifier {
    var cornerRadius: CGFloat = Theme.Radius.card

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.Color.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.Color.hairline, lineWidth: 1)
            )
    }
}

extension View {
    func auraCard(cornerRadius: CGFloat = Theme.Radius.card) -> some View {
        modifier(CardBackgroundModifier(cornerRadius: cornerRadius))
    }
}
