//
//  LaunchOnboardingFlowView.swift
//  Aura iOS
//
//  Container for the production launch onboarding. Renders the
//  independent `OnbLaunch*` copies so they can be redesigned without touching the
//  full v2 flow (`OnboardingFlowView`, still present and unchanged). Which screens
//  actually appear is decided by `OnboardingFlow.steps` (= `.launchSteps`); the
//  default case covers the enum cases the launch sequence never reaches.
//

import SwiftUI

struct LaunchOnboardingFlowView: View {
    @Environment(OnboardingFlow.self) private var flow

    var body: some View {
        Group {
            switch flow.step {
            case .welcome:  OnbLaunchWelcome()
            case .qGoal:    OnbLaunchGoal()
            case .qPersona:
                OnbLaunchSingleSelect(
                    progress: flow.progress,
                    question: "What is your gender?",
                    options: [("Male", "👨"),
                              ("Female", "👩"),
                              ("Other", "🧑")],
                    key: \.persona
                )
            case .age:      OnbLaunchAge()
            case .qDoomProfile: OnbLaunchComparison()
            case .name:     OnbLaunchName()
            case .qFeelings:
                OnbLaunchMultiSelect(
                    progress: flow.progress,
                    question: "How does your screen time affect you most?",
                    options: [
                        ("No focus / procrastination", "😵‍💫"),
                        ("Anxiety / overstimulation", "🤯"),
                        ("Bad sleep", "😴"),
                        ("Productivity loss", "📉"),
                        ("I feel mentally fried", "🫠"),
                        ("Less time with friends / family", "👥"),
                    ],
                    key: \.feelings
                )
            case .qWorstTime:
                OnbLaunchSingleSelect(
                    progress: flow.progress,
                    question: "When do you usually scroll the most?",
                    options: [
                        ("First thing in the morning", "🌅"),
                        ("During the day", "☀️"),
                        ("Evenings", "🌙"),
                        ("Honestly, all day", "📱"),
                        ("Not sure", "🤷"),
                    ],
                    key: \.worstTime
                )
            case .qHabits:     OnbLaunchHabits()
            case .qLoading:    OnbLaunchLoading()
            case .qCustomPlan: OnbLaunchCustomPlan()
            case .qCommit:     OnbLaunchCommit()
            // Steps outside the launch sequence never become `step`; render nothing.
            default:           Color.clear
            }
        }
        .id(flow.step)
        .onAppear { flow.appear() }
    }
}
