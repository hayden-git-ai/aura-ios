//
//  HabitDetailView.swift
//  Aura iOS
//

import SwiftUI

/// A habit's own screen: what it's earned you, how it's tuned, and the button
/// that starts it. Replaces the Edit Rewards sheets — every value those held is
/// still here, one row each, rather than buried two sheets deep behind a
/// global editor.
struct HabitDetailView: View {
    @Environment(HabitStore.self) private var store
    @State private var showRoutine = false
    @State private var showOffline = false
    @Environment(\.dismiss) private var dismiss

    let habit: Habit
    var onStart: () -> Void

    private enum Editing: String, Identifiable {
        case length
        var id: String { rawValue }
    }

    @State private var editing: Editing?

    /// Read live so the rows update as the sheets change them.
    private var live: Habit { store.liveHabit(habit.id) ?? habit }
    private var requiresFocus: Bool { live.requiresFocusSession }

    /// What to point the camera at. Stock habits ship their own line; habits
    /// someone built themselves have none, so they get the general rule.
    private var proofTip: String {
        live.proofHint.isEmpty
            ? "Frame whatever shows you're starting. I only need to see it once."
            : live.proofHint
    }

    var body: some View {
        HabitDetailScaffold(
            sticker: habit.iconAsset ?? "FoxPhotoProof",
            title: habit.name,
            accent: habit.category.accent,
            accentSoft: habit.category.accentSoft,
            accentShade: habit.category.accentShade,
            tip: proofTip,
            // Quick habits have no session, so "total time" would always be
            // 0m for them no matter how often they're done.
            stats: requiresFocus
                ? [("0", "Times done"), ("0m", "Total time"), ("0", "Coins earned")]
                : [("0", "Times done"), ("0", "Day streak"), ("0", "Coins earned")],
            primaryTitle: requiresFocus ? "Start Habit" : "Show the Proof",
            primaryCoins: live.earnedMinutes,
            onClose: { dismiss() },
            onRoutine: { showRoutine = true },
            onShareOffline: { showOffline = true },
            onPrimary: {
                dismiss()
                onStart()
            }
        ) {
            if requiresFocus {
                HabitSettingRow(
                    icon: .sticker("HealthyHabitsFocusLength"),
                    title: "Focus length",
                    subtitle: FocusDuration.label(live.defaultFocusMinutes)
                ) { editing = .length }
            } else {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    HabitToggleRow(
                        icon: .sticker("OncePerDayFlame"),
                        title: "Once per day",
                        subtitle: live.oncePerDay ? "Yes" : "No",
                        isOn: Binding(get: { live.oncePerDay },
                                      set: { store.setOncePerDay($0, for: habit) })
                            .animation(.snappy(duration: 0.25))
                    )

                    Text(live.oncePerDay
                         ? "Can only be earned once per day. Resets at midnight."
                         : "Pays out every time you do it. No daily limit.")
                        .auraFont(.body, SheetType.subtitle, .regular)
                        .foregroundStyle(SheetType.subtitleColor)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, Theme.Spacing.m)
                        .id(live.oncePerDay)
                        .transition(.push(from: .bottom).combined(with: .opacity))
                        .animation(.snappy(duration: 0.25), value: live.oncePerDay)
                }
            }
        }
        .sheet(isPresented: $showRoutine) {
            HabitRoutineSheet(habitName: habit.name,
                              accent: habit.category.accent,
                              accentShade: habit.category.accentShade)
                .auraSheet([.fraction(0.9)])
        }
        .sheet(isPresented: $showOffline) {
            // A focus habit announces an absence. A quick one is over in a
            // minute and has no absence to announce, so it dares instead.
            OfflineShareSheet(
                title: "Tell people you're offline",
                subtitle: "So nobody thinks you're ignoring them.",
                sticker: habit.iconAsset ?? habit.category.tileIconAsset,
                accent: habit.category.accent,
                accentShade: habit.category.accentShade)
                .auraSheet([.height(668)])
        }
        .sheet(item: $editing) { field in
            switch field {
            case .length:
                WheelPickerSheet(
                    title: "Focus length",
                    subtitle: "How long a session runs before it pays out.",
                    values: Array(stride(from: 5, through: 240, by: 5)),
                    selection: Binding(get: { live.defaultFocusMinutes },
                                       set: { store.setDefaultMinutes($0, for: habit) }),
                    label: { FocusDuration.label($0) }
                )

            }
        }
    }
}

/// The Camera Reps counterpart. Same shell, with the one thing left to set:
/// the goal you have to clear before anything pays.
struct ExerciseDetailView: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let exercise: Exercise
    var onStart: () -> Void

    private enum Editing: String, Identifiable {
        case goal
        var id: String { rawValue }
    }

    @State private var editing: Editing?
    @State private var showRoutine = false
    @State private var showOffline = false

    private var unit: String { exercise.unitNoun }

    var body: some View {
        HabitDetailScaffold(
            sticker: exercise.iconAsset,
            title: exercise.name,
            accent: HabitCategory.exercise.accent,
            accentSoft: HabitCategory.exercise.accentSoft,
            accentShade: HabitCategory.exercise.accentShade,
            tip: exercise.formTip,
            stats: [
                ("0", "Times done"),
                ("0", "Total \(unit)s"),
                ("0", "Coins earned"),
            ],
            primaryTitle: "Start Exercise",
            // What clearing the goal pays — the floor, not a cap.
            primaryCoins: exercise.earnedMinutes(forUnits: store.goal(for: exercise),
                                                 rate: store.rate(for: exercise),
                                                 goal: store.goal(for: exercise)),
            onClose: { dismiss() },
            onRoutine: { showRoutine = true },
            onShareOffline: { showOffline = true },
            onPrimary: {
                dismiss()
                onStart()
            }
        ) {
            HabitSettingRow(
                icon: .sticker("DailyExerciseGoal"),
                title: "Goal",
                subtitle: Exercise.goalDisplay(store.goal(for: exercise))
            ) { editing = .goal }
        }
        .sheet(isPresented: $showRoutine) {
            HabitRoutineSheet(habitName: exercise.name,
                              accent: HabitCategory.exercise.accent,
                              accentShade: HabitCategory.exercise.accentShade)
                .auraSheet([.fraction(0.9)])
        }
        .sheet(isPresented: $showOffline) {
            // No invented duration. Camera Reps is paid by reps, not by the
            // clock, so the card names the exercise instead of a number the
            // app would have had to make up.
            OfflineShareSheet(
                title: "Tell people you're offline",
                subtitle: "So nobody thinks you're ignoring them.",
                sticker: exercise.iconAsset,
                accent: HabitCategory.exercise.accent,
                accentShade: HabitCategory.exercise.accentShade)
                .auraSheet([.height(668)])
        }
        .sheet(item: $editing) { field in
            switch field {
            case .goal:
                WheelPickerSheet(
                    title: "Goal",
                    subtitle: "Goal to hit before you earn coins",
                    values: Array(stride(from: 5, through: 200, by: 5)),
                    selection: Binding(get: { store.goal(for: exercise) },
                                       set: { store.setGoal($0, for: exercise) }),
                    label: { Exercise.goalDisplay($0) }
                )
            }
        }
    }
}

// MARK: - Shell

/// Shared chrome: coloured header with a curved base, the sticker sitting on
/// the curve, a three-up stat row, the setting rows, and the CTA.
struct HabitDetailScaffold<Rows: View>: View {
    let sticker: String
    let title: String
    /// The method's colour, inherited so a habit screen matches the list it
    /// came from.
    var accent: Color = LightSheet.blue
    var accentSoft: Color = LightSheet.blueWash
    var accentShade: Color = LightSheet.blueShade
    /// A line from Aura on how to do this one — what to scan, or how to set up
    /// for the camera.
    let tip: String
    /// Value over label, left to right.
    let stats: [(String, String)]
    let primaryTitle: String
    /// Payout shown on the CTA beside its title.
    let primaryCoins: Int
    var onClose: () -> Void
    /// The calendar button, top-left. Nil on screens with no routine to set.
    var onRoutine: (() -> Void)? = nil
    /// The "tell people you're offline" pill above the CTA.
    var onShareOffline: (() -> Void)? = nil
    var onPrimary: () -> Void
    @ViewBuilder var rows: Rows

    /// Matches `MethodScreenBackground.standard` exactly — same construction
    /// (a 170-tall ellipse offset 74 onto the bottom edge, so the arc peaks 96
    /// above this), so the break lands on the mascot's midpoint on both. Only
    /// the two fills are swapped.
    private let headerHeight: CGFloat = MethodScreenBackground.standard

    var body: some View {
        ZStack(alignment: .top) {
            LightSheet.ground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    header

                    // Just the name. The inline sticker existed because the big
                    // one above was the METHOD's icon, due to be swapped for the
                    // fox, so the screen would otherwise have named the habit
                    // without ever showing it. The hero is the habit's own
                    // sticker now, so repeating it beside the title is the same
                    // drawing twice on one screen.
                    Text(title)
                        .auraFont(.display, SheetType.title, .bold)
                        .foregroundStyle(LightSheet.title)
                    // Pulled back up onto the header's tail so the gap
                    // under the sticker matches the method hero's rather
                    // than the 33 the stack would give it.
                    .padding(.top, -Theme.Spacing.m)

                    InfoCard(title: "Tip from Aura", copy: tip, borderColor: accent) {
                        Image("AuraAppIcon")
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(width: 27, height: 27)
                            .appIconChrome(side: 27, border: 0)
                    }
                        .padding(.horizontal, Theme.Spacing.xl)
                        .padding(.top, Theme.Spacing.l)

                    statRow
                        .padding(.top, Theme.Spacing.l)

                    VStack(spacing: Theme.Spacing.m) {
                        rows
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.xxl)
                }
                .padding(.bottom, Theme.Spacing.xxxl)
            }
            .ignoresSafeArea(edges: .top)

            VStack(spacing: Theme.Spacing.s) {
                Spacer()

                // Quiet, and above the CTA rather than beside it. Telling people
                // you're going offline is a thing some users will do every time
                // and most will never do once, which is exactly the weight a
                // text pill carries and a second filled button does not.
                if let onShareOffline {
                    Button(action: onShareOffline) {
                        HStack(spacing: Theme.Spacing.xs) {
                            Text("Tell people you're offline")
                                .auraFont(.body, SheetType.cardTitle, .semibold)
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(accent)
                        .padding(.horizontal, Theme.Spacing.l)
                        .padding(.vertical, Theme.Spacing.m)
                        .overlay(Capsule().strokeBorder(accent, lineWidth: 2))
                    }
                    .buttonStyle(PressBounceStyle())
                }

                LightPrimaryButton(title: primaryTitle, coins: primaryCoins,
                                   face: accent, shade: accentShade, action: onPrimary)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.bottom, Theme.Spacing.l)
            }
        }
        .overlay(alignment: .topLeading) {
            // Close on the left, the way every other full-screen flow in the
            // app opens and closes. The routine button took this corner first
            // and pushed the close to the right, which made this the one screen
            // where the exit moved.
            CircleIconButton(symbol: "xmark", fill: LightSheet.chromeOnBlue,
                             glyphColor: .white, action: onClose)
            .padding(.leading, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.l)
        }
        .overlay(alignment: .topTrailing) {
            if let onRoutine {
                Button(action: onRoutine) {
                    WoodButtonArtwork(role: .routine)
                        .frame(width: CircleIconButton.minimumTarget,
                               height: CircleIconButton.minimumTarget)
                        .contentShape(Circle())
                }
                .buttonStyle(PressBounceStyle())
                .accessibilityLabel("Create a routine")
                .padding(.trailing, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.l)
            }
        }
        // White status-bar glyphs, since the top of this screen is the blue
        // header rather than the light body.
        .preferredColorScheme(.light)
    }

    /// Blue field with a white dome cut out of the bottom, the sticker resting
    /// on it — the reference's shape in Aura's colour.
    private var header: some View {
        accent
            .frame(maxWidth: .infinity)
            .frame(height: headerHeight)
            // Overlays, not children: the dome is wider than the screen, and as
            // a sized child it would stretch the whole scroll content to its
            // width and push everything off both edges.
            .overlay(alignment: .bottom) {
                Ellipse()
                    .fill(LightSheet.ground)
                    .frame(width: 620, height: 170)
                    .offset(y: 74)
            }
            .overlay(alignment: .bottom) {
                // 134 tall with its bottom 29 above the header's edge: spans
                // 114–248 from the screen top, where the method hero's mascot
                // sits.
                Image(sticker)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(height: 134)
                    .foxShadow()
                    .offset(y: -29)
            }
            .clipped()
    }

    private var statRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(stats.enumerated()), id: \.offset) { index, stat in
                if index > 0 {
                    Rectangle()
                        .fill(LightSheet.fieldStroke)
                        .frame(width: 1, height: 34)
                }
                VStack(spacing: RowType.labelGap) {
                    Text(stat.0)
                        .auraFont(.body, 22, .bold)
                        .foregroundStyle(LightSheet.title)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(stat.1)
                        .auraFont(.body, RowType.subLabel, .medium)
                        .foregroundStyle(RowType.subLabelColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }
}

/// A setting that is just on or off — the switch lives on the card rather than
/// behind a sheet, since there is nothing else to choose.
struct HabitToggleRow: View {
    let icon: HabitSettingRow.Icon
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            HabitSettingRow.IconView(icon: icon)

            VStack(alignment: .leading, spacing: RowType.labelGap) {
                Text(title)
                    .auraFont(.body, RowType.label, .semibold)
                    .foregroundStyle(RowType.labelColor)
                // numericText only interpolates digits, so Yes/No hard-swapped
                // under it. A keyed push is a real transition for words.
                Text(subtitle)
                    .auraFont(.body, RowType.value, .medium)
                    .foregroundStyle(RowType.valueColor)
                    .id(subtitle)
                    .transition(.push(from: .bottom).combined(with: .opacity))
            }
            .animation(.snappy(duration: 0.25), value: subtitle)

            Spacer(minLength: Theme.Spacing.s)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Theme.Color.signalGood)
                .onChange(of: isOn) { _, _ in Haptics.impact(.light) }
        }
        .padding(Theme.Spacing.l)
        // The default shade, not `whiteShadeOnColour`. That token is the opaque
        // grey for a white card sitting on COLOUR; this screen's ground is white
        // now, and against it the opaque edge vanished while the habit rows on
        // the blue list kept theirs. The default is translucent and picks up
        // whatever is behind it, which is what a card on white wants.
        .bottomDropCard(radius: Theme.Radius.card)
    }
}

/// One tappable setting: icon, the current value, what it means, chevron.
struct HabitSettingRow: View {
    /// Stickers where the library has the right one. Duration and goal have no
    /// sticker yet, and borrowing the padlock (Deep Work) or the Screen Time
    /// tile would each say something the row doesn't mean, so they get a
    /// symbol on the same tinted disc the profile avatar uses.
    enum Icon {
        case sticker(String)
        case symbol(String, Color)
    }

    let icon: Icon
    let title: String
    let subtitle: String
    /// Nil for a fixed value: no chevron, no tap. Reward rates are set once,
    /// when a habit is created, and are read-only everywhere after that.
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: Theme.Spacing.m) {
                IconView(icon: icon)

                VStack(alignment: .leading, spacing: RowType.labelGap) {
                    Text(title)
                        .auraFont(.body, RowType.label, .semibold)
                        .foregroundStyle(RowType.labelColor)
                    Text(subtitle)
                        .auraFont(.body, RowType.value, .medium)
                        .foregroundStyle(RowType.valueColor)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }

                Spacer(minLength: Theme.Spacing.s)

                if action != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(LightSheet.subtitle)
                }
            }
            .padding(Theme.Spacing.l)
            .contentShape(Rectangle())
            .bottomDropCard(radius: Theme.Radius.card)
        }
        .buttonStyle(.plain)
        .allowsHitTesting(action != nil)
    }

    /// Shared with `HabitToggleRow` so both row shapes draw icons identically.
    struct IconView: View {
        let icon: Icon

        var body: some View {
            switch icon {
            case .sticker(let name):
                Image(name)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    // 38 and upright, matching the Lock In setting rows. The
                    // -10 tilt suited the old habit-sticker glyphs; these are
                    // purpose-drawn row icons and read wrong at an angle.
                    .frame(width: 38, height: 38)

            case .symbol(let name, let tint):
                // No disc: the stickers next to these don't have one either.
                Image(systemName: name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 38, height: 38)
            }
        }
    }
}

// MARK: - Editors

/// One wheel, one Save. Covers focus length, flat reward, and exercise goal —
/// they're the same interaction with different units.
struct WheelPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let subtitle: String
    let values: [Int]
    @Binding var selection: Int
    let label: (Int) -> String

    var body: some View {
        ZStack(alignment: .top) {
            LightSheet.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                LightDragCapsule()
                LightSheetTitle(title: title, subtitle: subtitle)

                // `AuraWheel`, not a system `Picker`. The old build drew Aura's
                // pill and then let SwiftUI draw its own on top — two
                // highlights for one selection. It went unnoticed only because
                // this sheet inherited `.dark` from the screen behind it, which
                // rendered the system indicator nearly invisible on white;
                // forcing the sheet light made it show up.
                ZStack {
                    AuraWheel.pill
                    AuraWheelColumn(values: values, selection: $selection, label: label)
                }
                .frame(height: AuraWheel.height)
                .padding(.top, Theme.Spacing.l)
                .padding(.horizontal, Theme.Spacing.xl)

                Spacer(minLength: Theme.Spacing.l)

                LightPrimaryButton(title: "Save") { dismiss() }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.bottom, Theme.Spacing.l)
            }
        }
        .auraSheet([.height(420)])
    }
}

#Preview {
    HabitDetailView(habit: HabitStore().habits[0]) {}
        .environment(HabitStore())
}
