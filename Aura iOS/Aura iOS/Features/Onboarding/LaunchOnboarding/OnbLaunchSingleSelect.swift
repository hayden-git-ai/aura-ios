//
//  OnbLaunchSingleSelect.swift
//  Aura iOS
//
//  Launch-flow copy of OnbSingleSelectScreen, built on OnbLaunchQuestionLayout so
//  the launch single-select questions get the gradient + DEBUG nav. Keeps the fox,
//  typewriter, and animated reaction. Reuses the shared OnbAnswerRow. v2 untouched.
//

import SwiftUI
import AudioToolbox

struct OnbLaunchSingleSelect: View {
    @Environment(OnboardingFlow.self) private var flow
    var showBack: Bool = true
    let progress: Double
    let question: String
    let options: [(label: String, icon: String)]
    let key: ReferenceWritableKeyPath<OnboardingFlow, String?>
    /// Fox's reaction to the chosen answer (shown in place after Continue). Nil
    /// skips the reaction beat.
    var reaction: ((String) -> String)? = nil
    /// Overrides what Continue does after the reaction (default: flow.advance()).
    var onAdvance: (() -> Void)? = nil

    @State private var reacting = false
    @State private var advanced = false

    private func finish() {
        guard !advanced else { return }
        advanced = true
        if let onAdvance { onAdvance() } else { flow.advance() }
    }

    private func tap() {
        Haptics.impact(.light)
        AudioServicesPlaySystemSound(1104)
    }

    var body: some View {
        let current = flow[keyPath: key]
        OnbLaunchQuestionLayout(showBack: showBack, progress: progress,
                                headerText: reacting ? (reaction?(current ?? "") ?? question) : question,
                                onFinishedTyping: {
                                    // Once the reaction has typed out, pause briefly then advance.
                                    if reacting {
                                        Task { try? await Task.sleep(nanoseconds: 1_500_000_000); finish() }
                                    }
                                },
                                content: {
            VStack(spacing: Theme.Spacing.s) {
                ForEach(options, id: \.label) { opt in
                    OnbAnswerRow(label: opt.label, icon: opt.icon,
                                 selected: current == opt.label, multi: false) {
                        guard !reacting else { return }
                        tap()
                        flow[keyPath: key] = opt.label
                    }
                }
            }
            .opacity(reacting ? 0.55 : 1)
        }, bottom: {
            onbContinue(enabled: current != nil) {
                if reaction != nil, !reacting {
                    withAnimation(.easeInOut(duration: 0.25)) { reacting = true }
                } else {
                    finish()
                }
            }
        })
    }
}
