//
//  FrozenAppTile.swift
//  Aura iOS
//

import SwiftUI

/// An app icon set inside the hand-drawn ice frame (`Frozen Apps_Frozen Ice`):
/// a glossy blue border with drips off the bottom and a clear window in the
/// middle where the app shows through in full colour.
struct FrozenAppTile: View {
    let icon: AppIconSource
    /// The app icon's visible size; the ice frame is sized around it.
    var side: CGFloat = 58
    /// A few degrees of hand-placed lean per tile.
    var tilt: Double = 0
    /// Compact drops the frame for tiny spots (the home pill), where the drips
    /// wouldn't read — a light frost tint and rim instead.
    var compact: Bool = false

    // Measured off the PNG (1200×1311, w/h 0.915): the clear icon window is
    // x 186–1007 (68.4% of width, centred), y 203–1011 (centre at 46.3% of height).
    private static let pngRatio: CGFloat = 1200.0 / 1311.0
    private static let iconRatio: CGFloat = 0.684
    private static let windowCentreY: CGFloat = 0.463

    private var tileWidth: CGFloat { side / Self.iconRatio }
    private var tileHeight: CGFloat { tileWidth / Self.pngRatio }

    var body: some View {
        if compact {
            frostedIcon
        } else {
            framed
        }
    }

    private var framed: some View {
        let r = side * 0.2
        return ZStack {
            AppIconView(source: icon, side: side)
                .clipShape(RoundedRectangle(cornerRadius: r, style: .continuous))
                // The original frost coat: a cool cast, a white glaze, heavier
                // frost creeping in from the edges, and a gloss sheen — keeps the
                // app's colour but reads clearly frozen.
                .overlay {
                    ZStack {
                        RoundedRectangle(cornerRadius: r, style: .continuous)
                            .fill(Color(hex: "BEE6FA").opacity(0.16))
                        RoundedRectangle(cornerRadius: r, style: .continuous)
                            .fill(LinearGradient(colors: [Color(hex: "EAF8FF").opacity(0.5),
                                                          Color(hex: "BEE6FA").opacity(0.2)],
                                                 startPoint: .top, endPoint: .bottom))
                        RoundedRectangle(cornerRadius: r, style: .continuous)
                            .fill(RadialGradient(colors: [.clear, Color(hex: "EAF8FF").opacity(0.85)],
                                                 center: .center,
                                                 startRadius: side * 0.28, endRadius: side * 0.72))
                        RoundedRectangle(cornerRadius: r, style: .continuous)
                            .fill(LinearGradient(colors: [.white.opacity(0.6), .clear],
                                                 startPoint: .topLeading, endPoint: .center))
                            .padding(2)
                    }
                }
                // Sit the icon in the frame's clear window (centred, ~40% down).
                .offset(y: tileHeight * (Self.windowCentreY - 0.5))

            Image("Frozen Apps_ Ice Frame")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: tileWidth, height: tileHeight)

            sparkles
        }
        .frame(width: tileWidth, height: tileHeight)
    }

    /// A few white glints on the ice that gently twinkle — the game-asset touch
    /// from the reference. Sized off the tile and parked on the frame's corners
    /// so they read as light catching the ice, clear of the app in the window.
    private var sparkles: some View {
        ZStack {
            IceSparkle(size: tileWidth * 0.22, delay: 0.0)
                .position(x: tileWidth * 0.17, y: tileHeight * 0.15)
            IceSparkle(size: tileWidth * 0.14, delay: 0.8)
                .position(x: tileWidth * 0.85, y: tileHeight * 0.20)
            IceSparkle(size: tileWidth * 0.12, delay: 1.4)
                .position(x: tileWidth * 0.11, y: tileHeight * 0.55)
        }
        .frame(width: tileWidth, height: tileHeight)
        .allowsHitTesting(false)
    }

    /// The pill version: too small for the frame + drips, so just a frosted icon.
    private var frostedIcon: some View {
        let r = side * 0.26
        return AppIconView(source: icon, side: side)
            .clipShape(RoundedRectangle(cornerRadius: r, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .fill(Color(hex: "AEE3FA").opacity(0.3))
            }
            .overlay {
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .strokeBorder(.white.opacity(0.85), lineWidth: 1.5)
            }
            .frame(width: side, height: side)
    }
}

#Preview {
    HStack(spacing: 14) {
        FrozenAppTile(icon: .asset("MessagesIcon"), tilt: -5)
        FrozenAppTile(icon: .asset("MusicIcon"), tilt: 4)
        FrozenAppTile(icon: .asset("BooksIcon"), tilt: -3)
    }
    .padding(40)
    .background(Color(hex: "EAF2FB"))
}
