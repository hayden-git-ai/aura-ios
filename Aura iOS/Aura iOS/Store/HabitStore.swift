//
//  HabitStore.swift
//  Aura iOS
//

import Foundation
import Observation
import UIKit
import UserNotifications

/// The single shared source of truth for habit/reward/streak/unlock state.
/// Every screen reads from this one instance via `@Environment(HabitStore.self)`
/// — never construct a second instance, and never let a screen hold its own
/// copy of a habit's reward text (see the picker/Earn-Settings desync bug
/// this store exists specifically to prevent).
///
/// In-memory for now, on purpose — the habit/reward model is still evolving
/// and SwiftData migrations would fight that churn. When persistence is
/// ready, this file's internals swap to read/write through a `ModelContext`;
/// no other file should need to change.
@Observable
final class HabitStore {

    /// The starting set. Once `habits.json` exists it wins — see `init`.
    private static let defaultHabits: [Habit] = [
        // MARK: Photo Proof — snap proof, AI verifies (a focus session earns the
        // coins for most; a few are one-shot photo-only).
        //
        // Rates are on one ladder, by what it costs to sustain the thing for an
        // hour: 20 for concentration or skill, 15 for real effort, 10 for light
        // and pleasant, 5 for something you'd happily do anyway. Quick habits
        // pay a flat 3 / 5 / 7 by how much they actually take, which keeps a
        // single photo from being worth an hour of work.
        Habit(name: "Read", category: .photoTask, emoji: "📚", iconSystemName: "book.fill", iconAsset: "FoxHabitRead",
              requiresFocusSession: true, defaultFocusMinutes: 30, rewardRate: 15, tag: .focus,
              proofHint: "Book in frame and readable. Open, closed, or e-reader, they all count."),
        Habit(name: "Hit the gym", category: .photoTask, emoji: "💪", iconSystemName: "dumbbell.fill", iconAsset: "FoxHabitGym",
              requiresFocusSession: true, defaultFocusMinutes: 40, rewardRate: 15, tag: .exercise,
              proofHint: "Point it at whatever you're about to lift. The treadmill counts too."),
        Habit(name: "Deep Work", category: .photoTask, emoji: "🔒", iconSystemName: "brain.head.profile", iconAsset: "FoxHabitDeepWork",
              requiresFocusSession: true, defaultFocusMinutes: 40, rewardRate: 20, tag: .focus,
              proofHint: "Show the work or the setup. Screen, desk, or notebook."),
        Habit(name: "Study", category: .photoTask, emoji: "🎓", iconSystemName: "graduationcap.fill", iconAsset: "FoxHabitStudy",
              requiresFocusSession: true, defaultFocusMinutes: 40, rewardRate: 20, tag: .focus,
              proofHint: "Notes, textbook, flashcards. Show what you're grinding through."),
        Habit(name: "Side Hustle", category: .photoTask, emoji: "📈", iconSystemName: "chart.line.uptrend.xyaxis", iconAsset: "FoxHabitWorkOnBusiness",
              requiresFocusSession: true, defaultFocusMinutes: 40, rewardRate: 20, tag: .focus,
              proofHint: "Show what you're building. The screen, the project, the orders."),
        Habit(name: "Play an instrument", category: .photoTask, emoji: "🎸", iconSystemName: "guitars.fill", iconAsset: "FoxHabitPracticeInstrument",
              requiresFocusSession: true, defaultFocusMinutes: 30, rewardRate: 20, tag: .creative,
              proofHint: "Instrument in frame and ready. Tuning counts as starting."),
        Habit(name: "Hang out with someone", category: .photoTask, emoji: "👋", iconSystemName: "bubble.left.and.bubble.right.fill", iconAsset: "FoxHabitSocialize",
              requiresFocusSession: true, defaultFocusMinutes: 60, rewardRate: 5, tag: .social,
              proofHint: "Selfie with the crew, or a shot of wherever you're hanging out."),
        Habit(name: "Go for a walk", category: .photoTask, emoji: "🚶", iconSystemName: "figure.walk", iconAsset: "FoxHabitWalk",
              requiresFocusSession: true, defaultFocusMinutes: 30, rewardRate: 10, tag: .exercise,
              proofHint: "Point it at the path ahead. Fresh air only, hallways don't count."),
        Habit(name: "Go for a run", category: .photoTask, emoji: "🏃", iconSystemName: "figure.run", iconAsset: "FoxHabitRun",
              requiresFocusSession: true, defaultFocusMinutes: 40, rewardRate: 15, tag: .exercise,
              proofHint: "Show the road, trail, or track before you take off."),
        Habit(name: "Meditate", category: .photoTask, emoji: "🧘", iconSystemName: "figure.mind.and.body", iconAsset: "FoxHabitMeditate",
              requiresFocusSession: true, defaultFocusMinutes: 20, rewardRate: 10, tag: .focus,
              proofHint: "Show your spot, set up and quiet. Cushion, corner, or floor all work."),
        Habit(name: "Write in your journal", category: .photoTask, emoji: "📝", iconSystemName: "pencil.and.scribble", iconAsset: "FoxHabitJournal",
              requiresFocusSession: true, defaultFocusMinutes: 20, rewardRate: 10, tag: .focus,
              proofHint: "Journal open, pen in frame. Today's page is all I need."),
        Habit(name: "Do some yoga", category: .photoTask, emoji: "🧘‍♀️", iconSystemName: "figure.yoga",
              iconAsset: "FoxHabitYoga",
              requiresFocusSession: true, defaultFocusMinutes: 30, rewardRate: 15, tag: .exercise,
              proofHint: "Mat down, phone propped, you in frame before the first pose."),
        Habit(name: "Do some gardening", category: .photoTask, emoji: "🪴", iconSystemName: "leaf.fill",
              iconAsset: "FoxHabitGardening",
              requiresFocusSession: true, defaultFocusMinutes: 30, rewardRate: 10, tag: .home,
              proofHint: "Show the plot, the pots, or whatever you're about to fuss over."),

        // Quick Habits — one photo, paid instantly.
        Habit(name: "Smile", category: .photoTask, emoji: "😊", iconSystemName: "face.smiling",
              iconAsset: "FoxHabitSmile",
              requiresFocusSession: false, rewardMinutes: 3, oncePerDay: true, tag: .social,
              proofHint: "Point the camera at your face and give me a real one."),
        Habit(name: "Touch grass", category: .photoTask, emoji: "🌱", iconSystemName: "leaf.fill", iconAsset: "FoxHabitTouchGrass",
              requiresFocusSession: false, rewardMinutes: 5, oncePerDay: true, tag: .health,
              proofHint: "Your hand on actual grass, in frame. I do mean literally."),
        Habit(name: "Eat a healthy meal", category: .photoTask, emoji: "🍎", iconSystemName: "fork.knife", iconAsset: "FoxHabitHealthyMeal",
              requiresFocusSession: false, rewardMinutes: 7, oncePerDay: true, tag: .health,
              proofHint: "Show the plate. I'm looking for real food, not the wrapper."),
        Habit(name: "Brush your teeth", category: .photoTask, emoji: "🪥", iconSystemName: "mouth.fill", iconAsset: "FoxHabitBrushTeeth",
              requiresFocusSession: false, rewardMinutes: 3, oncePerDay: true, tag: .health,
              proofHint: "Toothbrush in frame, paste on, before you start brushing."),
        Habit(name: "Make your bed", category: .photoTask, emoji: "🛏️", iconSystemName: "bed.double.fill", iconAsset: "FoxHabitMakeBed",
              requiresFocusSession: false, rewardMinutes: 5, oncePerDay: true, tag: .home,
              proofHint: "Show the bed, made and flat. Pillows count as effort."),
        Habit(name: "Clean your room", category: .photoTask, emoji: "🧹", iconSystemName: "sparkles", iconAsset: "FoxHabitCleanRoom",
              requiresFocusSession: false, rewardMinutes: 7, oncePerDay: true, tag: .home,
              proofHint: "Show the room once it's actually clear, floor included."),
        Habit(name: "Drink some water", category: .photoTask, emoji: "💧", iconSystemName: "drop.fill", iconAsset: "FoxHabitHydrate",
              requiresFocusSession: false, rewardMinutes: 3, oncePerDay: true, tag: .health,
              proofHint: "Glass or bottle in frame, filled and ready. Water only, sorry."),
        Habit(name: "Do your skincare", category: .photoTask, emoji: "🧴", iconSystemName: "sparkles", iconAsset: "FoxHabitSkincare",
              requiresFocusSession: false, rewardMinutes: 3, oncePerDay: true, tag: .health,
              proofHint: "Products lined up, or the routine mid-glow. Either works."),
        Habit(name: "Take your vitamins", category: .photoTask, emoji: "💊", iconSystemName: "pills.fill", iconAsset: "FoxHabitTakeVitamins",
              requiresFocusSession: false, rewardMinutes: 3, oncePerDay: true, tag: .health,
              proofHint: "Show the bottle or the handful you're about to take."),
    ]

    // MARK: - Account-owned local state

    private struct StoredFocusSession: Codable {
        let durationMinutes: Int
        let earnedMinutes: Int
        let date: Date
    }

    private struct AccountSnapshot: Codable {
        var firstSeenAt: Date
        var displayName: String
        var email: String
        var profileImageData: Data?
        var habits: [Habit]
        var dayRecords: [DayRecord]
        var favoriteHabitIDs: Set<UUID>
        var favoriteExerciseIDs: Set<String>
        var habitCompletionCounts: [String: Int]
        var exerciseCompletionCounts: [String: Int]
        var healthCollectCount: Int
        var healthCollectedToday: [String: Double]
        var healthCollectedDay: Date
        var lifetimeEarnedMinutes: Int
        var lifetimeHealthyHabits: Int
        var lifetimeReps: Int
        var lifetimeFocusMinutes: Int
        var baselineWeeklyScreenMinutes: Int?
        var dailyCoinGoal: Int
        var deepFocusSessions: [StoredFocusSession]
        var deepFocusRate: Double
        var exerciseGoals: [String: Int]
        var purchases: [Purchase]
        var wins: [Win]
        var runningTimers: RunningTimers
        var libraryUpdatedAt: Date
        var powerUpDate: Date?
        var claimedPowerUps: Set<Int>
    }

    enum AccountStorageOperation: Equatable {
        case readSnapshot
        case writeSnapshot
        case copyLegacy
        case move
        case delete
        case readPhoto
        case writePhoto
    }

    struct AccountDependencies {
        let rootURL: URL?
        let defaults: UserDefaults
        let currentUserID: () -> UUID?
        let deleteRemote: (UUID) async throws -> Void
        let shouldFail: (AccountStorageOperation) -> Bool

        static var live: AccountDependencies {
            let root = try? FileManager.default.url(
                for: .applicationSupportDirectory, in: .userDomainMask,
                appropriateFor: nil, create: true)
            return AccountDependencies(
                rootURL: root,
                defaults: .standard,
                currentUserID: { SupabaseManager.shared.currentUserID },
                deleteRemote: { try await SupabaseManager.shared.deleteAccount(expectedUserID: $0) },
                shouldFail: { _ in false })
        }
    }

    private static let accountStateDirectoryName = "AuraAccountState"
    private static let legacyQuarantineKey = "aura.account.legacy-quarantined.v1"
    private static let activeOwnerKey = "aura.account.active-owner.v1"
    private static let signedOutScope = "signed-out"

    private let accountDependencies: AccountDependencies
    private let runsRuntimeSideEffects: Bool
    private var activeAccountID: UUID?
    private var accountRevision: UInt = 0
    private var hasLoadedAccountScope = false
    private var isApplyingAccountSnapshot = false
    private(set) var accountPersistenceFailed = false
    private(set) var pendingAccountTransitionID: UUID?
    private var accountFirstSeenAt = Date()
    private var accountLibraryUpdatedAt = Date(timeIntervalSince1970: 0)
    private var powerUpDate: Date?
    private var claimedPowerUpThresholds: Set<Int> = []
    private var recoverySnapshots: [String: AccountSnapshot] = [:]
    private var recoveryWinPhotos: [String: [String: Data]] = [:]

    var accountPersistenceMessage: String? {
        accountPersistenceFailed
            ? "Aura couldn't safely save or load this account's local data. Your original cache was left untouched. Try again after freeing device storage."
            : nil
    }

    private enum SnapshotLoadResult {
        case missing
        case loaded(AccountSnapshot)
        case unreadable
    }

    private var accountScopeName: String {
        activeAccountID?.uuidString.lowercased() ?? Self.signedOutScope
    }

    private func scopeDirectory(_ scope: String) -> URL? {
        guard let root = accountDependencies.rootURL else { return nil }
        return root.appendingPathComponent(Self.accountStateDirectoryName, isDirectory: true)
            .appendingPathComponent(scope, isDirectory: true)
    }

    private func snapshotURL(_ scope: String) -> URL? {
        scopeDirectory(scope)?.appendingPathComponent("snapshot.json")
    }

    private func winsDirectory(_ scope: String) -> URL? {
        scopeDirectory(scope)?.appendingPathComponent("Wins", isDirectory: true)
    }

    private var activeWinsDirectory: URL? {
        accountDependencies.rootURL?.appendingPathComponent("Wins", isDirectory: true)
    }

    private static func snapshotDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private static func snapshotEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private func loadSnapshot(scope: String) -> SnapshotLoadResult {
        guard let url = snapshotURL(scope) else { return .unreadable }
        guard FileManager.default.fileExists(atPath: url.path) else { return .missing }
        if accountDependencies.shouldFail(.readSnapshot) { return .unreadable }
        do {
            return .loaded(try Self.snapshotDecoder().decode(
                AccountSnapshot.self, from: Data(contentsOf: url)))
        } catch {
            return .unreadable
        }
    }

    private static func newSnapshot() -> AccountSnapshot {
        #if DEBUG
        let focus = DeepFocusSession.samples
        #else
        let focus: [DeepFocusSession] = []
        #endif
        return AccountSnapshot(
            firstSeenAt: .now, displayName: "", email: "", profileImageData: nil,
            habits: defaultHabits, dayRecords: [], favoriteHabitIDs: [], favoriteExerciseIDs: [],
            habitCompletionCounts: [:], exerciseCompletionCounts: [:], healthCollectCount: 0,
            healthCollectedToday: [:], healthCollectedDay: Calendar.current.startOfDay(for: .now),
            lifetimeEarnedMinutes: 0, lifetimeHealthyHabits: 0, lifetimeReps: 0,
            lifetimeFocusMinutes: 0, baselineWeeklyScreenMinutes: nil, dailyCoinGoal: 100,
            deepFocusSessions: focus.map { .init(durationMinutes: $0.durationMinutes,
                                                  earnedMinutes: $0.earnedMinutes, date: $0.date) },
            deepFocusRate: 10, exerciseGoals: [:], purchases: [], wins: [],
            runningTimers: RunningTimers(), libraryUpdatedAt: Date(timeIntervalSince1970: 0),
            powerUpDate: nil, claimedPowerUps: [])
    }

    private func currentRunningTimers() -> RunningTimers {
        RunningTimers(unlockStartedAt: unlockStartedAt, unlockEndsAt: unlockEndsAt,
                      habit: activeHabitSession, habitMethod: sessionMethod, focus: activeFocusSession)
    }

    private func currentAccountSnapshot() -> AccountSnapshot {
        AccountSnapshot(
            firstSeenAt: accountFirstSeenAt, displayName: displayName, email: email,
            profileImageData: profileImageData, habits: habits, dayRecords: dayRecords,
            favoriteHabitIDs: favoriteHabitIds, favoriteExerciseIDs: favoriteExerciseIds,
            habitCompletionCounts: habitCompletionCounts,
            exerciseCompletionCounts: exerciseCompletionCounts,
            healthCollectCount: healthCollectCount, healthCollectedToday: healthCollectedToday,
            healthCollectedDay: healthCollectedDay, lifetimeEarnedMinutes: lifetimeEarnedMinutes,
            lifetimeHealthyHabits: lifetimeHealthyHabits, lifetimeReps: lifetimeReps,
            lifetimeFocusMinutes: lifetimeFocusMinutes,
            baselineWeeklyScreenMinutes: baselineWeeklyScreenMinutes, dailyCoinGoal: dailyCoinGoal,
            deepFocusSessions: deepFocusSessions.map { .init(durationMinutes: $0.durationMinutes,
                                                               earnedMinutes: $0.earnedMinutes, date: $0.date) },
            deepFocusRate: deepFocusRate, exerciseGoals: exerciseGoals, purchases: purchases,
            wins: wins, runningTimers: currentRunningTimers(),
            libraryUpdatedAt: accountLibraryUpdatedAt, powerUpDate: powerUpDate,
            claimedPowerUps: claimedPowerUpThresholds)
    }

    @discardableResult
    private func persistActiveAccount(includeWinPhotos: Bool = false) -> Bool {
        guard hasLoadedAccountScope, !isApplyingAccountSnapshot,
              let directory = scopeDirectory(accountScopeName),
              let url = snapshotURL(accountScopeName) else { return !hasLoadedAccountScope }
        let snapshot = currentAccountSnapshot()
        recoverySnapshots[accountScopeName] = snapshot
        do {
            if accountDependencies.shouldFail(.writeSnapshot) { throw CocoaError(.fileWriteUnknown) }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if includeWinPhotos { try archiveActiveWinPhotos(scope: accountScopeName) }
            let data = try Self.snapshotEncoder().encode(snapshot)
            try data.write(to: url, options: .atomic)
            accountDependencies.defaults.set(accountScopeName, forKey: Self.activeOwnerKey)
            accountPersistenceFailed = false
            return true
        } catch {
            recoveryWinPhotos[accountScopeName] = Dictionary(uniqueKeysWithValues: wins.compactMap { win in
                guard case .captured(let filename) = win.photo,
                      let url = activeWinsDirectory?.appendingPathComponent(filename),
                      let data = try? Data(contentsOf: url) else { return nil }
                return (filename, data)
            })
            accountPersistenceFailed = true
            return false
        }
    }

    private func archiveActiveWinPhotos(scope: String) throws {
        guard let directory = winsDirectory(scope) else { return }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let wanted = Set(wins.compactMap { win -> String? in
            if case .captured(let filename) = win.photo { return filename }
            return nil
        })
        for url in (try? FileManager.default.contentsOfDirectory(at: directory,
                                                                 includingPropertiesForKeys: nil)) ?? []
        where !wanted.contains(url.lastPathComponent) {
            try FileManager.default.removeItem(at: url)
        }
        for filename in wanted {
            guard let source = activeWinsDirectory?.appendingPathComponent(filename),
                  FileManager.default.fileExists(atPath: source.path) else { continue }
            let destination = directory.appendingPathComponent(filename)
            // Captured win filenames are immutable UUIDs. Existing scoped files
            // never need to be rewritten for an unrelated counter/name change.
            guard !FileManager.default.fileExists(atPath: destination.path) else { continue }
            if accountDependencies.shouldFail(.readPhoto) { throw CocoaError(.fileReadUnknown) }
            let data = try Data(contentsOf: source)
            if accountDependencies.shouldFail(.writePhoto) { throw CocoaError(.fileWriteUnknown) }
            try data.write(to: destination, options: .atomic)
        }
    }

    private func restoreWinPhotos(scope: String, replacing oldWins: [Win]) -> Bool {
        guard let root = accountDependencies.rootURL,
              let scoped = winsDirectory(scope) else { return false }
        let manager = FileManager.default
        let active = root.appendingPathComponent("Wins", isDirectory: true)
        let staging = root.appendingPathComponent("Wins-staging-\(UUID().uuidString)", isDirectory: true)
        let backup = root.appendingPathComponent("Wins-backup-\(UUID().uuidString)", isDirectory: true)
        do {
            try manager.createDirectory(at: staging, withIntermediateDirectories: true)
            for win in wins {
                guard case .captured(let filename) = win.photo else { continue }
                let destination = staging.appendingPathComponent(filename)
                if let recovered = recoveryWinPhotos[scope]?[filename] {
                    if accountDependencies.shouldFail(.writePhoto) { throw CocoaError(.fileWriteUnknown) }
                    try recovered.write(to: destination, options: .atomic)
                    continue
                }
                let source = scoped.appendingPathComponent(filename)
                // A remote-only photo may legitimately be absent and will be
                // downloaded by sync. If a referenced source exists, however,
                // inability to copy it must abort before the active set changes.
                if manager.fileExists(atPath: source.path) {
                    if accountDependencies.shouldFail(.readPhoto) { throw CocoaError(.fileReadUnknown) }
                    if accountDependencies.shouldFail(.writePhoto) { throw CocoaError(.fileWriteUnknown) }
                    try manager.copyItem(at: source, to: destination)
                }
            }
            if manager.fileExists(atPath: active.path) {
                try manager.moveItem(at: active, to: backup)
            }
            do {
                try manager.moveItem(at: staging, to: active)
            } catch {
                if manager.fileExists(atPath: backup.path) {
                    try? manager.moveItem(at: backup, to: active)
                }
                throw error
            }
            if manager.fileExists(atPath: backup.path) { try manager.removeItem(at: backup) }
            return true
        } catch {
            try? manager.removeItem(at: staging)
            return false
        }
    }

    @discardableResult
    private func quarantineLegacyStateIfNeeded() -> Bool {
        let defaults = accountDependencies.defaults
        if defaults.bool(forKey: Self.legacyQuarantineKey) { return true }
        let legacySnapshot = recoverySnapshots["legacy-unowned"] ?? currentAccountSnapshot()
        recoverySnapshots["legacy-unowned"] = legacySnapshot
        guard let root = accountDependencies.rootURL,
              let quarantine = scopeDirectory("legacy-unowned"),
              let parent = quarantine.deletingLastPathComponent() as URL? else {
            accountPersistenceFailed = true
            return false
        }
        let staging = parent.appendingPathComponent("legacy-unowned-staging-\(UUID().uuidString)",
                                                   isDirectory: true)
        do {
            if accountDependencies.shouldFail(.copyLegacy) { throw CocoaError(.fileWriteUnknown) }
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
            for name in ["habits.json", "day-log.json", "wins.json", "running-timers.json"] {
                let source = root.appendingPathComponent(name)
                let destination = staging.appendingPathComponent(name)
                if FileManager.default.fileExists(atPath: source.path) {
                    try FileManager.default.copyItem(at: source, to: destination)
                }
            }
            let legacyWins = root.appendingPathComponent("Wins", isDirectory: true)
            let archivedWins = staging.appendingPathComponent("Wins", isDirectory: true)
            if FileManager.default.fileExists(atPath: legacyWins.path) {
                try FileManager.default.copyItem(at: legacyWins, to: archivedWins)
            }
            if let routines = defaults.data(forKey: "aura.routines") {
                try routines.write(to: staging.appendingPathComponent("routines.json"), options: .atomic)
            }
            let data = try Self.snapshotEncoder().encode(legacySnapshot)
            try data.write(to: staging.appendingPathComponent("snapshot.json"), options: .atomic)
            if FileManager.default.fileExists(atPath: quarantine.path) {
                try FileManager.default.removeItem(at: quarantine)
            }
            if accountDependencies.shouldFail(.move) { throw CocoaError(.fileWriteUnknown) }
            try FileManager.default.moveItem(at: staging, to: quarantine)
            defaults.set(true, forKey: Self.legacyQuarantineKey)
            accountPersistenceFailed = false
            return true
        } catch {
            try? FileManager.default.removeItem(at: staging)
            accountPersistenceFailed = true
            return false
        }
    }

    func accountRequest() -> (owner: UUID, revision: UInt)? {
        guard isSignedIn, let owner = activeAccountID else { return nil }
        return (owner, accountRevision)
    }

    func requestIsCurrent(_ request: (owner: UUID, revision: UInt)) -> Bool {
        isSignedIn && activeAccountID == request.owner && accountRevision == request.revision
    }

    private func removeSnapshot(for owner: UUID) -> Bool {
        guard let directory = scopeDirectory(owner.uuidString.lowercased()) else { return false }
        guard FileManager.default.fileExists(atPath: directory.path) else { return true }
        do {
            if accountDependencies.shouldFail(.delete) { throw CocoaError(.fileWriteUnknown) }
            try FileManager.default.removeItem(at: directory)
            return true
        } catch {
            return false
        }
    }

    private func quarantineUnreadableSnapshot(scope: String) -> Bool {
        guard let source = snapshotURL(scope),
              FileManager.default.fileExists(atPath: source.path) else { return true }
        let destination = source.deletingLastPathComponent()
            .appendingPathComponent("snapshot-corrupt-\(UUID().uuidString).json")
        do {
            if accountDependencies.shouldFail(.move) { throw CocoaError(.fileWriteUnknown) }
            try FileManager.default.moveItem(at: source, to: destination)
            return true
        } catch {
            return false
        }
    }

    private func flushRecoverySnapshots() -> Bool {
        do {
            for (scope, snapshot) in recoverySnapshots where scope != "legacy-unowned" {
                guard let directory = scopeDirectory(scope),
                      let destinationURL = snapshotURL(scope) else { return false }
                if accountDependencies.shouldFail(.writeSnapshot) { return false }
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                if let photos = recoveryWinPhotos[scope], !photos.isEmpty,
                   let winsDirectory = winsDirectory(scope) {
                    try FileManager.default.createDirectory(
                        at: winsDirectory, withIntermediateDirectories: true)
                    for (filename, data) in photos {
                        let url = winsDirectory.appendingPathComponent(filename)
                        if !FileManager.default.fileExists(atPath: url.path) {
                            try data.write(to: url, options: .atomic)
                        }
                    }
                }
                // If preservation failed while reading the active photo, that
                // original is still untouched. Retry copies it only back into
                // the scope recorded as the last durable active owner.
                if accountDependencies.defaults.string(forKey: Self.activeOwnerKey) == scope,
                   let activeWinsDirectory,
                   let winsDirectory = winsDirectory(scope) {
                    try FileManager.default.createDirectory(
                        at: winsDirectory, withIntermediateDirectories: true)
                    for win in snapshot.wins {
                        guard case .captured(let filename) = win.photo else { continue }
                        let destination = winsDirectory.appendingPathComponent(filename)
                        guard !FileManager.default.fileExists(atPath: destination.path) else { continue }
                        let source = activeWinsDirectory.appendingPathComponent(filename)
                        guard FileManager.default.fileExists(atPath: source.path) else { continue }
                        if accountDependencies.shouldFail(.readPhoto) { return false }
                        let data = try Data(contentsOf: source)
                        if accountDependencies.shouldFail(.writePhoto) { return false }
                        try data.write(to: destination, options: .atomic)
                    }
                }
                let data = try Self.snapshotEncoder().encode(snapshot)
                try data.write(to: destinationURL, options: .atomic)
            }
            recoveryWinPhotos.removeAll()
            return true
        } catch {
            accountPersistenceFailed = true
            return false
        }
    }

    /// Habit reminder notifications. Set from Settings → Reminders, and turned on
    /// during setup when the user grants notification permission. Persisted so the
    /// choice survives relaunch.
    var remindersEnabled = (UserDefaults.standard.object(forKey: HabitStore.remindersKey) as? Bool) ?? true {
        didSet {
            UserDefaults.standard.set(remindersEnabled, forKey: HabitStore.remindersKey)
            rescheduleReminders()
        }
    }
    private static let remindersKey = "aura.reminders.enabled"

    /// A heads-up as the day's earned screen time runs low. Also Settings →
    /// Reminders. Persisted alongside `remindersEnabled`.
    var screenTimeRemindersEnabled = (UserDefaults.standard.object(forKey: HabitStore.screenTimeRemindersKey) as? Bool) ?? true {
        didSet {
            UserDefaults.standard.set(screenTimeRemindersEnabled, forKey: HabitStore.screenTimeRemindersKey)
            rescheduleReminders()
            // The screen-time reminders are event-driven off DeviceActivity usage,
            // scheduled separately from the daily habit nudges.
            screenTime.rescheduleUsageReminders(enabled: screenTimeRemindersEnabled)
        }
    }
    private static let screenTimeRemindersKey = "aura.screenTimeReminders.enabled"

    /// Schedules or cancels the daily habit reminders off the toggle and today's
    /// progress. Best-effort: only fires if notification permission is granted.
    /// Called on launch, on toggle change, and when a quest is completed (so the
    /// 2pm/8pm nags drop for the day).
    func rescheduleReminders() {
        ReminderScheduler.reschedule(habitReminders: remindersEnabled,
                                     questsDoneToday: todayEarnedCoins > 0)
    }

    /// Reconciles the reminder toggles with the OS notification permission. If the
    /// user revoked notifications in iOS Settings, both toggles fall back to off —
    /// they could never fire anyway, so Settings → Reminders must not keep showing
    /// "On" against a denied permission. Only ever turns things *off*: granting
    /// permission doesn't force them on, that stays the user's choice. Called on
    /// launch and whenever the app returns to the foreground.
    func reconcileReminderPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            guard settings.authorizationStatus == .denied, let self else { return }
            Task { @MainActor in
                if self.remindersEnabled { self.remindersEnabled = false }
                if self.screenTimeRemindersEnabled { self.screenTimeRemindersEnabled = false }
            }
        }
    }

    /// Hard Mode — no bypasses. When on, the scroll pass (Emergency Unlock) is
    /// disabled so apps can't be unblocked early.
    var hardMode = false

    /// Earnable Apple Health metrics — stubbed with a mix of states (collectable,

    // MARK: - Apple Health

    /// The rows on the Apple Health sheet, one per readable metric.
    ///
    /// Built from `HealthMetricKind` rather than written out, so a metric's
    /// name, icon, rate and unit can't disagree with the query that fills it.
    /// Amounts are zero until `refreshHealth()` has read today's totals.
    var healthMetrics: [HealthMetric] = HealthMetricKind.allCases.map { kind in
        HealthMetric(name: kind.name,
                     iconSystemName: kind.iconSystemName,
                     iconAsset: kind.iconAsset,
                     rateLabel: kind.rateLabel,
                     amountLabel: "No activity yet",
                     pendingMinutes: 0,
                     hasActivity: false)
    }

    /// Today's totals as last read, so a collect can subtract what's already
    /// been claimed instead of paying for the same steps twice.
    private var healthCollectedToday: [String: Double] = [:]
    private var healthCollectedDay: Date = Calendar.current.startOfDay(for: .now)

    /// Whether the user has been through Apple's permission sheet.
    ///
    /// Tracked by us because it can't be asked: HealthKit reports read access as
    /// "not determined" forever by design, so the app has no way to know what
    /// was granted. This records only that we've asked.
    var isHealthConnected: Bool = UserDefaults.standard.bool(forKey: HabitStore.healthConnectedKey) {
        didSet { UserDefaults.standard.set(isHealthConnected, forKey: HabitStore.healthConnectedKey) }
    }

    /// Named, not `Self.` — a stored property's initializer can't reference the
    /// covariant `Self` of a non-final class context.
    private static let healthConnectedKey = "health.connected"

    // MARK: - Interventions

    /// Which intervention styles can come up when a blocked app is opened.
    /// Everything built is on for a fresh install.
    var interventionStyles: Set<InterventionStyle> = HabitStore.loadStyles() {
        didSet {
            UserDefaults.standard.set(interventionStyles.map(\.rawValue),
                                      forKey: HabitStore.interventionStylesKey)
        }
    }

    private static let interventionStylesKey = "intervention.styles"

    private static func loadStyles() -> Set<InterventionStyle> {
        guard let saved = UserDefaults.standard.array(forKey: interventionStylesKey) as? [String] else {
            return InterventionStyle.defaults
        }
        return Set(saved.compactMap(InterventionStyle.init(rawValue:)))
    }

    /// The style to run this time. Falls back to the dialogue rather than
    /// nothing: turning every style off shouldn't quietly disable the shield's
    /// whole reason for sending you here.
    var interventionStyle: InterventionStyle {
        interventionStyles.randomElement() ?? .dialogue
    }

    func connectHealth() async {
        let completed = await HealthService.shared.requestAuthorization()
        guard completed else { return }
        isHealthConnected = true
        await refreshHealth()
    }

    /// Collect a metric's pending screen time.
    ///
    /// Marks the amount as claimed rather than zeroing the reading — Health's
    /// total for today only ever grows, so without a claimed watermark the next
    /// refresh would offer the same steps again.
    /// Collecting counts toward the streak, like the other three quests.
    ///
    /// It's passive to *earn* but not to collect, and you still had to move to
    /// have anything worth claiming. Leaving it out meant someone could walk
    /// 12,000 steps, collect, and lose their streak — while the screen telling
    /// them to "complete at least one quest" listed Passive Income as one.
    @discardableResult
    func collectHealth(_ id: UUID) -> Bool {
        guard let i = healthMetrics.firstIndex(where: { $0.id == id }),
              let kind = HealthMetricKind.allCases.first(where: { $0.name == healthMetrics[i].name }),
              healthMetrics[i].pendingMinutes > 0
        else { return false }
        grantScreenTime(minutes: healthMetrics[i].pendingMinutes, method: .healthSync)
        // Guarded on there being something to collect, so tapping a zero row
        // can't mint a streak day out of nothing.
        let firstToday = completeHabitToday()
        healthCollectedToday[kind.rawValue] = healthAmounts[kind.rawValue] ?? 0
        healthMetrics[i].pendingMinutes = 0
        healthMetrics[i].hasActivity = false
        healthMetrics[i].amountLabel = "No new activity"
        // The grant path persisted before the claimed watermark changed. Write
        // again so a relaunch cannot offer the same Health total twice.
        persistActiveAccount()
        return firstToday
    }

    /// Today's raw readings, before the claimed watermark is taken off.
    private var healthAmounts: [String: Double] = [:]

    /// Re-pull from Apple Health.
    ///
    /// Returns whether anything came back. HealthKit answers a query it can't
    /// satisfy with zero rather than an error, so "did we read something" is
    /// the only signal there is — and it's the difference between a refresh
    /// worth confirming and one with nothing to say.
    @discardableResult
    func refreshHealth() async -> Bool {
        let request = (owner: activeAccountID, revision: accountRevision)
        let today = Calendar.current.startOfDay(for: .now)
        if today != healthCollectedDay {
            // A new day resets what's been claimed — the totals start at zero
            // again, so an old watermark would swallow the whole morning.
            healthCollectedDay = today
            healthCollectedToday = [:]
            persistActiveAccount()
        }

        let totals = await HealthService.shared.todayTotals()
        guard activeAccountID == request.owner, accountRevision == request.revision else { return false }
        for (kind, amount) in totals {
            healthAmounts[kind.rawValue] = amount
            guard let i = healthMetrics.firstIndex(where: { $0.name == kind.name }) else { continue }
            let claimed = healthCollectedToday[kind.rawValue] ?? 0
            let unclaimed = Swift.max(0, amount - claimed)
            let minutes = Int(unclaimed * kind.coinsPerUnit)
            healthMetrics[i].pendingMinutes = minutes
            healthMetrics[i].hasActivity = minutes > 0
            healthMetrics[i].amountLabel = amount > 0
                ? kind.amountLabel(amount)
                : "No activity yet"
        }
        return totals.values.contains { $0 > 0 }
    }


    /// Habits for a given verification method (the picker's per-method list).
    func habits(for category: HabitCategory) -> [Habit] {
        habits.filter { $0.category == category && $0.isEnabled }
    }

    /// Photo-Proof habits only — the setup grid's options.
    var proofHabits: [Habit] { habits(for: .photoTask) }

    /// Photo habits split by kind: `focus` earn over a timed session
    /// (rate × length); `quick` snap once for a flat reward.
    var focusHabits: [Habit] { proofHabits.filter { $0.requiresFocusSession } }
    var quickHabits: [Habit] { proofHabits.filter { !$0.requiresFocusSession } }

    /// Create a new habit or replace an existing one (Create/Edit builder).
    var habits: [Habit] = HabitStore.mergedHabits() {
        didSet {
            if runsRuntimeSideEffects, hasLoadedAccountScope, !isApplyingAccountSnapshot {
                HabitFile.save(habits)
            }
            persistActiveAccount()
            // A local edit stamps the library and schedules a push. Suppressed
            // while adopting the server's library, so adopting doesn't look like
            // a local edit and bounce straight back up.
            if !isApplyingRemoteLibrary && !isApplyingAccountSnapshot { libraryChangedLocally() }
        }
    }

    func upsertHabit(_ habit: Habit) {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[index] = habit
        } else {
            habits.append(habit)
        }
    }

    func setDefaultMinutes(_ minutes: Int, for habit: Habit) {
        if let i = habits.firstIndex(where: { $0.id == habit.id }) { habits[i].defaultFocusMinutes = minutes }
    }

    func setOncePerDay(_ on: Bool, for habit: Habit) {
        if let i = habits.firstIndex(where: { $0.id == habit.id }) { habits[i].oncePerDay = on }
    }

    /// Current stored value for a habit (edits read through this so sliders
    /// reflect live state).
    func liveHabit(_ id: UUID) -> Habit? { habits.first { $0.id == id } }

    // MARK: - Favorites

    /// Hearted habits and exercises. They sort to the top of their picker the
    /// next time it opens, so the ones someone actually uses stop being a scroll
    /// away. Kept as id sets rather than a flag on the model so the stock lists
    /// stay immutable.
    var favoriteHabitIds: Set<UUID> = [] { didSet { persistActiveAccount() } }
    var favoriteExerciseIds: Set<String> = [] { didSet { persistActiveAccount() } }

    func isFavorite(_ habit: Habit) -> Bool { favoriteHabitIds.contains(habit.id) }
    func isFavorite(_ exercise: Exercise) -> Bool { favoriteExerciseIds.contains(exercise.id) }

    func toggleFavorite(_ habit: Habit) {
        if favoriteHabitIds.contains(habit.id) { favoriteHabitIds.remove(habit.id) }
        else { favoriteHabitIds.insert(habit.id) }
    }

    func toggleFavorite(_ exercise: Exercise) {
        if favoriteExerciseIds.contains(exercise.id) { favoriteExerciseIds.remove(exercise.id) }
        else { favoriteExerciseIds.insert(exercise.id) }
    }

    // Seeded so the streak reads as an ongoing run (last done yesterday), and
    // completing today increments rather than resetting.
    /// Derived, not stored. The run of kept days ending today — or ending
    /// yesterday, since a streak isn't broken until a day is missed, and today
    /// isn't over.
    ///
    /// Was a hardcoded 12 that agreed with the seeded 90-day grid only by
    /// coincidence; two numbers describing the same fact could drift the moment
    /// either changed.
    var streak: StreakInfo {
        let days = dayRecords.last90Days()
        // The run, with freezes bridging any missed days along the way.
        let current = dayRecords.streakRun().streak

        var longest = 0, run = 0
        for kept in days {
            run = kept ? run + 1 : 0
            longest = Swift.max(longest, run)
        }
        let lastCompleted = dayRecords.filter(\.kept).map(\.date).max()
        return StreakInfo(currentStreak: current,
                          longestStreak: Swift.max(longest, current),
                          lastCompletedDate: lastCompleted)
    }

    // MARK: - Day log
    //
    // The per-day record everything below derives from. Held here rather than
    // in its own object so `@Observable` sees the mutations — a separate class
    // would change under the views without telling them.

    private(set) var dayRecords: [DayRecord] = DayLogFile.load() {
        didSet { persistActiveAccount() }
    }

    /// Saves the current scope and synchronously replaces every account-owned
    /// value before any new cloud work can start. Device-wide privacy choices,
    /// Screen Time selections, notification permission, and Emergency Pass state
    /// deliberately live outside this switch.
    @discardableResult
    func activateAccount(_ accountID: UUID?, persistCurrent: Bool = true) -> Bool {
        if hasLoadedAccountScope, activeAccountID == accountID {
            isSignedIn = accountID != nil
            if accountPersistenceFailed {
                let saved = persistActiveAccount(includeWinPhotos: true)
                if saved { pendingAccountTransitionID = nil }
                return saved
            }
            return true
        }
        if persistCurrent, !persistActiveAccount(includeWinPhotos: true) {
            isolateAfterFailedAccountTransition(pending: accountID)
            return false
        }

        let targetScope = accountID?.uuidString.lowercased() ?? Self.signedOutScope
        let snapshot: AccountSnapshot
        if let recovered = recoverySnapshots[targetScope] {
            snapshot = recovered
        } else { switch loadSnapshot(scope: targetScope) {
        case .missing:
            snapshot = Self.newSnapshot()
        case .loaded(let loaded):
            snapshot = loaded
        case .unreadable:
            isolateAfterFailedAccountTransition(pending: accountID)
            return false
        } }

        progressPushTask?.cancel()
        libraryPushTask?.cancel()
        ticker?.invalidate()
        ticker = nil
        accountRevision &+= 1
        isApplyingRemoteLibrary = false
        isApplyingRemoteAvatar = false

        let oldWins = wins
        activeAccountID = accountID
        if runsRuntimeSideEffects { RoutineStore.activate(ownerID: accountID) }

        isApplyingAccountSnapshot = true
        accountFirstSeenAt = snapshot.firstSeenAt
        accountLibraryUpdatedAt = snapshot.libraryUpdatedAt
        powerUpDate = snapshot.powerUpDate
        claimedPowerUpThresholds = snapshot.claimedPowerUps
        displayName = snapshot.displayName
        email = snapshot.email
        profileImageData = snapshot.profileImageData
        habits = snapshot.habits
        dayRecords = snapshot.dayRecords
        favoriteHabitIds = snapshot.favoriteHabitIDs
        favoriteExerciseIds = snapshot.favoriteExerciseIDs
        habitCompletionCounts = snapshot.habitCompletionCounts
        exerciseCompletionCounts = snapshot.exerciseCompletionCounts
        healthCollectCount = snapshot.healthCollectCount
        healthCollectedToday = snapshot.healthCollectedToday
        healthCollectedDay = snapshot.healthCollectedDay
        lifetimeEarnedMinutes = snapshot.lifetimeEarnedMinutes
        lifetimeHealthyHabits = snapshot.lifetimeHealthyHabits
        lifetimeReps = snapshot.lifetimeReps
        lifetimeFocusMinutes = snapshot.lifetimeFocusMinutes
        baselineWeeklyScreenMinutes = snapshot.baselineWeeklyScreenMinutes
        dailyCoinGoal = snapshot.dailyCoinGoal
        deepFocusSessions = snapshot.deepFocusSessions.map {
            DeepFocusSession(durationMinutes: $0.durationMinutes,
                             earnedMinutes: $0.earnedMinutes, date: $0.date)
        }
        deepFocusRate = snapshot.deepFocusRate
        exerciseGoals = snapshot.exerciseGoals
        purchases = snapshot.purchases
        wins = snapshot.wins
        unlockStartedAt = snapshot.runningTimers.unlockStartedAt
        unlockEndsAt = snapshot.runningTimers.unlockEndsAt
        activeHabitSession = snapshot.runningTimers.habit
        sessionMethod = snapshot.runningTimers.habitMethod ?? .photoTask
        activeFocusSession = snapshot.runningTimers.focus
        isSignedIn = accountID != nil
        healthAmounts = [:]
        healthMetrics = HealthMetricKind.allCases.map { kind in
            HealthMetric(name: kind.name, iconSystemName: kind.iconSystemName,
                         iconAsset: kind.iconAsset, rateLabel: kind.rateLabel,
                         amountLabel: "No activity yet", pendingMinutes: 0, hasActivity: false)
        }
        pendingStreakCelebration = false
        pendingEarnPulse = nil
        focusSessionPayout = nil
        isFlowPresented = false
        guard restoreWinPhotos(scope: accountScopeName, replacing: oldWins) else {
            isApplyingAccountSnapshot = false
            isolateAfterFailedAccountTransition(pending: accountID)
            return false
        }
        if runsRuntimeSideEffects {
            HabitFile.save(habits)
            DayLogFile.save(dayRecords)
            WinLibrary.save(wins)
            RunningTimersFile.save(snapshot.runningTimers)
        }
        isApplyingAccountSnapshot = false
        hasLoadedAccountScope = true
        guard persistActiveAccount(includeWinPhotos: true) else {
            isolateAfterFailedAccountTransition(pending: accountID)
            return false
        }
        pendingAccountTransitionID = nil

        now = .now
        if runsRuntimeSideEffects { screenTime.cancelScheduledReshield() }
        if runsRuntimeSideEffects, let end = unlockEndsAt, end > now {
            screenTime.scheduleReshield(at: end)
        }
        if runsRuntimeSideEffects, !snapshot.runningTimers.isEmpty {
            startTicking()
            tick()
        }
        if runsRuntimeSideEffects {
            syncLiveActivity()
            Task { await refreshShield() }
        }
        return true
    }

    /// Authentication may already have moved even when local storage is not
    /// writable. Hide all owner data without touching the recoverable files.
    private func isolateAfterFailedAccountTransition(pending accountID: UUID?) {
        progressPushTask?.cancel()
        libraryPushTask?.cancel()
        ticker?.invalidate()
        ticker = nil
        accountRevision &+= 1
        hasLoadedAccountScope = false
        activeAccountID = nil
        isApplyingAccountSnapshot = true
        isApplyingRemoteLibrary = false
        isApplyingRemoteAvatar = false
        let blank = Self.newSnapshot()
        accountFirstSeenAt = .now
        accountLibraryUpdatedAt = Date(timeIntervalSince1970: 0)
        powerUpDate = nil
        claimedPowerUpThresholds = []
        displayName = ""
        email = ""
        profileImageData = nil
        habits = blank.habits
        dayRecords = []
        favoriteHabitIds = []
        favoriteExerciseIds = []
        habitCompletionCounts = [:]
        exerciseCompletionCounts = [:]
        healthCollectCount = 0
        healthCollectedToday = [:]
        healthCollectedDay = Calendar.current.startOfDay(for: .now)
        healthAmounts = [:]
        healthMetrics = HealthMetricKind.allCases.map { kind in
            HealthMetric(name: kind.name, iconSystemName: kind.iconSystemName,
                         iconAsset: kind.iconAsset, rateLabel: kind.rateLabel,
                         amountLabel: "No activity yet", pendingMinutes: 0, hasActivity: false)
        }
        lifetimeEarnedMinutes = 0
        lifetimeHealthyHabits = 0
        lifetimeReps = 0
        lifetimeFocusMinutes = 0
        baselineWeeklyScreenMinutes = nil
        dailyCoinGoal = 100
        deepFocusSessions = []
        deepFocusRate = 10
        exerciseGoals = [:]
        purchases = []
        wins = []
        unlockStartedAt = nil
        unlockEndsAt = nil
        activeHabitSession = nil
        activeFocusSession = nil
        sessionMethod = .photoTask
        pendingStreakCelebration = false
        pendingEarnPulse = nil
        focusSessionPayout = nil
        isFlowPresented = false
        isSignedIn = false
        isApplyingAccountSnapshot = false
        accountPersistenceFailed = true
        pendingAccountTransitionID = accountID
        if runsRuntimeSideEffects {
            RoutineStore.activate(ownerID: nil)
            screenTime.cancelScheduledReshield()
            LiveActivityController.end()
            Task { await refreshShield() }
        }
    }

    /// Retries a transition that was blocked to protect an unreadable/unwritable
    /// cache. The UI can call this after the user frees device storage.
    @discardableResult
    func retryPendingAccountTransition() -> Bool {
        let target = pendingAccountTransitionID ?? accountDependencies.currentUserID()
        guard quarantineLegacyStateIfNeeded() else { return false }
        guard flushRecoverySnapshots() else { return false }
        let targetScope = target?.uuidString.lowercased() ?? Self.signedOutScope
        if case .unreadable = loadSnapshot(scope: targetScope),
           !quarantineUnreadableSnapshot(scope: targetScope) {
            accountPersistenceFailed = true
            return false
        }
        guard activateAccount(target, persistCurrent: false) else { return false }
        guard runsRuntimeSideEffects else { return true }
        SupportChatStore.shared.switchAccount(to: target)
        guard let target, let request = accountRequest() else { return true }
        configureEntitlement()
        Task { @MainActor [weak self, request, target] in
            guard let self, self.requestIsCurrent(request) else { return }
            await self.refreshEntitlement()
            guard self.requestIsCurrent(request) else { return }
            if let profile = try? await SupabaseManager.shared.fetchProfile(expectedUserID: target),
               self.requestIsCurrent(request) {
                if let name = profile.displayName, !name.isEmpty { self.displayName = name }
                if let email = profile.email, !email.isEmpty { self.email = email }
            }
            await self.syncProgress(request)
            await self.syncLibrary(request)
            await self.syncAvatar(request)
        }
        return true
    }

    /// Restores persisted sessions, monitoring, and account state in every build.
    convenience init() {
        self.init(accountDependencies: .live, startRuntimeServices: true)
    }

    /// Internal only: tests provide a temporary directory/defaults suite and
    /// deterministic fault/identity closures while exercising the production
    /// account state machine.
    init(accountDependencies: AccountDependencies, startRuntimeServices: Bool) {
        self.accountDependencies = accountDependencies
        self.runsRuntimeSideEffects = startRuntimeServices
        // Preserve every ownerless pre-isolation cache in a one-time quarantine.
        // It remains recoverable, but is never guessed to belong to a login.
        if quarantineLegacyStateIfNeeded() {
            _ = activateAccount(accountDependencies.currentUserID(), persistCurrent: false)
        } else {
            isolateAfterFailedAccountTransition(pending: accountDependencies.currentUserID())
        }
        guard startRuntimeServices else { return }
        // Seeded here, not in `Aura_iOSApp.init` — that body runs *after*
        // `@State private var store = HabitStore()` has already loaded, so
        // anything seeded there lands a launch late.
        #if DEBUG
        BlockConfigFile.seedIfEmpty()
        #endif
        blockConfig = BlockConfigFile.load()
        screenTime.mirrorDistractingSelection(blockConfig.distracting.token)
        screenTime.rescheduleUsageReminders(enabled: screenTimeRemindersEnabled)
        rescheduleReminders()
        reconcileReminderPermission()

        // The locally-persisted signed-in flag can outlive the real session
        // (expired, signed out on another device, reinstalled). Reconcile it
        // against Supabase, and pull identity from the server for a fresh device.
        Task { @MainActor in await reconcileAuth() }

        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments

        // `-unlock [minutes]` opens the phone on launch, so the Live Activity
        // and the countdown can be seen without tapping through a purchase.
        if let flag = arguments.firstIndex(of: "-unlock") {
            let minutes = arguments.indices.contains(flag + 1)
                ? Int(arguments[flag + 1]) ?? 10
                : 10
            DispatchQueue.main.async { [self] in startPurchasedScreenTime(minutes: minutes) }
        }

        guard let flag = arguments.firstIndex(of: "-coins") else { return }
        let amount = arguments.indices.contains(flag + 1)
            ? Int(arguments[flag + 1]) ?? HabitStore.debugCoins
            : HabitStore.debugCoins
        dayRecords = DayLogFile.withTodayCoins(amount)
        #endif
    }

#if DEBUG
    /// Enough for a few purchases at every tier without being obviously fake.
    private static let debugCoins = 300
#endif

    /// 90-day completion history for the Home overview (index 0 = oldest,
    /// 89 = today). Real now: a day counts as kept if a habit was completed on
    /// it.
    /// The 90-day grid, day one first — the same anchor `detoxDay` counts from.
    var journeyDays: [Bool] { dayRecords.journeyDays() }

    /// Freezes in hand, out of `StreakFreeze.maximum`.
    ///
    /// Derived from the same walk as the streak, so the count and the run it
    /// protects can never disagree.
    var streakFreezes: Int { dayRecords.streakRun().freezes }

    /// Habits completed on the current 90-day board — the span the grid draws.
    var boardHabitsCompleted: Int { dayRecords.boardHabitsCompleted() }

    /// Current day within the journey, counted from the first day used.
    var detoxDay: Int { dayRecords.dayNumber() }

    /// Adds to today's record, creating it if this is the first thing to happen
    /// today, and writes through.
    private func recordToday(coins: Int = 0, habits: Int = 0,
                             method: HabitCategory? = nil, now: Date = .now) {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: now)
        let hour = calendar.component(.hour, from: now)
        if let index = dayRecords.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: day) }) {
            dayRecords[index].credit(coins: coins, hour: hour, method: method)
            dayRecords[index].habitsCompleted += habits
        } else {
            var record = DayRecord(date: day, habitsCompleted: habits)
            record.credit(coins: coins, hour: hour, method: method)
            dayRecords.append(record)
        }
        if runsRuntimeSideEffects { DayLogFile.save(dayRecords) }
        // Same funnel every earn passes through, so one push here keeps the
        // account's history current across devices (debounced, best-effort).
        syncProgressUp()

        // Published here rather than at each earn path, because this is the one
        // funnel all of them already go through: quick habits, a finished focus
        // session, exercise, Health. Anything that credits coins gets the Home
        // animation without knowing the animation exists.
        if coins > 0 { pendingEarnPulse = EarnPulse(amount: coins) }
    }

    #if DEBUG
    /// Debug only: drop coins straight into today's balance without unlocking
    /// apps, so the Home charge bar and anything priced in coins can be looked
    /// at without earning the hard way. Routed through `recordToday` so it lands
    /// exactly where a real earn would.
    func debugAddCoins(_ amount: Int) {
        recordToday(coins: amount)
    }

    /// Debug only: empty the coin balance so the "broke" intervention copy and
    /// any out-of-coins state can be checked. The balance is `earned - spent`,
    /// so zeroing today's earned coins floors it at 0.
    func debugClearCoins() {
        let today = Calendar.current.startOfDay(for: .now)
        if let index = dayRecords.firstIndex(where: {
            Calendar.current.isDate($0.date, inSameDayAs: today)
        }) {
            dayRecords[index].coinsEarned = 0
            if runsRuntimeSideEffects { DayLogFile.save(dayRecords) }
        }
    }

    /// Debug only: clear any bought/earned screen time so a purchase can be
    /// checked from zero — otherwise buying stacks on the time already remaining
    /// (10 bought + 1 left = 11 on the clock).
    func debugClearScreenTime() {
        lock()
    }
    #endif

    /// Coins credited that Home hasn't shown yet.
    ///
    /// Carries an id so two grants of the same size read as two events rather
    /// than one unchanged value.
    struct EarnPulse: Equatable {
        let id = UUID()
        let amount: Int
    }

    /// A streak day earned by a timer running out rather than by a screen the
    /// user was looking at.
    ///
    /// Held for the same reason `pendingEarnPulse` is: the session can finish
    /// while the app is backgrounded, or under a flow, and the celebration has
    /// to wait until somebody is actually on Home to see it.
    var pendingStreakCelebration = false

    /// Set by `recordToday`, cleared by Home once it has played it.
    ///
    /// Held rather than fired because almost every earn happens while a
    /// full-screen flow is covering Home. Firing on the spot would run the
    /// count-up behind the streak screen and leave nothing to see on the way
    /// back, which is the whole point of it.
    var pendingEarnPulse: EarnPulse?
    /// True while a full-screen flow is over Home. Home waits for this to clear
    /// before draining the pulse.
    var isFlowPresented = false

    /// Calendar weekday numbers (1=Sun … 7=Sat) completed in the current week —
    /// drives the streak celebration's week row.
    ///
    /// Derived like the streak. It used to be seeded with every day of the week
    /// before today, whether or not anything happened on them.
    var weekCompletionWeekdays: Set<Int> {
        let calendar = Calendar.current
        return Set(dayRecords.week().filter(\.kept).map { calendar.component(.weekday, from: $0.date) })
    }

    // MARK: - Rating

    /// A rating ask waiting for Home to be free. Same holding pattern as the
    /// streak and the earn pulse, and it queues behind both.
    var pendingRatingAsk = false

    /// Every habit ever completed, summed from the day log rather than counted
    /// alongside it. A second copy of a number is a second thing to get wrong.
    var lifetimeHabitsCompleted: Int {
        dayRecords.reduce(0) { $0 + $1.habitsCompleted }
    }

    private enum RatingKey {
        static let asks = "aura.rating.askCount"
        static let last = "aura.rating.lastAskAt"
        static let rated = "aura.rating.hasRated"
        static let installed = "aura.rating.firstOpenedAt"
    }

    /// The day the app was first opened. Written once, the first time anything
    /// asks for it, so an existing install starts its clock today rather than
    /// pretending to be old.
    private var firstOpenedAt: Date {
        let defaults = UserDefaults.standard
        if let stored = defaults.object(forKey: RatingKey.installed) as? Date { return stored }
        let now = Date()
        defaults.set(now, forKey: RatingKey.installed)
        return now
    }

    /// Whole days since the app was first opened, counted between start-of-day
    /// boundaries so "day 14" doesn't depend on the time of day they installed.
    private var daysSinceFirstOpen: Int {
        let cal = Calendar.current
        return cal.dateComponents([.day],
                                  from: cal.startOfDay(for: firstOpenedAt),
                                  to: cal.startOfDay(for: .now)).day ?? 0
    }

    private var ratingAskCount: Int { UserDefaults.standard.integer(forKey: RatingKey.asks) }

    /// The one gate every trigger passes through.
    private var mayAskForRating: Bool {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: RatingKey.rated) else { return false }
        guard ratingAskCount < 3 else { return false }
        guard let last = defaults.object(forKey: RatingKey.last) as? Date else { return true }
        return Date().timeIntervalSince(last) >= Self.ratingCooldownDays * 24 * 60 * 60
    }

    /// Fourteen days, which is also what spaces the milestones for a late
    /// starter. Somebody who installs and doesn't log anything until day 20
    /// trips the first ask then and would immediately satisfy day-14 as well;
    /// the cooldown is what holds the second one back.
    private static let ratingCooldownDays: Double = 14

    /// Called on every completion. Three moments: the first habit ever, then
    /// day 14, then day 30.
    ///
    /// Days since INSTALL, not streak days. A 14-day streak is a milestone most
    /// people never reach, so hanging two of the three asks on it would mean
    /// most users are asked exactly once, ever.
    ///
    /// The milestones are ordered thresholds, not exact days, and that is the
    /// whole trick. `day == 14` would silently skip anybody who didn't happen
    /// to complete a habit on that specific day, which is most people. `asks`
    /// says which milestone is next and `>=` says it's due, so a missed day
    /// delays the ask to their next completion instead of cancelling it.
    private func considerRatingAsk() {
        guard mayAskForRating else { return }
        let day = daysSinceFirstOpen
        let due: Bool
        switch ratingAskCount {
        case 0: due = lifetimeHabitsCompleted >= 1
        case 1: due = day >= 14
        case 2: due = day >= 30
        default: due = false
        }
        guard due else { return }
        pendingRatingAsk = true
    }

    /// Counted whichever way they answer. An ask is an ask, and the cooldown
    /// exists to stop us nagging, not to stop us hearing "no".
    func recordRatingAsk() {
        let defaults = UserDefaults.standard
        defaults.set(defaults.integer(forKey: RatingKey.asks) + 1, forKey: RatingKey.asks)
        defaults.set(Date(), forKey: RatingKey.last)
    }

    /// They said yes, so never ask again — whether or not iOS actually showed
    /// its own prompt, which is not something we get told.
    func markRated() {
        UserDefaults.standard.set(true, forKey: RatingKey.rated)
    }

    /// The shipped habits, wearing whatever the user has changed about them.
    ///
    /// The saved file used to be taken wholesale, which quietly froze the stock
    /// list at whatever it looked like the day somebody installed. Every edit to
    /// a shipped habit after that reached new installs only: a corrected proof
    /// hint, a changed rate, a new sticker, a habit added to the catalogue. It
    /// is how three habits kept rendering emoji today after their artwork
    /// landed — the asset was there, the seed pointed at it, and the file on
    /// disk had never heard of it.
    ///
    /// So the seed wins on everything the app owns, and the file wins on the
    /// four things the user owns. Matched by name, because `id` is a fresh
    /// `UUID()` per seed and can't survive a relaunch.
    static func mergedHabits() -> [Habit] {
        guard let saved = HabitFile.load() else { return defaultHabits }
        let byName = Dictionary(saved.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })

        var merged = defaultHabits.map { seed -> Habit in
            guard let mine = byName[seed.name] else { return seed }
            var habit = seed
            // Keep the id so anything holding a reference still resolves.
            habit.id = mine.id
            habit.isEnabled = mine.isEnabled
            habit.oncePerDay = mine.oncePerDay
            habit.defaultFocusMinutes = mine.defaultFocusMinutes
            habit.targetCount = mine.targetCount
            return habit
        }

        // Habits somebody built themselves aren't in the seed and are theirs
        // entirely, so they carry over untouched.
        let seeded = Set(defaultHabits.map(\.name))
        merged.append(contentsOf: saved.filter { $0.isCustom && !seeded.contains($0.name) })
        return merged
    }

    // MARK: - Per-habit all-time counts

    private static let habitCountsKey = "aura.habitCompletionCounts"

    /// All-time completion count per habit id (as a string). Powers the "Times
    /// done" tile and the habit ranking on the Photo Proof success screen — the
    /// day log only keeps a daily total, so this is the only per-habit history.
    private(set) var habitCompletionCounts: [String: Int] = HabitStore.loadHabitCounts() {
        didSet { persistActiveAccount() }
    }

    private static func loadHabitCounts() -> [String: Int] {
        (UserDefaults.standard.dictionary(forKey: habitCountsKey) as? [String: Int]) ?? [:]
    }

    /// How many times this habit has been completed, all time.
    func timesDone(_ habit: Habit) -> Int { habitCompletionCounts[habit.id.uuidString] ?? 0 }

    /// This habit's place among all habits by how often it's been done, and how
    /// many habits there are — `(1, n)` is your most-done. Ties share the better
    /// rank, so two joint-first habits both read #1.
    func habitRank(_ habit: Habit) -> (rank: Int, total: Int) {
        let mine = timesDone(habit)
        let ahead = habits.filter { $0.id != habit.id && timesDone($0) > mine }.count
        return (ahead + 1, habits.count)
    }

    // MARK: - Per-exercise all-time counts

    private static let exerciseCountsKey = "aura.exerciseCompletionCounts"

    /// All-time completion count per exercise id — the Camera Reps equivalent of
    /// the per-habit counts, so a set can rank among the exercises.
    private(set) var exerciseCompletionCounts: [String: Int] = HabitStore.loadExerciseCounts() {
        didSet { persistActiveAccount() }
    }

    private static func loadExerciseCounts() -> [String: Int] {
        (UserDefaults.standard.dictionary(forKey: exerciseCountsKey) as? [String: Int]) ?? [:]
    }

    /// Logs a completed set so the exercise's all-time count climbs.
    func recordExerciseDone(_ exercise: Exercise) {
        exerciseCompletionCounts[exercise.id, default: 0] += 1
    }

    func timesDone(_ exercise: Exercise) -> Int { exerciseCompletionCounts[exercise.id] ?? 0 }

    /// This exercise's place among all exercises by how often it's been done.
    func exerciseRank(_ exercise: Exercise) -> (rank: Int, total: Int) {
        let mine = timesDone(exercise)
        let ahead = Exercise.all.filter { $0.id != exercise.id && timesDone($0) > mine }.count
        return (ahead + 1, Exercise.all.count)
    }

    // MARK: - Passive Income collects

    private static let healthCollectsKey = "aura.healthCollectCount"

    /// How many times Passive Income has been collected, all time — one per
    /// tap of Collect, however many categories it swept up.
    private(set) var healthCollectCount: Int = UserDefaults.standard.integer(forKey: HabitStore.healthCollectsKey) {
        didSet { persistActiveAccount() }
    }

    func recordHealthCollect() { healthCollectCount += 1 }

    /// The health category that paid the most in the current pending set, with
    /// today's raw amount — for the Passive Income success tile. Read BEFORE
    /// collecting, since collecting zeroes the pending minutes.
    func topPendingHealthCategory() -> (kind: HealthMetricKind, amount: Double)? {
        guard let top = healthMetrics
                .filter({ $0.hasActivity && $0.pendingMinutes > 0 })
                .max(by: { $0.pendingMinutes < $1.pendingMinutes }),
              let kind = HealthMetricKind.allCases.first(where: { $0.name == top.name })
        else { return nil }
        return (kind, healthAmounts[kind.rawValue] ?? 0)
    }

    /// Marks a habit completed today. Increments the streak at most once per
    /// day. Returns `true` if this was the FIRST completion today — the signal
    /// to show the streak celebration. Pass the `habit` so its all-time count
    /// climbs (photo habits do; sessions and health collects don't name one).
    @discardableResult
    func completeHabitToday(habit: Habit? = nil, now: Date = .now) -> Bool {
        if let habit {
            habitCompletionCounts[habit.id.uuidString, default: 0] += 1
            // The Healthy Habits achievement counts the photoTask category only
            // (its Focus and Quick kinds) — Deep Focus and Exercise complete with
            // no `habit`, so they never land here.
            if habit.category == .photoTask { lifetimeHealthyHabits += 1 }
        }
        let cal = Calendar.current
        // Asked before recording, not after: the moment the completion lands in
        // the log, today becomes a kept day and the answer flips.
        let alreadyToday = dayRecords.contains { cal.isDate($0.date, inSameDayAs: now) && $0.kept }
        // Every completion counts toward the lifetime total; only the first of
        // the day moves the streak, and the streak works that out for itself.
        recordToday(habits: 1, now: now)
        considerRatingAsk()
        // A quest is done today — pull the 2pm/8pm "you've done nothing" nags.
        rescheduleReminders()
        return !alreadyToday
    }

    // MARK: - Blocking

    /// What's blocked, in three rules. The whole policy — there is no second
    /// mechanism that can also block something.
    var blockConfig: BlockConfig = BlockConfigFile.load() {
        didSet {
            guard blockConfig != oldValue else { return }
            BlockConfigFile.save(blockConfig)
            // The monitor extension wakes with no app around it, so what it
            // needs to re-shield has to be sitting in the shared container
            // before that happens.
            screenTime.mirrorDistractingSelection(blockConfig.distracting.token)
            // Rebuild the usage-reminder events against the new selection.
            screenTime.rescheduleUsageReminders(enabled: screenTimeRemindersEnabled)
            Task { await refreshShield() }
        }
    }

    /// The plan in force right now, from the one engine every surface reads.
    /// Any session that should hold the Distracting rule shut — a Lock In or a
    /// photo habit. Both are "I'm doing the thing", and neither is compatible
    /// with the apps being open.
    private var isSessionRunning: Bool {
        activeHabitSession != nil || activeFocusSession != nil
    }

    var currentPlan: ShieldPlan {
        BlockingEngine.plan(config: blockConfig,
                            isUnlocked: isUnlocked,
                            inSession: isSessionRunning,
                            hardMode: hardMode)
    }

    /// Whether the Distracting rule is open at this moment.
    var isDistractingLifted: Bool {
        BlockingEngine.softLifted(isUnlocked: isUnlocked,
                                  inSession: isSessionRunning)
    }

    /// The apps being shielded right now, drawable.
    var blockedNowIcons: [AppIconSource] {
        BlockingEngine.blockedNowIcons(config: blockConfig,
                                       isUnlocked: isUnlocked,
                                       inSession: isSessionRunning)
    }

    /// Puts an app selection into a rule, taking it out of the others.
    ///
    /// Resolution happens here, at write time, so the stored config is always
    /// already disjoint and the shield never has to arbitrate. Returns the rules
    /// the selection was pulled out of, so the picker can say so.
    @discardableResult
    func setSelection(_ selection: AppSelection, rule: BlockRule) -> [BlockRule] {
        var displaced: [BlockRule] = []
        for other in BlockRule.allCases where other != rule {
            // Pull anything this pick claims out of the other lanes, per app, so
            // the stored config is always disjoint. Set-subtract on real tokens
            // (device) or catalogue names (Simulator) — a whole-blob equality
            // check would miss any lane that only partly overlaps.
            let trimmed = blockConfig[other].subtracting(selection)
            if trimmed != blockConfig[other] {
                blockConfig[other] = trimmed
                displaced.append(other)
            }
        }
        blockConfig[rule] = selection
        return displaced
    }

    // MARK: - App Lists (Blocks screen's "App Lists" section)

    // MARK: - Blocking

    /// The Screen Time seam.
    ///
    /// Live on a device, Mock in the Simulator — not a convenience, a
    /// necessity: FamilyControls authorization always fails there, so the whole
    /// blocking half of the app would be untouchable in a simulator build.
    let screenTime: ScreenTimeService = {
        #if targetEnvironment(simulator)
        return MockScreenTimeService()
        #else
        return LiveScreenTimeService()
        #endif
    }()

    /// Subscription entitlement seam. Mock (subscribed) in the Simulator so the
    /// gate never blocks development; `-live-entitlements` opts a simulator run
    /// into the real identity path for reviewer and billing verification.
    let entitlements: EntitlementService = {
        #if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("-live-entitlements") {
            return LiveEntitlementService()
        }
        return MockEntitlementService(subscribed: true)
        #else
        return LiveEntitlementService()
        #endif
    }()

    /// Judges photo proof.
    ///
    /// Mock until `proofEndpoint` is filled in — see `server/README.md`. The
    /// key for the model behind it cannot live in the app: anything in the
    /// binary can be pulled out of it, and then the bill is somebody else's
    /// traffic. `LiveProofVerifier` talks to our own endpoint, which holds it.
    let proofVerifier: ProofVerifier = {
        if let url = proofEndpoint {
            return LiveProofVerifier(endpoint: url)
        }
        return MockProofVerifier()
    }()

    /// The deployed verification endpoint. Set this to nil to fall back to the
    /// mock, which is what the Simulator wants when there's no camera worth
    /// photographing.
    private static let proofEndpoint: URL? =
        URL(string: "https://xafxoixbxaezijooutlw.supabase.co/functions/v1/verify-proof")

    /// True while a re-apply is in flight, so a button can show it working.
    private(set) var isReapplyingBlocking = false
    /// Set when the last re-apply threw, so the caller can say so.
    private(set) var lastBlockingFailed = false

    /// Pushes the current plan onto the shield.
    ///
    /// Called on launch, foreground, config change, unlock start/end, focus
    /// start/end, purchase, and from the manual Reload Aura. Worth having a
    /// button for even once it's live: a `ManagedSettingsStore` can be cleared
    /// by a restart or by a Screen Time change made outside the app, and
    /// re-applying is the only fix a user can perform themselves.
    @discardableResult
    func refreshShield() async -> Bool {
        guard !isReapplyingBlocking else { return !lastBlockingFailed }
        isReapplyingBlocking = true
        lastBlockingFailed = false
        do {
            try await screenTime.apply(currentPlan)
        } catch {
            lastBlockingFailed = true
        }
        isReapplyingBlocking = false
        return !lastBlockingFailed
    }

    var appLists: [AppList] = [
        AppList(name: "Brainrot Apps", appIconNames: ["MessagesIcon", "MusicIcon", "BooksIcon"]),
    ]

    func addAppList(_ list: AppList) {
        appLists.append(list)
    }

    func updateAppList(_ list: AppList) {
        guard let index = appLists.firstIndex(where: { $0.id == list.id }) else { return }
        appLists[index] = list
    }

    func deleteAppList(_ id: UUID) {
        appLists.removeAll { $0.id == id }
    }

    /// When bought time runs out. Absolute rather than a counter, so the
    /// countdown stays true across backgrounding, termination and sleep — a
    /// decrementing integer simply stops while the app isn't running.
    private(set) var unlockEndsAt: Date?
    /// The running Lock In session, if there is one. Held here rather than on
    /// the focus screen so it survives that view going away, and so the Live
    /// Activity has something to mirror.
    private(set) var activeFocusSession: ActiveFocusSession?
    /// When the current stretch of bought time began, so the Island's progress
    /// bar has something to measure against.
    private var unlockStartedAt: Date?

    /// The clock every countdown on screen is measured against. One ticker for
    /// the whole store rather than one per timer, and it only runs while
    /// something is actually counting.
    private(set) var now: Date = .now

    var isUnlocked: Bool { secondsRemaining > 0 }
    var secondsRemaining: Int {
        guard let unlockEndsAt else { return 0 }
        return max(0, Int(unlockEndsAt.timeIntervalSince(now).rounded(.up)))
    }

    // MARK: - Lifetime achievement counters
    //
    // Completion funnels persist real counters. Fresh Release installs start
    // at zero; Debug builds retain demo seeds for development.

    private enum LifetimeKey {
        static let earnedMinutes = "aura.lifetime.earnedMinutes"
        static let healthyHabits = "aura.lifetime.healthyHabits"
        static let reps = "aura.lifetime.reps"
        static let focusMinutes = "aura.lifetime.focusMinutes"
    }

    /// Reads a persisted counter, seeding (and storing) it the first time.
    private static func loadLifetime(_ key: String, seed: Int) -> Int {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: key) != nil {
            return defaults.integer(forKey: key)
        }
        #if DEBUG
        defaults.set(seed, forKey: key)
        return seed
        #else
        return 0
        #endif
    }

    /// Lifetime screen-time earned through the habit loop, in minutes.
    var lifetimeEarnedMinutes: Int = HabitStore.loadLifetime(LifetimeKey.earnedMinutes, seed: 312) {
        didSet { persistActiveAccount() }
    }

    /// Healthy Habits completed all time — the photoTask category only, both its
    /// Focus and Quick kinds. Bumped in `completeHabitToday(habit:)`.
    var lifetimeHealthyHabits: Int = HabitStore.loadLifetime(LifetimeKey.healthyHabits, seed: 142) {
        didSet { persistActiveAccount() }
    }
    /// Reps counted by the exercise camera, all time. Bumped in
    /// `addExerciseSession(earnedMinutes:reps:)`.
    var lifetimeReps: Int = HabitStore.loadLifetime(LifetimeKey.reps, seed: 1240) {
        didSet { persistActiveAccount() }
    }
    /// Minutes held in Deep Focus sessions, all time. Bumped in
    /// `addDeepFocusSession(durationMinutes:earnedMinutes:)`.
    var lifetimeFocusMinutes: Int = HabitStore.loadLifetime(LifetimeKey.focusMinutes, seed: 2050) {
        didSet { persistActiveAccount() }
    }

    // MARK: - Time saved (baseline vs now)

    private static let kBaselineWeekly = "aura.lifetime.baselineWeeklyScreen"

    /// The user's first-week screen-time total (minutes), captured once the
    /// account is a week old. `nil` until then — the Time Saved achievement
    /// stays hidden. Persisted so it's captured exactly once.
    private(set) var baselineWeeklyScreenMinutes: Int? = HabitStore.loadBaselineWeekly() {
        didSet { persistActiveAccount() }
    }

    private static func loadBaselineWeekly() -> Int? {
        let defaults = UserDefaults.standard
        #if DEBUG
        // Seed a heavier first week in the sim so Time Saved demos with a real
        // number. The live-capture path below is what runs on device.
        if defaults.object(forKey: kBaselineWeekly) == nil {
            defaults.set(2400, forKey: kBaselineWeekly)   // 40h that first week
            return 2400
        }
        #endif
        return defaults.object(forKey: kBaselineWeekly) == nil
            ? nil
            : defaults.integer(forKey: kBaselineWeekly)
    }

    /// Captures the baseline once the account reaches a week old and it hasn't
    /// been set. Fed the current week's total by the view — the store has no
    /// screen-time source of its own. No-op once captured.
    func captureScreenTimeBaselineIfNeeded(currentWeeklyMinutes: Int) {
        guard baselineWeeklyScreenMinutes == nil, daysSinceInstall >= 7 else { return }
        baselineWeeklyScreenMinutes = currentWeeklyMinutes
    }

    /// All-time screen-time saved versus the baseline week, in minutes. `nil`
    /// until the baseline exists (the card stays hidden). Estimated as the
    /// current daily improvement projected across the days since the baseline
    /// week — the best available reading without a stored screen-time history.
    func timeSavedMinutes(currentWeeklyMinutes: Int) -> Int? {
        guard let baseline = baselineWeeklyScreenMinutes, daysSinceInstall >= 7 else { return nil }
        let savedPerDay = max(0, Double(baseline - currentWeeklyMinutes) / 7)
        let daysImproving = max(0, daysSinceInstall - 7)
        return Int((savedPerDay * Double(daysImproving)).rounded())
    }

    /// Coins earned *today* — drives the Home "Earned Today" charge bar against
    /// `dailyCoinGoal`. Coins and minutes are 1:1 (1 coin buys 1 minute), so
    /// every earn path adds to this. Sample value for now.
    /// TODO: reset at local midnight once the DeviceActivity feed is wired.
    /// Derived from today's log entry rather than counted alongside it.
    ///
    /// It used to be a stored `var` incremented in the same breath as the log —
    /// two copies of one number, and the copy had no date on it, so it survived
    /// midnight and reported yesterday's total as today's.
    var todayEarnedCoins: Int {
        let today = Calendar.current.startOfDay(for: .now)
        return dayRecords.first { Calendar.current.isDate($0.date, inSameDayAs: today) }?.coinsEarned ?? 0
    }

    /// The user's daily coin target. User-editable later via Earn Settings;
    /// fixed default for now.
    var dailyCoinGoal: Int = 100 { didSet { persistActiveAccount() } }

    /// Progress toward today's coin goal, clamped to 0…1.
    var dailyGoalProgress: Double {
        min(1, Double(todayEarnedCoins) / Double(max(1, dailyCoinGoal)))
    }

    /// Spendable Aura coin balance — the screen time the user currently has to
    /// What's left today: earned minus spent, 1 coin = 1 minute.
    ///
    /// Uncapped — it's a balance, and a ceiling on what you're allowed to have
    /// banked would punish the exact behaviour the app is asking for.
    ///
    /// Derived, so it resets at midnight on its own. Both sides of the sum are
    /// dated — the day log for earnings, `purchases` for spend — which means
    /// there's nothing to schedule and nothing to remember to zero.
    var coinBalance: Int {
        let calendar = Calendar.current
        let spentToday = purchases
            .filter { calendar.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.minutes }
        return Swift.max(0, todayEarnedCoins - spentToday)
    }

    /// The display name shown on the Profile page. Set from Sign in with Apple
    /// during setup; persisted locally (cross-device sync waits on the backend).
    private static let kDisplayName = "aura.profile.displayName"
    #if DEBUG
    private static let defaultDisplayName = "Hayden Berio"
    #else
    private static let defaultDisplayName = ""
    #endif
    var displayName: String = (UserDefaults.standard.string(forKey: HabitStore.kDisplayName)) ?? HabitStore.defaultDisplayName {
        didSet { persistActiveAccount() }
    }

    /// The account email, from Sign in with Apple. Empty until signed in.
    private static let kEmail = "aura.profile.email"
    var email: String = (UserDefaults.standard.string(forKey: HabitStore.kEmail)) ?? "" {
        didSet { persistActiveAccount() }
    }

    /// True once the user has signed in (Apple). Drives whether Settings shows the
    /// account as connected.
    private static let kSignedIn = "aura.profile.signedIn"
    var isSignedIn: Bool = UserDefaults.standard.bool(forKey: HabitStore.kSignedIn) {
        didSet {
            if runsRuntimeSideEffects {
                UserDefaults.standard.set(isSignedIn, forKey: Self.kSignedIn)
            }
        }
    }

    /// Resolved for this process and identity. Never trust the legacy ownerless
    /// persisted subscription flag at launch; RevenueCat/web cache resolve it.
    private(set) var isSubscribed = false
    private var subscriptionRevision: UInt = 0
    private var subscriptionResetInProgress = false
    private var subscriptionOperationInFlight = false
    private var subscriptionBlockedAccountID: UUID?
    private var subscriptionResolvedAccountID: UUID?

    @MainActor
    private func beginSubscriptionRequest() -> (revision: UInt, account: UUID?)? {
        guard !subscriptionResetInProgress, !subscriptionOperationInFlight else { return nil }
        let account = SupabaseManager.shared.currentUserID
        if let blocked = subscriptionBlockedAccountID, blocked == account { return nil }
        if let owner = subscriptionResolvedAccountID, owner != account { isSubscribed = false }
        configureEntitlement()
        subscriptionRevision &+= 1
        return (subscriptionRevision, account)
    }

    @MainActor
    private func subscriptionRequestIsCurrent(_ request: (revision: UInt, account: UUID?)) -> Bool {
        !subscriptionResetInProgress && subscriptionRevision == request.revision
            && SupabaseManager.shared.currentUserID == request.account
    }

    /// Re-reads access on launch/foreground. A refresh cannot race an explicit
    /// purchase or restore, and a superseded refresh cannot overwrite its result.
    @MainActor
    func refreshEntitlement() async {
        guard let request = beginSubscriptionRequest() else { return }
        let active = await entitlements.currentlySubscribed()
        guard subscriptionRequestIsCurrent(request) else { return }
        subscriptionResolvedAccountID = request.account
        isSubscribed = active
    }

    /// The returning-account gate needs a committed result, not an ordinary
    /// refresh that a newer foreground refresh can supersede. Use the same lock
    /// as purchase/restore until this account's result is committed; nil means
    /// the caller must stay on its current route and offer a retry.
    @MainActor
    func refreshEntitlementForSignIn() async -> Bool? {
        guard let request = beginSubscriptionRequest(), request.account != nil else { return nil }
        subscriptionOperationInFlight = true
        defer {
            if subscriptionRevision == request.revision { subscriptionOperationInFlight = false }
        }
        let active = await entitlements.currentlySubscribed()
        guard subscriptionRequestIsCurrent(request) else { return nil }
        subscriptionResolvedAccountID = request.account
        isSubscribed = active
        return active
    }

    @discardableResult @MainActor
    func subscribe() async -> Bool {
        await performSubscriptionOperation(restoring: false)
    }

    @discardableResult @MainActor
    func restorePurchase() async -> Bool {
        await performSubscriptionOperation(restoring: true)
    }

    @MainActor
    private func performSubscriptionOperation(restoring: Bool) async -> Bool {
        guard let request = beginSubscriptionRequest() else { return false }
        subscriptionOperationInFlight = true
        defer {
            if subscriptionRevision == request.revision { subscriptionOperationInFlight = false }
        }
        var active: Bool
        if restoring { active = await entitlements.restore() }
        else { active = await entitlements.purchaseDefault() }
        guard subscriptionRequestIsCurrent(request) else { return false }
        if !active {
            active = await entitlements.currentlySubscribed()
            guard subscriptionRequestIsCurrent(request) else { return false }
        }
        subscriptionResolvedAccountID = request.account
        isSubscribed = active
        return active
    }

    /// Anonymous onboarding purchases are linked by RevenueCat logIn when the
    /// Aura account becomes available. Never log out that identity on sign-in.
    private func configureEntitlement() {
        if let uid = SupabaseManager.shared.currentUserID {
            entitlements.configure(userID: uid.uuidString)
        } else {
            entitlements.configureAnonymous()
        }
    }

    /// Records a successful Sign in with Apple. Apple only returns the name and
    /// email on the FIRST authorization, so we keep whatever we already have when
    /// a later sign-in omits them.
    func applySignIn(fullName: String?, email newEmail: String?) {
        guard !subscriptionResetInProgress,
              let accountID = SupabaseManager.shared.currentUserID else { return }
        guard activateAccount(accountID) else {
            SupportChatStore.shared.switchAccount(to: nil)
            return
        }
        SupportChatStore.shared.switchAccount(to: accountID)
        subscriptionRevision &+= 1
        subscriptionOperationInFlight = false
        subscriptionBlockedAccountID = nil
        if let owner = subscriptionResolvedAccountID, owner != SupabaseManager.shared.currentUserID {
            isSubscribed = false
        }
        // Start linking immediately, before the setup UI advances or any cloud
        // sync can suspend. Existing anonymous access remains until resolution.
        configureEntitlement()
        if let fullName, !fullName.isEmpty { displayName = fullName }
        if let newEmail, !newEmail.isEmpty { email = newEmail }
        isSignedIn = true
        // Just signed in: pull this account's history and library, merge them
        // with whatever is on this device, and push the result back.
        Task { @MainActor in
            guard let request = self.accountRequest() else { return }
            await refreshEntitlement()
            guard requestIsCurrent(request) else { return }
            await syncProgress(request)
            await syncLibrary(request)
            await syncAvatar(request)
        }
    }

    /// Brings `isSignedIn` and the cached identity in line with the actual
    /// Supabase session at launch. A session can be gone even though the flag
    /// persisted; when it is present, name/email are refreshed from the server so
    /// a fresh device shows the real account rather than defaults.
    @MainActor
    private func reconcileAuth() async {
        let revision = subscriptionRevision
        let valid = await SupabaseManager.shared.hasValidSession()
        guard !subscriptionResetInProgress, subscriptionRevision == revision else { return }
        if let blocked = subscriptionBlockedAccountID,
           blocked == SupabaseManager.shared.currentUserID { return }
        guard valid else {
            SupportChatStore.shared.switchAccount(to: nil)
            _ = activateAccount(nil)
            await refreshEntitlement()
            return
        }
        guard let accountID = SupabaseManager.shared.currentUserID else {
            _ = activateAccount(nil)
            return
        }
        guard activateAccount(accountID) else {
            SupportChatStore.shared.switchAccount(to: nil)
            return
        }
        SupportChatStore.shared.switchAccount(to: accountID)
        configureEntitlement()
        await refreshEntitlement()
        guard let request = accountRequest(), request.owner == accountID else { return }
        if let profile = try? await SupabaseManager.shared.fetchProfile(expectedUserID: accountID),
           requestIsCurrent(request) {
            if let name = profile.displayName, !name.isEmpty { displayName = name }
            if let mail = profile.email, !mail.isEmpty { email = mail }
        }
        guard requestIsCurrent(request) else { return }
        await syncProgress(request)
        await syncLibrary(request)
        await syncAvatar(request)
        await refreshEntitlement()
    }

    /// Permanently deletes the account and resets this device to a clean slate.
    /// When signed in, deletes the server account first (auth user + every owned
    /// row and Storage object, via the `delete-account` function); if that fails
    /// it throws and nothing local is touched, so the user can retry. Then it
    /// wipes the local identity and progress so "all your data will be removed"
    /// is honest and nothing lingers on the device.
    @MainActor
    func deleteAccount() async throws {
        guard !subscriptionResetInProgress, let request = accountRequest() else { return }
        let supportAccount = runsRuntimeSideEffects ? SupportChatStore.shared.accountID : nil
        if runsRuntimeSideEffects { SupportChatStore.shared.switchAccount(to: nil) }
        subscriptionResetInProgress = true
        subscriptionRevision &+= 1
        subscriptionOperationInFlight = false
        do {
            try await accountDependencies.deleteRemote(request.owner)
        } catch {
            // A failed deletion keeps this account active. Restore only that same
            // account's support cache, never a different session's conversation.
            if runsRuntimeSideEffects, requestIsCurrent(request),
               supportAccount == accountDependencies.currentUserID() {
                SupportChatStore.shared.switchAccount(to: supportAccount)
            }
            subscriptionResetInProgress = false
            throw error
        }
        let localSnapshotRemoved = removeSnapshot(for: request.owner)
        let deletedScope = request.owner.uuidString.lowercased()
        recoverySnapshots.removeValue(forKey: deletedScope)
        recoveryWinPhotos.removeValue(forKey: deletedScope)
        if runsRuntimeSideEffects {
            RoutineStore.removeAccount(ownerID: request.owner)
            SupportChatStore.shared.removeAccountCache(for: request.owner)
        }
        _ = activateAccount(nil, persistCurrent: false)
        if !localSnapshotRemoved { accountPersistenceFailed = true }
        isSubscribed = false
        subscriptionResolvedAccountID = nil
        if runsRuntimeSideEffects { await entitlements.resetIdentity() }
        subscriptionResetInProgress = false
    }

    var accountHealthWatermarkForTesting: ([String: Double], Date) {
        (healthCollectedToday, healthCollectedDay)
    }

    func setAccountHealthWatermarkForTesting(_ amounts: [String: Double], day: Date) {
        healthCollectedToday = amounts
        healthCollectedDay = day
        persistActiveAccount()
    }

    func accountSnapshotURLForTesting(ownerID: UUID?) -> URL? {
        snapshotURL(ownerID?.uuidString.lowercased() ?? Self.signedOutScope)
    }

    @discardableResult
    func setWinsForTesting(_ values: [Win], capturedPhotos: [String: Data]) -> Bool {
        guard !runsRuntimeSideEffects, let directory = activeWinsDirectory else { return false }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for (filename, data) in capturedPhotos {
                if accountDependencies.shouldFail(.writePhoto) { throw CocoaError(.fileWriteUnknown) }
                try data.write(to: directory.appendingPathComponent(filename), options: .atomic)
            }
            wins = values
            return persistActiveAccount(includeWinPhotos: true)
        } catch {
            accountPersistenceFailed = true
            return false
        }
    }

    func activeWinPhotoURLForTesting(filename: String) -> URL? {
        activeWinsDirectory?.appendingPathComponent(filename)
    }

    /// Revoke access before either SDK can suspend. If Supabase cannot end its
    /// session, suppress entitlement reads for that account until explicit login.
    @MainActor
    func signOut() async {
        guard !subscriptionResetInProgress else { return }
        SupportChatStore.shared.switchAccount(to: nil)
        subscriptionResetInProgress = true
        subscriptionRevision &+= 1
        subscriptionOperationInFlight = false
        let accountID = activeAccountID ?? SupabaseManager.shared.currentUserID
        subscriptionBlockedAccountID = accountID
        _ = activateAccount(nil)
        isSubscribed = false
        subscriptionResolvedAccountID = nil
        await entitlements.resetIdentity()
        try? await SupabaseManager.shared.signOut()
        subscriptionResetInProgress = false
    }

    // MARK: - Progress sync

    /// Pulls the account's day-log, merges it into local, and pushes the union.
    ///
    /// Merge, not replace: two devices earning on different days both keep their
    /// days, and a day earned on both keeps the higher total. This is what makes
    /// streak, journey and stats follow the account across devices. The spendable
    /// balance stays device-local (a purchase unlocks apps on one device), so
    /// only the earn history travels.
    @MainActor
    private func syncProgress(_ request: (owner: UUID, revision: UInt)) async {
        guard requestIsCurrent(request) else { return }
        if let remote = try? await SupabaseManager.shared.fetchProgress(expectedUserID: request.owner) {
            guard requestIsCurrent(request) else { return }
            if let remoteRecords = remote.records {
                let merged = Self.mergeDayRecords(local: dayRecords, remote: remoteRecords)
                if merged != dayRecords {
                    dayRecords = merged
                    if runsRuntimeSideEffects { DayLogFile.save(dayRecords) }
                }
            }
            if let remoteStats = remote.stats { applyMergedStats(remoteStats) }
        }
        guard requestIsCurrent(request) else { return }
        let records = dayRecords
        let stats = currentStats
        try? await SupabaseManager.shared.pushProgress(
            records, stats: stats, expectedUserID: request.owner)
    }

    /// The achievement counters as one value for the wire.
    private var currentStats: SupabaseManager.SyncStats {
        .init(earnedMinutes: lifetimeEarnedMinutes,
              healthyHabits: lifetimeHealthyHabits,
              reps: lifetimeReps,
              focusMinutes: lifetimeFocusMinutes,
              baselineWeeklyScreenMinutes: baselineWeeklyScreenMinutes,
              habitCompletionCounts: habitCompletionCounts,
              exerciseCompletionCounts: exerciseCompletionCounts,
              healthCollectCount: healthCollectCount)
    }

    /// Folds the server's counters into local, taking the larger of each. Every
    /// counter only ever grows, so max never drops real progress and it lifts a
    /// fresh device (still on its seed) up to the account's true totals.
    @MainActor
    private func applyMergedStats(_ remote: SupabaseManager.SyncStats) {
        lifetimeEarnedMinutes = Swift.max(lifetimeEarnedMinutes, remote.earnedMinutes)
        lifetimeHealthyHabits = Swift.max(lifetimeHealthyHabits, remote.healthyHabits)
        lifetimeReps = Swift.max(lifetimeReps, remote.reps)
        lifetimeFocusMinutes = Swift.max(lifetimeFocusMinutes, remote.focusMinutes)
        healthCollectCount = Swift.max(healthCollectCount, remote.healthCollectCount)
        habitCompletionCounts = Self.mergeCounts(habitCompletionCounts, remote.habitCompletionCounts)
        exerciseCompletionCounts = Self.mergeCounts(exerciseCompletionCounts, remote.exerciseCompletionCounts)
        // Captured once on the first device to reach a week old; adopt it if this
        // device never captured its own. Written through to defaults so it sticks.
        if baselineWeeklyScreenMinutes == nil, let baseline = remote.baselineWeeklyScreenMinutes {
            baselineWeeklyScreenMinutes = baseline
        }
    }

    private static func mergeCounts(_ local: [String: Int], _ remote: [String: Int]) -> [String: Int] {
        var merged = local
        for (key, value) in remote { merged[key] = Swift.max(merged[key] ?? 0, value) }
        return merged
    }

    /// One record per day, keeping the richer of any two that share a day. A
    /// day's record only grows as coins are earned, so "more coins wins" is a
    /// safe tie-break that never drops a completion.
    private static func mergeDayRecords(local: [DayRecord], remote: [DayRecord]) -> [DayRecord] {
        let calendar = Calendar.current
        var byDay: [Date: DayRecord] = [:]
        for record in local + remote {
            let key = calendar.startOfDay(for: record.date)
            if let existing = byDay[key], existing.coinsEarned >= record.coinsEarned { continue }
            byDay[key] = record
        }
        return byDay.values.sorted { $0.date < $1.date }
    }

    /// Debounced push after an earn. Coalesces a burst of credits into one write
    /// a couple of seconds after the last one, so an earn animation never waits
    /// on the network.
    private var progressPushTask: Task<Void, Never>?
    private func syncProgressUp() {
        guard runsRuntimeSideEffects else { return }
        guard let request = accountRequest() else { return }
        let records = dayRecords
        let stats = currentStats
        progressPushTask?.cancel()
        progressPushTask = Task { @MainActor [weak self, records, stats, request] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled, let self, self.requestIsCurrent(request) else { return }
            try? await SupabaseManager.shared.pushProgress(
                records, stats: stats, expectedUserID: request.owner)
        }
    }

    // MARK: - Library sync (habits + routines, last-write-wins)

    /// True while adopting the server's library, so `habits`'s didSet and the
    /// routine hook don't treat the adoption as a fresh local edit.
    private var isApplyingRemoteLibrary = false

    private static let kLibraryUpdatedAt = "aura.sync.libraryUpdatedAt"
    /// When this device last changed its library. 1970 (the default) on a device
    /// that never edited, so the account's library always wins there.
    private var libraryUpdatedAt: Date {
        get { accountLibraryUpdatedAt }
        set {
            accountLibraryUpdatedAt = newValue
            persistActiveAccount()
        }
    }

    /// Called when the user edits a routine (the routine store is static, so the
    /// routine sheet calls this after saving), mirroring what `habits`'s didSet
    /// does for habit edits.
    func libraryChangedLocally() {
        libraryUpdatedAt = .now
        syncLibraryUp()
    }

    private var libraryPushTask: Task<Void, Never>?
    private func syncLibraryUp() {
        guard runsRuntimeSideEffects else { return }
        guard let request = accountRequest() else { return }
        let library = SupabaseManager.SyncLibrary(
            updatedAt: libraryUpdatedAt, habits: habits, routines: RoutineStore.all(), wins: wins)
        libraryPushTask?.cancel()
        libraryPushTask = Task { @MainActor [weak self, library, request] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled, let self, self.requestIsCurrent(request) else { return }
            try? await SupabaseManager.shared.pushLibrary(library, expectedUserID: request.owner)
        }
    }

    /// Reconciles the library with the server. Last-write-wins: if the server's
    /// copy is newer than this device's last edit, adopt it (habits + routines);
    /// otherwise push local. Adopting is guarded so it doesn't re-stamp as local.
    @MainActor
    private func syncLibrary(_ request: (owner: UUID, revision: UInt)) async {
        guard requestIsCurrent(request) else { return }
        if let remote = try? await SupabaseManager.shared.fetchLibrary(expectedUserID: request.owner),
           requestIsCurrent(request),
           remote.updatedAt > libraryUpdatedAt {
            isApplyingRemoteLibrary = true
            HabitFile.save(remote.habits)
            habits = HabitStore.mergedHabits()   // re-merge the adopted file with this build's seed
            await RoutineStore.replaceAll(remote.routines)
            guard requestIsCurrent(request) else {
                isApplyingRemoteLibrary = false
                return
            }
            wins = remote.wins
            WinLibrary.save(remote.wins)
            isApplyingRemoteLibrary = false
            libraryUpdatedAt = remote.updatedAt
            await downloadMissingWinPhotos(request)
        } else {
            guard requestIsCurrent(request) else { return }
            let library = SupabaseManager.SyncLibrary(
                updatedAt: libraryUpdatedAt, habits: habits, routines: RoutineStore.all(), wins: wins)
            try? await SupabaseManager.shared.pushLibrary(library, expectedUserID: request.owner)
            guard requestIsCurrent(request) else { return }
            await uploadUnsyncedWinPhotos(request)
        }
    }

    /// Pulls down any captured win photo whose file isn't on this device yet
    /// (the metadata came from the account, the JPEG hasn't). Re-assigns `wins`
    /// afterward so the grid redraws with the photos that just landed.
    @MainActor
    private func downloadMissingWinPhotos(_ request: (owner: UUID, revision: UInt)) async {
        var landed = false
        for win in wins {
            guard requestIsCurrent(request) else { return }
            guard case .captured(let filename) = win.photo,
                  let url = WinLibrary.photoURL(filename),
                  !FileManager.default.fileExists(atPath: url.path) else { continue }
            if let data = await SupabaseManager.shared.downloadWinPhoto(
                winID: win.id.uuidString, expectedUserID: request.owner),
               requestIsCurrent(request) {
                try? data.write(to: url, options: .atomic)
                landed = true
            }
        }
        if landed { wins = wins }   // nudge @Observable so views re-read the files
    }

    /// Uploads captured win photos the server doesn't have yet (wins created
    /// before this device had an account, say). Best-effort; upsert is idempotent.
    private func uploadUnsyncedWinPhotos(_ request: (owner: UUID, revision: UInt)) async {
        for win in wins {
            guard requestIsCurrent(request) else { return }
            guard case .captured(let filename) = win.photo,
                  let url = WinLibrary.photoURL(filename),
                  let data = try? Data(contentsOf: url) else { continue }
            try? await SupabaseManager.shared.uploadWinPhoto(
                winID: win.id.uuidString, jpeg: data, expectedUserID: request.owner)
        }
    }

    /// The user's chosen profile picture (downscaled JPEG), persisted locally.
    /// nil until they pick one. Server sync waits on the account backend.
    private static let kProfileImage = "aura.profile.imageData"
    var profileImageData: Data? = UserDefaults.standard.data(forKey: HabitStore.kProfileImage) {
        didSet {
            persistActiveAccount()
            // Mirror the change to the private bucket, unless we're the ones who
            // just pulled it down.
            if !isApplyingRemoteAvatar && !isApplyingAccountSnapshot { syncAvatarUp() }
        }
    }

    /// True while adopting the server's avatar, so setting it doesn't echo back up.
    private var isApplyingRemoteAvatar = false

    private func syncAvatarUp() {
        guard runsRuntimeSideEffects else { return }
        guard let request = accountRequest() else { return }
        let data = profileImageData
        Task { @MainActor [weak self, data, request] in
            guard let self, self.requestIsCurrent(request) else { return }
            if let data {
                try? await SupabaseManager.shared.uploadAvatar(
                    jpeg: data, expectedUserID: request.owner)
            } else {
                await SupabaseManager.shared.deleteAvatar(expectedUserID: request.owner)
            }
        }
    }

    /// Reconciles the profile picture with the bucket. A device that has one
    /// makes sure the server has it; a device without one adopts the server's.
    @MainActor
    private func syncAvatar(_ request: (owner: UUID, revision: UInt)) async {
        guard requestIsCurrent(request) else { return }
        if let local = profileImageData {
            try? await SupabaseManager.shared.uploadAvatar(
                jpeg: local, expectedUserID: request.owner)
        } else if let remote = await SupabaseManager.shared.downloadAvatar(
            expectedUserID: request.owner), requestIsCurrent(request) {
            isApplyingRemoteAvatar = true
            profileImageData = remote
            isApplyingRemoteAvatar = false
        }
    }

    /// Persisted local account age, widened by any older synced history. This is
    /// an actual date basis rather than the former hard-coded 35-day sample.
    var daysSinceInstall: Int {
        let historyStart = dayRecords.map(\.date).min() ?? accountFirstSeenAt
        let start = min(historyStart, accountFirstSeenAt)
        return max(0, Calendar.current.dateComponents(
            [.day], from: Calendar.current.startOfDay(for: start),
            to: Calendar.current.startOfDay(for: .now)).day ?? 0)
    }

    /// Device-local allowance, independent of account switching. Persist the
    /// next Monday boundary so relaunching cannot grant another pass.
    private static let emergencyUnlockResetKey = "aura.emergencyUnlock.resetAt.v1"
    private(set) var emergencyUnlockResetAt: Date? =
        UserDefaults.standard.object(forKey: HabitStore.emergencyUnlockResetKey) as? Date {
        didSet {
            UserDefaults.standard.set(emergencyUnlockResetAt, forKey: Self.emergencyUnlockResetKey)
        }
    }

    var emergencyUnlockUsed: Bool { emergencyUnlockIsUsed(at: now) }

    func emergencyUnlockIsUsed(at date: Date) -> Bool {
        guard let reset = emergencyUnlockResetAt else { return false }
        return date < reset
    }

    /// Preserve the pass screen's existing Monday-midnight, device-local rule.
    static func emergencyUnlockResetDate(after date: Date, calendar: Calendar = .current) -> Date {
        let weekday = calendar.component(.weekday, from: date)
        let days = (9 - weekday) % 7
        return calendar.date(byAdding: .day, value: days == 0 ? 7 : days,
                             to: calendar.startOfDay(for: date))
            ?? date.addingTimeInterval(7 * 24 * 60 * 60)
    }

    private var ticker: Timer?

    /// Dev-only affordance for this pass — real earn mechanic isn't built yet.
    /// Wired to the Gate screen's gear icon; toggles locked/unlocked and, when
    /// unlocking, seeds a demo countdown that ticks down for real.
    func devToggleUnlock() {
        if isUnlocked {
            lock()
        } else {
            unlock(seconds: 5 * 60)
        }
    }

    /// Opens the phone for `seconds`, extending any time already running.
    /// `replacing` sets a fresh window from now instead of stacking onto any
    /// time already on the clock — the Emergency Pass grants exactly one hour,
    /// not an hour on top of whatever was left.
    private func unlock(seconds: Int, replacing: Bool = false) {
        // Anchor to real time first. `now` only advances while something is
        // ticking, so if nothing was counting down it could be minutes stale —
        // and computing the window from a stale `now` silently shortened it (buy
        // 10 min, `now` 4 min behind, tick catches up → only 6 min left).
        now = .now
        if replacing {
            // A fresh window from now, but never shorter than what's already on
            // the clock — the free Emergency Pass hour can't take away time the
            // user paid coins for. With nothing on the clock this is exactly the
            // hour; with more already bought, that longer window stands.
            let fresh = now.addingTimeInterval(TimeInterval(seconds))
            if (unlockEndsAt ?? now) < fresh {
                unlockStartedAt = now
                unlockEndsAt = fresh
            }
        } else {
            let from = max(now, unlockEndsAt ?? now)
            if unlockEndsAt == nil { unlockStartedAt = now }
            unlockEndsAt = from.addingTimeInterval(TimeInterval(seconds))
        }
        // Handed to the system as well as kept here. `tick` only runs while
        // Aura is alive, and someone force-quitting during bought time is
        // exactly the case that still has to end.
        if let unlockEndsAt { screenTime.scheduleReshield(at: unlockEndsAt) }
        // The whole point of buying time is that the apps open. `lock` had its
        // matching re-apply; this side didn't, so the shield stayed up until
        // something else happened to refresh it.
        Task { await refreshShield() }
        startTicking()
        syncLiveActivity()
    }

    private func lock() {
        unlockEndsAt = nil
        unlockStartedAt = nil
        // The app got there first, so the safety net isn't needed.
        screenTime.cancelScheduledReshield()
        Task { await refreshShield() }
        stopTickingIfIdle()
        syncLiveActivity()
    }

    /// One second of wall clock, applied to whatever is running.
    ///
    /// Nothing is decremented here — `now` moves and every countdown is derived
    /// from it. The tick's only job is to notice when something has *finished*,
    /// which is the one thing a derived value can't do for itself.
    private func tick() {
        now = .now

        if var session = activeHabitSession, !session.isPaused,
           session.remainingSeconds(at: now) == 0 {
            let reward = session.rewardMinutes
            session.endsAt = nil
            endHabitSession()
            grantScreenTime(minutes: reward, method: sessionMethod)
            // THIS is where a focus habit counts, not where its photo passed.
            // The photo proves you started; sitting through the timer is the
            // thing being rewarded. Booking the day at photo time meant you
            // could snap a book, take the streak, kill the session and keep it.
            let habit = session.habitId.flatMap { id in habits.first { $0.id == id } }
            if completeHabitToday(habit: habit) { pendingStreakCelebration = true }
            return
        }

        // A timed Lock In that ran out. Settled here rather than on the focus
        // screen so it still pays when the app was closed at the moment it
        // finished — the screen may not exist any more, but the promise does.
        if let focus = activeFocusSession, !focus.isOpenEnded,
           focus.remainingSeconds(at: now) == 0 {
            focusSessionPayout = finishFocusSession(banking: true)
        }

        if unlockEndsAt != nil, secondsRemaining == 0 { lock() }
        // Cheap, and the only thing that notices a Live Activity that failed to
        // start or went away without the app being told.
        LiveActivityController.heal()
        stopTickingIfIdle()
    }

    private func startTicking() {
        guard ticker == nil else { return }
        now = .now
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    /// Stops the clock when there's nothing left to count, so a store sitting
    /// idle isn't waking every second for the rest of the session.
    private func stopTickingIfIdle() {
        guard activeHabitSession == nil, unlockEndsAt == nil, activeFocusSession == nil else { return }
        ticker?.invalidate()
        ticker = nil
    }

    /// Mirrors whatever is counting down onto the Dynamic Island.
    ///
    /// Reads `gateCountdown`'s own precedence rather than deciding again: a
    /// session outranks bought time on Home, so it does on the Island too.
    private func syncLiveActivity() {
        saveRunningTimers()

        // Lock In first: it's a full-screen mode, so nothing else can be the
        // thing the user is actually doing while it runs.
        if let focus = activeFocusSession {
            LiveActivityController.show(.init(kind: .focus,
                                              startedAt: focus.startedAt,
                                              endsAt: focus.endsAt))
            return
        }

        if let session = activeHabitSession {
            let ends = session.endsAt
                ?? now.addingTimeInterval(TimeInterval(session.remainingSeconds(at: now)))
            LiveActivityController.show(.init(kind: sessionMethod == .focus ? .focus : .habit,
                                              startedAt: ends.addingTimeInterval(-Double(session.totalSeconds)),
                                              endsAt: ends,
                                              pausedRemaining: session.pausedRemaining))
            return
        }

        if let unlockEndsAt, secondsRemaining > 0 {
            // Bought time has no fixed total — buying again extends it — so the
            // bar measures this stretch from when it was last topped up.
            LiveActivityController.show(.init(kind: .scrolling,
                                              startedAt: unlockStartedAt ?? now,
                                              endsAt: unlockEndsAt))
            return
        }

        LiveActivityController.end()
    }

    // MARK: - Lock In

    /// Starts a Lock In session and puts it on the Island.
    ///
    /// `isUntimed` is Extreme Focus: no end date, so the Island counts up and
    /// drops the progress bar. Ending is the user's call either way — the store
    /// holds the anchors and mirrors them, but the focus screen still owns what
    /// a finished session is worth.
    func startFocusSession(lengthMinutes: Int, isUntimed: Bool, earnRate: Double) {
        activeFocusSession = ActiveFocusSession(
            startedAt: .now,
            endsAt: isUntimed ? nil : Date.now.addingTimeInterval(TimeInterval(lengthMinutes * 60)),
            lengthMinutes: lengthMinutes,
            earnRate: earnRate
        )
        // The clock has to run for this too, or `heal()` never gets a chance to
        // put back an activity that failed to start.
        startTicking()
        Task { await refreshShield() }
        syncLiveActivity()
    }

    /// Stops a session and banks what it earned.
    ///
    /// Returns what was paid, so the screen that's watching can decide whether
    /// there's a celebration to show — and returns 0 when nothing was earned,
    /// which is what leaving a timed session early means.
    @discardableResult
    func finishFocusSession(banking: Bool) -> Int {
        guard let session = activeFocusSession else { return 0 }
        activeFocusSession = nil

        var earned = 0
        if banking {
            earned = session.earnedMinutes(at: .now)
            if earned > 0 {
                let minutes = session.isOpenEnded
                    ? session.elapsedSeconds(at: .now) / 60
                    : session.lengthMinutes
                addDeepFocusSession(durationMinutes: minutes, earnedMinutes: earned)
            }
        }

        stopTickingIfIdle()
        Task { await refreshShield() }
        syncLiveActivity()
        return earned
    }

    /// A timed session that ran out while nobody was watching.
    ///
    /// Set by `tick`, cleared by the focus screen once it has shown the result.
    /// Without it a session that completed with the app closed would pay out
    /// silently and the user would never see the celebration they earned.
    private(set) var focusSessionPayout: Int?

    func clearFocusSessionPayout() { focusSessionPayout = nil }

    // MARK: - Surviving a restart

    /// Picks up whatever was still running when the app went away.
    ///
    /// Anything that finished in the meantime is *not* resurrected — `tick`
    /// runs immediately after and settles it, so a session that ran out while
    /// the app was gone pays out on the way back in rather than sitting there
    /// at zero.
    private func restoreRunningTimers() {
        let saved = RunningTimersFile.load()
        guard !saved.isEmpty else { return }

        now = .now
        unlockStartedAt = saved.unlockStartedAt
        unlockEndsAt = saved.unlockEndsAt
        activeHabitSession = saved.habit
        sessionMethod = saved.habitMethod ?? .photoTask
        activeFocusSession = saved.focus

        startTicking()
        tick()
        syncLiveActivity()
    }

    /// Writes the running clocks down. Called from every place that starts,
    /// stops or pauses one — via `syncLiveActivity`, which already runs at
    /// exactly those moments.
    private func saveRunningTimers() {
        if runsRuntimeSideEffects { RunningTimersFile.save(currentRunningTimers()) }
        persistActiveAccount()
    }

    /// Re-reads the clock after time has passed with the app asleep. Nothing
    /// ticks in the background, so `now` is stale on return and a finished
    /// session would otherwise sit there unclaimed.
    func refreshClock() {
        now = .now
        tick()
        // Sweeping strays used to happen here, before the sync. On a fresh
        // launch that meant killing the activity the previous run left up and
        // hoping the replacement request succeeded. The controller adopts it
        // instead, and clears strays around whatever it settles on.
        syncLiveActivity()
    }

    // MARK: - Emergency Unlock

    @discardableResult
    func useEmergencyUnlock() -> Bool {
        let redeemedAt = Date()
        // Check persisted state at the action boundary as well as in the UI.
        // This also protects against another store instance redeeming first.
        let storedReset = UserDefaults.standard.object(forKey: Self.emergencyUnlockResetKey) as? Date
        guard !emergencyUnlockIsUsed(at: redeemedAt),
              storedReset.map({ redeemedAt >= $0 }) ?? true else { return false }
        emergencyUnlockResetAt = Self.emergencyUnlockResetDate(after: redeemedAt)
        // Exactly one hour, matching the pass copy, and a fresh window rather
        // than stacked onto any time already on the clock.
        unlock(seconds: 60 * 60, replacing: true)
        return true
    }

    // MARK: - Deep Focus

    /// Seeded from the same samples the Deep Focus history sheet used to read
    /// directly — now real, mutable state so a completed session shows up
    /// there immediately.
    #if DEBUG
    var deepFocusSessions: [DeepFocusSession] = DeepFocusSession.samples {
        didSet { persistActiveAccount() }
    }
    #else
    var deepFocusSessions: [DeepFocusSession] = [] {
        didSet { persistActiveAccount() }
    }
    #endif

    func addDeepFocusSession(durationMinutes: Int, earnedMinutes: Int) {
        deepFocusSessions.append(DeepFocusSession(durationMinutes: durationMinutes, earnedMinutes: earnedMinutes, date: .now))
        lifetimeEarnedMinutes += earnedMinutes
        lifetimeFocusMinutes += durationMinutes
        recordToday(coins: earnedMinutes, method: .focus)
    }

    /// Coins earned per hour focused, on the same 5/10/15/20 scale as habits.
    var deepFocusRate: Double = 10 { didSet { persistActiveAccount() } }

    func setDeepFocusRate(_ rate: Double) {
        deepFocusRate = min(20, max(5, rate))
    }

    // MARK: - Exercise

    /// Exercise earn rates are fixed at 1 coin per rep / per held second and
    /// aren't user-editable — a habit's rate is only ever set when it's created,
    /// and the stock exercises ship with theirs.
    func rate(for exercise: Exercise) -> Double {
        exercise.defaultMinutesPerUnit
    }

    /// User-set session goal (reps, or held seconds) keyed by `Exercise.id` —
    /// the target that must be hit for the session to count. Absent keys fall
    /// back to the exercise's built-in `unitsToStartEarning`.
    var exerciseGoals: [String: Int] = [:] { didSet { persistActiveAccount() } }

    func goal(for exercise: Exercise) -> Int {
        exerciseGoals[exercise.id] ?? exercise.unitsToStartEarning
    }

    func setGoal(_ goal: Int, for exercise: Exercise) {
        let bounds = 1...200
        exerciseGoals[exercise.id] = min(bounds.upperBound, max(bounds.lowerBound, goal))
    }

    /// Grants the screen time earned from a completed exercise: banks it into
    /// the lifetime total and unlocks the phone for that long (adding to any
    /// time already remaining). No-op for a session that earned nothing.
    func addExerciseSession(earnedMinutes: Int, reps: Int = 0) {
        lifetimeReps += reps
        grantScreenTime(minutes: earnedMinutes, method: .exercise)
    }

    /// One screen-time purchase, for the store's Recent Transactions list.
    /// Purchases only — earning is tracked separately and doesn't belong in a
    /// list of what you spent.
    struct Purchase: Identifiable, Hashable, Codable {
        let id: UUID
        let minutes: Int
        let date: Date

        init(id: UUID = UUID(), minutes: Int, date: Date) {
            self.id = id
            self.minutes = minutes
            self.date = date
        }
    }

    /// Newest first.
    var purchases: [Purchase] = [] { didSet { persistActiveAccount() } }

    // MARK: - Wall of wins

    /// Captured proof photos, newest first. Lives here rather than in the view
    /// so the strip, the grid and the detail all see the same list — deleting
    /// from one has to empty it everywhere.
    private(set) var wins: [Win] = WinLibrary.load() {
        didSet { persistActiveAccount() }
    }

    /// Files the capture and puts it at the top of the wall.
    func addWin(image: UIImage, habit: String, icon: String, date: Date = .now) {
        guard runsRuntimeSideEffects else { return }
        guard let win = WinLibrary.add(image, habit: habit, icon: icon, date: date) else { return }
        wins.insert(win, at: 0)
        WinLibrary.save(wins)
        persistActiveAccount(includeWinPhotos: true)
        libraryChangedLocally()   // pushes the updated win index
        // Upload the photo to the private bucket so it follows the account.
        if let request = accountRequest(),
           case .captured(let filename) = win.photo,
           let url = WinLibrary.photoURL(filename),
           let data = try? Data(contentsOf: url) {
            Task { @MainActor [weak self, request] in
                guard let self, self.requestIsCurrent(request) else { return }
                try? await SupabaseManager.shared.uploadWinPhoto(
                    winID: win.id.uuidString, jpeg: data, expectedUserID: request.owner)
            }
        }
    }

    /// Removes the record and the photograph behind it. There's no recycle bin,
    /// which is what the alerts promise.
    func deleteWin(_ win: Win) {
        guard runsRuntimeSideEffects else { return }
        WinLibrary.removePhoto(for: win)
        wins.removeAll { $0.id == win.id }
        WinLibrary.save(wins)
        persistActiveAccount(includeWinPhotos: true)
        libraryChangedLocally()
        if let request = accountRequest(), case .captured = win.photo {
            Task { @MainActor [weak self, request] in
                guard let self, self.requestIsCurrent(request) else { return }
                await SupabaseManager.shared.deleteWinPhoto(
                    winID: win.id.uuidString, expectedUserID: request.owner)
            }
        }
    }

    func deleteAllWins() {
        guard runsRuntimeSideEffects else { return }
        // A closure, not a method reference — passing `WinLibrary.removePhoto`
        // directly hands a main-actor method to a nonisolated `forEach`.
        let captured = wins.filter { if case .captured = $0.photo { return true }; return false }
        for win in wins { WinLibrary.removePhoto(for: win) }
        wins.removeAll()
        WinLibrary.save(wins)
        persistActiveAccount(includeWinPhotos: true)
        libraryChangedLocally()
        guard let request = accountRequest() else { return }
        Task { @MainActor [weak self, request] in
            for win in captured {
                guard let self, self.requestIsCurrent(request) else { return }
                await SupabaseManager.shared.deleteWinPhoto(
                    winID: win.id.uuidString, expectedUserID: request.owner)
            }
        }
    }

    /// Takes payment for screen time, 1 coin per minute, and logs it. Does not
    /// start the clock — `startPurchasedScreenTime` does, when the user taps
    /// Start Scrolling. Split because paying and scrolling are separate moments:
    /// the coins leave when the card is tapped, the phone opens when they say go.
    ///
    /// Deliberately not `grantScreenTime` — buying isn't earning, so this must
    /// not touch the lifetime or today counters.
    @discardableResult
    func chargeForScreenTime(minutes: Int) -> Bool {
        guard minutes > 0, coinBalance >= minutes else { return false }
        // The purchase IS the deduction — the balance counts it.
        purchases.insert(Purchase(minutes: minutes, date: .now), at: 0)
        return true
    }

    /// Opens the phone for minutes already paid for.
    func startPurchasedScreenTime(minutes: Int) {
        guard minutes > 0 else { return }
        unlock(seconds: minutes * 60)
    }

    /// Banks earned minutes and unlocks the phone for that long (adding to any
    /// time already remaining). The one grant path every earn mechanic uses.
    func grantScreenTime(minutes: Int, method: HabitCategory? = nil) {
        guard minutes > 0 else { return }
        lifetimeEarnedMinutes += minutes
        recordToday(coins: minutes, method: method)
        unlock(seconds: minutes * 60)
    }

    // MARK: - Power-ups

    /// The daily charge-bar power-up thresholds, in coins.
    static let powerUpThresholds = [25, 50, 75, 100]
    /// Bonus coins granted for each power-up reached.
    static let powerUpBonus = 5

    private static let powerUpDateKey = "aura.powerups.date"
    private static let powerUpClaimedKey = "aura.powerups.claimed"

    /// Which power-up thresholds have been claimed today.
    var claimedPowerUps: Set<Int> {
        guard let last = powerUpDate,
              Calendar.current.isDateInToday(last) else { return [] }
        return claimedPowerUpThresholds
    }

    /// Claims any power-up thresholds the balance has newly reached today and
    /// awards their bonus coins (once each, resetting at midnight). Returns the
    /// total bonus awarded, or nil if nothing new was reached.
    @discardableResult
    func claimReachedPowerUps() -> Int? {
        let last = powerUpDate
        let isToday = last != nil && Calendar.current.isDateInToday(last!)
        var claimed = isToday ? claimedPowerUpThresholds : []

        let coins = coinBalance
        let newly = Self.powerUpThresholds.filter { coins >= $0 && !claimed.contains($0) }
        guard !newly.isEmpty else {
            if !isToday {
                powerUpDate = Date()
                claimedPowerUpThresholds = []
                persistActiveAccount()
            }
            return nil
        }
        newly.forEach { claimed.insert($0) }
        powerUpDate = Date()
        claimedPowerUpThresholds = claimed
        persistActiveAccount()

        let bonus = newly.count * Self.powerUpBonus
        awardBonusCoins(bonus)
        return bonus
    }

    /// Adds coins to today's balance WITHOUT unlocking the phone — power-up
    /// bonuses are spendable coins, not free screen time.
    private func awardBonusCoins(_ n: Int) {
        guard n > 0 else { return }
        lifetimeEarnedMinutes += n
        recordToday(coins: n)
    }

    /// Drives the Home countdown above the blocked-apps pill. A running focus
    /// session wins over bought time — during one, apps are locked regardless of
    /// what's left in the bank.
    var gateCountdown: GateCountdown? {
        if let session = activeHabitSession {
            return .untilFocusEnds(seconds: session.remainingSeconds(at: now))
        }
        if isUnlocked, secondsRemaining > 0 {
            return .untilAppsLock(seconds: secondsRemaining)
        }
        return nil
    }

    // MARK: - Active habit session (Photo Proof home-screen timer)

    /// The habit timer shown on Home after a Photo-Proof session starts — apps
    /// stay locked while it counts down, then it grants the reward and unlocks.
    var activeHabitSession: ActiveHabitSession?
    /// Which method started the running session, so its reward lands in the
    /// right quest when the timer finishes.
    private var sessionMethod: HabitCategory = .photoTask

    func startHabitSession(habitName: String, habitId: UUID? = nil, rewardMinutes: Int,
                           sessionMinutes: Int, method: HabitCategory = .photoTask) {
        sessionMethod = method
        let total = max(1, sessionMinutes) * 60
        now = .now
        activeHabitSession = ActiveHabitSession(
            habitName: habitName,
            habitId: habitId,
            rewardMinutes: rewardMinutes,
            totalSeconds: total,
            endsAt: now.addingTimeInterval(TimeInterval(total))
        )
        startTicking()
        // A habit session re-shields Distracting even while time is bought, so
        // starting one changes the plan.
        Task { await refreshShield() }
        syncLiveActivity()
    }

    func toggleHabitSessionPause() {
        guard var session = activeHabitSession else { return }
        now = .now
        if session.isPaused { session.resume(at: now) } else { session.pause(at: now) }
        activeHabitSession = session
        // One of the two updates a pause costs. Everything else on the Island
        // runs off the end date without the app saying a word.
        syncLiveActivity()
    }

    /// Ends the session WITHOUT granting the reward (the user tapped End early).
    func endHabitSession() {
        activeHabitSession = nil
        stopTickingIfIdle()
        Task { await refreshShield() }
        syncLiveActivity()
    }
}
