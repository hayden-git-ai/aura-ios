//
//  DayOfWeek.swift
//  Aura iOS
//

import Foundation

/// Weekday identity, shared by every day picker in the app.
///
/// What used to live here — `ScheduledBlock`, `AppLimit`, `HabitBlock`, breaks —
/// went with the three-rule rewrite. See docs/blocks/BLOCKS_BUILD_SPEC.md.
enum DayOfWeek: Int, CaseIterable, Codable, Identifiable {
    case sun, mon, tue, wed, thu, fri, sat

    var id: Int { rawValue }

    var shortLabel: String {
        ["S", "M", "T", "W", "T", "F", "S"][rawValue]
    }

    var twoLetterLabel: String {
        ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"][rawValue]
    }
}

extension Set where Element == DayOfWeek {
    /// Human summary for the weekday picker's trailing label.
    var daySummary: String {
        if count == 7 { return "Daily" }
        if self == [.mon, .tue, .wed, .thu, .fri] { return "Weekdays" }
        if self == [.sat, .sun] { return "Weekends" }
        if isEmpty { return "Never" }
        return "\(count) days"
    }
}
