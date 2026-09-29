//
//  DeepFocusModels.swift
//  Aura iOS
//

import Foundation

/// Ambient sound bed for a focus session — purely presentational for this
/// pass, no real audio playback wired yet.
enum FocusMusic: String, CaseIterable, Identifiable {
    case silence, lofi, rain, forest
    var id: String { rawValue }

    var title: String {
        switch self {
        case .silence: return "Silence"
        case .lofi: return "Lo-fi"
        case .rain: return "Rain"
        case .forest: return "Forest"
        }
    }

    var subtitle: String {
        switch self {
        case .silence: return "No audio"
        case .lofi: return "Mellow study loop"
        case .rain: return "Soft rain on a window"
        case .forest: return "Birds + leaves"
        }
    }
}

/// The setup screen's committed choices, carried into the active timer.
struct DeepFocusConfig: Identifiable {
    let id = UUID()
    var lengthMinutes: Int = 30
    var music: FocusMusic = .lofi
    /// Apps blocked for this session — seeded from the standing habit-block
    /// set, then extended per-session on the setup screen.
    var blockedAppIcons: [String] = []
    /// Human label for the blocked-app selection ("All Apps" or a list name),
    /// shown on the setup card and carried through for display.
    var appsLabel: String = "All Apps"
    /// Extreme Focus — an open-ended session with no target time. The active
    /// timer counts up instead of down, and earns screen time by the minutes
    /// actually focused rather than a preset length.
    var isUntimed: Bool = false
    /// Legacy hourly field retained for active-session compatibility. Deep Focus
    /// now awards exactly one coin per minute, regardless of this value.
    var earnRate: Double = 60

    /// One coin per focused minute.
    var earnedMinutes: Int { max(0, lengthMinutes) }

    /// Coins for an untimed session, given the whole minutes actually focused.
    func earnedMinutes(forElapsedSeconds seconds: Int) -> Int { max(0, seconds) / 60 }
}

/// Shared minutes → label formatting for anything showing a focus length —
/// "45m" under an hour, "1h" / "1h 5m" at or past it.
enum FocusDuration {
    static func label(_ minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes)m" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
    }
}

/// A completed Deep Focus session. Lived in the old Profile insights file with
/// a pile of stats scaffolding; only this survived, so it moved next to the
/// rest of the Deep Focus model.
struct DeepFocusSession: Identifiable, Hashable {
    let id = UUID()
    let durationMinutes: Int
    let earnedMinutes: Int
    let date: Date

    /// Seeded history so Stats has something to draw before real sessions
    /// accumulate. TODO: drop once sessions persist.
    static let samples: [DeepFocusSession] = {
        let calendar = Calendar.current
        func date(_ daysAgo: Int, _ hour: Int) -> Date {
            let base = calendar.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
            return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: base) ?? base
        }
        return [
            DeepFocusSession(durationMinutes: 45, earnedMinutes: 45, date: date(0, 9)),
            DeepFocusSession(durationMinutes: 80, earnedMinutes: 80, date: date(1, 14)),
            DeepFocusSession(durationMinutes: 30, earnedMinutes: 30, date: date(2, 8)),
            DeepFocusSession(durationMinutes: 105, earnedMinutes: 105, date: date(3, 18)),
            DeepFocusSession(durationMinutes: 25, earnedMinutes: 25, date: date(4, 8)),
            DeepFocusSession(durationMinutes: 60, earnedMinutes: 60, date: date(5, 19)),
            DeepFocusSession(durationMinutes: 90, earnedMinutes: 90, date: date(6, 9)),
        ]
    }()
}
