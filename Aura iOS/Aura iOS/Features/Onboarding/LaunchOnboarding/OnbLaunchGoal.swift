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
            question: "what is your goal with Aura?",
            options: OnbQ.goal,
            key: \.goal,
            reaction: { answer in
                switch answer {
                case "Improve focus":             return "bold goal for someone holding a phone. i respect it."
                case "Reduce mindless scrolling": return "good, less scrolling. your thumb's been doing cardio for months."
                case "Sleep better":              return "yep, your 2am scrolling sessions are so cancelled."
                case "Be more present":           return "oh man, your phone's going to feel so left out."
                case "Be more productive":        return "more done, less doomscrolling. groundbreaking, i know."
                case "Just curious":              return "that's what everyone says before they stay."
                default:                          return ""
                }
            }
        )
    }
}
