//
//  FABMenuRow.swift
//  Aura iOS
//

import SwiftUI

/// One row of the FAB menu that springs out of the "+" button: a white emoji
/// circle (aligned in the FAB's column) with a bare white title + subtext
/// (no pill background) that slides out from behind it. Rows appear/exit
/// one-by-one — the bottom-most (nearest the FAB) leads on open, and the
/// order reverses on close.
///
/// The title/subtext block stays permanently in the view hierarchy (never
/// conditionally inserted/removed) so its enter animation is a plain
/// continuous modifier interpolation, identical in feel to the emoji
/// circle's. Exit is driven by the same explicit state rather than
/// reversing the enter modifiers, so it can shrink+fade in place instead of
/// sliding back under the circle.
struct FABMenuRow: View {
    let option: QuickAction
    let isOpen: Bool
    let index: Int
    let total: Int
    var circleDiameter: CGFloat = 56
    let onTap: () -> Void

    @State private var pillOffsetX: CGFloat = 0
    @State private var pillScale: CGFloat = 1
    @State private var pillOpacity: Double = 0

    /// Staggered delay: bottom item first on open, top item first on close.
    private var stagger: Double {
        let fromBottom = Double(total - 1 - index)
        return (isOpen ? fromBottom : Double(index)) * 0.05
    }

    private var insertionStagger: Double { Double(total - 1 - index) * 0.05 }
    private var removalStagger: Double { Double(index) * 0.05 }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Title + subtext — tucked behind the circle when closed, slides
            // left out from under it when open (drawn before the circle so
            // the circle covers it at rest). No pill background — bare white
            // text on the sheet's dim scrim, matching the reference. The
            // subtext shares the title's offset/scale/opacity state, so it
            // enters and exits with the exact same animation as the title.
            VStack(alignment: .trailing, spacing: RowType.labelGap) {
                // A title over a sub-line beside its own control: the card
                // title pair, not a 17 that exists nowhere else.
                Text(option.title)
                    .auraFont(.body, SheetType.cardTitle, .semibold)
                    .foregroundStyle(.white)
                Text(option.subtitle)
                    .auraFont(.body, RowType.subLabel, .medium)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .multilineTextAlignment(.trailing)
            .fabShadow()
            .offset(x: pillOffsetX)
            .scaleEffect(pillScale, anchor: .trailing)
            .opacity(pillOpacity)

            // Emoji circle — same column as the FAB.
            Text(option.emoji)
                .font(.system(size: 24))
                .frame(width: circleDiameter, height: circleDiameter)
                .background(.white, in: Circle())
                .fabShadow()
                .scaleEffect(isOpen ? 1 : 0.3)
                .opacity(isOpen ? 1 : 0)
                .animation(.spring(response: 0.34, dampingFraction: 0.7).delay(stagger), value: isOpen)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onChange(of: isOpen) { _, open in
            if open {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.78).delay(insertionStagger + 0.05)) {
                    pillOffsetX = -(circleDiameter + Theme.Spacing.s)
                    pillOpacity = 1
                }
            } else {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.7).delay(removalStagger)) {
                    pillScale = 0.3
                    pillOpacity = 0
                } completion: {
                    guard !isOpen else { return }
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        pillOffsetX = 0
                        pillScale = 1
                    }
                }
            }
        }
    }
}
