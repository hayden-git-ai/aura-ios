//
//  LeaveFocusConfirmSheet.swift
//  Aura iOS
//

import SwiftUI

/// Raised by the Focus Timer's stop button — a session in progress shouldn't end
/// on one accidental tap. Same shape as the blocker break sheet: the safe choice
/// is the primary button, ending is the red text underneath.
struct LeaveFocusConfirmSheet: View {
    var forfeitsProgress: Bool = true
    var onConfirmLeave: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            LightSheet.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                LightDragCapsule()

                // Reuse the delete-action sticker rather than the copied
                // end-session duplicate, and give it a full hero footprint.
                Image("Lock In_End Session Sticker")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(height: 136)
                    .foxShadow()
                    .padding(.top, Theme.Spacing.xl)
                    // The art carries ~19pt of empty space below the fox's feet,
                    // which stacks with the title's own top inset into a big gap.
                    // Pull the title back up so the fox sits close to it.
                    .padding(.bottom, -Theme.Spacing.xl)

                LightSheetTitle(
                    title: "End session?",
                    subtitle: forfeitsProgress
                        ? "Your apps stay blocked, and you won't earn any coins for the time you've put in so far."
                        : "Your apps stay blocked, and you'll earn coins for the full minutes you've focused so far."
                )

                Spacer(minLength: Theme.Spacing.l)

                // Ending takes a deliberate hold, so a stray tap on a live
                // session can't forfeit it. Backing out is the X up top.
                HoldToConfirmButton(
                    tint: LightSheet.danger,
                    idleCaption: "Press and hold to end",
                    holdingCaption: "Keep holding…",
                    doneCaption: "Session ended",
                    duration: 10
                ) {
                    dismiss()
                    onConfirmLeave()
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
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.hidden)
    }
}

#Preview {
    Color.gray.sheet(isPresented: .constant(true)) {
        LeaveFocusConfirmSheet(onConfirmLeave: {})
    }
}
