//
//  StreakFreezeCard.swift
//  Aura iOS
//

import SwiftUI

/// The freeze count in the streak screen's header, and what it means when
/// tapped.
///
/// Collapsed it's a capsule — the label and the freezes you hold. Expanded it
/// explains the mechanic and how the next one is earned, because "2/2" tells
/// nobody anything on its own.
///
/// One control in two states rather than a pill that opens a sheet: the whole
/// thing is three short lines, and a sheet for three lines is a lot of ceremony
/// to read a sentence.
struct StreakFreezeCard: View {
    let freezes: Int
    var maximum: Int = StreakFreeze.maximum

    @State private var expanded = false

    /// The pill's fill — a touch darker than the standard chrome so the white
    /// label and white outline read against the peach sunburst behind it.
    private var face: Color { Color.black.opacity(0.38) }

    /// The expanded card grows leftward. It sits `topInset + l` down — below the
    /// Dynamic Island's vertical band — so the island isn't a horizontal cap;
    /// this is set wide enough that the subtitle wraps to fewer lines and the
    /// card reads wide rather than tall.
    private static let expandedWidth: CGFloat = 278
    /// Both rules in the card. Full white was the only 100% white in the app —
    /// louder than the 85% text it was separating.
    private static let rule = Color.white.opacity(0.28)

    var body: some View {
        Button {
            Haptics.impact(.light)
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) { expanded.toggle() }
        } label: {
            VStack(spacing: 0) {
                if expanded { expandedTop } else { collapsed }

                if expanded {
                    // Inset to the copy below it — a rule the full width of the
                    // card cut the card in half instead of parting two lines.
                    Divider()
                        .overlay(Self.rule)
                        .padding(.horizontal, Theme.Spacing.s)
                    Text(earnRule)
                        .auraFont(.body, RowType.subLabel, .regular)
                        .foregroundStyle(LightSheet.onColour)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, Theme.Spacing.s)
                        .padding(.vertical, Theme.Spacing.m)
                }
            }
            .frame(width: expanded ? Self.expandedWidth : nil)
            .background(face, in: RoundedRectangle(cornerRadius: expanded ? Theme.Radius.card
                                                                          : Theme.Radius.pill,
                                                   style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: expanded ? Theme.Radius.card : Theme.Radius.pill,
                                 style: .continuous)
                    .strokeBorder(.white, lineWidth: 2)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var collapsed: some View {
        HStack(spacing: Theme.Spacing.s) {
            Text("Streak Freeze")
                .auraFont(.body, RowType.label, .bold)
                .foregroundStyle(.white)
            icons
        }
        .padding(.horizontal, Theme.Spacing.m)
        .frame(height: CircleIconButton.minimumTarget)
    }

    /// Two columns, as the reference has it: what it is on the left, what you
    /// hold on the right, a rule underneath.
    private var expandedTop: some View {
        HStack(spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: RowType.labelGap) {
                Text("Streak Freeze")
                    .auraFont(.body, SheetType.cardTitle, .bold)
                    .foregroundStyle(.white)
                Text("Miss a day and one is used automatically to save your streak")
                    .auraFont(.body, RowType.subLabel, .regular)
                    .foregroundStyle(LightSheet.onColour)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(Self.rule)
                .frame(width: 1)

            VStack(spacing: RowType.labelGap) {
                icons
                Text("\(freezes)/\(maximum) on hand")
                    .auraFont(.body, RowType.subLabel, .semibold)
                    .foregroundStyle(.white)
                    .fixedSize()
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(Theme.Spacing.m)
    }

    /// One glyph per freeze you could hold, the spent ones dimmed — a bare
    /// number can't show you're one short.
    private var icons: some View {
        HStack(spacing: RowType.labelGap) {
            ForEach(0..<maximum, id: \.self) { index in
                // The frozen-flame sticker — ice, not flame, because it's the
                // thing that stops the streak burning down. Spent slots dim.
                Image("AuraStreakFreeze")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    // A whole number: 26 × 3 = 78px, so the sticker lands on
                    // pixel boundaries instead of straddling them (a fractional
                    // height reads as pixelated).
                    .frame(height: 26)
                    .opacity(index < freezes ? 1 : 0.28)
            }
        }
    }

    private var earnRule: AttributedString {
        var sentence = AttributedString("Complete \(StreakFreeze.earnAt) quests in a day to earn 1 freeze.")
        if let range = sentence.range(of: "\(StreakFreeze.earnAt) quests in a day") {
            sentence[range].font = Typography.body(size: RowType.subLabel, weight: .bold)
            sentence[range].foregroundColor = .white
        }
        return sentence
    }
}
