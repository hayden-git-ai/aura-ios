//
//  InterventionPurchase.swift
//  Aura iOS
//

import Foundation
import UIKit

/// Buying screen time from inside an intervention.
///
/// Shared so every style spends coins the same way. The dialogue and the
/// message thread ask for it very differently, and the one thing that must not
/// differ is what actually happens to the balance.
enum InterventionPurchase {
    /// Charges, opens the phone, and schedules the time's-up notification.
    /// Returns false when the balance can't cover it, having changed nothing.
    @discardableResult
    @MainActor
    static func buy(minutes: Int, from store: HabitStore) -> Bool {
        guard store.chargeForScreenTime(minutes: minutes) else {
            Haptics.notify(.error)
            return false
        }
        Haptics.impact(.medium)
        store.startPurchasedScreenTime(minutes: minutes)
        InterventionNotifier.scheduleTimeUp(minutes: minutes)
        return true
    }
}
