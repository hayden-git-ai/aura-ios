//
//  ExerciseSelectView.swift
//  Aura iOS
//

import SwiftUI

/// Screen 1 of the Exercise flow — pick an exercise and hold to start. Mirrors
/// the Deep Focus setup screen's layout (close top-left, hero, a grid of glass
/// option cards, a live earn readout, a hold-to-start button). Rates are no
/// longer edited from here — each exercise's own screen owns them.
struct ExerciseSelectView: View {
    var onStart: (Exercise) -> Void
    var onClose: () -> Void

    @Environment(HabitStore.self) private var store

    @State private var selected: Exercise = Exercise.all[0]

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: Theme.Spacing.xxl) {
                    hero
                    exerciseSection
                    goalSection
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.l)
                .padding(.bottom, Theme.Spacing.xl)
            }

            HoldToConfirmButton(
                tint: Theme.Color.signalUnlock,
                idleCaption: "Hold to Commit",
                holdingCaption: "Keep Holding…",
                doneCaption: "Let's Go",
                idleCaptionColor: .white,
                duration: 2
            ) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    onStart(selected)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.l)
        }
        .background(Theme.Color.background.ignoresSafeArea())
    }

    private var header: some View {
        HStack {
            FocusCircleButton(systemImage: "xmark", action: onClose)
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, Theme.Spacing.l)
    }

    private var hero: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "figure.run")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
            Text("Exercise")
                .auraFont(.display, SheetType.title, .bold)
                .foregroundStyle(Theme.Color.textPrimary)
        }
    }

    private var exerciseSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            sectionLabel("Choose an exercise")

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: Theme.Spacing.m), GridItem(.flexible())],
                spacing: Theme.Spacing.m
            ) {
                ForEach(Exercise.all) { exercise in
                    exerciseCard(exercise)
                }
            }
        }
    }

    private func exerciseCard(_ exercise: Exercise) -> some View {
        let isSelected = selected == exercise
        return Button {
            selected = exercise
        } label: {
            FocusCard(
                borderColor: isSelected ? .white : Theme.Color.hairline,
                padding: Theme.Spacing.m,
                glass: true,
                interactive: true
            ) {
                HStack(spacing: Theme.Spacing.s) {
                    Image(systemName: exercise.iconSystemName)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: RowType.labelGap) {
                        Text(exercise.name)
                            .auraFont(.body, RowType.label, .medium)
                            .foregroundStyle(Theme.Color.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(rewardLabel(exercise))
                            .auraFont(.body, RowType.subLabel, .medium)
                            .foregroundStyle(Theme.Color.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    private func rewardLabel(_ exercise: Exercise) -> String {
        let unit = "Rep"
        return "\(String(format: "%g", store.rate(for: exercise))) Min x \(unit)"
    }

    // MARK: - Goal

    /// The session target for the currently selected exercise — hitting it makes
    /// the session count; the camera screen lets you keep going past it.
    private var goalSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            sectionLabel("Set a goal")

            FocusCard(padding: Theme.Spacing.l, glass: true, interactive: false) {
                VStack(spacing: Theme.Spacing.m) {
                    goalStepper

                    Text("Hit this goal to make the session count and be rewarded screen time. You can keep going past it.")
                        .auraFont(.body, SheetType.subtitle, .regular)
                        .foregroundStyle(Theme.Color.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var goalStepper: some View {
        let step = 1
        let value = store.goal(for: selected)
        return HStack(spacing: Theme.Spacing.xl) {
            goalStepButton(systemImage: "minus") { store.setGoal(value - step, for: selected) }

            Text(Exercise.goalDisplay(value))
                .auraFont(.display, 28, .bold)
                .foregroundStyle(.white)
                .frame(minWidth: 120)
                .monospacedDigit()
                .contentTransition(.numericText())

            goalStepButton(systemImage: "plus") { store.setGoal(value + step, for: selected) }
        }
    }

    private func goalStepButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) { action() }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: CircleIconButton.Grade.stepper.glyph, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: CircleIconButton.Grade.stepper.diameter,
                       height: CircleIconButton.Grade.stepper.diameter)
                .background(Circle().strokeBorder(LightSheet.chromeOnCamera, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .auraFont(.display, SheetType.sectionHeader, .bold)
            .foregroundStyle(Theme.Color.textPrimary)
    }
}

#Preview {
    ExerciseSelectView(onStart: { _ in }, onClose: {})
        .environment(HabitStore())
        .preferredColorScheme(.dark)
}
