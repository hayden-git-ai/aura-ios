//
//  ProofHelpSheet.swift
//  Aura iOS
//

import SwiftUI

/// What to do, for someone who has never done it.
///
/// The camera screen used to print the habit's proof hint over the viewfinder,
/// which put a paragraph of text on top of the thing you're trying to look
/// through. It lives here instead, behind the question mark, where it can be as
/// long as it needs to be and can say the obvious parts out loud.
///
/// Deliberately dumb. Three steps, one line each, no technique. The tip sits
/// above them because it's the habit-specific part and the reason most people
/// open this at all; the steps are the same every time.
struct ProofHelpSheet: View {
    let habit: Habit

    /// Title and copy per step, the shape `StepsExplainerSheet` uses on every
    /// "How X Works" sheet. Three, not four: this is one screen's instructions,
    /// not the whole method.
    private let steps: [StepsExplainerSheet.Step] = [
        .init(title: "Point your camera at your habit",
              copy: "Show whatever you're doing, however you're doing it."),
        .init(title: "Fit it inside the frame",
              copy: "Aura just needs to see it clearly."),
        .init(title: "Tap the camera button",
              copy: "One photo is all it takes."),
    ]

    var body: some View {
        ZStack(alignment: .top) {
            LightSheet.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    // `xxl` between the steps and above them, matching
                    // `StepsExplainerSheet`. At `l` the two-line steps ran into
                    // each other: the gap between steps was the same as the gap
                    // inside one, so the list read as six lines rather than
                    // three pairs.
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                        tip

                        VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                                row(number: index + 1, step: step)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.xl)
                    .padding(.bottom, Theme.Spacing.xxxl)
                }
            }
        }
    }

    /// `LightSubSheetHeader` composed by hand so this reads as the same header
    /// as the other help sheets.
    private var header: some View {
        VStack(spacing: 0) {
            LightDragCapsule()

            Text("How Healthy Habits Work")
                .auraFont(.display, SheetType.title, .bold)
                .foregroundStyle(LightSheet.title)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.l)

            Text("Show Aura you started, then earn coins.")
                .auraFont(.body, SheetType.subtitle, .regular)
                .foregroundStyle(SheetType.subtitleColor)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Theme.Spacing.xxl)
                .padding(.top, Theme.Spacing.xs)
        }
    }

    /// Identical construction to `StepsExplainerSheet.row`, so a step reads the
    /// same whichever sheet it's on.
    private func row(number: Int, step: StepsExplainerSheet.Step) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            Text("\(number)")
                .auraFont(.display, SheetType.cardTitle, .bold)
                .foregroundStyle(.white)
                .frame(width: CircleIconButton.Grade.chrome.diameter,
                       height: CircleIconButton.Grade.chrome.diameter)
                .background(Circle().fill(habit.category.accent))

            VStack(alignment: .leading, spacing: RowType.labelGap) {
                Text(step.title)
                    .auraFont(.body, SheetType.cardTitle, .semibold)
                    .foregroundStyle(SheetType.titleColor)
                Text(step.copy)
                    .auraFont(.body, SheetType.cardBlurb, .regular)
                    .foregroundStyle(SheetType.subtitleColor)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    /// The habit's own hint, in the app's tip card. Above the steps, because
    /// the steps are the same every time and this is the part that changes.
    private var tip: some View {
        InfoCard(title: "Tip from Aura", copy: habit.proofHint) {
            // The app icon itself, not the wordmark on a blue square: it's
            // Aura speaking, and the icon is what the user already recognises
            // from their home screen.
            Image("AuraAppIcon")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 27, height: 27)
                .appIconChrome(side: 27, border: 0)
        }
    }
}
