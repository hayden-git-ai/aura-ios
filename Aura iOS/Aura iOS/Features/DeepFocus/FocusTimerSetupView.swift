//
//  FocusTimerSetupView.swift
//  Aura iOS
//

import SwiftUI

/// The Deep Focus "Focus Mode" setup sheet — light design system, adapted from
/// the Brainrot/Unrot reference into Aura's own components. The Aura fox sits at
/// the top over a set of tappable setting cards: Target Time (opens a wheel
/// picker), Apps to block (opens the app-list picker), and Extreme Focus (an
/// untimed, open-ended session). Committed via Start Focus; the sheet then gives
/// way to the full-screen timer.
struct FocusTimerSetupView: View {
    var initialLength: Int? = nil
    var onStart: (DeepFocusConfig) -> Void
    var onClose: () -> Void

    @Environment(HabitStore.self) private var store

    @State private var lengthMinutes = 30
    @State private var extremeFocus = false
    @State private var didApplyInitial = false

    @State private var showTargetPicker = false
    @State private var showRoutine = false
    @State private var showOffline = false
    /// Re-read when the routine sheet closes, so the row shows what was just
    /// set rather than what it said when the screen opened.
    @State private var routine = RoutineStore.routine(for: FocusTimerSetupView.routineKey)

    var body: some View {
        VStack(spacing: 0) {
            EarnMethodIllustratedHeader {
                EarnMethodRewardRibbon(
                    asset: "DeepFocusRewardRibbon",
                    accessibilityLabel: "Stay focused, Earn coins!"
                )
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: Theme.Spacing.m) {
                    // Routine first: it is the only row that says WHEN,
                    // and the two under it both describe the session itself.
                    routineCard
                    targetCard
                    extremeFocusCard
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.xxl)
                .padding(.bottom, Theme.Spacing.l)
            }

            // Same pill, same place as the habit detail screens.
            Button { showOffline = true } label: {
                HStack(spacing: Theme.Spacing.s) {
                    Text("Tell people you're offline")
                        .auraFont(.body, SheetType.cardTitle, .semibold)
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(LightSheet.title)
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.vertical, Theme.Spacing.s)
                .background(LightSheet.chromeOnLight, in: Capsule())
            }
            .buttonStyle(PressBounceStyle())
            .padding(.bottom, Theme.Spacing.s)

            startButton
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.l)
        }
        .overlay(alignment: .topLeading) {
            CircleIconButton(symbol: "xmark", fill: LightSheet.chromeOnBlue,
                             glyphColor: .white, bounces: false) { onClose() }
                .padding(.leading, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.l)
        }
        .overlay(alignment: .topTrailing) {
            ExplainerButton(explainer: QuestExplainer.lockIn, onBlue: true)
            .padding(.trailing, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.l)
        }
        .background(EarnMethodIllustratedBackground())
        .preferredColorScheme(.light)
        .onAppear {
            if let initialLength, !didApplyInitial {
                didApplyInitial = true
                lengthMinutes = initialLength
            }
        }
        .sheet(isPresented: $showTargetPicker) {
            TargetTimePickerSheet(totalMinutes: $lengthMinutes)
        }
        .sheet(isPresented: $showRoutine, onDismiss: {
            routine = RoutineStore.routine(for: Self.routineKey)
        }) {
            HabitRoutineSheet(habitName: Self.routineKey,
                              accent: HabitCategory.focus.accent,
                              accentShade: HabitCategory.focus.accentShade)
                .auraSheet([.fraction(0.9)])
        }
        .sheet(isPresented: $showOffline) {
            OfflineShareSheet(
                title: "Tell people you're offline",
                subtitle: "So nobody thinks you're ignoring them.",
                sticker: HabitCategory.focus.tileIconAsset,
                accent: HabitCategory.focus.accent,
                accentShade: HabitCategory.focus.accentShade)
                .auraSheet([.height(668)])
        }
    }

    // MARK: - Cards

    private var targetCard: some View {
        Button { showTargetPicker = true } label: {
            settingRow(
                sticker: "DeepFocusFocusLength",
                stickerSize: 44,
                title: "Focus Length",
                value: extremeFocus ? "As long as you can!" : FocusDuration.label(lengthMinutes),
                // Greyed while Extreme Focus is on: the row is disabled.
                valueColor: extremeFocus ? LightSheet.subtitle : RowType.valueColor
            ) {
                if !extremeFocus { chevron }
            }
        }
        .buttonStyle(PressBounceStyle())
        .disabled(extremeFocus)
    }

    private var extremeFocusCard: some View {
        settingRow(
            sticker: "FoxLockInExtremeFocus",
            stickerSize: 44,
            title: "Extreme Focus",
            value: extremeFocus ? "On" : "Off",
            // On the orange face both lines go white; off, they take the same
            // colours as every other row on this screen.
            valueColor: extremeFocus ? LightSheet.onColour : RowType.valueColor,
            titleColor: extremeFocus ? .white : RowType.labelColor,
            fill: extremeFocus ? LightSheet.orange : .white,
            shade: extremeFocus ? LightSheet.orangeShade : LightSheet.whiteShadeOnColour
        ) {
            Toggle("", isOn: $extremeFocus.animation(.snappy(duration: 0.25)))
                .labelsHidden()
                .tint(.white.opacity(extremeFocus ? 0.35 : 0))
                .onChange(of: extremeFocus) { _, _ in Haptics.impact(.light) }
        }
    }

    /// A ROW, not a button in the corner.
    ///
    /// On the habit detail screens the routine has to be chrome, because those
    /// screens have no list to put it in. This one already has a settings list,
    /// and a row can show what the routine actually is — "Weekdays, 8:00 AM" —
    /// where an icon can only say that a feature exists.
    private var routineCard: some View {
        Button { showRoutine = true } label: {
            settingRow(
                sticker: "DeepFocusRoutine",
                stickerSize: 44,
                title: "Routine",
                value: routine?.summary ?? "Off"
            ) { chevron }
        }
        .buttonStyle(PressBounceStyle())
    }

    /// One key for Lock In's routine. It isn't a habit and has no name of its
    /// own, so this stands in as the id `RoutineStore` files it under.
    static let routineKey = "Lock In"

    /// Matches the habit detail rows: a small right chevron, no disc, in the
    /// same grey. Was a down chevron on a white disc.
    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(LightSheet.subtitle)
    }

    /// One setting card: a flat sticker icon, title over value, and a trailing
    /// accessory (chevron or toggle).
    private func settingRow<Trailing: View>(
        sticker: String,
        stickerSize: CGFloat = 44,
        title: String,
        value: String,
        valueColor: Color = RowType.valueColor,
        titleColor: Color = RowType.labelColor,
        fill: Color = .white,
        // The drop edge is the face's own shadow, so it has to follow the face
        // — a white edge under the orange card reads as a rendering bug.
        shade: Color = LightSheet.whiteShadeOnColour,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(sticker)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: stickerSize, height: stickerSize)
                .frame(width: 44, height: 44)

            // A settings row, not a chart key: the NAME leads and the value is
            // its current state underneath — same order as Settings' nav rows,
            // stacked instead of trailing.
            VStack(alignment: .leading, spacing: RowType.labelGap) {
                Text(title)
                    .auraFont(.body, RowType.label, .semibold)
                    .foregroundStyle(titleColor)
                Text(value)
                    .auraFont(.body, RowType.value, .medium)
                    .foregroundStyle(valueColor)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            Spacer(minLength: Theme.Spacing.s)

            trailing()
        }
        .padding(.horizontal, Theme.Spacing.m)
        .frame(height: 68)
        .bottomDropCard(radius: Theme.Radius.card, face: fill, shade: shade)
    }

    // MARK: - Start

    private var startButton: some View {
        Button {
            onStart(DeepFocusConfig(
                lengthMinutes: extremeFocus ? 0 : lengthMinutes,
                music: .lofi,
                isUntimed: extremeFocus,
                earnRate: store.deepFocusRate
            ))
        } label: {
            Text("Lock In")
                .font(SheetType.ctaFont)
                .foregroundStyle(.white)
        }
        .buttonStyle(PillPressButtonStyle(face: HabitCategory.focus.accent,
                                           shade: HabitCategory.focus.accentShade))
    }
}

#Preview {
    Color.gray.sheet(isPresented: .constant(true)) {
        FocusTimerSetupView(onStart: { _ in }, onClose: {})
            .environment(HabitStore())
    }
}
