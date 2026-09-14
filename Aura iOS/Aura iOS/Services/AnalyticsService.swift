//
//  AnalyticsService.swift
//  Aura iOS
//
//  Provider-agnostic analytics seam + the onboarding event taxonomy. The protocol
//  is tiny (log name + string props); `OnboardingAnalytics` is the typed facade
//  that assembles the master-prompt taxonomy and *structurally* prevents sensitive
//  payloads (there is no code path that accepts app tokens, photos, or health
//  samples). Answer events carry enumerated option ids, never free-text copy.
//

import Foundation

// MARK: - Transport

protocol AnalyticsService: AnyObject {
    func log(event name: String, properties: [String: String])
}

final class NoopAnalyticsService: AnalyticsService {
    static let shared = NoopAnalyticsService()
    private init() {}

    func log(event name: String, properties: [String: String]) {}
}

final class PostHogAnalyticsService: AnalyticsService {
    static let shared = PostHogAnalyticsService()
    private init() {}

    func log(event name: String, properties: [String: String] = [:]) {
        #if canImport(PostHog)
        PostHogSDK.shared.capture(name, properties: properties)
        #endif
    }
}

// MARK: - Entry source

/// How a screen was entered — attached to every screen-view event.
enum OnboardingEntrySource: String {
    case new, resume, back, retry
}

// MARK: - Typed facade

/// Assembles the onboarding event taxonomy with consistent base properties
/// (version, screen_id, position, phase, entry source, variant). This is the only
/// thing screens/coordinator call; it owns what may and may not be sent.
struct OnboardingAnalytics {
    private let service: AnalyticsService
    private let version: Int
    private let experimentVariant: String?

    init(service: AnalyticsService,
         version: Int = OnboardingDraft.currentVersion,
         experimentVariant: String? = nil) {
        self.service = service
        self.version = version
        self.experimentVariant = experimentVariant
    }

    private func base(for step: OnboardingStep, entry: OnboardingEntrySource) -> [String: String] {
        var props: [String: String] = [
            "onboarding_version": String(version),
            "screen_id": step.rawValue,
            "position": String(step.flowIndex ?? -1),
            "phase": String(step.phase.rawValue),
            "entry_source": entry.rawValue
        ]
        if let v = experimentVariant { props["variant"] = v }
        return props
    }

    // Lifecycle
    func started() { service.log(event: "onboarding_started", properties: ["onboarding_version": String(version)]) }
    func resumed(at step: OnboardingStep) {
        service.log(event: "onboarding_resumed", properties: base(for: step, entry: .resume))
    }
    func screenViewed(_ step: OnboardingStep, entry: OnboardingEntrySource) {
        service.log(event: "onboarding_screen_viewed", properties: base(for: step, entry: entry))
    }
    func backTapped(from: OnboardingStep, to: OnboardingStep) {
        service.log(event: "onboarding_back_tapped", properties: [
            "onboarding_version": String(version),
            "from": from.rawValue,
            "to": to.rawValue
        ])
    }
    func completed(totalMs: Int, purchased: Bool, degraded: Bool) {
        service.log(event: "onboarding_completed", properties: [
            "onboarding_version": String(version),
            "total_ms": String(totalMs),
            "purchased": String(purchased),
            "degraded": String(degraded)
        ])
    }

    // Answers — enumerated option id(s) only, never copy
    func answerSelected(_ step: OnboardingStep, optionIDs: [String]) {
        service.log(event: "onboarding_answer_selected", properties: [
            "onboarding_version": String(version),
            "screen_id": step.rawValue,
            "options": optionIDs.joined(separator: ",")
        ])
    }

    // Permissions
    func permissionPrepViewed(_ type: String) {
        service.log(event: "onboarding_permission_prep_viewed", properties: ["type": type])
    }
    func permissionResult(_ type: String, status: PermissionStatus) {
        service.log(event: "onboarding_permission_result", properties: ["type": type, "status": status.rawValue])
    }

    // App selection — counts only, never tokens/app names
    func appPickerOpened() { service.log(event: "onboarding_app_picker_opened", properties: [:]) }
    func appSelectionCompleted(appCount: Int, categoryCount: Int) {
        service.log(event: "onboarding_app_selection_completed", properties: [
            "app_count": String(appCount), "category_count": String(categoryCount)
        ])
    }

    // Habits / plan / commitment
    func habitsSelected(count: Int) {
        service.log(event: "onboarding_habits_selected", properties: ["count": String(count)])
    }
    func planGenerated() { service.log(event: "onboarding_plan_generated", properties: [:]) }
    func commitmentCompleted() { service.log(event: "onboarding_commitment_completed", properties: [:]) }

    // Paywall / purchase / restore
    func paywallViewed(_ step: OnboardingStep) {
        service.log(event: "onboarding_paywall_viewed", properties: ["screen_id": step.rawValue])
    }
    func planSelected(_ plan: SelectedPlan) {
        service.log(event: "onboarding_plan_selected", properties: ["plan": plan.rawValue])
    }
    func exitOfferViewed() { service.log(event: "onboarding_exit_offer_viewed", properties: [:]) }
    func purchaseStarted(_ plan: SelectedPlan) {
        service.log(event: "onboarding_purchase_started", properties: ["plan": plan.rawValue])
    }
    func purchaseCompleted(_ plan: SelectedPlan) {
        service.log(event: "onboarding_purchase_completed", properties: ["plan": plan.rawValue])
    }
    func purchaseFailed(_ plan: SelectedPlan, reason: String) {
        service.log(event: "onboarding_purchase_failed", properties: ["plan": plan.rawValue, "reason": reason])
    }
    func restoreStarted() { service.log(event: "onboarding_restore_started", properties: [:]) }
    func restoreResult(_ outcome: PurchaseOutcome) {
        service.log(event: "onboarding_restore_result", properties: ["outcome": outcome.rawValue])
    }
}

// MARK: - Live native onboarding flow

struct NativeOnboardingAnalytics {
    private let service: AnalyticsService
    private let version: Int
    private let experimentVariant: String?

    init(service: AnalyticsService = PostHogAnalyticsService.shared,
         version: Int = OnboardingDraft.currentVersion,
         experimentVariant: String? = nil) {
        self.service = service
        self.version = version
        self.experimentVariant = experimentVariant
    }

    private func base(for step: OnboardingFlow.Step, entry: OnboardingEntrySource) -> [String: String] {
        var props: [String: String] = [
            "onboarding_version": String(version),
            "screen_id": step.analyticsID,
            "position": String(step.rawValue),
            "phase": step.analyticsPhase,
            "entry_source": entry.rawValue
        ]
        if let experimentVariant { props["variant"] = experimentVariant }
        return props
    }

    func started() {
        service.log(event: "onboarding_started", properties: ["onboarding_version": String(version)])
    }

    func screenViewed(_ step: OnboardingFlow.Step, entry: OnboardingEntrySource) {
        service.log(event: "onboarding_screen_viewed", properties: base(for: step, entry: entry))
    }

    func backTapped(from: OnboardingFlow.Step, to: OnboardingFlow.Step) {
        service.log(event: "onboarding_back_tapped", properties: [
            "onboarding_version": String(version),
            "from": from.analyticsID,
            "to": to.analyticsID
        ])
    }

    func completed(totalMs: Int, purchased: Bool = false, degraded: Bool = false) {
        service.log(event: "onboarding_completed", properties: [
            "onboarding_version": String(version),
            "total_ms": String(totalMs),
            "purchased": String(purchased),
            "degraded": String(degraded)
        ])
    }

    func answerSelected(_ step: OnboardingFlow.Step, value: String) {
        service.log(event: "onboarding_answer_selected", properties: [
            "onboarding_version": String(version),
            "screen_id": step.analyticsID,
            "answer": value.analyticsSafeValue
        ])
    }

    func answerSelected(_ step: OnboardingFlow.Step, values: Set<String>) {
        service.log(event: "onboarding_answer_selected", properties: [
            "onboarding_version": String(version),
            "screen_id": step.analyticsID,
            "answers": values.map(\.analyticsSafeValue).sorted().joined(separator: ",")
        ])
    }

    func planGenerated() {
        service.log(event: "onboarding_plan_generated", properties: ["onboarding_version": String(version)])
    }

    func commitmentCompleted() {
        service.log(event: "onboarding_commitment_completed", properties: ["onboarding_version": String(version)])
    }
}

struct PaywallAnalytics {
    private let service: AnalyticsService

    init(service: AnalyticsService = PostHogAnalyticsService.shared) {
        self.service = service
    }

    func gateViewed(source: String) {
        service.log(event: "paywall_gate_viewed", properties: ["source": source])
    }

    func paywallPresented(placement: String) {
        service.log(event: "paywall_presented", properties: ["placement": placement])
    }

    func purchaseStarted(productID: String) {
        service.log(event: "paywall_purchase_started", properties: ["product_id": productID])
    }

    func purchaseResult(_ outcome: PurchaseOutcome, productID: String) {
        service.log(event: "paywall_purchase_result", properties: [
            "outcome": outcome.rawValue,
            "product_id": productID
        ])
    }

    func restoreStarted(source: String) {
        service.log(event: "paywall_restore_started", properties: ["source": source])
    }

    func restoreResult(_ outcome: PurchaseOutcome, source: String) {
        service.log(event: "paywall_restore_result", properties: [
            "outcome": outcome.rawValue,
            "source": source
        ])
    }
}

private extension String {
    var analyticsSafeValue: String {
        lowercased()
            .replacingOccurrences(of: " / ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "+", with: "plus")
    }
}

extension OnboardingFlow.Step {
    var analyticsID: String { String(describing: self).analyticsSafeValue }

    var analyticsPhase: String {
        switch self {
        case .welcome, .meet, .name, .age, .handoff, .chat, .loopDemo:
            return "intro_diagnosis"
        case .demoFreeze, .demoEarn, .demoSpend, .reframe, .bridge:
            return "mechanism"
        case .qGoal, .qSlider, .qFeelings, .qPersona, .qWorstTime, .qDoomProfile,
             .qSkip, .qReviewDrop, .qTried, .qWhyFlopped, .qReclaim:
            return "questions"
        case .qHabits, .qExercises, .qDailyGoal:
            return "habit_setup"
        case .qLoading, .qCustomPlan, .qScience, .qReviews, .qCommit:
            return "plan_commitment"
        }
    }
}

#if canImport(PostHog)
import PostHog
#endif
