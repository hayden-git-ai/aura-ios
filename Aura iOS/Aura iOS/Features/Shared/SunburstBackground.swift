//
//  SunburstBackground.swift
//  Aura iOS
//

import SwiftUI

/// A slowly rotating radial sunburst — 8 lighter and 8 darker wedge rays fanning
/// from behind the mascot. Peach by default (the streak screen); the colours and
/// centre are overridable so other screens can wear the same treatment in their
/// own hue (the Lock In success screen uses a light purple).
struct SunburstBackground: View {
    var lighter: Color = Color(hex: "FEE4C3")
    var darker: Color = Color(hex: "FFDAAD")
    /// The rays' centre, as a fraction of screen height — behind the mascot.
    var centre: CGFloat = 0.40

    @State private var angle: Double = 0

    /// 16 rays: even indices lighter (8), odd darker (8) — perfectly even.
    private static let rayCount = 16

    private var rayStops: [Gradient.Stop] {
        var stops: [Gradient.Stop] = []
        for i in 0..<Self.rayCount {
            let c = i % 2 == 0 ? lighter : darker
            stops.append(.init(color: c, location: Double(i) / Double(Self.rayCount)))
            stops.append(.init(color: c, location: Double(i + 1) / Double(Self.rayCount)))
        }
        return stops
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Solid base behind everything so the blurred layers never fade
                // to black at the edges.
                lighter
                rays(geo)
                // Progressive blur: two masked, blurred copies fading in from the
                // rays' centre downward, so the field gets blurrier toward the
                // bottom.
                rays(geo).blur(radius: 16).mask(blurMask(from: centre, to: 0.72))
                rays(geo).blur(radius: 40).mask(blurMask(from: 0.60, to: 1.0))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 90).repeatForever(autoreverses: false)) {
                angle = 360
            }
        }
    }

    private func rays(_ geo: GeometryProxy) -> some View {
        let side = max(geo.size.width, geo.size.height) * 2.6
        return Rectangle()
            .fill(AngularGradient(gradient: Gradient(stops: rayStops), center: .center))
            .frame(width: side, height: side)
            .rotationEffect(.degrees(angle))
            .position(x: geo.size.width * 0.5, y: geo.size.height * centre)
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
    }

    private func blurMask(from: CGFloat, to: CGFloat) -> some View {
        LinearGradient(stops: [.init(color: .clear, location: from),
                               .init(color: .black, location: to)],
                       startPoint: .top, endPoint: .bottom)
    }
}
