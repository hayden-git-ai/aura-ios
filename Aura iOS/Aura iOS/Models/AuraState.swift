//
//  AuraState.swift
//  Aura iOS
//

import Foundation

struct StreakInfo: Codable, Hashable {
    var currentStreak: Int
    var longestStreak: Int
    var lastCompletedDate: Date?
}

/// A habit "session" running on the Home screen — the Photo-Proof loop's timer
/// that counts down while apps stay locked, then grants the habit's reward and
/// unlocks when it hits zero.
struct ActiveHabitSession: Hashable, Codable {
    let habitName: String
    /// Which habit this is, so its all-time count can climb when the timer ends.
    /// Optional so sessions persisted before this field decode cleanly.
    var habitId: UUID?
    let rewardMinutes: Int
    let totalSeconds: Int

    /// When it finishes. Absolute, not a counter being decremented — a ticking
    /// integer stops ticking the moment the app is backgrounded, so a session
    /// left running while the phone slept came back with the wrong time on it.
    /// A date is also what a Live Activity needs to count down on its own.
    var endsAt: Date?
    /// What was left at the moment it was paused. Non-nil only while paused,
    /// which is what `endsAt` can't express.
    var pausedRemaining: Int?

    var isPaused: Bool { pausedRemaining != nil }

    func remainingSeconds(at now: Date) -> Int {
        if let pausedRemaining { return pausedRemaining }
        guard let endsAt else { return 0 }
        return max(0, Int(endsAt.timeIntervalSince(now).rounded(.up)))
    }

    func progress(at now: Date) -> Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(totalSeconds - remainingSeconds(at: now)) / Double(totalSeconds)
    }

    mutating func pause(at now: Date) {
        guard !isPaused else { return }
        pausedRemaining = remainingSeconds(at: now)
        endsAt = nil
    }

    mutating func resume(at now: Date) {
        guard let pausedRemaining else { return }
        endsAt = now.addingTimeInterval(TimeInterval(pausedRemaining))
        self.pausedRemaining = nil
    }
}

/// A Lock In session that's currently running.
///
/// Anchors, not counters, for the same reason `ActiveHabitSession` keeps them:
/// a ticking integer stops the moment the app is backgrounded. It lives on the
/// store rather than in the focus screen's `@State` because a session held in
/// view state dies with the view, and the Live Activity has to outlive it.
struct ActiveFocusSession: Hashable, Codable {
    let startedAt: Date
    /// When it's due to finish. Nil for Extreme Focus, which has no target:
    /// the clock counts up and stopping is what ends it.
    let endsAt: Date?
    /// The length it was set to, kept so a finished session can report what it
    /// was worth without re-reading the config.
    let lengthMinutes: Int
    /// Coins per hour, captured at commit. Held here so the store can settle up
    /// on its own — a session that ends while the app is closed still has to
    /// pay out, and the setup screen that knew the rate is long gone.
    let earnRate: Double

    /// What this session has earned, given where the clock is.
    ///
    /// A timed session pays its full length; an open-ended one pays for the
    /// minutes actually sat through.
    func earnedMinutes(at now: Date) -> Int {
        let seconds = isOpenEnded ? elapsedSeconds(at: now) : lengthMinutes * 60
        return Int((Double(seconds) / 3600 * earnRate).rounded())
    }

    var isOpenEnded: Bool { endsAt == nil }

    func elapsedSeconds(at now: Date) -> Int {
        max(0, Int(now.timeIntervalSince(startedAt)))
    }

    func remainingSeconds(at now: Date) -> Int {
        guard let endsAt else { return 0 }
        return max(0, Int(endsAt.timeIntervalSince(now).rounded(.up)))
    }
}

/// What the Home screen's countdown is waiting on. Only one can run at a time —
/// a focus session keeps apps locked, bought screen time keeps them open — so
/// the caption tells the user which way the clock is pointing.
enum GateCountdown: Equatable {
    /// A Photo Proof or Deep Focus timer is running; apps unlock when it ends.
    case untilFocusEnds(seconds: Int)
    /// Screen time was bought and is burning down; apps lock when it runs out.
    case untilAppsLock(seconds: Int)

    var caption: String {
        switch self {
        case .untilFocusEnds: return "Until focus session ends"
        case .untilAppsLock:  return "Until your apps lock"
        }
    }

    var seconds: Int {
        switch self {
        case .untilFocusEnds(let s), .untilAppsLock(let s): return s
        }
    }

    /// "4:07", or "1:04:07" once there's an hour or more on the clock.
    var clock: String {
        let total = max(0, seconds)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s)
                     : String(format: "%d:%02d", m, s)
    }
}
