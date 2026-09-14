//
//  HoldConfirmSheet.swift
//  Aura iOS
//

import SwiftUI

/// The shape every "you're about to undo a commitment" moment shares: white
/// sheet, art, title block, and a hold rather than a tap. Extracted from
/// `LeaveFocusConfirmSheet`'s layout so the adult-content switch and Always
/// Blocked's removals can't drift from it or from each other.
///
/// A hold, not a button, because these are the decisions a stray tap shouldn't
/// be able to make. Backing out is the X up top.
struct HoldConfirmSheet: View {
    var sticker: String
    /// Sheets whose art fills its frame differently size it here; the default is
    /// the compact hero the removals use.
    var stickerHeight: CGFloat = 72
    /// A negative value pulls the title up under art that carries empty space
    /// below it, so the gap doesn't balloon.
    var stickerBottomInset: CGFloat = 0
    let title: String
    let subtitle: String
    let idleCaption: String
    let doneCaption: String
    /// How long the finger stays down. Longer for anything that removes
    /// protection than for anything that adds it.
    var duration: Double = 5
    var onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            LightSheet.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                LightDragCapsule()

                Image(sticker)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(height: stickerHeight)
                    .foxShadow()
                    .padding(.top, Theme.Spacing.xl)
                    .padding(.bottom, stickerBottomInset)

                LightSheetTitle(title: title, subtitle: subtitle)

                Spacer(minLength: Theme.Spacing.l)

                HoldToConfirmButton(
                    // The Tempting lane's red, so the commit moment reads as part
                    // of that world.
                    tint: LightSheet.rippleRed,
                    idleCaption: idleCaption,
                    holdingCaption: "Keep holding…",
                    doneCaption: doneCaption,
                    duration: duration
                ) {
                    dismiss()
                    onConfirm()
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.xxl)
            }
        }
        .overlay(alignment: .topTrailing) {
            LightCloseButton { dismiss() }
                .padding(.trailing, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.l)
        }
        .preferredColorScheme(.light)
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.hidden)
    }
}

#Preview {
    Color.gray.sheet(isPresented: .constant(true)) {
        HoldConfirmSheet(
            sticker: "FoxHabitDeepWork",
            title: "Remove Reddit?",
            subtitle: "It can be opened again unless another rule blocks it.",
            idleCaption: "Press and hold to remove",
            doneCaption: "Removed",
            duration: 10
        ) {}
    }
}
