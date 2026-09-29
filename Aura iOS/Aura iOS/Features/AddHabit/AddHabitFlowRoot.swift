//
//  AddHabitFlowRoot.swift
//  Aura iOS
//

import SwiftUI

/// What the picker asks the app to launch once a habit is chosen. The picker
/// itself doesn't present the earn flows (that would nest full-screen covers) —
/// it dismisses and hands one of these back to `RootTabView`, which presents
/// the matching flow.
enum HabitLaunch: Identifiable {
    case photo(Habit, Int)
    case reps(Exercise)

    var id: String {
        switch self {
        case .photo(let h, _): return "photo-\(h.id)"
        case .reps(let e): return "reps-\(e.id)"
        }
    }
}

/// Connected game-menu tabs for Healthy Habits. The selected face uses the
/// exact card artwork so the mint gradient and stars stay as clean as the
/// cards below it rather than being approximated in code.
private struct HealthyHabitGameTabs: View {
    let titles: [String]
    @Binding var selection: Int
    var selectedBackgroundAsset = "HealthyHabitCardBackground"
    var inactiveColor = LightSheet.healthyHabitsReward

    private let height: CGFloat = 58

    var body: some View {
        GeometryReader { geometry in
            let selectedShape = HealthyHabitSelectedTabShape(isLeading: selection == 0)

            ZStack {
                HealthyHabitTabBaseShape()
                    .fill(inactiveColor)

                Image(selectedBackgroundAsset)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: height)
                    .clipShape(selectedShape)

                selectedShape
                    .stroke(.white, lineWidth: 3)

                HStack(spacing: 0) {
                    ForEach(titles.indices, id: \.self) { index in
                        let selected = selection == index
                        Button {
                            guard selection != index else { return }
                            Haptics.selection()
                            selection = index
                        } label: {
                            HealthyHabitTabLabel(
                                text: titles[index],
                                selected: selected
                            )
                            .accessibilityHidden(true)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(titles[index])
                        .accessibilityValue(selected ? "Selected" : "")
                    }
                }
                .padding(.horizontal, Theme.Spacing.xs)
            }
            .overlay {
                HealthyHabitTabBaseShape()
                    .stroke(.white, lineWidth: 3)
            }
            .shadow(color: .black.opacity(0.22), radius: 5, y: 4)
        }
        .frame(height: height)
    }
}

private struct HealthyHabitTabLabel: View {
    let text: String
    let selected: Bool

    private let outlineWidth: CGFloat = 1.15
    private let directions: [(CGFloat, CGFloat)] = [
        (-1, -1), (0, -1), (1, -1),
        (-1, 0),            (1, 0),
        (-1, 1),  (0, 1),  (1, 1)
    ]

    var body: some View {
        ZStack {
            if selected {
                ForEach(directions.indices, id: \.self) { index in
                    label
                        .foregroundStyle(.white)
                        .offset(x: directions[index].0 * outlineWidth,
                                y: directions[index].1 * outlineWidth)
                }
            }

            label
                .foregroundStyle(selected ? .black : .white)
        }
        .shadow(color: .black.opacity(selected ? 0.14 : 0.20), radius: 1, y: 1)
    }

    private var label: some View {
        Text(text)
            .auraFont(.display, 18, .bold)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
    }
}

private struct HealthyHabitTabBaseShape: Shape {
    func path(in rect: CGRect) -> Path {
        RoundedRectangle(cornerRadius: 14, style: .continuous).path(in: rect)
    }
}

private struct HealthyHabitSelectedTabShape: Shape {
    let isLeading: Bool

    func path(in rect: CGRect) -> Path {
        let inset: CGFloat = 7
        let cut: CGFloat = 10
        let seam = rect.midX
        var path = Path()

        if isLeading {
            path.move(to: CGPoint(x: inset + cut, y: inset))
            path.addLine(to: CGPoint(x: seam - 10, y: inset))
            path.addLine(to: CGPoint(x: seam + 10, y: rect.maxY - inset))
            path.addLine(to: CGPoint(x: inset + cut, y: rect.maxY - inset))
            path.addQuadCurve(
                to: CGPoint(x: inset, y: rect.maxY - inset - cut),
                control: CGPoint(x: inset, y: rect.maxY - inset)
            )
            path.addLine(to: CGPoint(x: inset, y: inset + cut))
            path.addQuadCurve(
                to: CGPoint(x: inset + cut, y: inset),
                control: CGPoint(x: inset, y: inset)
            )
        } else {
            path.move(to: CGPoint(x: seam - 10, y: inset))
            path.addLine(to: CGPoint(x: rect.maxX - inset - cut, y: inset))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - inset, y: inset + cut),
                control: CGPoint(x: rect.maxX - inset, y: inset)
            )
            path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY - inset - cut))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - inset - cut, y: rect.maxY - inset),
                control: CGPoint(x: rect.maxX - inset, y: rect.maxY - inset)
            )
            path.addLine(to: CGPoint(x: seam + 10, y: rect.maxY - inset))
        }

        path.closeSubpath()
        return path
    }
}

/// The habit list + builder sheet for a single earn method — laid out to match
/// the Apple Health sheet (grabber, centered-title header, then a divided list
/// of icon rows) so the earn flows read as one consistent family. The method is
/// chosen upstream (the FAB popover). Tapping a habit hands a `HabitLaunch` back
/// up; the "Create your own" row opens the builder.
struct AddHabitFlowRoot: View {
    let startCategory: HabitCategory
    var onLaunch: (HabitLaunch) -> Void

    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// A pending builder presentation (nil existing == new habit). Presented as
    /// its own sub-sheet over the list so it gets its own compact detent.
    private struct BuilderTarget: Identifiable {
        let id = UUID()
        let existing: Habit?
        let category: HabitCategory
    }

    @State private var builderTarget: BuilderTarget?
    @State private var detail: Habit?
    @State private var exerciseDetail: Exercise?
    /// Favourites as they were when this sheet opened. Sorting off a snapshot
    /// rather than live state means tapping a heart doesn't re-order the list
    /// mid-scroll; the pin takes effect the next time it's opened.
    @State private var pinnedHabits: Set<UUID> = []
    @State private var pinnedExercises: Set<String> = []
    @State private var photoTab = 0
    /// Camera Reps uses the same two-face selector as Healthy Habits.
    /// Easy stays approachable; Medium and Hard are grouped under Hard.
    @State private var exerciseTab = 0

    private enum HealthyHeader {
        static let ribbonVisibleWidthRatio: CGFloat = 2062.0 / 2172.0
    }

    var body: some View {
        VStack(spacing: 0) {
            habitList(startCategory)
        }
        .background {
            if usesIllustratedEarnHeader(startCategory) {
                EarnMethodIllustratedBackground()
            } else {
                MethodScreenBackground(
                    height: MethodScreenBackground.heroCentred(stickerHeight: EarnFoxPlaybackView.defaultSize),
                    color: startCategory.accent)
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            pinnedHabits = store.favoriteHabitIds
            pinnedExercises = store.favoriteExerciseIds
        }
        .sheet(item: $builderTarget) { target in
            HabitBuilderView(
                existing: target.existing,
                method: target.category,
                onSave: { habit in
                    store.upsertHabit(habit)
                    if target.existing == nil && target.category == .photoTask {
                        if !store.isFavorite(habit) { store.toggleFavorite(habit) }
                        pinnedHabits = store.favoriteHabitIds
                        photoTab = habit.requiresFocusSession ? 0 : 1
                    }
                    builderTarget = nil
                },
                onClose: { builderTarget = nil }
            )
        }
    }

    /// Gray-circle icon button matching the light sheet's close button.
    // MARK: - Habits for a method

    private func methodTitle(_ category: HabitCategory) -> String {
        category.displayName
    }

    private func methodSubtitle(_ category: HabitCategory) -> String {
        switch category {
        case .photoTask: return "Snap a pic, earn coins!"
        case .exercise: return "Every rep you knock out earns you coins!"
        case .focus: return "Apps stay locked till the timer's up!"
        case .healthSync: return "Your steps are secretly stacking coins!"
        }
    }

    private func usesIllustratedEarnHeader(_ category: HabitCategory) -> Bool {
        category == .photoTask || category == .exercise
    }

    private func rewardRibbonAsset(_ category: HabitCategory) -> String {
        category == .exercise
            ? "DailyExerciseRewardRibbon"
            : "HealthyHabitsRewardRibbon"
    }

    private func rewardRibbonLabel(_ category: HabitCategory) -> String {
        category == .exercise
            ? "Do reps, earn coins!"
            : methodSubtitle(category)
    }

    @ViewBuilder
    private func habitList(_ category: HabitCategory) -> some View {
        VStack(spacing: 0) {
        if usesIllustratedEarnHeader(category) {
            EarnMethodIllustratedHeader {
                GeometryReader { geometry in
                    let artworkWidth = (geometry.size.width - Theme.Spacing.xl * 2)
                        / HealthyHeader.ribbonVisibleWidthRatio
                    Image(rewardRibbonAsset(category))
                        .resizable()
                        .scaledToFit()
                        .frame(width: artworkWidth, height: artworkWidth / 3)
                        .position(x: geometry.size.width / 2,
                                  y: geometry.size.height / 2 + Theme.Spacing.xs)
                        .shadow(color: .black.opacity(0.16), radius: 2, y: 2)
                }
                .accessibilityLabel(rewardRibbonLabel(category))
            }
            if category == .photoTask {
                photoToggle
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.xxl)
                    .padding(.bottom, Theme.Spacing.s)
            } else if category == .exercise {
                exerciseToggle
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.xxl)
                    .padding(.bottom, Theme.Spacing.s)
            }
        }
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                if !usesIllustratedEarnHeader(category) {
                    EarnMethodHero(title: methodTitle(category), subtitle: methodSubtitle(category))
                        .frame(maxWidth: .infinity)
                        .id("top")
                }

                if category == .photoTask {
                    photoTabbed(category)
                        .id("top")
                } else if category == .exercise {
                    exerciseList
                } else {
                    genericList(category)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.s)
            // Clears the FAB where there is one: its disc plus halo is 80 tall
            // and sits 24 off the bottom, so the last row's heart would be
            // under it and untappable.
            .padding(.bottom, category == .photoTask ? 120 : Theme.Spacing.xxl)
        }
        // The two lists are different lengths, so switching mid-scroll would
        // reflow the content under the slide. Start each at the top instead.
        .onChange(of: photoTab) { proxy.scrollTo("top", anchor: .top) }
        .onChange(of: exerciseTab) {
            withAnimation(.easeInOut(duration: 0.28)) { proxy.scrollTo("top", anchor: .top) }
        }
        }
        }
        // Close X floats over the scrolling hero. The rate-editor button that
        // used to sit opposite it is gone — every rate it held now lives on the
        // habit's own screen, one tap in from its tile.
        // X left, `?` right — the same pairing on every quest screen, so the
        // way out is always in one corner and the explainer in the other.
        .overlay(alignment: .topLeading) {
            CircleIconButton(symbol: "xmark",
                             fill: usesIllustratedEarnHeader(category) ? LightSheet.chromeOnBlue : LightSheet.chromeOnLight,
                             glyphColor: usesIllustratedEarnHeader(category) ? .white : LightSheet.subtitleDark,
                             bounces: false) {
                dismiss()
            }
                .padding(.leading, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.l)
        }
        .overlay(alignment: .topTrailing) {
            ExplainerButton(explainer: QuestExplainer.forCategory(category),
                            onBlue: usesIllustratedEarnHeader(category))
                .padding(.trailing, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.l)
        }
        .overlay(alignment: .bottomTrailing) {
            if category == .photoTask {
                CreateHabitButton(color: LightSheet.healthyHabitsMint) { openBuilder(category) }
                    .padding(.trailing, Theme.Spacing.xl)
                    .padding(.bottom, Theme.Spacing.xl)
            }
        }
        .fullScreenCover(item: $detail) { habit in
            HabitDetailView(habit: habit) { launch(habit) }
        }
        .fullScreenCover(item: $exerciseDetail) { exercise in
            ExerciseDetailView(exercise: exercise) { onLaunch(.reps(exercise)) }
        }
    }

    /// Hero mascot per method — placeholder stickers for the three that are
    /// still waiting on their own art.
    private func methodSticker(_ category: HabitCategory) -> String {
        category.heroIconAsset
    }

    // MARK: - Photo Proof (Focus / Quick tabs)

    private var photoToggle: some View {
        HealthyHabitGameTabs(
            titles: ["Focus Habits", "Quick Habits"],
            selection: Binding(
                get: { photoTab },
                set: { new in
                    withAnimation(.snappy(duration: 0.24)) { photoTab = new }
                }
            )
        )
    }

    @ViewBuilder
    private func photoTabbed(_ category: HabitCategory) -> some View {
        let habits = pinnedFirst(visibleHabits)
        VStack(spacing: Theme.Spacing.m) {
            LazyVGrid(
                columns: [GridItem(.flexible())],
                spacing: 12
            ) {
                ForEach(habits) { habit in
                    habitCard(habit)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }

            // Empty state remains available if a tab has no habits.
            if habits.isEmpty {
                VStack(spacing: Theme.Spacing.m) {
                    VStack(spacing: Theme.Spacing.xs) {
                        Text("No custom habits yet")
                            .auraFont(.display, SheetType.sectionHeader, .bold)
                            .foregroundStyle(.black)
                        Text("Press \"+\" to create your own")
                            .auraFont(.body, SheetType.subtitle, .regular)
                            .foregroundStyle(.black)
                    }
                    .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.Spacing.xxl)
                .transition(.opacity)
            }
        }
        .padding(.top, Theme.Spacing.xs)
        // Same left/right slide as the Stats and builder toggles.
        .id(photoTab)
        .transition(
            .asymmetric(
                insertion: .move(edge: photoTab == 0 ? .leading : .trailing).combined(with: .opacity),
                removal: .move(edge: photoTab == 0 ? .trailing : .leading).combined(with: .opacity)
            )
        )
    }

    /// Hearted first, everything else in its original order.
    private func pinnedFirst(_ habits: [Habit]) -> [Habit] {
        let favorites = habits.filter { pinnedHabits.contains($0.id) }
        return favorites.filter { $0.isCustom } + favorites.filter { !$0.isCustom }
            + habits.filter { !pinnedHabits.contains($0.id) }
    }

    private var visibleHabits: [Habit] {
        photoTab == 0 ? store.focusHabits : store.quickHabits
    }

    private func habitRow(_ habit: Habit) -> some View {
        HabitPickerRow(
            title: habit.name,
            rate: habit.requiresFocusSession
                ? "\(Int(habit.rewardRate))/hr"
                : "\(habit.rewardMinutes)",
            isFavorite: store.isFavorite(habit),
            // Straight to the habit's own screen rather than the camera: it
            // holds the reward settings that used to live in Edit Rewards, and
            // its CTA is what actually starts the run.
            onTap: { detail = habit },
            onFavorite: { store.toggleFavorite(habit) },
            icon: { habitGlyph(habit) }
        )
    }

    private func habitCard(_ habit: Habit) -> some View {
        HabitPickerCard(
            title: habit.name,
            rate: habit.requiresFocusSession
                ? "\(Int(habit.rewardRate))/hr"
                : "\(habit.rewardMinutes)",
            isFavorite: store.isFavorite(habit),
            onTap: { detail = habit },
            onFavorite: { store.toggleFavorite(habit) },
            icon: { habitGlyph(habit) }
        )
    }

    /// The habit's sticker illustration (or emoji fallback) — no circle behind it.
    @ViewBuilder
    private func habitGlyph(_ habit: Habit) -> some View {
        if let asset = habit.iconAsset {
            Image(asset)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                // Angle the dumbbell up toward the top-right.
                .rotationEffect(.degrees(asset == "FoxHabitGym" ? -15 : 0))
        } else {
            Text(habit.emoji.isEmpty ? "📸" : habit.emoji)
                .font(.system(size: 34))
        }
    }

    // MARK: - Camera Reps

    private var exerciseToggle: some View {
        HealthyHabitGameTabs(
            titles: ["Easy", "Hard"],
            selection: Binding(
                get: { exerciseTab },
                set: { new in
                    withAnimation(.snappy(duration: 0.24)) { exerciseTab = new }
                }
            ),
            selectedBackgroundAsset: "DailyExerciseCardBackground",
            inactiveColor: LightSheet.Achievement.reps.ink
        )
    }

    private var exerciseList: some View {
        // Easy at the top, hard at the bottom by default; favourites still float
        // above the rest, ordered easy→hard among themselves. Swift's sort is
        // stable, so the authored order holds within a tier.
        let byDifficulty = Exercise.all.sorted { $0.difficulty.rank < $1.difficulty.rank }
        let ordered = byDifficulty.filter { pinnedExercises.contains($0.id) }
            + byDifficulty.filter { !pinnedExercises.contains($0.id) }
        let shown = ordered.filter {
            exerciseTab == 0 ? $0.difficulty == .easy : $0.difficulty != .easy
        }
        return VStack(spacing: Theme.Spacing.m) {
            ForEach(shown) { exercise in
                exerciseRow(exercise)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .id(exerciseTab)
        .transition(
            .asymmetric(
                insertion: .move(edge: exerciseTab == 0 ? .leading : .trailing).combined(with: .opacity),
                removal: .move(edge: exerciseTab == 0 ? .trailing : .leading).combined(with: .opacity)
            )
        )
    }

    private func exerciseRow(_ exercise: Exercise) -> some View {
        HabitPickerCard(
            title: exercise.name,
            rate: "\(String(format: "%g", store.rate(for: exercise)))/\(exercise.unitNoun)",
            isFavorite: store.isFavorite(exercise),
            backgroundAsset: "DailyExerciseCardBackground",
            rewardColor: LightSheet.Achievement.reps.ink,
            onTap: { exerciseDetail = exercise },
            onFavorite: { store.toggleFavorite(exercise) },
            icon: {
                Image(exercise.iconAsset)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            }
        )
    }

    // MARK: - Generic (other categories)

    private func genericList(_ category: HabitCategory) -> some View {
        let habits = pinnedFirst(store.habits(for: category))
        return VStack(spacing: Theme.Spacing.m) {
            ForEach(habits) { habit in
                habitRow(habit)
            }
        }
    }

    // MARK: - Helpers

    private func openBuilder(_ category: HabitCategory) {
        builderTarget = BuilderTarget(existing: nil, category: category)
    }

    private func launch(_ habit: Habit) {
        switch habit.category {
        // The habit screen already applied any edits, so read the live copy
        // rather than the snapshot the tile was built from.
        case .photoTask:
            let live = store.liveHabit(habit.id) ?? habit
            onLaunch(.photo(live, live.defaultFocusMinutes))
        case .exercise, .focus, .healthSync: break
        }
    }
}
