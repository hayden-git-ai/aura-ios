//
//  AuraTabBar.swift
//  Aura iOS
//

import SwiftUI
import UIKit

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
    /// The current account's photo, supplied by the shell so the profile tab
    /// updates with the same observable store value as the profile screen.
    var profileImageData: Data? = nil
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
            tabIcon(tab)
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
        .buttonStyle(PressBounceStyle(hapticsEnabled: false))
    }

    @ViewBuilder
    private func tabIcon(_ tab: AuraTab) -> some View {
        if tab == .profile, let data = profileImageData,
           let image = UIImage(data: data) {
            // Preserve the default sticker itself as the outline. Its 512px
            // canvas has an opaque contour at (68,53)-(444,435), with the
            // purple face at (104,89)-(408,399). Replace only that face so
            // uploaded photos have exactly the same white edge and footprint.
            Image(tab.sticker)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: icon, height: icon)
                .overlay {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: icon * 304 / 512, height: icon * 310 / 512)
                        .clipShape(Ellipse())
                        .offset(y: -icon * 12 / 512)
                }
        } else {
            ZStack {
                Image(tab.sticker)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: icon, height: icon)

                if tab == .stats {
                    Text(String(Calendar.current.component(.day, from: .now)))
                        .font(.system(size: 9.5, weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                        // The raw calendar carries a sample date. This small
                        // white field replaces it before the live day is drawn.
                        .frame(width: 18, height: 12)
                        .background(Color.white)
                        .offset(y: 2)
                }
            }
        }
    }

}
