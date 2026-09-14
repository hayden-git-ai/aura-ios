//
//  AuraTimerAttributes.swift
//  Aura iOS
//
//  Shared between the app and the widget extension. Add this file to BOTH
//  targets — the app starts and updates the activity, the extension draws it.
//

import ActivityKit
import Foundation

/// Whatever Aura is counting down right now.
///
/// One activity, never two, because the app already decides which timer matters:
/// `HabitStore.gateCountdown` gives a focus session precedence over bought time,
/// and this mirrors that exactly rather than inventing a second answer.
struct AuraTimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var kind: Kind
        /// When it began. Only used to draw the progress bar, which
        /// `ProgressView(timerInterval:)` fills on its own from the pair — the
        /// same no-update trick the countdown uses.
        var startedAt: Date
        /// When it ends. The widget counts down from this on its own via
        /// `Text(timerInterval:)`, so the app pushes no per-second updates —
        /// ActivityKit throttles those hard and they'd drain the battery.
        ///
        /// Nil for Extreme Focus, which has no target time: the clock counts up
        /// from `startedAt` instead, and the progress bar drops out, since a
        /// fraction of nothing isn't a thing to draw.
        var endsAt: Date?
        /// Seconds left at the moment it was paused. Non-nil only while paused,
        /// because a live countdown can't express a stopped clock.
        var pausedRemaining: Int?
        var isPaused: Bool { pausedRemaining != nil }

        /// Open-ended: counting up, with nothing to count towards.
        var isOpenEnded: Bool { endsAt == nil }

        /// Whether the clock will ever read h:mm:ss rather than mm:ss.
        ///
        /// Read off the whole run, not what's left right now: the countdown
        /// updates itself without the widget re-laying out, so anything sized
        /// against it has to hold for the longest reading it will show. Lock In
        /// goes up to four hours, so this is a real case, not a hypothetical.
        ///
        /// Strictly *over* an hour, not at it: a run of exactly one hour — the
        /// Emergency Pass — reads "1:00:00" for a single second and "mm:ss" for
        /// the other 3,599, so sizing the compact Island for the hours form the
        /// whole time only pads the pill wide enough to shove the status-bar
        /// battery and Wi-Fi off the edge. That lone first second scales to fit.
        var showsHours: Bool {
            guard let endsAt else { return true }   // open-ended runs up past an hour
            return endsAt.timeIntervalSince(startedAt) > 3600
        }

        /// What the clock is counting *to*. Lives here rather than on `Kind`
        /// because Extreme Focus is the same kind of session with the opposite
        /// answer — there's no timer for it to be up.
        var title: String {
            switch kind {
            case .scrolling: return "This is rented screen time \u{1F440}"
            case .focus: return isOpenEnded ? "Cash out whenever \u{1F4B0}" : "Staying locked in pays \u{1F4B0}"
            // The photo is already taken and verified by the time this runs —
            // the session is the part that pays out.
            case .habit: return "The pic was the easy part \u{1F605}"
            }
        }
    }

    enum Kind: String, Codable, Hashable {
        /// Bought or earned time, running down until the apps lock again.
        case scrolling
        /// A Lock In session.
        case focus
        /// A photo-proof habit session.
        case habit

    }

    /// Nothing static varies between sessions, but `ActivityAttributes` needs a
    /// concrete type — the name is what shows in Settings › Live Activities.
    var name: String = "Aura"
}
