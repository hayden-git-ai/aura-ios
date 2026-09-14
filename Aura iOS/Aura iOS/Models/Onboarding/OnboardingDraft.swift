//
//  OnboardingDraft.swift
//  Aura iOS
//
//  The durable onboarding record. Written transactionally on every material
//  answer alongside `lastStepReached`, so the flow resumes cleanly across
//  termination. Struct + Codable to match house style (Habit/AuraState), ready
//  for a future `@Model` swap behind PersistenceService.
//
//  Privacy: `blockedSelectionToken` holds the opaque, service-encoded
//  FamilyActivitySelection — never readable app names. Analytics must never see
//  this, raw photos, or health samples.
//

import Foundation

struct OnboardingDraft: Codable, Hashable {

    /// Bump when the flow's shape changes in a way that should re-run onboarding
    /// (with still-valid answers prefilled), per the State Machine's version
    /// migration rule.
    static let currentVersion = 1

    // Meta / resume
    var onboardingVersion: Int = OnboardingDraft.currentVersion
    var startedAt: Date?
    var completedAt: Date?
    var lastStepReached: OnboardingStep = .launchReset
    /// Idempotent cursor for the plan-generation step (Screen 44 / OB-35).
    var planStepCursor: Int = 0

    // Phase 1 — identity
    var preferredName: String?
    var prefersNoName: Bool = false

    // Phase 2 — diagnosis
    var goal: PrimaryGoal?
    var estimate: ScreenTimeEstimate?
    var consequence: PrimaryConsequence?
    var vulnerableTime: VulnerableTime?
    var previousAttempts: Set<PreviousAttempt> = []

    // Phase 3 — time cost
    /// Slider value from Screen 16 (defaults to the estimate midpoint).
    var dayLossHours: Double?
    /// Screen 21 — minutes/day the user commits to reclaiming.
    var targetReductionMinutes: Int?

    // Phase 4 — Screen Time + app selection
    var screenTimeAuth: PermissionStatus = .notDetermined
    /// Opaque, service-encoded FamilyActivitySelection. Never decoded for analytics.
    var blockedSelectionToken: Data?
    var blockedAppCount: Int = 0
    var blockedCategoryCount: Int = 0
    var protectionTiming: ProtectionTiming?
    /// "Do it later" degraded mode — completed but Screen Time not yet granted.
    var degradedScreenTime: Bool = false

    // Phase 5 — mechanism + habits
    var earningMethods: Set<EarningMethod> = []
    var starterHabitIDs: [String] = []
    var dailyCommitment: DailyCommitment?

    // Part 2 — post-scroll feelings
    var postScrollFeelings: Set<PostScrollFeeling> = []

    // Phase 6 — reminders + notifications
    var notificationAuth: PermissionStatus = .notDetermined
    var reminderChoice: ReminderChoice?

    // Phase 7 — subscription
    var selectedPlan: SelectedPlan = .annual
    var subscriptionStatus: SubscriptionStatus = SubscriptionStatus.none
    var exitOfferShown: Bool = false

    // MARK: - Derived

    /// Name to use in copy, or nil if the user preferred not to say.
    var displayName: String? {
        guard !prefersNoName else { return nil }
        let trimmed = preferredName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty == false) ? trimmed : nil
    }

    /// Hours/day used for projections: the slider value if set, else the estimate
    /// midpoint. Nil when the user chose "I'm not sure" and hasn't dragged.
    var resolvedDailyHours: Double? {
        dayLossHours ?? estimate?.midpointHours
    }

    var isComplete: Bool { completedAt != nil }

    /// Whether onboarding was completed under the *current* flow version.
    var isCurrentVersion: Bool { onboardingVersion == OnboardingDraft.currentVersion }
}
