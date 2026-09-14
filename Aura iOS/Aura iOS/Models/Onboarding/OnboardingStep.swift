//
//  OnboardingStep.swift
//  Aura iOS
//
//  The canonical 52-screen onboarding graph (+ 7 branch/recovery states), per the
//  master implementation prompt. Each case's rawValue is the stable analytics
//  `screen_id`. The generated spec's OB-XX ids are noted in comments for cross-doc
//  lookup (copy deck / motion spec).
//

import Foundation

// MARK: - Phase

/// The seven master-prompt phases. `rawValue` is the zero-based phase index used
/// in analytics; `number` is the 1-based display number.
enum OnboardingPhase: Int, CaseIterable, Codable {
    case premiumReset       // Screens 01–05   (OB-01..05)
    case diagnosis          // Screens 06–15   (OB-04..10 conversational core)
    case timeCost           // Screens 16–21   (OB-22..27)
    case screenTimeSetup    // Screens 22–30   (OB-28..31)
    case mechanism          // Screens 31–40   (OB-11..21 mechanism + habit config)
    case commitment         // Screens 41–47   (OB-32..38 reminders, plan, ritual)
    case paywall            // Screens 48–52   (OB-43..48)

    var number: Int { rawValue + 1 }

    var title: String {
        switch self {
        case .premiumReset:    return "Premium reset"
        case .diagnosis:       return "Diagnosis"
        case .timeCost:        return "Time cost"
        case .screenTimeSetup: return "Screen Time setup"
        case .mechanism:       return "Mechanism"
        case .commitment:      return "Commitment"
        case .paywall:         return "Plans"
        }
    }
}

// MARK: - Screen class

/// Behavioral class of a screen (drives advance rule + back policy).
enum OnboardingScreenClass {
    case informational   // tap-to-continue, no captured input
    case input           // captures a value then advances
    case interactive     // tactile; produces a value/analytic then advances
    case system          // hands off to OS UI (auth/picker/purchase/rating)
    case terminal        // completes onboarding
    case recovery        // branch/recovery state (denied/failed/empty/pending)
}

// MARK: - Step

/// One addressable onboarding state. `rawValue` is the analytics `screen_id`.
enum OnboardingStep: String, CaseIterable, Codable, Hashable {

    // Phase 1 — Premium reset & coaching contract (01–05)
    case launchReset = "launch_reset"
    case limitsTruth = "limits_truth"
    case coachPromise = "coach_promise"
    case preferredName = "preferred_name"
    case coachingContract = "coaching_contract"

    // Phase 2 — Conversational diagnosis (06–15)
    case primaryGoal = "primary_goal"
    case goalReflection = "goal_reflection"
    case dailyScrollEstimate = "daily_scroll_estimate"
    case estimateReflection = "estimate_reflection"
    case primaryConsequence = "primary_consequence"
    case consequenceReflection = "consequence_reflection"
    case vulnerableTime = "vulnerable_time"
    case previousAttempt = "previous_attempt"
    case failedSolutionReflection = "failed_solution_reflection"
    case engineeredEnvironment = "engineered_environment"

    // Phase 3 — Tactile time-cost realization & agency (16–21)
    case interactiveDayLoss = "interactive_day_loss"
    case annualCost = "annual_cost"
    case oneYearGrid = "one_year_grid"
    case tenYearProjection = "ten_year_projection"
    case agencyReversal = "agency_reversal"
    case reclaimTarget = "reclaim_target"

    // Phase 4 — Screen Time setup & app selection (22–30)
    case screenTimeBridge = "screen_time_bridge"
    case screenTimePrivacy = "screen_time_privacy"
    case screenTimeNativeAuthorization = "screen_time_native_authorization"
    case screenTimeAuthorized = "screen_time_authorized"
    case appSelectionPrimer = "app_selection_primer"
    case familyActivityPicker = "family_activity_picker"
    case selectedAppsSummary = "selected_apps_summary"
    case protectionTiming = "protection_timing"
    case appsLockDemo = "apps_lock_demo"

    // Phase 5 — Aura mechanism & habit configuration (31–40)
    case mechanismOverview = "mechanism_overview"
    case verificationMethods = "verification_methods"
    case starterHabitSelection = "starter_habit_selection"
    case rewardPreview = "reward_preview"
    case mechanismDemoAction = "mechanism_demo_action"
    case mechanismDemoVerify = "mechanism_demo_verify"
    case mechanismDemoReward = "mechanism_demo_reward"
    case mechanismDemoUnlock = "mechanism_demo_unlock"
    case mechanismDemoRelock = "mechanism_demo_relock"
    case dailyCommitment = "daily_commitment"

    // Phase 6 — Reminders, personalized plan & commitment (41–47)
    case reminderStrategy = "reminder_strategy"
    case notificationPrimer = "notification_primer"
    case notificationNativeAuthorization = "notification_native_authorization"
    case planGeneration = "plan_generation"
    case planSummary = "plan_summary"
    case commitmentHold = "commitment_hold"
    case commitmentSuccess = "commitment_success"

    // Phase 7 — Plans, paywall, purchase & exit offer (48–52)
    case planOverview = "plan_overview"
    case primaryPaywall = "primary_paywall"
    case purchaseProcessing = "purchase_processing"
    case subscriptionSuccess = "subscription_success"
    case exitDiscountPaywall = "exit_discount_paywall"

    // Branch & recovery states (B01–B07). B08 (resume) is behavior, not a screen.
    case screenTimeDenied = "screen_time_denied"       // B01
    case noAppsSelected = "no_apps_selected"           // B02
    case notificationsDenied = "notifications_denied"  // B03
    case purchasePending = "purchase_pending"          // B04
    case purchaseFailed = "purchase_failed"            // B05
    case restorePurchases = "restore_purchases"        // B06
    case interruptedSetup = "interrupted_setup"        // B07

    /// The 52 main screens in happy-path order. Branch states are excluded so the
    /// funnel and progress fraction stay deterministic (one path length).
    static let linearFlow: [OnboardingStep] = [
        .launchReset, .limitsTruth, .coachPromise, .preferredName, .coachingContract,
        .primaryGoal, .goalReflection, .dailyScrollEstimate, .estimateReflection,
        .primaryConsequence, .consequenceReflection, .vulnerableTime, .previousAttempt,
        .failedSolutionReflection, .engineeredEnvironment,
        .interactiveDayLoss, .annualCost, .oneYearGrid, .tenYearProjection,
        .agencyReversal, .reclaimTarget,
        .screenTimeBridge, .screenTimePrivacy, .screenTimeNativeAuthorization,
        .screenTimeAuthorized, .appSelectionPrimer, .familyActivityPicker,
        .selectedAppsSummary, .protectionTiming, .appsLockDemo,
        .mechanismOverview, .verificationMethods, .starterHabitSelection, .rewardPreview,
        .mechanismDemoAction, .mechanismDemoVerify, .mechanismDemoReward,
        .mechanismDemoUnlock, .mechanismDemoRelock, .dailyCommitment,
        .reminderStrategy, .notificationPrimer, .notificationNativeAuthorization,
        .planGeneration, .planSummary, .commitmentHold, .commitmentSuccess,
        .planOverview, .primaryPaywall, .purchaseProcessing, .subscriptionSuccess,
        .exitDiscountPaywall
    ]

    /// Position within the 52-screen linear flow, or nil for branch states.
    var flowIndex: Int? { OnboardingStep.linearFlow.firstIndex(of: self) }

    /// 1-based screen number (01–52) for the main flow; nil for branches.
    var screenNumber: Int? { flowIndex.map { $0 + 1 } }

    var phase: OnboardingPhase {
        switch self {
        case .launchReset, .limitsTruth, .coachPromise, .preferredName, .coachingContract:
            return .premiumReset
        case .primaryGoal, .goalReflection, .dailyScrollEstimate, .estimateReflection,
             .primaryConsequence, .consequenceReflection, .vulnerableTime, .previousAttempt,
             .failedSolutionReflection, .engineeredEnvironment:
            return .diagnosis
        case .interactiveDayLoss, .annualCost, .oneYearGrid, .tenYearProjection,
             .agencyReversal, .reclaimTarget:
            return .timeCost
        case .screenTimeBridge, .screenTimePrivacy, .screenTimeNativeAuthorization,
             .screenTimeAuthorized, .appSelectionPrimer, .familyActivityPicker,
             .selectedAppsSummary, .protectionTiming, .appsLockDemo,
             .screenTimeDenied, .noAppsSelected:
            return .screenTimeSetup
        case .mechanismOverview, .verificationMethods, .starterHabitSelection, .rewardPreview,
             .mechanismDemoAction, .mechanismDemoVerify, .mechanismDemoReward,
             .mechanismDemoUnlock, .mechanismDemoRelock, .dailyCommitment:
            return .mechanism
        case .reminderStrategy, .notificationPrimer, .notificationNativeAuthorization,
             .planGeneration, .planSummary, .commitmentHold, .commitmentSuccess,
             .notificationsDenied, .interruptedSetup:
            return .commitment
        case .planOverview, .primaryPaywall, .purchaseProcessing, .subscriptionSuccess,
             .exitDiscountPaywall, .purchasePending, .purchaseFailed, .restorePurchases:
            return .paywall
        }
    }

    var screenClass: OnboardingScreenClass {
        switch self {
        case .preferredName, .primaryGoal, .dailyScrollEstimate, .primaryConsequence,
             .vulnerableTime, .previousAttempt, .starterHabitSelection, .protectionTiming,
             .dailyCommitment, .reminderStrategy:
            return .input
        case .interactiveDayLoss, .reclaimTarget, .commitmentHold:
            return .interactive
        case .screenTimeNativeAuthorization, .familyActivityPicker,
             .notificationNativeAuthorization, .purchaseProcessing:
            return .system
        case .subscriptionSuccess:
            return .terminal
        case .screenTimeDenied, .noAppsSelected, .notificationsDenied, .purchasePending,
             .purchaseFailed, .restorePurchases, .interruptedSetup:
            return .recovery
        default:
            return .informational
        }
    }

    /// Whether the thin progress bar shows. Shown across the question/form stretch
    /// (diagnosis + setup selects); hidden on immersive, permission, and paywall
    /// beats where a progress bar cheapens the moment (Tokens §12).
    var showsProgress: Bool {
        switch phase {
        case .diagnosis:
            return true
        case .mechanism:
            return self == .starterHabitSelection || self == .rewardPreview || self == .dailyCommitment
        case .commitment:
            return self == .reminderStrategy
        default:
            return false
        }
    }

    /// One-way doors and OS hand-offs cannot be reversed with the back control.
    /// (For `commitmentHold`, back is allowed before the hold completes; the
    /// coordinator enforces the post-hold lock.)
    var allowsBack: Bool {
        switch self {
        case .launchReset,
             .screenTimeNativeAuthorization, .familyActivityPicker,
             .notificationNativeAuthorization,
             .planGeneration, .commitmentSuccess,
             .primaryPaywall, .purchaseProcessing, .subscriptionSuccess,
             .exitDiscountPaywall:
            return false
        default:
            return true
        }
    }

    /// The surface that owns the visible UI: Aura-rendered vs OS UI.
    var isSystemSurface: Bool { screenClass == .system }
}
