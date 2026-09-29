//
//  OnbLaunchSingleSelect.swift
//  Aura iOS
//

import SwiftUI

struct OnbLaunchSingleSelect: View {
    @Environment(OnboardingFlow.self) private var flow
    var showBack: Bool = true
    let progress: Double
    let question: String
    let options: [(label: String, emoji: String)]
    let key: ReferenceWritableKeyPath<OnboardingFlow, String?>
    var onAdvance: (() -> Void)? = nil

    var body: some View {
        let current = flow[keyPath: key]
        OnbLaunchQuestionLayout(showBack: showBack, progress: progress, question: question) {
            VStack(spacing: Theme.Spacing.s) {
                ForEach(options, id: \.label) { option in
                    OnbLaunchAnswerCard(label: option.label, emoji: option.emoji,
                                        selected: current == option.label) {
                        Haptics.impact(.light)
                        flow[keyPath: key] = option.label
                    }
                }
            }
        } bottom: {
            onbLaunchContinue(enabled: current != nil) {
                if let onAdvance { onAdvance() } else { flow.advance() }
            }
        }
    }
}
