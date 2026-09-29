//
//  OnboardingFlow.swift
//  Aura iOS
//
//  The native onboarding funnel (fox / light / Brainrot design), cloning the
//  proven competitor structure. No permissions or account creation here: those
//  happen after the paywall, in the existing Setup flow. Built phase by phase.
//

import SwiftUI

@Observable
final class OnboardingFlow {

    /// The steps, in order. `rawValue` drives forward/back navigation.
    enum Step: Int, CaseIterable {
        // Phase 1 - brand and disarm
        case welcome            // promise: phone mockup + "Live More. Scroll Less."
        case meet               // companion intro: "hi there! i'm Aura" / "tell me a little about you"
        case name
        case age
        case handoff            // fox texts you: scrim + notification -> chat
        case chat               // the diagnosis chat, ending on "here's how the app works"
        case loopDemo           // interactive: tap Scroll, the hour burns, the fox delivers the verdict

        // Phase 3 - how it works (3-step demo) + the earn-first reframe + setup bridge
        case demoFreeze         // "I Freeze Your Distracting Apps"
        case demoEarn           // "Complete Quests, Earn Aura Coins"
        case demoSpend          // "Buy Screen Time"
        case reframe            // fox: "i'm not here to take your phone away..."
        case bridge             // fox: "let's set you up / a few quick questions"

        // Phase 4 - the question stretch (fox + question over option rows, blue ground).
        // Reactions are inline: after Continue the question text swaps to a reaction
        // in place, so the fox and layout never move. qSlider sits right after qGoal
        // so their lost-time number surfaces early.
        case qGoal              // "what is your goal with Aura?"
        case qSlider            // slider: daily screen time -> leads into the cost math
        case qFeelings          // "how does your screen time affect you the most?"
        case qPersona           // "what best describes you?"
        case qWorstTime         // "when do you usually scroll the most?"
        case qDoomProfile       // beat: "your doomscroll profile" (reacts to feelings + persona + worst-time)
        case qSkip              // "what would you like to prioritize over scrolling?"
        case qReviewDrop        // beat: a single tester quote drops in (placeholder now, real at launch)
        case qTried             // "have you tried to reduce your screen time before?"
        case qWhyFlopped        // "did you know?" facts

        // Phase 5 - reclaim their time as real things (books / courses / workouts)
        case qReclaim

        // Phase 6 - personalize: pick starter habits from the real catalogue
        case qHabits            // healthy habits (photo-proof), heart to favorite
        case qExercises         // daily exercise, heart to favorite
        case qDailyGoal         // daily habit goal (picker)

        // Phase 7 - loading -> Wrapped payoff -> commit (paywall follows, post-onboarding).
        // qImmediate's first-week benefits fold into the Wrapped rebuild.
        case qLoading           // "personalizing your experience" (the only loader)
        case qCustomPlan        // the Wrapped payoff
        case qScience           // "the science behind your plan" (proof: Harvard / UCL / Atomic Habits)
        case qReviews           // reviews wall ("made for people like you"): real tester testimonials
        case qCommit            // hold-to-commit ritual (right before the paywall)
    }

    // MARK: - Active sequence (launch vs full)

    /// The shortened flow shipping for the App Store launch. The long flow is kept
    /// intact in `fullSteps` (and every `Step` case still exists) for a future v2;
    /// switch `steps` back to `fullSteps` to restore it.
    static let launchSteps: [Step] = [
        .welcome, .qGoal, .qPersona, .age, .name,
        .qFeelings, .qWorstTime, .qHabits, .qLoading, .qCustomPlan, .qReviews,
        .qCommit,
    ]
    /// The complete onboarding, in declared enum order.
    static let fullSteps: [Step] = Step.allCases

    /// The active sequence. `advance()` / `back()` walk THIS array, not the raw
    /// enum order, so the launch flow can reorder and skip freely.
    var steps: [Step] = OnboardingFlow.launchSteps

    /// The current step's 0...1 position within the active sequence, so progress
    /// bars fill correctly whatever the sequence length. The launch screens feed
    /// this to their top bars instead of hardcoded per-screen values.
    var progress: Double {
        guard steps.count > 1, let i = steps.firstIndex(of: step) else { return 0 }
        return Double(i + 1) / Double(steps.count)
    }

    var step: Step = .welcome {
        didSet {
            guard oldValue != step else { return }
            analytics.screenViewed(step, entry: nextEntrySource)
            nextEntrySource = .new
        }
    }
    var onFinish: () -> Void = {}
    /// Returning users can authenticate before the anonymous purchase funnel.
    var onSignInRequested: () -> Void = {}
    private let analytics = NativeOnboardingAnalytics()
    private var nextEntrySource: OnboardingEntrySource = .new
    private var startedAt = Date()
    private var hasTrackedStart = false

    // MARK: - Collected answers (grow as phases land)

    var name: String = "" {
        didSet {
            guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            analytics.answerSelected(step, value: "provided")
        }
    }
    /// Pre-set to 18 so the age wheel opens on a sensible default (and it's the
    /// answer even if the user never scrolls).
    var age: Int? = 18

    // Phase 4 - question stretch answers.
    var goal: String? = nil {               // single-select
        didSet { if let goal { analytics.answerSelected(step, value: goal) } }
    }
    /// Honest daily screen-time hours from the slider (0...12, .5 steps).
    /// Starts at 6 so the slider always opens there.
    var hours: Double = 6
    var feelings: Set<String> = [] {        // multi-select
        didSet { if !feelings.isEmpty { analytics.answerSelected(step, values: feelings) } }
    }
    var persona: String? = nil {            // single-select (ICP)
        didSet { if let persona { analytics.answerSelected(step, value: persona) } }
    }
    var worstTime: String? = nil {          // single-select
        didSet { if let worstTime { analytics.answerSelected(step, value: worstTime) } }
    }
    var skips: Set<String> = [] {           // multi-select
        didSet { if !skips.isEmpty { analytics.answerSelected(step, values: skips) } }
    }
    var triedBefore: String? = nil {        // single-select (yes-didn't-stick / yes-briefly / no)
        didSet { if let triedBefore { analytics.answerSelected(step, value: triedBefore) } }
    }
    var dailyMinutes: Int? = nil {          // daily time commitment (single-select cards)
        didSet { if let dailyMinutes { analytics.answerSelected(step, value: "\(dailyMinutes)") } }
    }

    /// Whole-number hours for copy ("[hours] hours a day").
    var hoursText: String {
        let r = (hours * 2).rounded() / 2
        return r == r.rounded() ? String(Int(r)) : String(format: "%.1f", r)
    }

    var daysPerYear: Int { Int((hours * 365 / 24).rounded()) }

    /// First name only, trimmed, for reuse in later copy. Empty until entered.
    var firstName: String {
        name.trimmingCharacters(in: .whitespaces).split(separator: " ").first.map(String.init) ?? ""
    }

    // MARK: - Navigation

    func appear() {
        guard !hasTrackedStart else {
            analytics.screenViewed(step, entry: .resume)
            return
        }
        hasTrackedStart = true
        startedAt = Date()
        analytics.started()
        analytics.screenViewed(step, entry: .new)
    }

    func advance() {
        if step == .qSlider {
            analytics.answerSelected(step, value: hoursText)
        }
        // The commitment event fires whenever we leave qCommit, whether or not it
        // is the final screen in the active sequence.
        if step == .qCommit {
            analytics.commitmentCompleted()
        }

        // Walk the ACTIVE sequence, not rawValue + 1, so launch reorders/skips work.
        guard let idx = steps.firstIndex(of: step), idx + 1 < steps.count else {
            let totalMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            analytics.completed(totalMs: totalMs)
            onFinish()
            return
        }
        let next = steps[idx + 1]
        if next == .qCustomPlan {
            analytics.planGenerated()
        }
        nextEntrySource = .new
        step = next
    }

    func back() {
        guard let idx = steps.firstIndex(of: step), idx > 0 else { return }
        let prev = steps[idx - 1]
        analytics.backTapped(from: step, to: prev)
        nextEntrySource = .back
        step = prev
    }
}
