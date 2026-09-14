//
//  AppConfig.swift
//  Aura iOS
//
//  The single handoff contract from onboarding to the running app. Derived from a
//  completed OnboardingDraft and consumed once by `HabitStore` on the first
//  post-onboarding launch, so the app boots in the user's configured state
//  instead of the seeded sample state. (Applied via HabitStore+AppConfig.)
//

import Foundation

struct AppConfig: Codable, Hashable {
    var displayName: String?
    var starterHabitIDs: [String]
    var earningMethods: [EarningMethod]
    var protectionTiming: ProtectionTiming?
    var blockedAppCount: Int
    var blockedCategoryCount: Int
    var dailyCommitment: DailyCommitment?
    var targetReductionMinutes: Int?
    var subscriptionStatus: SubscriptionStatus
    /// True when the user completed onboarding without granting Screen Time.
    var screenTimeDegraded: Bool

    init(
        displayName: String? = nil,
        starterHabitIDs: [String] = [],
        earningMethods: [EarningMethod] = [],
        protectionTiming: ProtectionTiming? = nil,
        blockedAppCount: Int = 0,
        blockedCategoryCount: Int = 0,
        dailyCommitment: DailyCommitment? = nil,
        targetReductionMinutes: Int? = nil,
        subscriptionStatus: SubscriptionStatus = SubscriptionStatus.none,
        screenTimeDegraded: Bool = false
    ) {
        self.displayName = displayName
        self.starterHabitIDs = starterHabitIDs
        self.earningMethods = earningMethods
        self.protectionTiming = protectionTiming
        self.blockedAppCount = blockedAppCount
        self.blockedCategoryCount = blockedCategoryCount
        self.dailyCommitment = dailyCommitment
        self.targetReductionMinutes = targetReductionMinutes
        self.subscriptionStatus = subscriptionStatus
        self.screenTimeDegraded = screenTimeDegraded
    }

    /// Derives the runtime config from a completed draft.
    init(from draft: OnboardingDraft) {
        self.init(
            displayName: draft.displayName,
            starterHabitIDs: draft.starterHabitIDs,
            earningMethods: Array(draft.earningMethods),
            protectionTiming: draft.protectionTiming,
            blockedAppCount: draft.blockedAppCount,
            blockedCategoryCount: draft.blockedCategoryCount,
            dailyCommitment: draft.dailyCommitment,
            targetReductionMinutes: draft.targetReductionMinutes,
            subscriptionStatus: draft.subscriptionStatus,
            screenTimeDegraded: draft.degradedScreenTime
        )
    }
}
