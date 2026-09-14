//
//  AuraTabBar.swift
//  Aura iOS
//

import SwiftUI

/// Floating capsule nav in Instagram's shape: icon-only, evenly spaced, inset to
/// the width of the Blocks cards and riding above the home indicator. The active
/// tab sits in a lighter capsule highlight. No Earn item — that opens from Home's
/// own card.
///
/// The pill wears the exact material of Home's Frozen Apps pill (translucent
/// black + a white lift + a hairline), so the two floating chrome pieces match.
/// It scales and fades away as the content scrolls, and returns on scroll-up.
struct AuraTabBar: View {
    let items: [AuraTab]
    @Binding var selection: AuraTab
    /// Kept for call-site compatibility; Earn no longer lives in the row.
    var centre: AuraTab
    var onCentre: () -> Void
    /// True on the flat-white tabs — the pill goes a touch darker there (still
    /// translucent, never a flat solid) so it reads against the white.
    var onLight: Bool = false
    /// 0 full size, 1 fully shrunk — driven by the scrolling content.
    var shrink: CGFloat = 0

    private let icon: CGFloat = 40

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.self) { tab in
                item(tab)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, Theme.Spacing.xs)
        .padding(.vertical, Theme.Spacing.xs)
        .background { pill }
        // As wide as the Forbidden / Tempting / Allowed cards (their `xl` inset).
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.bottom, -12)
        // Scales down as the content scrolls but stays put and visible, anchored
        // to the bottom — it never disappears.
        .scaleEffect(1 - shrink * 0.16, anchor: .bottom)
    }

    /// Home's Frozen Apps pill material; on the white tabs the same recipe with
    /// a deeper black and a brighter border (plus a soft shadow) so the edge
    /// reads against the white without going solid.
    private var pill: some View {
        Capsule()
            .fill(Color.black.opacity(onLight ? 0.86 : 0.70))
            // A crisp SOLID grey hairline on the white tabs. On Home the border
            // goes near-black so it almost blends, leaning on the soft shadow to
            // ease onto the photo — a bright hairline there cut a hard, abrupt ring.
            .overlay(Capsule().strokeBorder(Color(white: onLight ? 0.54 : 0.18), lineWidth: 1))
            .shadow(color: .black.opacity(onLight ? 0.16 : 0.30), radius: onLight ? 14 : 18, y: 6)
    }

    @ViewBuilder
    private func item(_ tab: AuraTab) -> some View {
        let selected = selection == tab
        // A faint translucent white — subtle on both the photo (Home) and the
        // dark pill (white tabs), rather than an opaque patch.
        let highlight = Color.white.opacity(0.12)

        Button {
            Haptics.impact(.light)
            withAnimation(.snappy(duration: 0.25)) { selection = tab }
        } label: {
            Image(tab.sticker)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: icon, height: icon)
                .overlay { statsDate(tab, scaled: icon) }
                // The active sticker pops up and tilts.
                .scaleEffect(selected ? 1.1 : 1)
                .rotationEffect(.degrees(selected ? -9 : 0))
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
                // The active highlight is a capsule, so its corners match the bar.
                // A solid grey, matching the crisp solid border.
                .background {
                    if selected {
                        Capsule().fill(highlight)
                    }
                }
                .contentShape(Capsule())
                .animation(.snappy(duration: 0.25), value: selected)
        }
        .buttonStyle(PressBounceStyle())
    }

    @ViewBuilder
    private func statsDate(_ tab: AuraTab, scaled: CGFloat) -> some View {
        if tab == .stats {
            let s = scaled / Theme.Spacing.xxxl
            Text("\(Calendar.current.component(.day, from: .now))")
                .auraFont(.display, 15 * s, .bold)
                .foregroundStyle(.black)
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .frame(width: 30 * s)
                .offset(y: 3 * s)
        }
    }
}
