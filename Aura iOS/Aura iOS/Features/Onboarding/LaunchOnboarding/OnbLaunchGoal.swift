//
//  OnbLaunchGoal.swift
//  Aura iOS
//
//  Launch-flow copy of the "what is your goal" question (screen 4). Reuses the
//  shared OnbSingleSelectScreen; the question/options/reaction config lives here so
//  it can be tuned for launch without touching the v2 flow. Progress off the active
//  sequence (flow.progress).
//

import SwiftUI

struct OnbLaunchGoal: View {
    @Environment(OnboardingFlow.self) private var flow

    var body: some View {
        OnbLaunchSingleSelect(
            showBack: true,
            progress: flow.progress,
            question: "What is your goal with Aura?",
            options: [
                ("Improve focus", "🎯"),
                ("Reduce mindless scrolling", "📵"),
                ("Sleep better", "🛏️"),
                ("Be more present", "🧘"),
                ("Be more productive", "💻"),
                ("Just curious", "🤔"),
            ],
            key: \.goal
        )
    }
}
