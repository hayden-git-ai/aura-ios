//
//  OnbLaunchName.swift
//  Aura iOS
//
//  Launch-flow name screen (screen 3). Uses the SAME blue question layout +
//  fox + typewriter + reaction as the other launch question screens (Goal, Slider),
//  instead of the snowy companion intro, so every question reads consistently.
//  Reuses the shared OnbQuestionLayout; nothing in the v2 flow changes.
//

import SwiftUI

struct OnbLaunchName: View {
    @Environment(OnboardingFlow.self) private var flow
    @FocusState private var focused: Bool
    /// Once they've answered, the fox reacts by name before we move on.
    @State private var reacting = false
    @State private var advanced = false

    private func finish() {
        guard !advanced else { return }
        advanced = true
        flow.advance()
    }

    private var reactionLine: String {
        "welcome, \(flow.firstName.lowercased()). the start of a beautiful, slightly naggy friendship."
    }

    var body: some View {
        @Bindable var flow = flow
        return OnbLaunchQuestionLayout(
            showBack: false,
            progress: flow.progress,
            headerText: reacting ? reactionLine : "what should i call you?",
            onFinishedTyping: {
                // Once the reaction has typed out, pause briefly then advance.
                if reacting {
                    Task { try? await Task.sleep(nanoseconds: 1_500_000_000); finish() }
                }
            },
            content: {
                // The field only exists while he's still asking; the reaction beat
                // is just fox + line + CTA, matching the single-select screens.
                if !reacting {
                    TextField("", text: $flow.name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.continue)
                        .focused($focused)
                        .onSubmit { if !flow.firstName.isEmpty { react() } }
                        .auraFont(.body, 17, .medium)
                        .foregroundStyle(.white)
                        .overlay(alignment: .leading) {
                            if flow.name.isEmpty {
                                Text("Your name")
                                    .auraFont(.body, 17, .medium)
                                    .foregroundStyle(.white.opacity(0.6))
                                    .allowsHitTesting(false)
                            }
                        }
                        .padding(Theme.Spacing.l)
                        // Same translucent-dark fill the answer rows use on the blue ground.
                        .background(Color.black.opacity(0.16), in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                        .padding(.top, Theme.Spacing.m)
                }
            },
            bottom: {
                onbContinue(enabled: !flow.firstName.isEmpty) {
                    if !reacting { react() } else { finish() }
                }
            }
        )
    }

    private func react() {
        focused = false
        withAnimation(.easeInOut(duration: 0.25)) { reacting = true }
    }
}
