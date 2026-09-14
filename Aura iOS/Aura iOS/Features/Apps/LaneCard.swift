//
//  LaneCard.swift
//  Aura iOS
//

import SwiftUI

/// One Blocks lane as a card: the lane's name over a subtitle, a bare row of its
/// apps, and its character bleeding off the bottom-right corner over a ghosted
/// burst, all on the lane's own colour.
///
/// Shared on purpose — the Blocks screen and the "How Blocking Works" sheet both
/// render this exact card, so the sheet is guaranteed to match the board's craft
/// rather than a hand-built copy that drifts.
struct LaneCard: View {
    let rule: BlockRule
    let selection: AppSelection
    /// The line under the name — the app count on the board, the explanation in
    /// the help sheet.
    let subtitle: String
    /// When set, the card is a button (the board opens the lane's editor). Nil
    /// makes it a plain, non-interactive card (the explainer).
    var onTap: (() -> Void)? = nil
    /// Whether to draw the app row. The board shows it; the How Blocking Works
    /// sheet hides it so the explanation copy has the card to itself, clear of
    /// the rings, rays and fox.
    var showApps: Bool = true
    /// A fixed card height. The board leaves this nil (the app row makes every
    /// card the same height); the help sheet sets it so all three cards are
    /// identical regardless of how long each explanation runs.
    var fixedHeight: CGFloat? = nil

    var body: some View {
        if let onTap {
            Button(action: onTap) { card }
                .buttonStyle(PressBounceStyle())
        } else {
            card
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            // The lane's name over its subtitle, then the apps below.
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(rule.title)
                    .auraFont(.display, 19, .bold)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(subtitle)
                    .auraFont(.body, 14, .medium)
                    // Slightly translucent so it sits inside the colour rather
                    // than punched on top — the Duolingo trick.
                    .foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            // Keep the text clear of the character in the corner. Harmless on the
            // board (its subtitle is one short line); it's the multi-line
            // explanation in the help sheet that would otherwise run under the fox.
            .padding(.trailing, Self.textFoxInset)

            if showApps { iconRow }
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        // A fixed height keeps every help-sheet card identical; nil on the board
        // is a no-op (the app row already equalises them).
        .frame(height: fixedHeight, alignment: .topLeading)
        .background(gradient,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous))
        .overlay { cornerVignette }
        .overlay { if rule == .allowed { sunburst } else { rings } }
        .overlay(alignment: .bottomTrailing) {
            // Each source PNG has a different canvas + margin, so `artLayout` is
            // computed per image so every character lands the same visible height
            // with its bottom-right anchored at the same point.
            let art = artLayout
            Image(cornerArt)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(height: art.height)
                .offset(x: art.offset.width, y: art.offset.height)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous))
        // Layered depth so the cards lift off the ground and read as chunky game
        // pieces: a soft ambient shadow plus a tighter contact shadow.
        .shadow(color: .black.opacity(0.16), radius: 20, y: 11)
        .shadow(color: .black.opacity(0.10), radius: 4, y: 2)
    }

    // MARK: - Colour + burst

    /// Each lane's own colour, sourced from the failure ripple so Blocks speaks
    /// the same colour language as the proof screens.
    private var colour: Color {
        switch rule {
        // A severity ramp: near-black for Forbidden (most severe — skulls and the
        // scared fox pop hard on it), the old Forbidden red slides down to
        // Tempting, blue for Allowed.
        case .blocked: return Color(hex: "16151C")      // Forbidden — cold near-black (red pulled out)
        case .distracting: return LightSheet.rippleRed  // Tempting — deep ripple red
        case .allowed: return LightSheet.blue           // Allowed — system blue
        }
    }

    /// A touch lighter at the top falling to the base, so it reads with depth.
    private var gradient: LinearGradient {
        LinearGradient(colors: [colour.lightened(by: 0.12), colour],
                       startPoint: .top, endPoint: .bottom)
    }

    /// A soft dark vignette in the bottom-right corner so it reads recessed and
    /// the character/rays lift off it.
    private var cornerVignette: some View {
        Rectangle()
            .fill(RadialGradient(gradient: Gradient(colors: [Color.black.opacity(0.20), .clear]),
                                 center: .bottomTrailing, startRadius: 0, endRadius: 230))
            .allowsHitTesting(false)
    }

    /// Concentric ripples from the bottom-right corner (restrict lanes).
    private var rings: some View {
        let n = 10
        // White reads louder on Forbidden's near-black than on Tempting's red,
        // so the same opacity looks stronger there — dial it back on Forbidden
        // to match the other two cards' subtlety.
        let ringAlpha = rule == .blocked ? 0.05 : 0.10
        var stops: [Gradient.Stop] = []
        for i in 0..<n {
            let c: Color = i % 2 == 0 ? Color.white.opacity(ringAlpha) : .clear
            stops.append(.init(color: c, location: Double(i) / Double(n)))
            stops.append(.init(color: c, location: Double(i + 1) / Double(n)))
        }
        return Rectangle()
            .fill(RadialGradient(gradient: Gradient(stops: stops),
                                 center: .bottomTrailing, startRadius: 0, endRadius: 200))
            .allowsHitTesting(false)
    }

    /// Angular rays from the bottom-right corner, radial-masked into the corner
    /// (earn lane) — the streak/success sunburst language.
    private var sunburst: some View {
        let rays = 40
        var stops: [Gradient.Stop] = []
        for i in 0..<rays {
            let c: Color = i % 2 == 0 ? Color.white.opacity(0.24) : .clear
            stops.append(.init(color: c, location: Double(i) / Double(rays)))
            stops.append(.init(color: c, location: Double(i + 1) / Double(rays)))
        }
        return Rectangle()
            .fill(AngularGradient(gradient: Gradient(stops: stops), center: .bottomTrailing))
            .mask(
                RadialGradient(gradient: Gradient(colors: [.white, .white, .clear]),
                               center: .bottomTrailing, startRadius: 0, endRadius: 210)
            )
            .allowsHitTesting(false)
    }

    // MARK: - Character

    private var cornerArt: String {
        switch rule {
        case .blocked: return "Blocked Apps_Forbidden"       // pleading / scared
        case .distracting: return "Blocked Apps_Distracting" // spiral-eyed doomscroller
        case .allowed: return "Blocked Apps_Productive"      // star-eyed, sparkling
        }
    }

    private var artLayout: (height: CGFloat, offset: CGSize) {
        switch rule {
        case .blocked:     return (130, CGSize(width: 18, height: 12))
        case .distracting: return (134, CGSize(width: 17, height: 16))
        case .allowed:     return (142, CGSize(width: 8, height: 24))
        }
    }

    // MARK: - App row

    /// Trailing space kept clear for the corner character, so text never runs
    /// under it.
    private static let textFoxInset: CGFloat = 132

    private static let rowIcon: CGFloat = 26
    /// How many apps a row shows before its last slot becomes a "+N" count.
    private static let rowSlots = 4
    /// The row area is always reserved at this height so an empty lane is the
    /// same size card as a full one.
    private static let rowReserve: CGFloat = 30
    /// An app tile's real on-screen size: the artwork plus the keyline chrome.
    private static let rowFootprint = rowIcon + 2 * max(1.5, rowIcon * 0.075)

    private var iconRow: some View {
        let icons = selection.iconSources
        return ZStack(alignment: .leading) {
            Color.clear.frame(height: Self.rowReserve)
            if rule == .blocked {
                if !icons.isEmpty { blockedRow(icons) }
            } else if !icons.isEmpty {
                filledRow(icons)
            }
        }
    }

    private func filledRow(_ icons: [AppIconSource]) -> some View {
        row(icons) { icon in
            AppIconView(source: icon, side: Self.rowIcon)
                .appIconChrome(side: Self.rowIcon)
        }
    }

    /// Forbidden: each hidden app becomes a skull instead of its icon.
    private func blockedRow(_ icons: [AppIconSource]) -> some View {
        row(icons) { _ in skullTile }
    }

    private var skullTile: some View {
        // Layout box = an app tile's full footprint (so the row lines up with the
        // other lanes), with the art scaled up to cancel the sticker's
        // transparent margin (content is 0.83 of the canvas).
        Image("StatsMostDistracting")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: Self.rowFootprint, height: Self.rowFootprint)
            .scaleEffect(1.2)
    }

    /// The shared row: a tile per app up to the slot count, then a "+N" count in
    /// the last slot.
    private func row<Tile: View>(_ icons: [AppIconSource],
                                 @ViewBuilder tile: @escaping (AppIconSource) -> Tile) -> some View {
        let overflowing = icons.count > Self.rowSlots
        let visible = Array(icons.prefix(overflowing ? Self.rowSlots - 1 : Self.rowSlots))
        let remaining = icons.count - visible.count

        return HStack(spacing: Theme.Spacing.s) {
            ForEach(Array(visible.enumerated()), id: \.offset) { _, icon in
                tile(icon)
            }
            if overflowing {
                // A white tile with the count in the lane's own colour, so it
                // reads as one more app slot rather than a stray blue chip.
                Text("+\(remaining)")
                    .auraFont(.body, RowType.label, .bold)
                    .foregroundStyle(colour)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(width: Self.rowIcon, height: Self.rowIcon)
                    .background(.white)
                    .appIconChrome(side: Self.rowIcon)
            }
            Spacer(minLength: 0)
        }
    }
}
