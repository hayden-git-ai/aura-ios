//
//  BuyScreentimeSheet.swift
//  Aura iOS
//

import SwiftUI

/// The step between wanting screen time and paying for it: pick or type an
/// amount, then Done. Deliberate friction — buying used to be one tap from the
/// store, which made it the path of least resistance.
struct BuyScreentimeSheet: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// Handed back on Done so the caller can start the checkout as this closes.
    var onDone: (Int) -> Void

    @State private var hours = 0
    @State private var loose = 5

    private static let step = 5

    /// Coins and minutes are 1:1, so the total is the price — there's nothing to
    /// convert, only to add up.
    private var minutes: Int { hours * 60 + loose }

    private var canAfford: Bool { minutes > 0 && store.coinBalance >= minutes }
    private var overspending: Bool { minutes > store.coinBalance }

    var body: some View {
        ZStack(alignment: .top) {
            LightSheet.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                LightDragCapsule()
                LightSheetTitle(
                    title: "How long are we scrolling?",
                    subtitle: "Every Aura coin buys one minute of scrolling."
                )

                // A wheel, matching the Focus Length picker — same light sheet,
                // same numerals, same `colorScheme` override.
                //
                // It replaces both the readout and the input: the wheel already
                // shows the number large and centred, so the separate 34pt
                // figure above it was the same value twice.
                wheels
                    .frame(maxHeight: .infinity)

                Spacer(minLength: Theme.Spacing.l)

                // The balance, stated plainly, going red only when the amount
                // actually passes it. It used to be a reserved red line that
                // showed for every unaffordable value — which on a 74-coin
                // balance is most of the range, so the loudest colour in the
                // palette was on screen nearly always. Done already disables;
                // red was saying it twice.
                // Only the failure case. The balance and its reset rule live on
                // the store screen now — repeating them here would be the same
                // two facts twice, one tap apart.
                Text("You only have \(store.coinBalance) coins.")
                    .auraFont(.body, SheetType.subtitle, .regular)
                    .foregroundStyle(LightSheet.danger)
                    .frame(height: 18)
                    .opacity(overspending ? 1 : 0)
                    .padding(.bottom, Theme.Spacing.s)
                    .animation(.easeInOut(duration: 0.18), value: overspending)

                LightPrimaryButton(title: "Done", enabled: canAfford) {
                    guard canAfford else { return }
                    Haptics.impact(.medium)
                    // Dismiss first: the caller starts the checkout on the same
                    // frame, so the card is already moving as the sheet drops.
                    dismiss()
                    onDone(minutes)
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.l)
            }
        }
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.hidden)
    }

    /// Whole hours they can afford. Usually 0…1 or 2, so the column stays short.
    private var hourOptions: [Int] { Array(0...(store.coinBalance / 60)) }

    /// The minutes column, which shrinks on the last hour.
    ///
    /// With 74 coins, an hour leaves 14 — so at hours = 1 the column stops at
    /// 10 rather than offering 55 and refusing to sell it. The ceiling lives in
    /// the options, not in a disabled button.
    private var looseOptions: [Int] {
        let remaining = hours == store.coinBalance / 60
            ? (store.coinBalance % 60 / Self.step) * Self.step
            : 55
        return Array(stride(from: 0, through: Swift.max(0, remaining), by: Self.step))
    }

    private var wheels: some View {
        HStack(spacing: 0) {
            Picker("", selection: $hours) {
                ForEach(hourOptions, id: \.self) { value in
                    Text("\(value)").auraFont(.display, 20, .bold).monospacedDigit()
                        .foregroundStyle(LightSheet.title).tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 70)

            Text(hours == 1 ? "hour" : "hours")
                .auraFont(.body, SheetType.cardTitle, .semibold)
                .foregroundStyle(LightSheet.title)
                .frame(width: 70, alignment: .leading)

            Picker("", selection: $loose) {
                ForEach(looseOptions, id: \.self) { value in
                    Text("\(value)").auraFont(.display, 20, .bold).monospacedDigit()
                        .foregroundStyle(LightSheet.title).tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 70)

            Text("min")
                .auraFont(.body, SheetType.cardTitle, .semibold)
                .foregroundStyle(LightSheet.title)
                .frame(width: 70, alignment: .leading)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        // Moving to the last hour can strand the minutes wheel on a value that
        // column no longer contains, which leaves the picker showing a number
        // it isn't selecting.
        .onChange(of: hours) { _, _ in
            if let ceiling = looseOptions.last, loose > ceiling { loose = ceiling }
        }
        // The app forces dark at the root; the wheel has to be told otherwise or
        // its numerals come out white on a white sheet.
        .environment(\.colorScheme, .light)
    }
}
