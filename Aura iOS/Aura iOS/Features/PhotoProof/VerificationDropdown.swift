//
//  VerificationDropdown.swift
//  Aura iOS
//

import SwiftUI

/// Four corner brackets (a camera viewfinder), drawn as a single stroked shape.
/// Reused big on the camera and small, pulsing, inside the verification drop.
///
/// Corners are arcs, not right angles, so it reads as SF Symbols' `viewfinder`
/// rather than crop marks. The radius is capped at half the arm length, which
/// keeps the shape honest at the small size inside the verification drop as
/// well as at the large one on the camera.
struct ViewfinderBrackets: Shape {
    var cornerLength: CGFloat = 12
    var cornerRadius: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let l = cornerLength
        let r = min(cornerRadius, l / 2)

        // Each corner: straight in, round the turn, straight out.
        // Top-left
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + l))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY),
                       control: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + l, y: rect.minY))
        // Top-right
        p.move(to: CGPoint(x: rect.maxX - l, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r),
                       control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + l))
        // Bottom-right
        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - l))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY),
                       control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - l, y: rect.maxY))
        // Bottom-left
        p.move(to: CGPoint(x: rect.minX + l, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r),
                       control: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - l))
        return p
    }
}

/// The frame the brackets mark out, as a rounded rectangle.
///
/// Its own shape rather than a number, because the scrim has to cut exactly the
/// hole the brackets sit on. Two descriptions of the same rectangle is how they
/// drift apart.
struct ViewfinderFrame {
    static let size = CGSize(width: 300, height: 460)
    static let radius: CGFloat = 28
    static let cornerLength: CGFloat = 36
}

/// The Dynamic-Island-style verification indicator: a black squircle that
/// springs down from the notch, shows a pulsing white viewfinder while the
/// photo is "verified", then morphs to a green check (pass) or red ✕ (fail)
/// with a matching hairline border. It only renders state — the parent owns the
/// timing and what happens next.
struct VerificationDropdown: View {
    /// nil = verifying, true = passed, false = failed.
    let result: Bool?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dropped = false
    @State private var pulse = false

    private let green = Theme.Color.signalGood
    private let red = LightSheet.danger

    private var borderColor: Color {
        switch result {
        case .some(true): return green
        case .some(false): return red
        case .none: return Color.white.opacity(0.14)
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous)
            .fill(.black)
            .frame(width: 128, height: 128)
            .overlay { content }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.55), radius: 24, y: 10)
            .scaleEffect(dropped ? 1 : 0.3, anchor: .top)
            .offset(y: dropped ? 0 : -90)
            .opacity(dropped ? 1 : 0)
            .animation(.snappy(duration: 0.3), value: result)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) { dropped = true }
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) { pulse = true }
            }
    }

    /// Waiting is the viewfinder, breathing. The verdict replaces it outright
    /// rather than sitting beside it, so the drop reads as one object changing
    /// its mind rather than a panel filling up.
    @ViewBuilder
    private var content: some View {
        switch result {
        case .none:
            ViewfinderBrackets(cornerLength: 20, cornerRadius: 8)
                .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 58, height: 58)
                .scaleEffect(pulse ? 1.06 : 0.94)
                .opacity(pulse ? 1 : 0.55)

        case .some(true):
            Image(systemName: "checkmark")
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(green)
                .transition(.scale.combined(with: .opacity))

        case .some(false):
            Image(systemName: "xmark")
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(red)
                .transition(.scale.combined(with: .opacity))
        }
    }
}
