//
//  HealthConnectHero.swift
//  Aura iOS
//

import SwiftUI

/// The two apps being joined, with the handshake drawn between them.
///
/// Replaces a lone Apple Health icon, which said what the screen was about but
/// not what the button does. Two icons and an arrow into a checkmark says
/// "these two are about to be connected" without a word of copy.
struct HealthConnectHero: View {
    var healthIcon: String = "AppleHealthLogo"
    /// Aura's own icon. Named here so swapping the artwork is one line.
    var auraIcon: String = "AuraAppIcon"

    private let side: CGFloat = 64
    private let halo: CGFloat = 240
    private var radius: CGFloat { halo / 2 }

    /// The connector artwork's own proportions, 101 × 40.
    private static let lineRatio: CGFloat = 101.0 / 40.0

    /// The run the line actually covers: from the middle of an icon's facing
    /// side to the check, NOT from the icon's centre.
    ///
    /// Solved rather than chosen. Three things have to hold at once — the line
    /// keeps its drawn 101:40 or the rounded corner skews, it starts at the
    /// icon's edge, and the icon still sits on the circle. That's
    /// `(ratio·h + side/2)² + h² = radius²`, one quadratic, one answer.
    private var lineHeight: CGFloat {
        let inset = side / 2
        let a = Self.lineRatio * Self.lineRatio + 1
        let b = 2 * Self.lineRatio * inset
        let c = inset * inset - radius * radius
        return (-b + sqrt(b * b - 4 * a * c)) / (2 * a)
    }

    private var lineWidth: CGFloat { Self.lineRatio * lineHeight }

    /// Each icon's centre still lands on the circle — half on, half off — with
    /// the line leaving the side that faces the check.
    private var healthCentre: CGPoint {
        CGPoint(x: -(lineWidth + side / 2), y: lineHeight)
    }

    private var auraCentre: CGPoint {
        CGPoint(x: lineWidth + side / 2, y: -lineHeight)
    }

    /// Where the arrows aim, and where the check sits.
    private let checkSide: CGFloat = 34


    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: halo, height: halo)

            chips

            // Your artwork, anchored to the two points it has to join: the
            // image is sized to the exact run and its endpoints sit at its own
            // corners, so putting its centre on the midpoint lands them on the
            // icon and the check with nothing to tune.
            // Health sits low-left, so its line leaves the RIGHT side and runs
            // right-then-up — the artwork turned 180°. Aura is the mirror, and
            // takes it as drawn.
            line(from: healthCentre, rotated: true)
            line(from: auraCentre, rotated: false)

            icon(healthIcon).offset(x: healthCentre.x, y: healthCentre.y)
            icon(auraIcon).offset(x: auraCentre.x, y: auraCentre.y)

            check
        }
        .frame(width: halo + side, height: halo + side)
    }

    /// No `appIconChrome` here: at this size the keyline and drop edge read as a
    /// frame around a picture rather than as an app icon, and there are already
    /// two arrows and a check competing for the eye.
    @ViewBuilder
    private func icon(_ name: String) -> some View {
        // An imageset with no artwork in it draws nothing at all, so the Aura
        // slot was simply absent. The coin on a white tile holds the space and
        // reads as an app icon until the real one is dropped in.
        let shape = RoundedRectangle(cornerRadius: side * LightSheet.iconCornerRatio,
                                     style: .continuous)
        if UIImage(named: name) != nil {
            Image(name)
                .resizable()
                .scaledToFill()
                .frame(width: side, height: side)
                .clipShape(shape)
        } else {
            shape
                .fill(.white)
                .frame(width: side, height: side)
                .overlay {
                    Image("AuraCoinIcon")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: side * 0.56, height: side * 0.56)
                }
        }
    }

    /// The drawn connector, from an icon's centre to the check.
    ///
    /// The artwork runs bottom-left to top-right, which is the Health side as
    /// drawn; the Aura side is the same asset turned 180°, so the two elbows are
    /// guaranteed identical rather than two drawings that nearly match.
    private func line(from iconCentre: CGPoint, rotated: Bool) -> some View {
        // The end that touches the icon: the middle of its facing side.
        let edge = CGPoint(x: iconCentre.x - (iconCentre.x < 0 ? -side / 2 : side / 2),
                           y: iconCentre.y)
        return Image("AppleHealthLines")
            .renderingMode(.template)
            .resizable()
            .foregroundStyle(.white)
            .frame(width: lineWidth, height: lineHeight)
            .rotationEffect(.degrees(rotated ? 180 : 0))
            // Endpoints are at the artwork's own corners, so centring it on the
            // midpoint of edge → check lands them on both.
            .offset(x: edge.x / 2, y: edge.y / 2)
    }

    private var check: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(LightSheet.healthPermissionPink)
            .frame(width: checkSide, height: checkSide)
            .background(Circle().fill(.white))
    }

    // MARK: - Chips

    /// What's actually being read, as floating labels.
    ///
    /// Placed in the two quadrants the icons leave empty — upper-left and
    /// lower-right — so nothing has to dodge anything.
    private var chips: some View {
        // Mirrored through the centre — Walking pairs with Sleep, Running with
        // Yoga — so the two sets sit on the same diagonal and each is the same
        // distance from the icon beside it. The old values were picked by eye
        // and were neither.
        //
        // Pushed further round the circle than the first pass too: at ±18 the
        // inner chips were nearly touching the icons.
        ZStack {
            chip("Walking", y: -96, onLeft: true)
            chip("Running", y: -52, onLeft: true)
            chip("Yoga", y: 52, onLeft: false)
            chip("Sleep", y: 96, onLeft: false)
        }
    }

    /// x is solved from y so the chip's centre lands on the circle itself —
    /// half on, half off, the same as the icons. Hand-picked offsets only look
    /// right at one radius.
    private func edgeX(_ y: CGFloat, onLeft: Bool) -> CGFloat {
        let inside = max(0, radius * radius - y * y)
        return (onLeft ? -1 : 1) * sqrt(inside)
    }

    private func chip(_ text: String, y: CGFloat, onLeft: Bool) -> some View {
        Text(text)
            .auraFont(.body, RowType.subLabel, .semibold)
            .foregroundStyle(LightSheet.healthPermissionPink)
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.xs + 2)
            .background(Capsule().fill(.white))
            .offset(x: edgeX(y, onLeft: onLeft), y: y)
    }
}
