//
//  QuickAction.swift
//  Aura iOS
//

import Foundation

/// One earn-screen-time option shown in the FAB menu off the "+" button next
/// to the nav bar. Purely presentational for this pass — none of the
/// underlying features (AI photo verification, rep counting, a deep-work
/// timer) exist yet, so tapping a row just closes the menu.
struct QuickAction: Identifiable {
    enum Kind: Equatable {
        case photoProof, exercise, deepFocus
    }

    let id = UUID()
    let kind: Kind
    let title: String
    let subtitle: String
    let emoji: String

    static let all: [QuickAction] = [
        QuickAction(kind: .photoProof, title: "Healthy Habits", subtitle: "Snap a pic, Aura verifies your habit, earn coins", emoji: "📸"),
        QuickAction(kind: .exercise, title: "Daily Exercise", subtitle: "The more you move, the more you earn", emoji: "💪"),
        QuickAction(kind: .deepFocus, title: "Deep Focus", subtitle: "Start the timer, stay off your phone, earn coins", emoji: "🔒"),
    ]
}
