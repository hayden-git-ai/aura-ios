//
//  TrendBadge.swift
//  Aura iOS
//

import SwiftUI

/// A change against the previous period: tinted disc with an angled arrow, the
/// percentage, and what it's measured against.
///
/// The colour comes from `isGoodWhenUp`, not from the sign. More screen time is
/// worse and more coins are better, so a badge that greened every rise would
/// congratulate someone for scrolling more.
struct TrendBadge: View {
    /// Signed percentage change. Zero renders as flat and neutral.
    let percent: Int
    let caption: String
    var isGoodWhenUp: Bool = true
    /// One line — small disc, then percentage and caption as a single run.
    /// For sitting under a chart rather than beside a headline number.
    var inline: Bool = false
    /// On the blue field the dark text disappears. The tinted disc survives —
    /// green and red both hold against blue — so only the type inverts.
    var onBlue: Bool = false

    private var amountColor: Color { onBlue ? .white : LightSheet.title }
    private var captionColor: Color { onBlue ? .white.opacity(0.7) : LightSheet.controlIdle }

    private var isFlat: Bool { percent == 0 }
    private var isUp: Bool { percent > 0 }

    private var tint: Color {
        guard !isFlat else { return LightSheet.subtitle }
        return isUp == isGoodWhenUp ? Theme.Color.signalGood : LightSheet.danger
    }

    private var symbol: String {
        isFlat ? "minus" : isUp ? "arrow.up.right" : "arrow.down.right"
    }

    private var amount: String {
        isFlat ? "0%" : "\(isUp ? "+" : "")\(percent)%"
    }

    var body: some View {
        HStack(spacing: inline ? 6 : Theme.Spacing.s) {
            Image(systemName: symbol)
                .font(.system(size: inline ? 7 : 13, weight: .black))
                .foregroundStyle(.white)
                .frame(width: inline ? 14 : 28, height: inline ? 14 : 28)
                .background(tint, in: Circle())

            if inline {
                HStack(spacing: 4) {
                    Text(amount)
                        .auraFont(.body, 11, .bold)
                        .foregroundStyle(amountColor)
                    Text(caption)
                        .auraFont(.body, 11, .medium)
                        .foregroundStyle(captionColor)
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Text(amount)
                        .auraFont(.body, 17, .bold)
                        .foregroundStyle(amountColor)
                    Text(caption)
                        .auraFont(.body, 11, .medium)
                        .foregroundStyle(captionColor)
                }
            }
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 20) {
        TrendBadge(percent: 100, caption: "vs last week", isGoodWhenUp: false)
        TrendBadge(percent: -32, caption: "vs last week", isGoodWhenUp: false)
        TrendBadge(percent: 24, caption: "vs last week")
        TrendBadge(percent: 0, caption: "vs last week")
    }
    .padding()
    .background(Color.white)
}
