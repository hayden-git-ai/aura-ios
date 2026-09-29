//
//  OnbLaunchName.swift
//  Aura iOS
//

import SwiftUI

struct OnbLaunchName: View {
    @Environment(OnboardingFlow.self) private var flow
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var flow = flow
        OnbLaunchQuestionLayout(showBack: true, progress: flow.progress,
                                 question: "What should I call you?") {
            TextField("Your name", text: $flow.name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.continue)
                .focused($focused)
                .auraFont(.display, SheetType.hero, .bold)
                .foregroundStyle(LightSheet.title)
                .multilineTextAlignment(.center)
                .padding(.vertical, Theme.Spacing.xl)
        } bottom: {
            onbLaunchContinue(enabled: ProfileIdentity.isValidName(flow.name)) {
                focused = false
                flow.advance()
            }
        }
    }
}
