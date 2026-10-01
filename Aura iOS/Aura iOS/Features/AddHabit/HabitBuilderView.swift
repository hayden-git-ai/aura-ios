//
//  HabitBuilderView.swift
//  Aura iOS
//

import SwiftUI

/// Create-a-habit / edit-defaults builder. Same screen for both — pass an
/// `existing` habit to edit it, or nil to create a new one for `method`.
/// Laid out like the Create Blocker (Add Block) sheet: a centered avatar, a
/// name field, a segmented mode picker, labeled field sections, and a method-colored
/// primary button.
struct HabitBuilderView: View {
    let existing: Habit?
    let method: HabitCategory
    var onSave: (Habit) -> Void
    var onClose: () -> Void

    @State private var name = ""
    @State private var emoji = ""
    /// A random sticker fills the avatar by default; re-rolls each time the sheet
    /// is presented (the view is re-created per presentation).
    @State private var sticker = StickerCatalog.all.randomElement() ?? ""
    @State private var showStickerPicker = false
    @State private var showFocusPicker = false
    @State private var colorHex = "00BFFF"
    @State private var requiresFocus = true
    @State private var focusMinutes = 45
    @State private var rewardRate = 10.0
    @State private var flatReward = 5
    @State private var oncePerDay = false
    @State private var photoHint = ""

    @FocusState private var nameFocused: Bool
    @FocusState private var photoHintFocused: Bool

    private var isFocusMethod: Bool { method == .focus }
    private var usesFocus: Bool { requiresFocus || isFocusMethod }
    private var accent: Color { method.accent }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    private var focusModeBinding: Binding<Int> {
        Binding(get: { requiresFocus ? 0 : 1 },
                set: { new in
                    withAnimation(.easeInOut(duration: 0.28)) { requiresFocus = (new == 0) }
                })
    }

    /// Same left/right slide the Stats toggle uses, so the two mode switches in
    /// the app behave identically.
    private var slide: AnyTransition {
        .asymmetric(
            insertion: .move(edge: requiresFocus ? .leading : .trailing).combined(with: .opacity),
            removal: .move(edge: requiresFocus ? .trailing : .leading).combined(with: .opacity)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            LightDragCapsule()

            avatar
                .frame(maxWidth: .infinity)
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.l)

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    nameField

                    if !isFocusMethod {
                        LightSegmentedPill(titles: ["Focus Habit", "Quick Habit"], selection: focusModeBinding,
                                           selectedFillColor: accent)
                    }

                    Group {
                        if usesFocus {
                            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                                fieldSection("Reward Rate") { rateChipsCard }
                                fieldSection("Focus Length") { focusLengthCard }
                            }
                        } else {
                            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                                fieldSection("Reward") { flatRewardChipsCard }
                                // Only a quick habit can be once-a-day: a focus
                                // habit already gates itself on session length.
                                fieldSection("Frequency") { oncePerDayRow }
                            }
                        }
                    }
                    .transition(slide)

                        if method == .photoTask {
                            fieldSection("Photo Hint") { photoHintField }
                                .id("photo-hint")
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.l)
                    .padding(.bottom, Theme.Spacing.xxl)
                }
                .onChange(of: photoHintFocused) { _, focused in
                    guard focused else { return }
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("photo-hint", anchor: .center)
                    }
                }
            }

            footer
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.l)
        }
        .background(LightSheet.bg.ignoresSafeArea())
        .environment(\.colorScheme, .light)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .onAppear(perform: load)
        .sheet(isPresented: $showStickerPicker) {
            StickerPickerSheet(selected: sticker.isEmpty ? nil : sticker, accent: accent) { sticker = $0 ?? "" }
        }
        .sheet(isPresented: $showFocusPicker) {
            TargetTimePickerSheet(totalMinutes: $focusMinutes)
        }
    }

    // MARK: - Header chrome

    // MARK: - Avatar (sticker picker)

    private var avatar: some View {
        Button {
            Haptics.impact(.light)
            showStickerPicker = true
        } label: {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if sticker.isEmpty {
                        Image(systemName: "face.smiling")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(accent)
                    } else {
                        Image(sticker)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(width: 62, height: 62)
                    }
                }
                .frame(width: 96, height: 96)
                .background(accent.opacity(0.2), in: Circle())

                Image(systemName: "pencil")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LightSheet.title)
                    .frame(width: 32, height: 32)
                    .background(LightSheet.field, in: Circle())
                    .offset(x: 4, y: 4)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Name

    private var nameField: some View {
        TextField("", text: $name, prompt: Text("Name your habit").foregroundStyle(LightSheet.subtitle))
            .auraFont(.body, 16, .medium)
            .foregroundStyle(LightSheet.title)
            .focused($nameFocused)
            .submitLabel(.done)
            .onSubmit { nameFocused = false }
            .padding(.horizontal, Theme.Spacing.l)
            .frame(height: 56)
            .background(LightSheet.field, in: RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous).strokeBorder(LightSheet.fieldStroke, lineWidth: 1))
    }

    // MARK: - Field sections

    private func fieldSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(title)
                .auraFont(.display, SheetType.sectionHeader, .bold)
                .foregroundStyle(SheetType.titleColor)
            content()
        }
    }

    /// A recessed, stroked field card (matches the Add Block sheet's fields).
    private func plainCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(Theme.Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LightSheet.field, in: RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous).strokeBorder(LightSheet.fieldStroke, lineWidth: 1))
    }

    private let rateOptions: [Double] = [5, 10, 15, 20]
    /// The quick-habit ladder: seconds of effort, a minute or two, real work.
    private let flatRewardOptions: [Int] = [3, 5, 7]

    /// Reward-rate pill selectors, styled like the Add Block sheet's Daily Limit
    /// chips.
    private var rateChipsCard: some View {
        plainCard {
            HStack(spacing: Theme.Spacing.s) {
                ForEach(rateOptions, id: \.self) { value in
                    let selected = abs(rewardRate - value) < 0.001
                    HStack(spacing: 4) {
                        Image("AuraCoinIcon")
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                        Text("\(Int(value))/hr")
                            .auraFont(.body, RowType.value, .semibold)
                            .foregroundStyle(selected ? .white : LightSheet.subtitleDark)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(selected ? accent : Color.white, in: Capsule())
                    .contentShape(Capsule())
                    .onTapGesture {
                        Haptics.selection()
                        withAnimation(.snappy(duration: 0.15)) { rewardRate = value }
                    }
                }
            }
        }
    }

    /// Opens the same hours/minutes wheel Lock In uses, rather than a stepper —
    /// picking 45m shouldn't take nine taps.
    private var focusLengthCard: some View {
        Button {
            Haptics.impact(.light)
            showFocusPicker = true
        } label: {
            plainCard {
                HStack(spacing: Theme.Spacing.m) {
                    Text(FocusDuration.label(focusMinutes))
                        .auraFont(.body, 16, .medium)
                        .foregroundStyle(LightSheet.title)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(LightSheet.subtitle)
                }
                // Matches the frequency card, whose height comes from its
                // switch rather than its text.
                .frame(height: 31)
            }
        }
        .buttonStyle(PressBounceStyle())
    }

    /// Same chips as the rate, for the flat payout.
    private var flatRewardChipsCard: some View {
        plainCard {
            HStack(spacing: Theme.Spacing.s) {
                ForEach(flatRewardOptions, id: \.self) { value in
                    let selected = flatReward == value
                    HStack(spacing: 4) {
                        Image("AuraCoinIcon")
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                        Text("\(value)")
                            .auraFont(.body, RowType.value, .semibold)
                            .foregroundStyle(selected ? .white : LightSheet.subtitleDark)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(selected ? accent : Color.white, in: Capsule())
                    .contentShape(Capsule())
                    .onTapGesture {
                        Haptics.selection()
                        withAnimation(.snappy(duration: 0.15)) { flatReward = value }
                    }
                }
            }
        }
    }

    private var photoHintField: some View {
        plainCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                TextField("", text: $photoHint, prompt: Text("What should the photo show?").foregroundStyle(LightSheet.subtitle), axis: .vertical)
                    // 16 medium, like every other field in the app.
                    .auraFont(.body, 16, .medium)
                    .foregroundStyle(LightSheet.title)
                    .lineLimit(1...3)
                    .focused($photoHintFocused)
                    // Return inserts a newline here, so give it an explicit close.
                    .keyboardDoneToolbar()
                Text("This helps Aura verify niche habits")
                    .auraFont(.body, 13, .regular)
                    .foregroundStyle(LightSheet.subtitleDark)
            }
        }
    }

    private var oncePerDayRow: some View {
        plainCard {
            HStack(spacing: Theme.Spacing.m) {
                Text("Once per day")
                    .auraFont(.body, RowType.label, .medium)
                    .foregroundStyle(RowType.labelColor)
                Spacer(minLength: Theme.Spacing.s)
                Toggle("", isOn: $oncePerDay)
                    .labelsHidden()
                    .tint(accent)
                    .onChange(of: oncePerDay) { _, _ in Haptics.impact(.light) }
            }
            .frame(height: 31)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        LightPrimaryButton(title: existing == nil ? "Create" : "Save",
                           face: accent, shade: method.accentShade, enabled: canSave) { save() }
    }

    // MARK: - Bindings / load / save

    private func load() {
        guard let h = existing else {
            requiresFocus = (method == .focus)
            return
        }
        name = h.name
        emoji = h.emoji
        if let icon = h.iconAsset { sticker = icon }   // else keep the random default
        colorHex = h.colorHex
        requiresFocus = h.requiresFocusSession
        focusMinutes = h.defaultFocusMinutes
        rewardRate = h.rewardRate
        flatReward = h.rewardMinutes
        oncePerDay = h.oncePerDay
        photoHint = h.proofHint
    }

    private func save() {
        let finalEmoji = emoji.isEmpty ? "✨" : emoji
        let requires = isFocusMethod ? true : requiresFocus
        let habit = Habit(
            id: existing?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            category: method,
            emoji: finalEmoji,
            iconSystemName: existing?.iconSystemName ?? "sparkles",
            iconAsset: sticker.isEmpty ? nil : sticker,
            colorHex: colorHex,
            requiresFocusSession: requires,
            defaultFocusMinutes: focusMinutes,
            rewardRate: rewardRate,
            rewardMinutes: flatReward,
            oncePerDay: oncePerDay,
            isCustom: true,
            proofHint: photoHint,
            proofExamples: existing?.proofExamples ?? []
        )
        onSave(habit)
    }
}
