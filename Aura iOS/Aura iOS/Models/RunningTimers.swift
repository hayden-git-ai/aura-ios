//
//  RunningTimers.swift
//  Aura iOS
//

import Foundation

/// Whatever clocks were running when the app last put itself away.
///
/// These used to live only in memory, which was survivable while a timer was
/// just a number on Home — the app being gone meant nobody was looking at it
/// anyway. A Live Activity changes that: the countdown stays on the Lock Screen
/// after the app is killed, so the state behind it has to still be there when
/// the app comes back, or the Island is showing a session the app has no
/// memory of.
///
/// Dates, never counters, for the same reason everything else here is: an
/// elapsed count written to disk is wrong the moment the phone sleeps.
struct RunningTimers: Codable {
    var unlockStartedAt: Date?
    var unlockEndsAt: Date?
    var habit: ActiveHabitSession?
    var habitMethod: HabitCategory?
    var focus: ActiveFocusSession?

    var isEmpty: Bool {
        unlockEndsAt == nil && habit == nil && focus == nil
    }
}

enum RunningTimersFile {
    private static let filename = "running-timers.json"

    private static var url: URL? {
        guard let directory = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        ) else { return nil }
        return directory.appendingPathComponent(filename)
    }

    static func load() -> RunningTimers {
        guard let url, let data = try? Data(contentsOf: url) else { return RunningTimers() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(RunningTimers.self, from: data)) ?? RunningTimers()
    }

    static func save(_ timers: RunningTimers) {
        guard let url else { return }
        // Nothing running is worth a delete rather than an empty file — a
        // leftover file is how a finished session comes back from the dead.
        guard !timers.isEmpty else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(timers) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
