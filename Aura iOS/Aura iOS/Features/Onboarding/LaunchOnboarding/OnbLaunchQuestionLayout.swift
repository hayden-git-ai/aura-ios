//
//  OnbLaunchQuestionLayout.swift
//  Aura iOS
//
//  Launch-flow copy of OnbQuestionLayout (the blue question chrome shared by the
//  fox question screens). Forked so the launch flow can carry a subtle blue
//  gradient and a DEBUG-only back/forward nav without touching the v2 layout.
//  Reuses the shared OnbTopBar + OnbQuestionHeader (fox + typewriter).
//

import SwiftUI

struct OnbLaunchQuestionLayout<Content: View, Bottom: View>: View {
    var showBack: Bool = true
    var progress: Double? = nil
    let headerText: String
    var note: String? = nil
    var onFinishedTyping: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content
    @ViewBuilder var bottom: () -> Bottom

    var body: some View {
        ZStack {
            // Art gradient (DESIGN.md §4 allows multi-stop art gradients inline): a
            // lighter blue up top easing to a darker blue at the bottom.
            LinearGradient(colors: [Color(hex: "3F94FF"), Color(hex: "1857BE")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                OnbTopBar(showBack: showBack, progress: progress, onSky: true)
                    .padding(.bottom, Theme.Spacing.l)

                OnbQuestionHeader(text: headerText, note: note, onFinishedTyping: onFinishedTyping)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.bottom, Theme.Spacing.xl)

                content()
                    .padding(.horizontal, Theme.Spacing.xl)

                Spacer(minLength: Theme.Spacing.l)

                bottom()
                    .padding(.horizontal, Theme.Spacing.xl)
                Spacer().frame(height: Theme.Spacing.l)
            }
        }
    }
}
