//
//  HealthService.swift
//  Aura iOS
//

import Foundation
import HealthKit

/// The five things Aura reads out of Apple Health, and what each one is worth.
///
/// One case per metric rather than five hand-rolled queries: the name, the
/// HealthKit type, the unit, the rate and the label all travel together, so a
/// metric can't end up reading steps and priced as kilometres.
enum HealthMetricKind: String, CaseIterable, Identifiable {
    case distance
    case exerciseMinutes
    case mindfulMinutes
    case steps
    case activeEnergy

    var id: String { rawValue }

    var name: String {
        switch self {
        case .distance: "Run / Walk"
        case .exerciseMinutes: "Exercise Minutes"
        case .mindfulMinutes: "Mindful Minutes"
        case .steps: "Steps"
        case .activeEnergy: "Calories Burned"
        }
    }

    var iconSystemName: String {
        switch self {
        case .distance: "figure.run"
        case .exerciseMinutes: "figure.strengthtraining.traditional"
        case .mindfulMinutes: "figure.mind.and.body"
        case .steps: "shoeprints.fill"
        case .activeEnergy: "flame.fill"
        }
    }

    var iconAsset: String {
        switch self {
        case .distance: "FoxRunWalk"
        case .exerciseMinutes: "FoxExerciseMinutes"
        case .mindfulMinutes: "FoxMindfulMinutes"
        case .steps: "FoxSteps"
        case .activeEnergy: "FoxCaloriesBurned"
        }
    }

    /// What HealthKit is asked for.
    ///
    /// Mindful minutes is a *category* sample, not a quantity — you can't sum it
    /// with a statistics query, so it's the one case handled separately below.
    var quantityType: HKQuantityType? {
        switch self {
        case .distance: HKQuantityType(.distanceWalkingRunning)
        case .exerciseMinutes: HKQuantityType(.appleExerciseTime)
        case .steps: HKQuantityType(.stepCount)
        case .activeEnergy: HKQuantityType(.activeEnergyBurned)
        case .mindfulMinutes: nil
        }
    }

    var sampleType: HKSampleType {
        quantityType ?? HKCategoryType(.mindfulSession)
    }

    var unit: HKUnit {
        switch self {
        case .distance: .meterUnit(with: .kilo)
        case .exerciseMinutes, .mindfulMinutes: .minute()
        case .steps: .count()
        case .activeEnergy: .kilocalorie()
        }
    }

    /// Coins per unit of this metric. Deliberately stingy on the passive ones:
    /// steps accrue whether or not you meant them to, so they can't pay like a
    /// deliberate workout does.
    var coinsPerUnit: Double {
        switch self {
        case .distance: 8            // per km
        case .exerciseMinutes: 1     // per active minute
        case .mindfulMinutes: 1      // per mindful minute
        case .steps: 0.003           // 3 per 1,000
        case .activeEnergy: 0.06     // 6 per 100 kcal
        }
    }

    var rateLabel: String {
        switch self {
        case .distance: "8 min / km"
        case .exerciseMinutes: "1 min / active min"
        case .mindfulMinutes: "1 min / mindful min"
        case .steps: "3 min / 1k steps"
        case .activeEnergy: "6 min / 100 kcal"
        }
    }

    /// The short label under the Passive Income success tile.
    var tileLabel: String {
        switch self {
        case .distance: "Distance"
        case .exerciseMinutes: "Exercise"
        case .mindfulMinutes: "Mindful"
        case .steps: "Steps"
        case .activeEnergy: "Calories"
        }
    }

    /// The big number on that tile — the raw amount with its unit where one
    /// helps (minutes, km), bare where it doesn't (steps, calories).
    func tileValue(_ amount: Double) -> String {
        switch self {
        case .distance: String(format: "%.1fkm", amount)
        case .exerciseMinutes, .mindfulMinutes: "\(Int(amount))m"
        case .steps: Int(amount).formatted(.number.grouping(.automatic))
        case .activeEnergy: "\(Int(amount))"
        }
    }

    /// How today's total reads on the row.
    func amountLabel(_ amount: Double) -> String {
        switch self {
        case .distance: String(format: "%.1f km today", amount)
        case .exerciseMinutes: "\(Int(amount)) min today"
        case .mindfulMinutes: "\(Int(amount)) min today"
        case .steps: "\(Int(amount).formatted(.number.grouping(.automatic))) steps today"
        case .activeEnergy: "\(Int(amount)) kcal today"
        }
    }
}

/// Reads today's activity out of Apple Health.
///
/// Read-only — Aura never writes to Health. That also means the app can't ask
/// whether it was granted permission: Apple deliberately reports read access as
/// "not determined" forever, so an app can't infer a health condition from a
/// refusal. `authorizationStatus` only ever describes *writing*.
///
/// The consequence shapes the UI: a denied permission and a day with no
/// recorded activity are indistinguishable, so both have to land on the same
/// honest state — "no activity yet" — rather than an error the user can't act
/// on.
@MainActor
final class HealthService {
    static let shared = HealthService()

    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var readTypes: Set<HKObjectType> {
        Set(HealthMetricKind.allCases.map(\.sampleType))
    }

    /// Shows Apple's sheet. Returns whether the sheet completed, NOT whether
    /// anything was granted — that answer doesn't exist for read access.
    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            return true
        } catch {
            return false
        }
    }

    /// Today's total for every metric, midnight to now.
    func todayTotals() async -> [HealthMetricKind: Double] {
        guard isAvailable else { return [:] }
        var totals: [HealthMetricKind: Double] = [:]
        for kind in HealthMetricKind.allCases {
            totals[kind] = await total(for: kind)
        }
        return totals
    }

    /// Samples Aura will pay for: today's, and not typed in by hand.
    ///
    /// The second half is the important one. Health lets anyone add a sample
    /// manually — open Health, tap Steps, Add Data, type 50,000 — and a query
    /// that only filters on date counts it, which turned Passive Income into a
    /// number you could type. Everything here is meant to be earned by having
    /// done something, so a hand-typed sample is worth nothing.
    ///
    /// `HKMetadataKeyWasUserEntered` is set by Health itself on anything added
    /// through its UI. Devices and apps that record activity don't set it, so
    /// this costs a legitimate user nothing.
    private static func earnedTodayPredicate() -> NSPredicate {
        let start = Calendar.current.startOfDay(for: .now)
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForSamples(withStart: start, end: .now),
            NSCompoundPredicate(notPredicateWithSubpredicate:
                HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeyWasUserEntered,
                                            operatorType: .equalTo,
                                            value: true))
        ])
    }

    private func total(for kind: HealthMetricKind) async -> Double {
        let predicate = Self.earnedTodayPredicate()

        if let quantityType = kind.quantityType {
            return await withCheckedContinuation { continuation in
                let query = HKStatisticsQuery(
                    quantityType: quantityType,
                    quantitySamplePredicate: predicate,
                    options: .cumulativeSum
                ) { _, statistics, _ in
                    let sum = statistics?.sumQuantity()?.doubleValue(for: kind.unit) ?? 0
                    continuation.resume(returning: sum)
                }
                store.execute(query)
            }
        }

        // Mindful sessions are category samples with no value to sum — the
        // number Aura wants is how long each one lasted, added up by hand.
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKCategoryType(.mindfulSession),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                let minutes = (samples ?? []).reduce(0.0) {
                    $0 + $1.endDate.timeIntervalSince($1.startDate) / 60
                }
                continuation.resume(returning: minutes)
            }
            store.execute(query)
        }
    }
}
