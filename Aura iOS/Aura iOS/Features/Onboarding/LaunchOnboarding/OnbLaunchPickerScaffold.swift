//
//  OnbLaunchPickerScaffold.swift
//  Aura iOS
//
//  Launch-flow copy of OnbPickerScaffold. Same blue picker chrome (fox, typewriter,
//  reaction, scrolling rows) but the Continue button FLOATS over the content with a
//  translucent pill behind it, exactly like the custom plan screen's CTA. Reuses the
//  shared OnbTopBar / OnbQuestionHeader / onbContinue. v2's scaffold is untouched.
//

import SwiftUI

struct OnbLaunchPickerScaffold<Rows: View>: View {
    var progress: Double
    var showBack: Bool = true
    let title: String
    /// Fox's reaction after Continue (types in place, then auto-advances). Nil skips it.
    var reaction: String? = nil
    var canContinue: Bool = true
    let onContinue: () -> Void
    @ViewBuilder var rows: () -> Rows

    @State private var reacting = false
    @State private var advanced = false

    /// Bottom scroll clearance so the last card clears the floating CTA (matches
    /// the custom plan screen).
    private let buttonClearance: CGFloat = 92

    private func finish() {
        guard !advanced else { return }
        advanced = true
        onContinue()
    }

    var body: some View {
        ZStack {
            LightSheet.blue.ignoresSafeArea()

            VStack(spacing: 0) {
                OnbTopBar(showBack: showBack, progress: progress, onSky: true)

                OnbQuestionHeader(text: reacting ? (reaction ?? title) : title,
                                  onFinishedTyping: {
                                      if reacting {
                                          Task { try? await Task.sleep(nanoseconds: 1_500_000_000); finish() }
                                      }
                                  })
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.bottom, Theme.Spacing.s)

                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.s) {
                        rows()
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                    // Clearance so the last card scrolls clear of the floating button.
                    .padding(.bottom, buttonClearance)
                }
                .opacity(reacting ? 0.55 : 1)
                .allowsHitTesting(!reacting)
            }

            // The button floats over the content with a translucent pill behind it
            // (same shape, a little bigger), matching the custom plan CTA.
            VStack(spacing: 0) {
                Spacer()
                onbContinue(enabled: canContinue) {
                    if reaction != nil, !reacting {
                        withAnimation(.easeInOut(duration: 0.25)) { reacting = true }
                    } else {
                        finish()
                    }
                }
                .padding(Theme.Spacing.s)
                .background(Capsule().fill(.black.opacity(0.12)))
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.l)
            }
        }
    }
}
