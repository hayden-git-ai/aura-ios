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
    @State private var pops: [String: Int] = [:]

    private var groups: [(tag: HabitTag, items: [Habit])] {
        let order: [HabitTag] = [.focus, .exercise, .health, .social, .creative, .home]
        return order.compactMap { tag in
            let items = store.proofHabits.filter { $0.tag == tag }
            return items.isEmpty ? nil : (tag, items)
        }
    }

    private var hasPick: Bool { store.proofHabits.contains { store.isFavorite($0) } }

    var body: some View {
        OnbLaunchPickerScaffold(
            progress: flow.progress,
            showBack: false,
            title: "which healthy habits do you want to earn Aura Coins with?",
            reaction: "love it. those are your ways back to guilt-free scrolling.",
            canContinue: hasPick,
            onContinue: { flow.advance() }
        ) {
            ForEach(groups, id: \.tag) { group in
                OnbSectionHeader(group.tag.label)
                OnbCardGrid(group.items) { habit in
                    let key = habit.id.uuidString
                    OnbPickCard(
                        title: habit.name,
                        isFavorite: store.isFavorite(habit),
                        popTrigger: pops[key] ?? 0,
                        onTap: { favorite(habit, key: key) },
                        onFavorite: { tap(); store.toggleFavorite(habit) },
                        icon: { habitGlyph(habit) }
                    )
                }
            }
        }
    }

    private func tap() {
        Haptics.impact(.light)
        AudioServicesPlaySystemSound(1104)
    }

    private func favorite(_ habit: Habit, key: String) {
        tap()
        if !store.isFavorite(habit) { pops[key, default: 0] += 1 }
        store.toggleFavorite(habit)
    }

    @ViewBuilder private func habitGlyph(_ habit: Habit) -> some View {
        if let asset = habit.iconAsset {
            Image(asset).resizable().interpolation(.high).scaledToFit()
        } else {
            Text(habit.emoji.isEmpty ? "📸" : habit.emoji).font(.system(size: 40))
        }
    }
}
