//
//  AdultContentSheet.swift
//  Aura iOS
//

import SwiftUI

/// The commit sheet for the adult-content filter, both ways round.
///
/// `HoldConfirmSheet` with this decision's words — the shared shape every
/// commitment moment wears.
struct AdultContentSheet: View {
    /// What the toggle is being moved *to*.
    let turningOn: Bool
    /// When the filter was switched on. Turning it off cites how long it's
    /// been standing — a decision made hours ago is the one most worth pausing
    /// over, and a long run is worth naming before someone ends it.
    var enabledAt: Date?
    var onCommit: () -> Void

    var body: some View {
        HoldConfirmSheet(
            sticker: "Blocks_Adult Websites Sheet",
            // Same treatment as the End Session sheet's STOP-sign fox, with the
            // title pulled up under it. The Allow side (turning protection off)
            // runs the warning a touch smaller.
            stickerHeight: turningOn ? 120 : 104,
            stickerBottomInset: -Theme.Spacing.xl,
            title: title,
            subtitle: subtitle,
            idleCaption: turningOn ? "Press and hold to block" : "Press and hold to allow",
            doneCaption: turningOn ? "Blocked" : "Allowed",
            // 3 seconds to commit, 20 to undo. The switch most apps leave free
            // is the one that turns protection off, and twenty seconds is long
            // enough that it can't be an impulse.
            duration: turningOn ? 3 : 20,
            onConfirm: onCommit
        )
    }

    private var title: String {
        turningOn ? "Block adult websites?" : "Allow adult websites?"
    }

    private var subtitle: String {
        if turningOn {
            return "Block adult websites 24/7 across your browsers and disable private browsing."
        }
        return "Are you sure you want to enable all adult websites? \(standingLine)"
    }

    /// How long the filter has been on, as a sentence. The same fact at every
    /// age — a day-one impulse and a two-month run both get named, rather than
    /// the older one quietly getting the easier copy.
    private var standingLine: String {
        guard let enabledAt else { return "" }
        let calendar = Calendar.current
        if calendar.isDateInToday(enabledAt) { return "You only enabled this setting today." }
        if calendar.isDateInYesterday(enabledAt) { return "You only enabled this setting yesterday." }
        let days = calendar.dateComponents([.day],
                                           from: calendar.startOfDay(for: enabledAt),
                                           to: calendar.startOfDay(for: .now)).day ?? 0
        if days < 14 { return "You've had this on for \(days) days." }
        let weeks = days / 7
        return "You've had this on for \(weeks) weeks."
    }
}

#Preview {
    Color.gray.sheet(isPresented: .constant(true)) {
        AdultContentSheet(turningOn: true) {}
    }
}
