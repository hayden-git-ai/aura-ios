//
//  HabitRoutine.swift
//  Aura iOS
//

import Foundation
import UserNotifications

/// A standing reminder for one habit: a time, and the weekdays it fires on.
///
/// Stored per habit NAME rather than per id, for the same reason
/// `HabitStore.mergedHabits` matches on name — a habit's `id` is regenerated
/// from the seed on every launch, so anything keyed to it is lost the moment the
/// app restarts.
struct HabitRoutine: Codable, Equatable, Identifiable {
    var id: String { habitName }
    let habitName: String
    /// Minutes from midnight. Not a `Date`, which would carry a day with it and
    /// quietly mean "8am on the 12th of August" forever.
    var minuteOfDay: Int
    /// Calendar weekday numbers, 1 = Sunday.
    var weekdays: Set<Int>

    nonisolated var hour: Int { minuteOfDay / 60 }
    nonisolated var minute: Int { minuteOfDay % 60 }

    /// One request per weekday. `UNCalendarNotificationTrigger` takes a single
    /// weekday, so a routine on three days is three requests that have to be
    /// cancelled together — hence the shared id prefix.
    /// What the settings row shows: "Weekdays, 8:00 AM", "Sun & Wed, 6:30 PM".
    ///
    /// A row can say this; an icon in the corner cannot, which is the whole
    /// reason a routine belongs in a list rather than in the chrome.
    var summary: String {
        var parts = DateComponents()
        parts.hour = hour
        parts.minute = minute
        let date = Calendar.current.date(from: parts) ?? .now
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let time = formatter.string(from: date)

        let short = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let sorted = weekdays.sorted()
        let days: String
        if sorted.count == 7 {
            days = "Every day"
        } else if sorted == [2, 3, 4, 5, 6] {
            days = "Weekdays"
        } else if sorted == [1, 7] {
            days = "Weekends"
        } else {
            days = sorted.map { short[$0] }.joined(separator: ", ")
        }
        return "\(days), \(time)"
    }

    var requestIDs: [String] { weekdays.sorted().map { "aura.routine.\(habitName).\($0)" } }
    static func idPrefix(for habitName: String) -> String { "aura.routine.\(habitName)." }
}

/// Where routines live and how they reach iOS.
enum RoutineStore {
    private static let legacyKey = "aura.routines"
    private static let activeOwnerKey = "aura.routines.active-owner.v2"
    private static let revisionKey = "aura.routines.revision.v2"
    private static let signedOutOwner = "signed-out"
    private static let notificationCoordinator = RoutineNotificationCoordinator()

    private static func ownerKey(_ ownerID: UUID?) -> String {
        ownerID?.uuidString.lowercased() ?? signedOutOwner
    }

    private static func storageKey(for owner: String) -> String {
        "aura.routines.v2.\(owner)"
    }

    private static var activeOwner: String {
        UserDefaults.standard.string(forKey: activeOwnerKey) ?? signedOutOwner
    }

    private static func nextRevision() -> Int {
        let revision = UserDefaults.standard.integer(forKey: revisionKey) + 1
        UserDefaults.standard.set(revision, forKey: revisionKey)
        return revision
    }

    private static func load(owner: String) -> [HabitRoutine] {
        guard let data = UserDefaults.standard.data(forKey: storageKey(for: owner)),
              let list = try? JSONDecoder().decode([HabitRoutine].self, from: data)
        else { return [] }
        return list
    }

    @discardableResult
    private static func persist(_ routines: [HabitRoutine], owner: String) -> Bool {
        guard let data = try? JSONEncoder().encode(routines) else { return false }
        UserDefaults.standard.set(data, forKey: storageKey(for: owner))
        return true
    }

    /// Switches the active routine namespace synchronously. Legacy ownerless
    /// routines remain untouched and are never silently assigned to a login.
    static func activate(ownerID: UUID?) {
        let owner = ownerKey(ownerID)
        UserDefaults.standard.set(owner, forKey: activeOwnerKey)
        let revision = nextRevision()
        let routines = load(owner: owner)
        Task { await notificationCoordinator.refresh(owner: owner, revision: revision, routines: routines) }
    }

    static func all() -> [HabitRoutine] {
        load(owner: activeOwner)
    }

    static func routine(for habitName: String) -> HabitRoutine? {
        all().first { $0.habitName == habitName }
    }

    /// Replaces any routine for this habit, then rewrites its notifications.
    ///
    /// Cancelling first is not optional: changing Tuesday to Wednesday without
    /// it leaves the Tuesday request alive, and the user gets reminded on a day
    /// they explicitly removed.
    static func save(_ routine: HabitRoutine) async {
        let owner = activeOwner
        var list = load(owner: owner).filter { $0.habitName != routine.habitName }
        if !routine.weekdays.isEmpty { list.append(routine) }
        guard owner == activeOwner, persist(list, owner: owner) else { return }
        let revision = nextRevision()
        await notificationCoordinator.refresh(owner: owner, revision: revision, routines: list)
    }

    /// Replaces the whole set (a sync adopting the account's routines), then
    /// re-lays every notification. Cancels all existing routine requests first so
    /// a routine dropped on another device stops firing here too.
    static func replaceAll(_ routines: [HabitRoutine]) async {
        let owner = activeOwner
        // Persist before the first suspension. A stale cancellation can no longer
        // wake up later and overwrite a newly activated account's routines.
        guard persist(routines, owner: owner), owner == activeOwner else { return }
        let revision = nextRevision()
        await notificationCoordinator.refresh(owner: owner, revision: revision, routines: routines)
    }

    static func remove(habitName: String) async {
        let owner = activeOwner
        let list = load(owner: owner).filter { $0.habitName != habitName }
        guard owner == activeOwner, persist(list, owner: owner) else { return }
        let revision = nextRevision()
        await notificationCoordinator.refresh(owner: owner, revision: revision, routines: list)
    }

    /// Re-lays every stored routine.
    ///
    /// Called at launch because permission can be granted long after a routine
    /// was made — somebody denies the prompt, sets three routines anyway, then
    /// turns notifications on in Settings weeks later. Without this their
    /// routines stay silent forever, because the only code that ever scheduled
    /// them ran on the day they were saved and bailed on the authorisation
    /// check.
    static func rescheduleAll() async {
        let owner = activeOwner
        let revision = nextRevision()
        await notificationCoordinator.refresh(owner: owner, revision: revision,
                                              routines: load(owner: owner))
    }

    /// Removes only a successfully deleted account's routine namespace.
    static func removeAccount(ownerID: UUID) {
        let owner = ownerKey(ownerID)
        UserDefaults.standard.removeObject(forKey: storageKey(for: owner))
        guard activeOwner == owner else { return }
        activate(ownerID: nil)
    }

    /// Raw ownerless data is exposed only for the one-time quarantine archive.
    static func legacyDataForQuarantine() -> Data? {
        UserDefaults.standard.data(forKey: legacyKey)
    }
}

private actor RoutineNotificationCoordinator {
    private var latestRevision = 0

    func refresh(owner: String, revision: Int, routines: [HabitRoutine]) async {
        guard revision >= latestRevision else { return }
        latestRevision = revision
        let centre = UNUserNotificationCenter.current()
        let pending = await centre.pendingNotificationRequests()
        guard revision == latestRevision else { return }
        let identifiers = pending.map(\.identifier).filter { $0.hasPrefix("aura.routine.") }
        centre.removePendingNotificationRequests(withIdentifiers: identifiers)

        let settings = await centre.notificationSettings()
        guard revision == latestRevision, settings.authorizationStatus == .authorized else { return }

        for routine in routines where !routine.weekdays.isEmpty {
            let content = UNMutableNotificationContent()
            content.title = routine.habitName
            content.body = "You said now. I'm holding you to it."
            content.sound = .default

            for weekday in routine.weekdays {
                guard revision == latestRevision else { return }
                var when = DateComponents()
                when.weekday = weekday
                when.hour = routine.hour
                when.minute = routine.minute
                let requestID = "aura.routine.\(owner).r\(revision).\(routine.habitName).\(weekday)"
                let request = UNNotificationRequest(
                    identifier: requestID,
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
                )
                try? await centre.add(request)
                if revision != latestRevision {
                    // A newer refresh may have removed old requests while this
                    // add was suspended. Revision-specific ids let the stale
                    // task clean up only its own late request.
                    centre.removePendingNotificationRequests(withIdentifiers: [requestID])
                    return
                }
            }
        }
    }
}
