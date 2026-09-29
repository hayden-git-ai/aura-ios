//
//  ExerciseHelpSheet.swift
//  Aura iOS
//

import SwiftUI

/// How to set the phone up, for someone who has never done it.
///
/// `ProofHelpSheet`'s twin, down to the header construction and the spacing,
/// because the two cameras should answer the same question the same way.
///
/// This one earns its place more than Photo Proof's does. Pointing a camera at
/// a book is obvious; propping a phone far enough back that a whole body stays
/// in frame through a rep is not, and it's the single reason a session counts
/// nothing. The exercise's own form tip used to live on the detail screen and
/// then disappear the moment the camera opened, which is exactly when it was
/// needed.
struct ExerciseHelpSheet: View {
    let exercise: Exercise

    /// Deliberately general. The exercise-specific part is the tip card above;
    /// these three are the same whichever exercise you picked, and writing them
    /// about push-ups would confuse anyone doing jumping jacks.
    private let steps: [StepsExplainerSheet.Step] = [
        .init(title: "Prop your phone up",
              copy: "Anywhere it can see you from head to toe."),
        .init(title: "Back up until you fit",
              copy: "Further than feels necessary. All of you has to stay in frame."),
        .init(title: "Start moving",
              copy: "Aura counts as you go. Nothing to tap."),
    ]

    var body: some View {
        ZStack(alignment: .top) {
            LightSheet.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
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

            Text("How Daily Exercises Work")
                .auraFont(.display, SheetType.title, .bold)
                .foregroundStyle(LightSheet.title)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.l)

            Text("Move in front of your camera and earn as you go.")
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
                .background(Circle().fill(HabitCategory.exercise.accent))

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

    /// The exercise's own form tip, in the app's tip card. Above the steps,
    /// because the steps are the same every time and this is the part that
    /// changes.
    private var tip: some View {
        InfoCard(title: "Tip from Aura", copy: exercise.formTip) {
            Image("AuraAppIcon")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 27, height: 27)
                .appIconChrome(side: 27, border: 0)
        }
    }
}
