//
//  RatingAskSheet.swift
//  Aura iOS
//

import SwiftUI

/// Asks whether they like Aura, before Apple does.
///
/// The two-step gate, and the reason for it is arithmetic: iOS shows its own
/// review prompt at most three times a year per user, and it will not tell you
/// whether it showed one. Sending everybody straight to it spends those three
/// chances on whoever happened to be standing there, including the person about
/// to leave two stars. Asking first means only people who already said yes ever
/// reach Apple's prompt.
///
/// A "no" costs the user nothing and goes nowhere. There is no feedback form
/// behind it: almost nobody fills those in, and putting one there makes the
/// honest answer feel like the punished one.
struct RatingAskSheet: View {
    var onYes: () -> Void
    var onNo: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            LightSheet.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                LightDragCapsule()

                art
                    .padding(.top, Theme.Spacing.l)

                Text("Enjoying Aura?")
                    .auraFont(.display, SheetType.title, .bold)
                    .foregroundStyle(LightSheet.title)
                    .padding(.top, Theme.Spacing.l)

                Text("Your honest answer helps us make Aura better.")
                    .auraFont(.body, SheetType.subtitle, .regular)
                    .foregroundStyle(SheetType.subtitleColor)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.xs)

                Spacer(minLength: Theme.Spacing.xl)

                LightPrimaryButton(title: "Yes, I love it!", action: onYes)

                Button(action: onNo) {
                    Text("Not really")
                        .auraFont(.body, SheetType.cardTitle, .semibold)
                        .foregroundStyle(LightSheet.controlIdle)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.plain)
                .padding(.top, Theme.Spacing.s)
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.l)
        }
    }

    /// The happy fox holding a heart — same size and shadow as the other sheet
    /// heroes. The art carries empty space below the fox, so the title is pulled
    /// up under it rather than sitting a full gap away.
    private var art: some View {
        Image("Leave A Rating_Enjoying Aura Sheet")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(height: 120)
            .foxShadow()
            .padding(.bottom, -Theme.Spacing.l)
    }
}
