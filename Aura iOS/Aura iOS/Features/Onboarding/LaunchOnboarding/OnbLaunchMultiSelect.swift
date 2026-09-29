//
//  OnbLaunchMultiSelect.swift
//  Aura iOS
//

import SwiftUI

struct OnbLaunchMultiSelect: View {
    @Environment(OnboardingFlow.self) private var flow
    let progress: Double
    let question: String
    let options: [(label: String, emoji: String)]
    let key: ReferenceWritableKeyPath<OnboardingFlow, Set<String>>

    var body: some View {
        let current = flow[keyPath: key]
        OnbLaunchQuestionLayout(progress: progress, question: question) {
            VStack(spacing: Theme.Spacing.s) {
                ForEach(options, id: \.label) { option in
                    OnbLaunchAnswerCard(label: option.label, emoji: option.emoji,
                                        selected: current.contains(option.label)) {
                        Haptics.impact(.light)
                        if current.contains(option.label) {
                            flow[keyPath: key].remove(option.label)
                        } else {
                            flow[keyPath: key].insert(option.label)
                        }
                    }
                }
            }
        } bottom: {
            onbLaunchContinue(enabled: !current.isEmpty) {
                flow.advance()
            }
        }
    }
}
