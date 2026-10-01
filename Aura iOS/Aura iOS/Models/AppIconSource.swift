//
//  AppIconSource.swift
//  Aura iOS
//

import FamilyControls
import Foundation
import ManagedSettings

/// One chosen app, in whichever form we have it.
///
/// A real selection is a set of opaque `ApplicationToken`s — there is no name,
/// no bundle id, and no image, and the only thing that can draw one is
/// `Label(token)`, which the system renders itself. The catalogue stand-ins
/// stay alongside so the screens still work in the Simulator, where Screen Time
/// authorization always fails and there are no tokens to be had.
enum AppIconSource: Hashable, Identifiable {
    /// A bundled asset. Development and previews only.
    case asset(String)
    /// The real thing.
    case token(ApplicationToken, name: String?, bundleIdentifier: String?)
    case category(ActivityCategoryToken, name: String?)
    case webDomain(WebDomainToken, name: String?)

    private static var canonicalEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }

    var id: Self { self }

    /// Stable identity for SwiftUI collection reuse and confirmation sheets.
    /// Offset IDs can reuse a removed cell's old action after the array shifts.
    var stableID: String {
        switch self {
        case .asset(let name): return "asset:\(name)"
        case .token(let token, _, _):
            guard let data = try? Self.canonicalEncoder.encode(token) else { return "token" }
            return "token:\(data.base64EncodedString())"
        case .category(let token, _):
            return "category:\((try? Self.canonicalEncoder.encode(token))?.base64EncodedString() ?? "")"
        case .webDomain(let token, _):
            return "web:\((try? Self.canonicalEncoder.encode(token))?.base64EncodedString() ?? "")"
        }
    }

    var displayName: String? {
        switch self {
        case .asset(let name): return AppCatalog.displayName(for: name)
        case .token(_, let name, _), .category(_, let name), .webDomain(_, let name):
            guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
                return nil
            }
            return name
        }
    }

    var bundleIdentifier: String? {
        guard case .token(_, _, let bundleIdentifier) = self,
              let bundleIdentifier = bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
              !bundleIdentifier.isEmpty else {
            return nil
        }
        return bundleIdentifier
    }
}

extension AppSelection {
    /// The apps in this selection, drawable.
    ///
    /// Real tokens win when there are any; the stand-ins are the fallback, not
    /// a supplement, so a live selection never shows a mixture of somebody's
    /// actual apps and our sample ones.
    var iconSources: [AppIconSource] {
        if let decoded {
            let applications = decoded.applications.compactMap { application -> AppIconSource? in
                guard let token = application.token else { return nil }
                return .token(
                    token,
                    name: application.localizedDisplayName,
                    bundleIdentifier: application.bundleIdentifier
                )
            }
            let categories = decoded.categories.compactMap { category -> AppIconSource? in
                guard let token = category.token else { return nil }
                return .category(token, name: category.localizedDisplayName)
            }
            let webDomains = decoded.webDomains.compactMap { domain -> AppIconSource? in
                guard let token = domain.token else { return nil }
                return .webDomain(token, name: domain.domain)
            }

            let namedSources = applications + categories + webDomains
            let namedIDs = Set(namedSources.map(\.stableID))
            let unnamedSources = decoded.applicationTokens
                .map { AppIconSource.token($0, name: nil, bundleIdentifier: nil) }
                + decoded.categoryTokens.map { AppIconSource.category($0, name: nil) }
                + decoded.webDomainTokens.map { AppIconSource.webDomain($0, name: nil) }

            return (namedSources + unnamedSources.filter { !namedIDs.contains($0.stableID) })
                .sorted { $0.stableID < $1.stableID }
        }
        return mockIconNames.map(AppIconSource.asset)
    }

    /// The same selection with one app taken out.
    ///
    /// Removal has to rewrite the encoded selection, not just a display list —
    /// the tokens are what actually get shielded, and a name crossed off a
    /// preview would leave the app blocked.
    func removing(_ source: AppIconSource) -> AppSelection {
        var updated = self

        switch source {
        case .asset(let name):
            updated.mockIconNames.removeAll { $0 == name }
            updated.appCount = updated.mockIconNames.count
            updated.categoryCount = 0

        case .token, .category, .webDomain:
            guard var selection = decoded else { return self }
            switch source {
            case .token(let token, _, _): selection.applicationTokens.remove(token)
            case .category(let token, _): selection.categoryTokens.remove(token)
            case .webDomain(let token, _): selection.webDomainTokens.remove(token)
            case .asset: break
            }
            updated.token = try? JSONEncoder().encode(selection)
            updated.appCount = selection.applicationTokens.count + selection.webDomainTokens.count
            updated.categoryCount = selection.categoryTokens.count
        }

        if updated.isEmpty { updated.token = nil }
        return updated
    }

    private var decoded: FamilyActivitySelection? {
        guard let token else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: token)
    }
}
