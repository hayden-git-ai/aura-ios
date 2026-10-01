//
//  LiveActivityController.swift
//  Aura iOS
//

import ActivityKit
import Foundation

/// Starts, updates and ends the one Live Activity Aura ever shows.
///
/// Deliberately dumb: it's told what's running and mirrors it. All the deciding
/// — which timer wins, when one ends — already happens in `HabitStore`, and a
/// second opinion here is how the Island ends up disagreeing with the app.
@MainActor
enum LiveActivityController {
    private static var current: Activity<AuraTimerAttributes>?
    /// What should be on screen right now, so a failed start can be retried
    /// without the caller having to notice it failed.
    private static var wanted: AuraTimerAttributes.ContentState?
    /// Set when the user swipes the activity away. Their call, not ours — the
    /// timer keeps running, but it stays off the Lock Screen until the next one.
    private static var dismissedByUser = false
    private static var lastRequest: Date = .distantPast
    /// When the activity now on screen first appeared, which is how a person
    /// swiping it away is told apart from the system taking it.
    private static var showingSince: Date = .distantPast
    private static var stateWatcher: Task<Void, Never>?

    /// Whether the user has them switched on. Off is a normal state, not an
    /// error — every call below no-ops rather than throwing.
    static var isAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Puts back an activity that went away on its own.
    ///
    /// Starting one can fail for reasons that clear up a second later — the app
    /// wasn't foreground yet, the system was mid-install, the activity limit was
    /// momentarily full — and a timer with nothing on the Lock Screen is the
    /// failure the user actually notices. Cheap enough to call every tick: it's
    /// a state read, and it only acts when nothing is live.
    ///
    /// Deliberately silent when the user dismissed it. Putting back something
    /// somebody just swiped away is the sort of thing that gets an app pulled.
    static func heal() {
        guard let wanted, isAvailable, !dismissedByUser else { return }
        if wanted.pausedRemaining == nil, let end = wanted.endsAt, end <= .now {
            self.end()
            return
        }
        guard !Activity<AuraTimerAttributes>.activities.contains(where: { $0.activityState == .active || $0.activityState == .stale })
        else { return }
        guard Date.now.timeIntervalSince(lastRequest) > 5 else { return }
        show(wanted)
    }

    /// Puts the given state on screen, starting or updating as needed.
    ///
    /// One call handles both because the caller shouldn't have to track whether
    /// an activity already exists — that's exactly the sort of bookkeeping that
    /// leaves a stale timer on the Lock Screen.
    static func show(_ state: AuraTimerAttributes.ContentState) {
        guard isAvailable else { return }
        if state.pausedRemaining == nil, let end = state.endsAt, end <= .now {
            self.end()
            return
        }

        // A different timer than the one that was dismissed, so the user's
        // "not this one" doesn't carry over to the next thing they start.
        if state.startedAt != wanted?.startedAt || state.kind != wanted?.kind {
            dismissedByUser = false
        }
        wanted = state

        // A local countdown remains accurate without network updates. Expiry
        // is not missing data, and staleDate does not end an activity.
        // The system timer clamps to zero until the app can dismiss it.
        let content = ActivityContent(state: state, staleDate: nil)

        if let live = adopted() {
            current = live
            watch(live)
            Task { await live.update(content) }
            endStrays(keeping: live)
            return
        }

        lastRequest = .now
        do {
            current = try Activity.request(
                attributes: AuraTimerAttributes(),
                content: content,
                pushType: nil
            )
            if let current { watch(current) }
        } catch {
            // Denied, over the system's activity limit, or requested from the
            // background. None of it is worth interrupting the app for —
            // `heal()` comes back around and tries again.
            current = nil
        }
        endStrays(keeping: current)
    }

    /// Takes it off screen. `.immediate` rather than letting it linger on the
    /// Lock Screen: when Aura's timer is done, a countdown showing zero is
    /// clutter, not information.
    ///
    /// Sweeps every activity, not just the handle this process happens to
    /// hold — after a relaunch there is no handle, and "I don't know about it"
    /// is not a reason to leave a dead timer on someone's Lock Screen.
    static func end() {
        current = nil
        wanted = nil
        dismissedByUser = false
        stateWatcher?.cancel()
        stateWatcher = nil
        for activity in Activity<AuraTimerAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    /// The activity this app should be driving, if one is already on screen.
    ///
    /// A relaunch starts with `current` empty while the previous run's activity
    /// is still up, so without this the app would end a perfectly good activity
    /// and request a replacement — a request that can fail, and did, leaving
    /// the Island blank with time still on the clock. Adopting keeps the one
    /// that's already working.
    ///
    /// Active and stale activities can receive updates. Adopt both, including
    /// stale activities from older app versions, rather than duplicating them.
    /// Ended and dismissed activities are never adopted.
    private static func adopted() -> Activity<AuraTimerAttributes>? {
        if let current, current.activityState == .active || current.activityState == .stale { return current }
        return Activity<AuraTimerAttributes>.activities.first { $0.activityState == .active || $0.activityState == .stale }
    }

    /// Watches for the user swiping it away, which is the one disappearance
    /// `heal()` must not undo.
    ///
    /// `.dismissed` doesn't say who did it — a person swiping and the system
    /// discarding the activity look identical. Time apart tells them apart: the
    /// system's discards land within moments of the activity appearing (an app
    /// reinstall is the usual cause), while a person has to see it first. So a
    /// dismissal in the opening seconds is treated as the system's and healed,
    /// and anything later is treated as theirs and left alone.
    private static func watch(_ activity: Activity<AuraTimerAttributes>) {
        stateWatcher?.cancel()
        showingSince = .now
        let appeared = showingSince
        stateWatcher = Task { @MainActor in
            for await state in activity.activityStateUpdates where state == .dismissed {
                dismissedByUser = Date.now.timeIntervalSince(appeared) > Self.deliberateAfter
                return
            }
        }
    }

    /// How long an activity has to have been on screen for its disappearance to
    /// count as somebody's decision.
    private static let deliberateAfter: TimeInterval = 15

    /// Ends everything except the one being kept — duplicates from a crash or a
    /// failed hand-off, which would otherwise sit there contradicting it.
    private static func endStrays(keeping keeper: Activity<AuraTimerAttributes>?) {
        for activity in Activity<AuraTimerAttributes>.activities where activity.id != keeper?.id {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
