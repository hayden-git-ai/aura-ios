//
//  BlockedNowPill.swift
//  Aura iOS
//

import SwiftUI

/// The glass pill above the fox: what's locked right now, at a glance. Shows at
/// most three app icons plus a "+N" count, with a padlock on the left. Tapping it
/// opens the full list. Renders nothing when nothing is blocked — the caller
/// checks `store.blockedNowAppIcons` so the layout closes up rather than
/// holding an empty slot.
struct BlockedNowPill: View {
    let icons: [AppIconSource]
    var onTap: () -> Void

    /// Three tiles, never four.
    ///
    /// Past three apps the third slot becomes the count rather than sitting
    /// beside it, so the row is always the same width whether you block three
    /// apps or thirty. It used to show three icons AND a count, which made the
    /// pill grow by a whole tile the moment a fourth app was added.
    private var visible: [AppIconSource] {
        Array(icons.prefix(icons.count > 3 ? 2 : 3))
    }
    private var remaining: Int { max(0, icons.count - visible.count) }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.Spacing.m) {
                // Negative spacing fans the icons like a stack of cards. Later
                // views draw on top in an HStack, so the count tile lands in
                // front of the icons without any zIndex juggling.
                HStack(spacing: -Theme.Spacing.s) {
                    ForEach(Array(visible.enumerated()), id: \.offset) { _, icon in
                        // Plain app icons (no frost tint) wrapped in the app's
                        // sticker chrome — white keyline + soft shadow.
                        AppIconView(source: icon, side: 18)
                            .appIconChrome(side: 18)
                    }

                    if remaining > 0 {
                        // The count stands in for apps — a dark tile in the same
                        // sticker chrome, so it sits level with the icons.
                        Text("+\(remaining)")
                            .auraFont(.body, 11, .semibold)
                            .foregroundStyle(.white)
                            // "+10" is four glyphs in an 18pt square. Without
                            // these it clips the moment somebody blocks a
                            // thirteenth app, which is not a rare number.
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .frame(width: 18, height: 18)
                            .background(Color(hex: "4A4A4E"))
                            .appIconChrome(side: 18)
                    }
                }

                HStack(spacing: Theme.Spacing.xs) {
                    Text("Frozen Apps")
                        .auraFont(.body, RowType.label, .bold)
                        .foregroundStyle(.white)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(.leading, Theme.Spacing.m)
            .padding(.trailing, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.s)
            .background {
                Capsule()
                    .fill(Color.black.opacity(0.70))
                    .overlay(Capsule().strokeBorder(Color(white: 0.18), lineWidth: 1))
                    .shadow(color: .black.opacity(0.30), radius: 18, y: 6)
            }
        }
        .buttonStyle(PressBounceStyle())
    }
}

#Preview("Pill") {
    ZStack {
        Color.black
        BlockedNowPill(icons: [.asset("MessagesIcon"), .asset("MusicIcon"), .asset("BooksIcon")]) {}
    }
    .preferredColorScheme(.dark)
}
