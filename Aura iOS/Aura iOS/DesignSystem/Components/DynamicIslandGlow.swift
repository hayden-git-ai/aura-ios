//
//  DynamicIslandGlow.swift
//  Aura iOS
//

import SwiftUI

/// A soft white glow bloom centered behind the Dynamic Island, radiating down
/// into the top of the screen. Drop it into a screen's background `ZStack`
/// (above the base color) — it's non-interactive and ignores safe area so it
/// sits behind the status bar / island.
struct DynamicIslandGlow: View {
    var body: some View {
        // Color.clear fills the available space but demands no minimum size, so
        // the oversized glow drawn in its overlay spills past the screen edges
        // without ever widening the parent layout.
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .overlay(alignment: .top) {
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [Theme.Color.signalUnlock.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 130
                        )
                    )
                    .frame(width: 520, height: 80)
                    .blur(radius: 40)
                    .offset(y: -40)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}
