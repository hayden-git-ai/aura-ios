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
    @State private var filter: HabitFilter = .all
    /// Camera Reps difficulty tab. nil == "All".
    @State private var exerciseFilter: ExerciseDifficulty? = nil
    /// Lets the selected capsule travel between pills rather than blink over.
    @Namespace private var filterPill

    var body: some View {
        VStack(spacing: 0) {
            habitList(startCategory)
        }
        .background(MethodScreenBackground(
            height: MethodScreenBackground.heroCentred(stickerHeight: startCategory.heroHeight),
            color: startCategory.accent))
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
        case .photoTask: return "Snap the proof, pocket the coins!"
        case .exercise: return "Every rep you knock out earns you coins!"
        case .focus: return "Apps stay locked till the timer's up!"
        case .healthSync: return "Your steps are secretly stacking coins!"
        }
    }

    @ViewBuilder
    private func habitList(_ category: HabitCategory) -> some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                FocusHero(
                    sticker: methodSticker(category),
                    title: methodTitle(category),
                    subtitle: methodSubtitle(category),
                    stickerHeight: category.heroHeight,
                    titleColor: .white,
                    subtitleColor: LightSheet.onColour,
                    titleGap: 0
                )
                .frame(maxWidth: .infinity)
                .id("top")

                if category == .photoTask {
                    photoTabbed(category)
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
        // A short filter after scrolling down would otherwise leave the content
        // jumping out from under the thumb.
        .onChange(of: filter) {
            withAnimation(.easeInOut(duration: 0.28)) { proxy.scrollTo("top", anchor: .top) }
        }
        .onChange(of: exerciseFilter) {
            withAnimation(.easeInOut(duration: 0.28)) { proxy.scrollTo("top", anchor: .top) }
        }
        }
        // Close X floats over the scrolling hero. The rate-editor button that
        // used to sit opposite it is gone — every rate it held now lives on the
        // habit's own screen, one tap in from its tile.
        // X left, `?` right — the same pairing on every quest screen, so the
        // way out is always in one corner and the explainer in the other.
        .overlay(alignment: .topLeading) {
            CircleIconButton(symbol: "xmark", glyphColor: LightSheet.subtitleDark, bounces: false) { dismiss() }
                .padding(.leading, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.l)
        }
        .overlay(alignment: .topTrailing) {
            ExplainerButton(explainer: QuestExplainer.forCategory(category))
                .padding(.trailing, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.l)
        }
        .overlay(alignment: .bottomTrailing) {
            if category == .photoTask {
                CreateHabitButton(color: category.accent) { openBuilder(category) }
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

    @ViewBuilder
    private func photoTabbed(_ category: HabitCategory) -> some View {
        // Stats' curve, not the pill's default snap — the two mode switches in
        // the app should feel identical.
        LightSegmentedPill(
            titles: ["Focus Habits", "Quick Habits"],
            selection: Binding(get: { photoTab },
                               set: { new in
                                   withAnimation(.easeInOut(duration: 0.32)) {
                                       photoTab = new
                                       filter = .all
                                   }
                               }),
            onBlue: true,
            onColor: startCategory.accent
        )
            .padding(.top, Theme.Spacing.xs)

        filterStrip
            .padding(.top, Theme.Spacing.xs)

        let habits = pinnedFirst(visibleHabits)
        VStack(spacing: Theme.Spacing.m) {
            ForEach(habits) { habit in
                habitRow(habit)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            // The one filter that can legitimately be empty.
            if habits.isEmpty {
                VStack(spacing: Theme.Spacing.m) {
                    // Its own art now, not the method's mascot standing in. The
                    // same illustration whichever method you're on, because
                    // "you haven't made one yet" is the same fact in all four.
                    //
                    // No contour, but it keeps the shadow. The white outline
                    // is what makes something read as a sticker CUT OUT and
                    // laid on a surface; the shadow is just what lifts it off
                    // one. An illustration wants the second without the first.
                    //
                    // Applied here rather than baked, because at 150pt the
                    // sticker pipeline's proportions would be a much heavier
                    // shadow than the same treatment gives a 34pt icon.
                    Image("FoxEmptyState")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        // 141, not 150, and the number comes from the art.
                        // The drawing is 425px tall; at 3x that is 141pt of
                        // screen. Asking for 150 stretched it, and no amount of
                        // interpolation invents detail that was never exported.
                        .frame(height: 141)
                        .foxShadow()

                    VStack(spacing: Theme.Spacing.xs) {
                        Text("No custom habits yet")
                            .auraFont(.display, SheetType.sectionHeader, .bold)
                            .foregroundStyle(.white)
                        Text("Press \"+\" to create your own")
                            .auraFont(.body, SheetType.subtitle, .regular)
                            .foregroundStyle(LightSheet.onColour)
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
        habits.filter { pinnedHabits.contains($0.id) } + habits.filter { !pinnedHabits.contains($0.id) }
    }

    /// The current tab's habits, narrowed by the filter pill.
    private var visibleHabits: [Habit] {
        let base = photoTab == 0 ? store.focusHabits : store.quickHabits
        return base.filter { filter.matches($0) }
    }

    /// Only the pills that would actually return something in this tab — an
    /// empty category is a dead end, not a filter.
    private var availableFilters: [HabitFilter] {
        let base = photoTab == 0 ? store.focusHabits : store.quickHabits
        // "Created by me" is always second, whether or not anything is in it —
        // it's how someone learns they can build their own.
        var options: [HabitFilter] = [.all, .custom]
        options += HabitTag.allCases
            .filter { tag in base.contains { $0.tag == tag } }
            .map { HabitFilter.tag($0) }
        return options
    }

    /// Horizontal pills over the list, in the same translucent material the FAB
    /// sits on. Bleeds past the content's margins so it scrolls edge to edge.
    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.s) {
                ForEach(availableFilters, id: \.self) { option in
                    let selected = filter == option
                    Text(option.label)
                        .auraFont(.body, RowType.value, .semibold)
                        .foregroundStyle(selected ? startCategory.accent : .white)
                        .padding(.horizontal, Theme.Spacing.l)
                        .frame(height: 32)
                        .background {
                            // The unselected track is always there; only the
                            // white capsule moves, and it moves rather than
                            // fading out and back in somewhere else.
                            Capsule().fill(.black.opacity(0.12))
                            if selected {
                                Capsule()
                                    .fill(.white)
                                    .matchedGeometryEffect(id: "filterPill", in: filterPill)
                            }
                        }
                        .contentShape(Capsule())
                        .onTapGesture {
                            guard filter != option else { return }
                            Haptics.selection()
                            withAnimation(.snappy(duration: 0.28)) { filter = option }
                        }
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
        }
        .scrollClipDisabled()
        .padding(.horizontal, -Theme.Spacing.xl)
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

    private var exerciseList: some View {
        // Easy at the top, hard at the bottom by default; favourites still float
        // above the rest, ordered easy→hard among themselves. Swift's sort is
        // stable, so the authored order holds within a tier.
        let byDifficulty = Exercise.all.sorted { $0.difficulty.rank < $1.difficulty.rank }
        let ordered = byDifficulty.filter { pinnedExercises.contains($0.id) }
            + byDifficulty.filter { !pinnedExercises.contains($0.id) }
        let shown = ordered.filter { exerciseFilter == nil || $0.difficulty == exerciseFilter }
        return VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            exerciseFilterStrip
                .padding(.top, Theme.Spacing.xs)

            VStack(spacing: Theme.Spacing.m) {
                ForEach(shown) { exercise in
                    exerciseRow(exercise)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
        }
    }

    /// Difficulty tabs over the exercise list — All / Easy / Medium / Hard, the
    /// same translucent pill strip Photo Proof uses for its categories.
    private var exerciseFilterStrip: some View {
        let options: [ExerciseDifficulty?] = [nil] + ExerciseDifficulty.allCases
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.s) {
                ForEach(options, id: \.self) { option in
                    let selected = exerciseFilter == option
                    Text(option?.label ?? "All")
                        .auraFont(.body, RowType.value, .semibold)
                        .foregroundStyle(selected ? startCategory.accent : .white)
                        .padding(.horizontal, Theme.Spacing.l)
                        .frame(height: 32)
                        .background {
                            Capsule().fill(.black.opacity(0.12))
                            if selected {
                                Capsule()
                                    .fill(.white)
                                    .matchedGeometryEffect(id: "exerciseFilterPill", in: filterPill)
                            }
                        }
                        .contentShape(Capsule())
                        .onTapGesture {
                            guard exerciseFilter != option else { return }
                            Haptics.selection()
                            withAnimation(.snappy(duration: 0.28)) { exerciseFilter = option }
                        }
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
        }
        .scrollClipDisabled()
        .padding(.horizontal, -Theme.Spacing.xl)
    }

    private func exerciseRow(_ exercise: Exercise) -> some View {
        HabitPickerRow(
            title: exercise.name,
            rate: "\(String(format: "%g", store.rate(for: exercise)))/\(exercise.unitNoun)",
            isFavorite: store.isFavorite(exercise),
            iconWidth: 66,
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

