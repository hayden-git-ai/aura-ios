//
//  BlockingEngine.swift
//  Aura iOS
//

import Foundation

/// The one place that decides what is shielded.
///
/// Every surface reads this — the shield, the Blocks screen's Blocking Now
/// strip, the Home pill. Nothing computes its own answer. The old code had
/// `gateCountdown` preferring a running focus session while `blockedNowAppIcons`
/// preferred bought time, so during a focus session with minutes banked the pill
/// and the block set said different things.
enum BlockingEngine {

    /// Resolve the config and the current session state into a plan.
    ///
    /// - Parameters:
    ///   - isUnlocked: bought or earned time is running.
    ///   - inSession: a session is live — Lock In or a photo habit.
    ///   - hardMode: no bypasses. Removes the weekly pass and, here, stops iOS
    ///     letting Aura be deleted while it is actually blocking something.
    ///
    /// A focus session outranks bought time: start one with twenty minutes in
    /// the bank and Distracting re-shields for the duration, bank untouched.
    /// Otherwise you could "focus" while scrolling, which would make the coins
    /// that session pays out fake.
    static func plan(config: BlockConfig,
                     isUnlocked: Bool,
                     inSession: Bool,
                     hardMode: Bool = false) -> ShieldPlan {
        var plan = ShieldPlan(
            // Always Blocked is in every plan. There is no state that lifts it —
            // only Emergency Unlock, which clears the shield outright.
            hardTokens: config.blocked.token,
            softTokens: softLifted(isUnlocked: isUnlocked, inSession: inSession)
                ? nil
                : config.distracting.token,
            exceptTokens: config.allowed.token,
            blockEverything: config.blockEverything,
            blockAdultWebsites: config.blockAdultWebsites
        )
        // Only while something is actually shielded. Denying removal on an
        // empty plan would leave someone who blocked nothing unable to delete
        // an app that isn't doing anything to them, which is not strictness,
        // it's a trap.
        plan.denyAppRemoval = hardMode && !plan.isEmpty
        return plan
    }

    /// Whether the Distracting rule is currently open.
    ///
    /// Bought time opens it, and a running session closes it again regardless.
    /// That second half is what makes Lock In mean anything: someone who buys
    /// twenty minutes and then starts a session to earn more would otherwise be
    /// sitting in front of the very apps they're being paid to stay out of.
    static func softLifted(isUnlocked: Bool, inSession: Bool) -> Bool {
        isUnlocked && !inSession
    }

    /// The rule an app should end up in when it's picked into `rule` while
    /// already sitting in others. Highest rank wins — see `BlockRule.rank`.
    static func winner(of rules: [BlockRule]) -> BlockRule? {
        rules.max { $0.rank < $1.rank }
    }

    /// Icons for the Blocking Now strip while the picker is still mocked.
    ///
    /// **Always Blocked never appears here.** That rule is private — someone
    /// who permanently blocks an app is often blocking something they'd rather
    /// not have on a screen a friend glances at, and a strip on the Blocks tab
    /// and a pill on Home are both screens other people see. It's still
    /// shielded; it just isn't advertised.
    static func blockedNowIcons(config: BlockConfig,
                                isUnlocked: Bool,
                                inSession: Bool) -> [AppIconSource] {
        var seen = Set<AppIconSource>()
        var ordered: [AppIconSource] = []

        func add(_ icons: [AppIconSource]) {
            for icon in icons where seen.insert(icon).inserted { ordered.append(icon) }
        }

        if !softLifted(isUnlocked: isUnlocked, inSession: inSession) {
            add(config.distracting.iconSources)
        }
        return ordered
    }
}
