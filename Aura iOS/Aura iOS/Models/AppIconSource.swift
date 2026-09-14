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
    case token(ApplicationToken)

    var id: Self { self }
}

extension AppSelection {
    /// The apps in this selection, drawable.
    ///
    /// Real tokens win when there are any; the stand-ins are the fallback, not
    /// a supplement, so a live selection never shows a mixture of somebody's
    /// actual apps and our sample ones.
    var iconSources: [AppIconSource] {
        if let decoded, !decoded.applicationTokens.isEmpty {
            // A `Set` has no order of its own and tokens aren't sortable, so
            // the grid can reshuffle between launches. Nothing depends on the
            // order, and there's no ordering the system will give us.
            return decoded.applicationTokens.map(AppIconSource.token)
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

        case .token(let token):
            guard var selection = decoded else { return self }
            selection.applicationTokens.remove(token)
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
