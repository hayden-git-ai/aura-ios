//
//  OnboardingHabits.swift
//  Aura iOS
//
//  Phase 6: pick starter habits from the REAL catalogue, grouped into categories.
//  Two screens — healthy habits (photo-proof, by HabitTag) and daily exercise
//  (by difficulty). Compact 2-column cards (sticker over label, heart top-right,
//  no coin rate) on the same translucent ground as the question cards, so the fox
//  header fits on every screen. Hearting favourites them in the store; a tap
//  anywhere on a card also plays the heart pop (onboarding only).
//

import SwiftUI
import AudioToolbox

/// The same tap feedback the other onboarding cards use.
private func cardTap() {
    Haptics.impact(.light)
    AudioServicesPlaySystemSound(1104)
}

// MARK: - Healthy habits (grouped by category)

struct OnbHabitPickView: View {
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
        OnbPickerScaffold(
            progress: 0.94,
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
                        onFavorite: { cardTap(); store.toggleFavorite(habit) },
                        icon: { habitGlyph(habit) }
                    )
                }
            }
        }
    }

    private func favorite(_ habit: Habit, key: String) {
        cardTap()
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

// MARK: - Daily exercise (grouped by difficulty)

struct OnbExercisePickView: View {
    @Environment(OnboardingFlow.self) private var flow
    @Environment(HabitStore.self) private var store
    @State private var pops: [String: Int] = [:]

    private var groups: [(tier: ExerciseDifficulty, items: [Exercise])] {
        ExerciseDifficulty.allCases.compactMap { tier in
            let items = Exercise.all.filter { $0.difficulty == tier }
            return items.isEmpty ? nil : (tier, items)
        }
    }

    private var hasPick: Bool { Exercise.all.contains { store.isFavorite($0) } }

    var body: some View {
        OnbPickerScaffold(
            progress: 0.96,
            title: "which exercises do you want to earn Aura Coins with?",
            reaction: "jeez, the couch is gonna miss you.",
            canContinue: hasPick,
            onContinue: { flow.advance() }
        ) {
            ForEach(groups, id: \.tier) { group in
                OnbSectionHeader(group.tier.label)
                OnbCardGrid(group.items) { exercise in
                    OnbPickCard(
                        title: exercise.name,
                        isFavorite: store.isFavorite(exercise),
                        popTrigger: pops[exercise.id] ?? 0,
                        onTap: { favorite(exercise) },
                        onFavorite: { cardTap(); store.toggleFavorite(exercise) },
                        icon: {
                            Image(exercise.iconAsset).resizable().interpolation(.high).scaledToFit()
                        }
                    )
                }
            }
        }
    }

    private func favorite(_ exercise: Exercise) {
        cardTap()
        if !store.isFavorite(exercise) { pops[exercise.id, default: 0] += 1 }
        store.toggleFavorite(exercise)
    }
}

// MARK: - 2-column grid of a category's items

struct OnbCardGrid<Item: Identifiable, Card: View>: View {
    let items: [Item]
    @ViewBuilder let card: (Item) -> Card
    init(_ items: [Item], @ViewBuilder card: @escaping (Item) -> Card) {
        self.items = items; self.card = card
    }
    private let columns = [GridItem(.flexible(), spacing: Theme.Spacing.s),
                           GridItem(.flexible(), spacing: Theme.Spacing.s)]
    var body: some View {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.s) {
            ForEach(items) { card($0) }
        }
    }
}

// MARK: - Compact pick card (sticker over label, heart top-right)

struct OnbPickCard<Icon: View>: View {
    let title: String
    let isFavorite: Bool
    var popTrigger: Int = 0
    let onTap: () -> Void
    let onFavorite: () -> Void
    @ViewBuilder let icon: () -> Icon

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: Theme.Spacing.s) {
                icon()
                    .frame(width: 56, height: 56)
                Text(title)
                    .auraFont(.body, SheetType.cardTitle, .semibold)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 132)
            .padding(.horizontal, Theme.Spacing.s)
            .background(Color.black.opacity(0.16),
                        in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(isFavorite ? Color.white : Color.clear, lineWidth: 2.5))
            .overlay(alignment: .topTrailing) {
                FavoriteHeart(isOn: isFavorite, action: onFavorite, popTrigger: popTrigger,
                              idleTint: .white.opacity(0.45))
                    .padding(Theme.Spacing.s)
            }
        }
        .buttonStyle(PressBounceStyle())
    }
}

// MARK: - Section header

struct OnbSectionHeader: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .auraFont(.display, SheetType.sectionHeader, .bold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Theme.Spacing.m)
            .padding(.bottom, Theme.Spacing.xs)
    }
}

// MARK: - Shared scaffold (fox header, scroll grid, gated CTA)

struct OnbPickerScaffold<Rows: View>: View {
    var progress: Double
    let title: String
    /// Fox's reaction after Continue (types in place, then auto-advances). Nil skips it.
    var reaction: String? = nil
    var canContinue: Bool = true
    let onContinue: () -> Void
    @ViewBuilder var rows: () -> Rows

    @State private var reacting = false
    @State private var advanced = false

    private func finish() {
        guard !advanced else { return }
        advanced = true
        onContinue()
    }

    var body: some View {
        ZStack {
            LightSheet.blue.ignoresSafeArea()

            VStack(spacing: 0) {
                OnbTopBar(showBack: true, progress: progress, onSky: true)

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
                    .padding(.bottom, Theme.Spacing.xl)
                }
                .opacity(reacting ? 0.55 : 1)
                .allowsHitTesting(!reacting)

                onbContinue(enabled: canContinue) {
                    if reaction != nil, !reacting {
                        withAnimation(.easeInOut(duration: 0.25)) { reacting = true }
                    } else {
                        finish()
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
                Spacer().frame(height: Theme.Spacing.l)
            }
        }
    }
}
