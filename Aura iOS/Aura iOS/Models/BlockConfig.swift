//
//  BlockConfig.swift
//  Aura iOS
//
//  What's blocked, in three rules. Replaces the schedule/limit/break rules —
//  see docs/blocks/BLOCKS_BUILD_SPEC.md.
//

import FamilyControls
import Foundation

/// Which promise an app is under.
///
/// One axis, one rule per app. The rule is the whole policy: there's no second
/// mechanism that can also block something, so "why is this blocked?" always
/// has exactly one answer.
enum BlockRule: String, Codable, CaseIterable, Identifiable {
    /// Never shielded. Only means anything alongside `blockEverything` — with an
    /// explicit distracting list you'd simply not add the app.
    case allowed
    /// Shielded permanently. Nothing lifts it: not coins, not Emergency
    /// Unlock. The only way out is taking the app off the list, which costs a
    /// ten-second hold. `BlockingEngine.plan` already reflects this — the hard
    /// tokens are in every plan regardless of session state.
    case blocked
    /// Shielded until time is earned or bought. The bargain the app is built on.
    case distracting

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allowed: return "Allowed"
        case .blocked: return "Forbidden"
        case .distracting: return "Tempting"
        }
    }

    /// The lane's sticker, shown in its card's tile on Blocks. Borrowed from
    /// where each idea already lives: the Stats skull and bolt, and the eyes
    /// from the Intervention Style setting.
    var sticker: String {
        switch self {
        case .blocked: return "StatsMostDistracting"          // skull
        case .distracting: return "FoxSettingsInterventionStyle"  // eyes
        case .allowed: return "StatsMostProductive"           // bolt
        }
    }

    /// The rule's promise, in the user's words. Shown at the top of its screen.
    var promise: String {
        switch self {
        case .allowed: return "Aura keeps these open, and never freezes them."
        case .blocked: return "Gone for good. Only you can see this list."
        case .distracting: return "Frozen until you buy screen time with the coins you earn."
        }
    }

    /// Highest first. An app picked into two rules lands in the stronger one.
    ///
    /// Always Blocked outranks Always Allowed deliberately: letting an allow
    /// list override a hard block would quietly defeat the strongest statement a
    /// user can make in this app.
    var rank: Int {
        switch self {
        case .blocked: return 2
        case .allowed: return 1
        case .distracting: return 0
        }
    }
}

/// An opaque `FamilyActivitySelection` plus what's needed to render it.
///
/// The token is the only real identity. There is no API to turn a bundle ID into
/// an `ApplicationToken` — selections come back from the system picker and
/// nowhere else — which is why icons are drawn with FamilyControls' own
/// `Label(token)` rather than from our asset catalogue, and why starter bundles
/// of named apps aren't buildable.
struct AppSelection: Codable, Hashable {
    var token: Data?
    var appCount: Int = 0
    var categoryCount: Int = 0

    /// `AppCatalog` stand-ins so the screens are real before the entitlement
    /// is. Empty in production, where icons come from `Label(token)` — kept out
    /// of `#if DEBUG` so the views have one code path rather than two.
    var mockIconNames: [String] = []

    var isEmpty: Bool { appCount == 0 && categoryCount == 0 }

    /// "3 apps", "2 apps · 1 category", "Empty".
    var summary: String {
        if isEmpty { return "Empty" }
        var parts: [String] = []
        if appCount > 0 { parts.append("\(appCount) app\(appCount == 1 ? "" : "s")") }
        if categoryCount > 0 {
            parts.append("\(categoryCount) categor\(categoryCount == 1 ? "y" : "ies")")
        }
        return parts.joined(separator: " · ")
    }

    static let empty = AppSelection()
}

// MARK: - Cross-lane exclusivity

/// An app can only be under one rule at a time. Enforcing that means comparing
/// selections item by item, and the only real identity an app has is its
/// `ApplicationToken` — so the comparison has to happen on the decoded
/// `FamilyActivitySelection`, not on the opaque `Data` blob.
///
/// Two lanes that share one app hold *different* blobs (different sets), so a
/// blob-equality check catches nothing until the sets are byte-identical. These
/// helpers do the set arithmetic the exclusivity rule actually needs. On device
/// they work on real tokens; in the Simulator, where the token isn't a
/// `FamilyActivitySelection`, they fall back to the catalogue stand-in names.
extension AppSelection {
    /// The decoded system selection, or `nil` when there's no token or it isn't
    /// a `FamilyActivitySelection` (the Simulator's mock token never is).
    var systemSelection: FamilyActivitySelection? {
        guard let token else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: token)
    }

    /// Rebuilds an `AppSelection` from a system selection, keeping counts in the
    /// same shape `LiveScreenTimeService` produces (web domains count as apps).
    static func from(_ selection: FamilyActivitySelection) -> AppSelection {
        let isEmpty = selection.applicationTokens.isEmpty
            && selection.categoryTokens.isEmpty
            && selection.webDomainTokens.isEmpty
        return AppSelection(
            token: isEmpty ? nil : (try? JSONEncoder().encode(selection)),
            appCount: selection.applicationTokens.count + selection.webDomainTokens.count,
            categoryCount: selection.categoryTokens.count
        )
    }

    /// A copy of `self` with everything that also appears in `other` removed.
    /// This is the displacement the exclusivity rule performs when an app is
    /// claimed by a new lane.
    func subtracting(_ other: AppSelection) -> AppSelection {
        if let mine = systemSelection, let theirs = other.systemSelection {
            var result = mine
            result.applicationTokens.subtract(theirs.applicationTokens)
            result.categoryTokens.subtract(theirs.categoryTokens)
            result.webDomainTokens.subtract(theirs.webDomainTokens)
            return .from(result)
        }
        // Simulator / stand-in path: subtract by catalogue name.
        let drop = Set(other.mockIconNames)
        if !drop.isEmpty && !mockIconNames.isEmpty {
            var copy = self
            copy.mockIconNames.removeAll { drop.contains($0) }
            copy.appCount = copy.mockIconNames.count
            if copy.mockIconNames.isEmpty { copy.token = nil }
            return copy
        }
        // Neither side is readable: the only comparison left is whole-selection
        // identity, so an exact token match empties this lane and nothing else.
        if let token, token == other.token { return .empty }
        return self
    }

    /// How much of `self` also lives in `other`: the count of shared items and,
    /// where names are available (Simulator), which ones. The count drives the
    /// "already in another list" alert; the names make it specific when we have
    /// them.
    func overlap(with other: AppSelection) -> (count: Int, names: [String]) {
        if let mine = systemSelection, let theirs = other.systemSelection {
            let shared = mine.applicationTokens.intersection(theirs.applicationTokens).count
                + mine.categoryTokens.intersection(theirs.categoryTokens).count
                + mine.webDomainTokens.intersection(theirs.webDomainTokens).count
            return (shared, [])
        }
        let mineNames = Set(mockIconNames)
        let shared = other.mockIconNames.filter { mineNames.contains($0) }
        return (shared.count, shared)
    }
}

/// The whole blocking configuration. One of these, persisted.
struct BlockConfig: Codable, Hashable {
    var allowed = AppSelection.empty
    var blocked = AppSelection.empty
    var distracting = AppSelection.empty

    /// Shield everything except `allowed`, rather than only `distracting`.
    /// `ShieldSettings` supports this via `.all(except:)`, and it's the only
    /// configuration in which Always Allowed does any work.
    var blockEverything = false

    /// ManagedSettings' own adult-content restrictions — no picker, no
    /// extension, no tokens. Lives in the Always Blocked rule because it makes
    /// that rule's promise about content instead of apps.
    var blockAdultWebsites = false

    /// When the adult-content switch was last turned on. The confirm sheet for
    /// turning it *off* cites recency ("you only turned this on today"), which
    /// needs a date rather than a flag.
    var adultWebsitesEnabledAt: Date?

    subscript(rule: BlockRule) -> AppSelection {
        get {
            switch rule {
            case .allowed: return allowed
            case .blocked: return blocked
            case .distracting: return distracting
            }
        }
        set {
            switch rule {
            case .allowed: allowed = newValue
            case .blocked: blocked = newValue
            case .distracting: distracting = newValue
            }
        }
    }

    /// Nothing picked anywhere — drives the Blocks screen's empty state.
    var isEmpty: Bool { allowed.isEmpty && blocked.isEmpty && distracting.isEmpty }
}

enum BlockConfigFile {
    private static let filename = "block-config.json"

    private static var url: URL? {
        guard let directory = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        ) else { return nil }
        return directory.appendingPathComponent(filename)
    }

    static func load() -> BlockConfig {
        guard let url, let data = try? Data(contentsOf: url) else { return BlockConfig() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(BlockConfig.self, from: data)) ?? BlockConfig()
    }

    static func save(_ config: BlockConfig) {
        guard let url else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(config) else { return }
        try? data.write(to: url, options: .atomic)
    }

    #if DEBUG
    /// A fresh simulator has nothing picked and no picker to pick with, so the
    /// screens would all be empty states. Release builds start empty, correctly.
    static func seedIfEmpty() {
        guard load().isEmpty else { return }
        var config = BlockConfig()
        config.distracting = AppSelection(
            token: Data([0x1]), appCount: 3, categoryCount: 0,
            mockIconNames: ["AppIconInstagram", "AppIconTikTok", "AppIconX"]
        )
        config.blocked = AppSelection(
            token: Data([0x2]), appCount: 1, categoryCount: 0,
            mockIconNames: ["AppIconReddit"]
        )
        save(config)
    }
    #endif
}
