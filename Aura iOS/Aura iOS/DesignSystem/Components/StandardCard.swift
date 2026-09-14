//
//  StandardCard.swift
//  Aura iOS
//

import SwiftUI

/// Shared background, border, size, and padding for the Wins strip cards
/// (Photo Proof, Exercise, Deep Focus) and the Blocks Rules cards — one card
/// language across both features instead of each rolling its own gradient.
enum StandardCard {
    static let size = CGSize(width: 196, height: 224)
    static let cornerRadius: CGFloat = 24
    static let padding: CGFloat = 18
    static let borderColor = Color.white.opacity(0.08)

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [Theme.Color.surfaceRecessedAlt, Theme.Color.surfaceRecessed],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    /// Top-to-bottom darkening layered over `backgroundGradient` — gives the
    /// flat fill depth and keeps bottom-anchored white text/labels legible.
    static var vignette: LinearGradient {
        LinearGradient(
            colors: [.clear, .black.opacity(0.15), .black.opacity(0.72)],
            startPoint: .top, endPoint: .bottom
        )
    }

    static var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    /// Width:height ratio — used by grid contexts (e.g. "See all" sheets)
    /// that scale the card to fit N-per-row instead of using `size` directly.
    static var aspectRatio: CGFloat {
        size.width / size.height
    }
}
