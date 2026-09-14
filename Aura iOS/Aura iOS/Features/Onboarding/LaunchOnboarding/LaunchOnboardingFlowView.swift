//
//  LaunchOnboardingFlowView.swift
//  Aura iOS
//
//  Container for the SHORTENED launch onboarding (12 screens). Renders the
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
            case .meet:     OnbLaunchMeet()
            case .name:     OnbLaunchName()
            case .qGoal:    OnbLaunchGoal()
            case .qSlider:  OnbLaunchSlider()
            case .loopDemo: OnbLaunchLoopDemo()
            case .demoFreeze:
                OnbLaunchDemoScreen(showBack: false,
                                    title: "Block Distracting Apps",
                                    subtext: "To get them back you need to spend Aura Coins.",
                                    cta: "Next")
            case .demoEarn:
                OnbLaunchDemoScreen(showBack: false,
                                    title: "Earn Aura Coins",
                                    subtext: "There are 30+ unique ways to earn Aura Coins & you can even create your own!",
                                    cta: "Next")
            case .demoSpend:
                OnbLaunchDemoScreen(showBack: false,
                                    title: "Buy Screen Time",
                                    subtext: "Use Aura Coins to purchase screen time and use the apps you blocked.",
                                    cta: "Continue")
            case .qHabits:     OnbLaunchHabits()
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
