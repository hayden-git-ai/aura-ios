//
//  HealthMetric.swift
//  Aura iOS
//

import Foundation

/// One earnable Apple Health metric shown on the Apple Health sheet. Stubbed
/// until the HealthKit entitlement lands — `amountLabel` and `pendingMinutes`
/// come from fabricated "today" values for now; wire to real HealthKit samples
/// later without changing the view.
struct HealthMetric: Identifiable {
    let id: UUID
    var name: String
    var iconSystemName: String
    /// Custom Aura-fox icon asset for this metric. When set, the sheet shows it
    /// in place of the white-tile SF-symbol glyph. `nil` falls back to the tile.
    var iconAsset: String?
    /// e.g. "8 min / km" — how much screen time each unit earns.
    var rateLabel: String
    /// e.g. "3.2 km today" or "No activity yet".
    var amountLabel: String
    /// Screen time (minutes) available to collect right now. 0 when there's
    /// nothing to collect.
    var pendingMinutes: Int
    /// Whether there's new, uncollected activity to claim. Goes false after a
    /// collect (no *new* activity) and back true as more activity accrues.
    var hasActivity: Bool

    init(
        id: UUID = UUID(),
        name: String,
        iconSystemName: String,
        iconAsset: String? = nil,
        rateLabel: String,
        amountLabel: String,
        pendingMinutes: Int,
        hasActivity: Bool
    ) {
        self.id = id
        self.name = name
        self.iconSystemName = iconSystemName
        self.iconAsset = iconAsset
        self.rateLabel = rateLabel
        self.amountLabel = amountLabel
        self.pendingMinutes = pendingMinutes
        self.hasActivity = hasActivity
    }
}
