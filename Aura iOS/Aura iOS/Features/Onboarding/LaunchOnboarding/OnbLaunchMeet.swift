//
//  OnbLaunchMeet.swift
//  Aura iOS
//
//  Launch-flow copy of OnbMeetView (screen 2). Reuses the shared CompanionScaffold
//  chrome; the copy exists so the launch flow's copy/order can change freely.
//

import SwiftUI

struct OnbLaunchMeet: View {
    @Environment(OnboardingFlow.self) private var flow
    /// Gates the CTA until the fox has finished talking.
    @State private var ready = false
    var body: some View {
        CompanionScaffold(
            showBack: false,
            progress: nil,
            lines: [
                "hey, i'm Aura",
                "i'll help you block the apps that distract you the most",
                "don't worry, i'll give them back",
                "you just have to do healthy habits first",
                "think of me as your slightly pushy friend",
                "you'll thank me later. probably...",
            ],
            onAllDone: { ready = true },
            content: { EmptyView() },
            bottom: {
                LightPrimaryButton(title: "Continue",
                                   face: .white, textColor: LightSheet.title, shade: LightSheet.whiteShadeOnColour,
                                   enabled: ready) { flow.advance() }
            }
        )
    }
}
