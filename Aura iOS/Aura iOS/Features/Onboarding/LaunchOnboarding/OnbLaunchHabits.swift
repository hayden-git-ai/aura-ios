//
//  OnbLaunchHabits.swift
//  Aura iOS
//
//  Launch-flow copy of OnbHabitPickView (screen 10). Reuses the shared picker
//  scaffold/grid/card; progress off the active sequence (flow.progress).
//

import SwiftUI
import AudioToolbox

struct OnbLaunchHabits: View {
    @Environment(OnboardingFlow.self) private var flow
    @Environment(HabitStore.self) private var store
    @State private var heartPops: [UUID: Int] = [:]
    @State private var selectedHabitIDs: Set<UUID> = []

    private var groups: [(tag: HabitTag, items: [Habit])] {
        let order: [HabitTag] = [.focus, .exercise, .health, .social, .creative, .home]
        return order.compactMap { tag in
            let items = store.proofHabits.filter { $0.tag == tag }
            return items.isEmpty ? nil : (tag, items)
        }
    }

    private var hasPick: Bool { !selectedHabitIDs.isEmpty }

    var body: some View {
        OnbLaunchQuestionLayout(showBack: true, progress: flow.progress,
                                question: "Which healthy habits do you want to build?") {
            ScrollView {
                // This screen has a small, fixed catalogue. A LazyVStack enters a
                // placement loop when its grouped sections cross the viewport on
                // iOS 26, pinning the main thread and making the screen appear
                // frozen. Eager layout is cheap here and keeps scrolling stable.
                VStack(spacing: Theme.Spacing.s) {
                    ForEach(Array(groups.enumerated()), id: \.element.tag) { index, group in
                        Text(group.tag.label)
                            .auraFont(.display, 22, .bold)
                            .foregroundStyle(LightSheet.title)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, index == 0 ? Theme.Spacing.m : Theme.Spacing.xxl)
                            .padding(.bottom, Theme.Spacing.m)
                        VStack(spacing: Theme.Spacing.s) {
                            ForEach(group.items) { habit in
                                HabitPickerCard(
                                    title: habit.name,
                                    rate: habit.requiresFocusSession
                                        ? "\(Int(habit.rewardRate))/hr"
                                        : "\(habit.rewardMinutes)",
                                    isFavorite: selectedHabitIDs.contains(habit.id),
                                    popTrigger: heartPops[habit.id, default: 0],
                                    onTap: { toggleSelection(habit) },
                                    onFavorite: { toggleSelection(habit) },
                                    icon: { habitGlyph(habit) }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.s)
            }
        } bottom: {
            onbLaunchContinue(enabled: hasPick) {
                saveAndContinue()
            }
        }
    }

    private func tap() {
        Haptics.impact(.light)
        AudioServicesPlaySystemSound(1104)
    }

    private func toggleSelection(_ habit: Habit) {
        tap()
        if selectedHabitIDs.insert(habit.id).inserted {
            heartPops[habit.id, default: 0] += 1
        } else {
            selectedHabitIDs.remove(habit.id)
        }
    }

    private func saveAndContinue() {
        // Onboarding is a fresh choice, not a reflection of favorites that may
        // already exist in restored account data. Replace only the stock proof
        // habit choices and preserve custom/non-proof favorites.
        store.favoriteHabitIds.subtract(store.proofHabits.map(\.id))
        store.favoriteHabitIds.formUnion(selectedHabitIDs)
        flow.advance()
    }

    @ViewBuilder private func habitGlyph(_ habit: Habit) -> some View {
        if let asset = habit.iconAsset {
            Image(asset).resizable().interpolation(.high).scaledToFit()
        } else {
            Image("FoxPhotoProof").resizable().interpolation(.high).scaledToFit()
        }
    }
}
