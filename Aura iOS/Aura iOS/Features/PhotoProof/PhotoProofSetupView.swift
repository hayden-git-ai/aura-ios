//
//  PhotoProofSetupView.swift
//  Aura iOS
//

import SwiftUI

/// Screen 1 of the Photo Proof flow — pick a Proof habit, set the session
/// length, and hold to commit. Mirrors the Deep Focus / Exercise setup layout.
struct PhotoProofSetupView: View {
    var onStart: (Habit, Int) -> Void
    var onClose: () -> Void

    @Environment(HabitStore.self) private var store

    @State private var selectedID: UUID?
    @State private var lengthMinutes = 30

    private var habits: [Habit] { store.proofHabits }
    private var selected: Habit? { habits.first { $0.id == selectedID } ?? habits.first }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: Theme.Spacing.xxl) {
                    hero
                    habitSection
                    lengthSection
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
                guard let selected else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    onStart(selected, lengthMinutes)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.l)
        }
        .background(Theme.Color.background.ignoresSafeArea())
        .onAppear { if selectedID == nil { selectedID = habits.first?.id } }
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
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
            Text("Healthy Habits")
                .auraFont(.display, SheetType.title, .bold)
                .foregroundStyle(Theme.Color.textPrimary)
        }
    }

    private var habitSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            sectionLabel("Choose a habit")
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: Theme.Spacing.m), GridItem(.flexible())],
                spacing: Theme.Spacing.m
            ) {
                ForEach(habits) { habit in
                    habitCard(habit)
                }
            }
        }
    }

    private func habitCard(_ habit: Habit) -> some View {
        let isSelected = habit.id == selected?.id
        return Button {
            selectedID = habit.id
        } label: {
            FocusCard(
                borderColor: isSelected ? .white : Theme.Color.hairline,
                padding: Theme.Spacing.m,
                glass: true,
                interactive: true
            ) {
                HStack(spacing: Theme.Spacing.s) {
                    Image(systemName: habit.iconSystemName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: RowType.labelGap) {
                        Text(habit.name)
                            .auraFont(.body, RowType.label, .medium)
                            .foregroundStyle(Theme.Color.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text("\(habit.rewardMinutes) min reward")
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

    private var lengthSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            sectionLabel("Session length")
            FocusLengthScrubber(lengthMinutes: $lengthMinutes)
            Text("Do this for \(Text(FocusDuration.label(lengthMinutes)).font(Typography.body(size: 14, weight: .bold)).foregroundStyle(.white)) to unlock \(Text("\(selected?.rewardMinutes ?? 0) min").font(Typography.body(size: 14, weight: .bold)).foregroundStyle(.white)) of screen time")
                .auraFont(.body, 14, .medium)
                .foregroundStyle(Theme.Color.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, Theme.Spacing.xs)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .auraFont(.display, SheetType.sectionHeader, .bold)
            .foregroundStyle(Theme.Color.textPrimary)
    }
}

#Preview {
    PhotoProofSetupView(onStart: { _, _ in }, onClose: {})
        .environment(HabitStore())
        .preferredColorScheme(.dark)
}
