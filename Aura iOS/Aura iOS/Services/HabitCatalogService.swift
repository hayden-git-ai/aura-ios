//
//  HabitCatalogService.swift
//  Aura iOS
//
//  Supplies the starter-habit catalog for onboarding (Screen 33) grouped into
//  concise themes, plus goal/consequence-driven recommendations. The Live impl
//  will read Aura's real seeded habit library from HabitStore (Phase B/E); the
//  Mock provides a deterministic curated set for the flow + tests.
//

import Foundation

/// Concise starter-habit themes (Screen 33): Body, Focus, Home, Mind, Relationships.
enum OnboardingHabitGroup: String, CaseIterable, Identifiable, Codable {
    case body, focus, home, mind, relationships
    var id: String { rawValue }
    var title: String {
        switch self {
        case .body:          return "Body"
        case .focus:         return "Focus"
        case .home:          return "Home"
        case .mind:          return "Mind"
        case .relationships: return "Relationships"
        }
    }
}

/// A selectable starter habit. `earnMinutes` is the fixed window it grants.
struct OnboardingHabit: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let emoji: String
    let group: OnboardingHabitGroup
    let earnMinutes: Int
}
