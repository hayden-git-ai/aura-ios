//
//  IceSparkle.swift
//  Aura iOS
//

import SwiftUI

/// One white four-point glint with a soft glow, easing between dim/small and
/// bright/full on a slow loop. Each is given a `delay` so a group doesn't twinkle
/// in lockstep. Shared by the frozen tiles and the Home coin.
struct IceSparkle: View {
    var size: CGFloat
    var delay: Double

    @State private var on = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: "sparkle")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(.white)
            .shadow(color: .white.opacity(0.85), radius: size * 0.28)
            .opacity(on ? 1 : 0.4)
            .scaleEffect(on ? 1 : 0.7)
            .onAppear {
                guard !reduceMotion else { on = true; return }
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(delay)) {
                    on = true
                }
            }
    }
}
