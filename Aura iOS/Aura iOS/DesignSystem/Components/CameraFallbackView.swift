//
//  CameraFallbackView.swift
//  Aura iOS
//

import SwiftUI

/// What stands in for the viewfinder when there's no feed — denied permission,
/// or the simulator.
///
/// Both cameras drew this separately: the same three-stop radial gradient
/// written out hex by hex in each, the same 46pt glyph at the same opacity, the
/// same layout. Only the message and the gradient's centre differed.
struct CameraFallbackView: View {
    let message: String
    /// Nudged to sit behind whatever that screen puts over it.
    var center = UnitPoint(x: 0.5, y: 0.35)
    var endRadius: CGFloat = 400

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color(hex: "26262C"), Color(hex: "141417"), Color(hex: "0A0A0C")],
                center: center, startRadius: 20, endRadius: endRadius
            )
            VStack(spacing: Theme.Spacing.m) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(.white.opacity(0.25))
                Text(message)
                    .auraFont(.body, 14, .medium)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
        }
        .ignoresSafeArea()
    }
}

/// Darkens the top and bottom of a viewfinder so chrome reads over any frame.
///
/// Shared so the two cameras can't drift: their bottoms had already reached
/// 0.75 and 0.6 while their tops matched. 0.75 wins — the scrim exists to keep
/// controls legible, and too light fails worse than too dark.
struct CameraScrim: View {
    var body: some View {
        LinearGradient(
            colors: [.black.opacity(0.55), .clear, .clear, .black.opacity(0.75)],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

extension View {
    /// Punches a hole in this view the shape of `mask`.
    ///
    /// The viewfinder needs a dimmed field with a clear rectangle in it, which
    /// is the inverse of what `.mask` does. `destinationOut` on a composited
    /// group is the way to say "remove this bit", and the group is what keeps
    /// the blend from reaching the camera preview underneath.
    func reverseMask<Mask: View>(@ViewBuilder _ mask: () -> Mask) -> some View {
        self.mask {
            Rectangle()
                .overlay(alignment: .center) {
                    mask().blendMode(.destinationOut)
                }
                .compositingGroup()
        }
    }
}
