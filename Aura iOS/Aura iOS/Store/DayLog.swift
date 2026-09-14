//
//  DayLog.swift
//  Aura iOS
//

import Foundation

/// What one day of using Aura amounted to.
///
/// The record the whole habits side of Stats was missing. `habitsCompleted`,
/// `detoxDay` and `last90Days` were `let` constants in `HabitStore`, and
/// `CoinSample` invented a week out of a fixed shape, because nothing recorded
/// an earning with a date on it. Everything derives from these now.
///
/// One entry per calendar day, keyed on `startOfDay` so a day is a day
/// regardless of what time the coin landed.
struct DayRecord: Codable, Hashable, Identifiable {
    var id: Date { date }
    /// Midnight, local.
    let date: Date
    var coinsEarned: Int = 0
    /// Every completion, not just the first. The streak cares about the first
    /// one a day; this doesn't.
    var habitsCompleted: Int = 0
    /// Coins earned in each hour of the day — 24 buckets, deliberately the same
    /// shape as `ScreenTimeDay.hourly` so the two sides of Stats answer "when"
    /// the same way.
    ///
    /// A day total can't produce a peak hour, which is why "Most productive"
    /// was the last sampled figure on the habits side.
    var hourly: [Int] = Array(repeating: 0, count: 24)
    /// Coins by the method that earned them, keyed on `HabitCategory.rawValue`.
    ///
    /// "Your favorite quests" was inventing three of its four rows as fractions
    /// of the week's total, because a coin arrived with no idea where it came
    /// from.
    var byMethod: [String: Int] = [:]

    var kept: Bool { habitsCompleted > 0 }

    init(date: Date, coinsEarned: Int = 0, habitsCompleted: Int = 0,
         hourly: [Int] = Array(repeating: 0, count: 24),
         byMethod: [String: Int] = [:]) {
        self.date = date
        self.coinsEarned = coinsEarned
        self.habitsCompleted = habitsCompleted
        self.hourly = hourly
        self.byMethod = byMethod
    }

    /// Written by hand because Swift's synthesized decoder ignores default
    /// values and throws on a missing key — every record written before `hourly`
    /// existed would fail to load, taking the whole log with it.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(Date.self, forKey: .date)
        coinsEarned = try container.decodeIfPresent(Int.self, forKey: .coinsEarned) ?? 0
        habitsCompleted = try container.decodeIfPresent(Int.self, forKey: .habitsCompleted) ?? 0
        let stored = try container.decodeIfPresent([Int].self, forKey: .hourly)
        hourly = (stored?.count == 24) ? stored! : Array(repeating: 0, count: 24)
        byMethod = try container.decodeIfPresent([String: Int].self, forKey: .byMethod) ?? [:]
    }

    /// Adds to one hour and the day total together, so the buckets can never
    /// disagree with the number above them.
    mutating func credit(coins: Int, hour: Int, method: HabitCategory?) {
        guard coins > 0, (0..<24).contains(hour) else { return }
        coinsEarned += coins
        hourly[hour] += coins
        if let method { byMethod[method.rawValue, default: 0] += coins }
    }
}

/// The log on disk.
///
/// JSON in Application Support rather than SwiftData: the whole file is a few
/// KB of one flat record type, there's no relational shape to model, and a
/// plain file moves into a shared App Group container in one line the day a
/// Screen Time extension needs to read it. A schema and a migration story would
/// be ceremony around an array of structs.
///
/// Writes are best-effort and silent. A dropped write costs one day's counters,
/// which is not worth interrupting an earn animation to report.
enum DayLogFile {
    private static let filename = "day-log.json"

    private static var url: URL? {
        guard let directory = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        ) else { return nil }
        return directory.appendingPathComponent(filename)
    }

    static func load() -> [DayRecord] {
        guard let url, let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([DayRecord].self, from: data)) ?? []
    }

    static func save(_ records: [DayRecord]) {
        guard let url else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(records) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

/// The 90-day board the habits side is built around.
enum Journey {
    /// How many days a board runs for. "Your past 90 days" is named after it,
    /// the grid draws it, and `dayNumber` counts within it.
    static let board = 90
}

// MARK: - Reads

extension Array where Element == DayRecord {
    /// Oldest first, one entry per day, gaps filled with zeros.
    ///
    /// The log only holds days something happened on; every chart wants a
    /// continuous run. Filling here means no view has to think about holes.
    func filled(from start: Date, days: Int, calendar: Calendar = .current) -> [DayRecord] {
        let byDay = Dictionary(uniqueKeysWithValues: map { (calendar.startOfDay(for: $0.date), $0) })
        return (0..<days).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: start) ?? start
            return byDay[calendar.startOfDay(for: date)] ?? DayRecord(date: date)
        }
    }

    /// The current week, Sunday first — the run both Stats charts are drawn on.
    func week(now: Date = .now, calendar: Calendar = .current) -> [DayRecord] {
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.dateInterval(of: .weekOfYear, for: today)?.start else { return [] }
        return filled(from: start, days: 7, calendar: calendar)
    }

    /// The current 90-day board, day one first.
    ///
    /// Anchored to the start of the board today falls in, which is what
    /// `dayNumber` counts within. `last90Days` is a *trailing* window — it
    /// always puts today in the last cell — so on a fresh install the grid lit
    /// its ninetieth dot directly under the words "Day 1 of 90".
    func journeyDays(now: Date = .now, calendar: Calendar = .current) -> [Bool] {
        // `[Bool]` explicitly: inside an Array extension, a bare `Array` binds
        // to `Self` — the same shadowing that `dayNumber` documents for `max`.
        guard let start = boardStart(now: now, calendar: calendar) else {
            return [Bool](repeating: false, count: Journey.board)
        }
        return filled(from: start, days: Journey.board, calendar: calendar).map(\.kept)
    }

    /// The first day of the 90 today belongs to. Nil until something's logged.
    private func boardStart(now: Date, calendar: Calendar) -> Date? {
        guard let first = map(\.date).min() else { return nil }
        let origin = calendar.startOfDay(for: first)
        let elapsed = Swift.max(0, calendar.dateComponents(
            [.day], from: origin, to: calendar.startOfDay(for: now)
        ).day ?? 0)
        return calendar.date(byAdding: .day,
                             value: (elapsed / Journey.board) * Journey.board,
                             to: origin)
    }

    /// A trailing 90-day window: kept or not, oldest first, today last.
    ///
    /// For counting runs, not for drawing the journey — the streak cares about
    /// the days just gone, wherever they fall in the 90.
    func last90Days(now: Date = .now, calendar: Calendar = .current) -> [Bool] {
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -89, to: today) else { return [] }
        return filled(from: start, days: 90, calendar: calendar).map(\.kept)
    }

    /// Habits completed on the current board.
    ///
    /// Scoped to the same 90 days the grid draws, not to all time. The two sit
    /// on one line under one grid, so a lifetime figure beside a board-scoped
    /// row of dots would start disagreeing on day 91 and never stop.
    ///
    /// Counts every completion, not one per day — the streak is what cares
    /// about the first of the day.
    func boardHabitsCompleted(now: Date = .now, calendar: Calendar = .current) -> Int {
        guard let start = boardStart(now: now, calendar: calendar) else { return 0 }
        return filled(from: start, days: Journey.board, calendar: calendar)
            .reduce(0) { $0 + $1.habitsCompleted }
    }

    /// The streak, and the freezes protecting it, walked in one pass.
    ///
    /// Derived rather than stored, like everything else here. A freeze is a
    /// consequence of the log — earned on a day with two or more quests, spent
    /// on a day with none — so replaying the log always gives the same answer,
    /// and there's no counter to keep in step with the days it describes.
    ///
    /// - Parameters:
    ///   - earnAt: quests in a day that earns a freeze.
    ///   - maxFreezes: how many can be held at once.
    func streakRun(now: Date = .now, calendar: Calendar = .current,
                   earnAt: Int = StreakFreeze.earnAt,
                   maxFreezes: Int = StreakFreeze.maximum) -> (streak: Int, freezes: Int) {
        let today = calendar.startOfDay(for: now)
        guard let horizon = calendar.date(byAdding: .day, value: -(StreakFreeze.window - 1), to: today)
        else { return (0, 0) }
        // Start at the first day there's a record for. A fresh install walks a
        // handful of days; only a user who has actually been here for years
        // pays for the full window.
        let oldest = map { calendar.startOfDay(for: $0.date) }.min() ?? today
        let start = Swift.max(horizon, Swift.min(oldest, today))
        let span = (calendar.dateComponents([.day], from: start, to: today).day ?? 0) + 1
        let days = filled(from: start, days: Swift.max(1, span), calendar: calendar)

        var streak = 0
        var freezes = 0

        for (index, day) in days.enumerated() {
            let isToday = index == days.count - 1

            if day.kept {
                streak += 1
                if day.habitsCompleted >= earnAt {
                    freezes = Swift.min(maxFreezes, freezes + 1)
                }
                continue
            }

            // Today isn't a miss until it's over.
            if isToday { continue }

            if freezes > 0 {
                // Bridged: the run holds, but a skipped day doesn't lengthen it.
                freezes -= 1
            } else {
                streak = 0
            }
        }
        return (streak, freezes)
    }

    /// The hour the most is earned in, summed across the week rather than read
    /// off one day — a single unusual morning shouldn't move it.
    ///
    /// Falls back to 8am on an empty log: the card draws a marker either way,
    /// and a silent 0 would put it at midnight and read as a real finding.
    func peakEarningHour(now: Date = .now, calendar: Calendar = .current) -> Int {
        // `[Int](...)` spelled out: inside a `[DayRecord]` extension, a bare
        // `Array(repeating: 0,…)` infers itself as `[DayRecord]`.
        let totals = week(now: now, calendar: calendar).reduce(into: [Int](repeating: 0, count: 24)) { sum, day in
            for hour in 0..<24 { sum[hour] += day.hourly[hour] }
        }
        guard totals.contains(where: { $0 > 0 }) else { return 8 }
        return totals.enumerated().max { $0.element < $1.element }?.offset ?? 8
    }
    var coinsEarnedAllTime: Int { reduce(0) { $0 + $1.coinsEarned } }

    /// This week's earnings per method, biggest first — what "Your favorite
    /// quests" ranks.
    func coinsByMethod(now: Date = .now, calendar: Calendar = .current) -> [(method: HabitCategory, coins: Int)] {
        var totals: [String: Int] = [:]
        for day in week(now: now, calendar: calendar) {
            for (key, coins) in day.byMethod { totals[key, default: 0] += coins }
        }
        return HabitCategory.allCases
            .map { ($0, totals[$0.rawValue] ?? 0) }
            .sorted { $0.1 > $1.1 }
    }

    /// Which day of the journey today is — 1 on the first day the app is used.
    ///
    /// Counted from the first record rather than stored, so it can't drift out
    /// of step with the log it describes.
    /// Which day of the current board today is, 1 through 90.
    ///
    /// Wraps rather than counting on forever. Day 91 is day 1 of a fresh board,
    /// which is what the grid draws and what "Your past 90 days" promises —
    /// before this it read "Day 92 of 90" and the grid had run out of cells to
    /// put today in.
    func dayNumber(now: Date = .now, calendar: Calendar = .current) -> Int {
        guard let first = map(\.date).min() else { return 1 }
        let days = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: first), to: calendar.startOfDay(for: now)
        ).day ?? 0
        // `Swift.max` explicitly: inside an Array extension, plain `max` binds
        // to the sequence's own no-argument method.
        return Swift.max(0, days) % Journey.board + 1
    }
}

/// The user's habits on disk.
///
/// Same treatment as the day log, for the same reason: a habit the user creates
/// or edits is theirs, and losing it on relaunch is the difference between a
/// demo and an app. `HabitStore.habits` was an in-memory array seeded at launch.
///
/// The seeded defaults are the starting set, not a fallback — once the file
/// exists it wins, so deleting a default habit keeps it deleted.
enum HabitFile {
    private static let filename = "habits.json"

    private static var url: URL? {
        guard let directory = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        ) else { return nil }
        return directory.appendingPathComponent(filename)
    }

    static func load() -> [Habit]? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([Habit].self, from: data)
    }

    static func save(_ habits: [Habit]) {
        guard let url, let data = try? JSONEncoder().encode(habits) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

#if DEBUG
extension DayLogFile {
    /// Back-fills 90 days so the charts have something to draw on a fresh
    /// install. Debug only — a real first launch should show an empty history,
    /// because that's what it is.
    static func seedIfEmpty() {
        guard load().isEmpty else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let coinShape = [35, 60, 45, 80, 55, 95, 70]
        let habitShape = [2, 4, 3, 5, 3, 6, 4]

        let records: [DayRecord] = (0..<90).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -(89 - offset), to: today) else { return nil }
            // The last twelve days unbroken, so the seeded streak of 12 is a
            // fact of the log rather than a separate constant that disagrees
            // with it. Before that, a miss every third day.
            let kept = offset >= 78 || offset % 3 != 0
            guard kept else { return DayRecord(date: date) }
            let coins = coinShape[offset % coinShape.count]
            return DayRecord(date: date,
                             coinsEarned: coins,
                             habitsCompleted: habitShape[offset % habitShape.count],
                             hourly: seededHours(total: coins),
                             byMethod: seededMethods(total: coins))
        }
        save(records)
    }

    /// Sets today's earnings to `coins` and returns the whole log.
    ///
    /// Sets rather than adds, so relaunching with `-coins` twice doesn't stack
    /// into a number no real user could reach. `habitsCompleted` is floored at
    /// one because today has to count as kept — coins that arrive without a
    /// completed habit would break the streak they're supposed to sit beside.
    static func withTodayCoins(_ coins: Int) -> [DayRecord] {
        var records = load()
        let today = Calendar.current.startOfDay(for: .now)
        var record = records.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
            ?? DayRecord(date: today)
        record.coinsEarned = coins
        record.habitsCompleted = Swift.max(1, record.habitsCompleted)
        record.hourly = seededHours(total: coins)
        record.byMethod = seededMethods(total: coins)
        records.removeAll { Calendar.current.isDate($0.date, inSameDayAs: today) }
        records.append(record)
        records.sort { $0.date < $1.date }
        save(records)
        return records
    }

    /// A morning-weighted day, peaking at 8am — habits get done early, and it
    /// keeps the peak clear of Screen Time's 10pm so the two markers on the
    /// peak-hours rail don't sit on top of each other.
    /// Roughly how a week's earning splits across the four methods.
    private static func seededMethods(total: Int) -> [String: Int] {
        let split: [(HabitCategory, Int)] = [(.photoTask, 45), (.focus, 30), (.exercise, 15), (.healthSync, 10)]
        return Dictionary(uniqueKeysWithValues: split.map { ($0.0.rawValue, total * $0.1 / 100) })
    }

    private static func seededHours(total: Int) -> [Int] {
        let shape = [0, 0, 0, 0, 0, 2, 9, 26, 34, 22, 14, 10,
                     12, 9, 7, 6, 9, 12, 10, 6, 4, 2, 1, 0]
        let sum = shape.reduce(0, +)
        guard sum > 0 else { return Array(repeating: 0, count: 24) }
        return shape.map { $0 * total / sum }
    }
}
#endif

/// The freeze mechanic's numbers, in one place.
enum StreakFreeze {
    /// Quests completed in a day that earns one.
    static let earnAt = 2
    /// How many can be held at once.
    static let maximum = 2
    /// How far back a streak is counted.
    ///
    /// Was 90, which silently capped every streak at 90 days while the
    /// milestone grid ran to 1000 — a 120-day run would have rendered as 90.
    /// The walk starts at the oldest record rather than blindly this far back,
    /// so the window's size costs nothing until someone has filled it.
    static let window = 1100
}
