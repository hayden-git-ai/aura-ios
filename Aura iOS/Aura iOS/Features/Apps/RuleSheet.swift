//
//  RuleSheet.swift
//  Aura iOS
//

import SwiftUI

/// One rule's apps. Opened from its lane on the board.
///
/// A plain app-management sheet in the standard light-sheet grammar the rest of
/// the app uses — `LightSheet.bg`, `LightDragCapsule`, `LightSheetTitle`. The
/// board carries the frozen theme; this sheet just lists the apps in the lane
/// and lets you add or remove them. There's no edit mode and no Save — the sheet
/// *is* the state.
struct RuleSheet: View {
    let rule: BlockRule

    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// The app awaiting a delete confirmation — Tempting and Allowed only.
    /// Forbidden costs a hold on its own sheet.
    @State private var pendingRemoval: AppIconSource?
    /// The last pick's clash with the other lanes: how many items it reached for
    /// that already live elsewhere, and their names where we have them (the
    /// Simulator does; the device's opaque tokens don't). Non-nil shows the
    /// "already in another list" alert.
    @State private var conflict: Conflict?
    /// Whichever sheet is up. One piece of state, because two `.sheet`
    /// modifiers on the same view fight: SwiftUI honours the last one and the
    /// first flashes open and shuts.
    @State private var activeSheet: ActiveSheet?

    private enum ActiveSheet: Identifiable {
        case adult
        case remove(AppIconSource)

        var id: String {
            switch self {
            case .adult: return "adult"
            case .remove(let icon): return "remove-\(icon.stableID)"
            }
        }
    }

    private var selection: AppSelection { store.blockConfig[rule] }

    var body: some View {
        ZStack(alignment: .top) {
            LightSheet.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                LightDragCapsule()
                LightSheetTitle(title: rule.title, subtitle: rule.promise)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                        if rule == .blocked { adultRow }
                        appsSection
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.xl)
                    .padding(.bottom, Theme.Spacing.xl)
                }

                LightPrimaryButton(title: "Add more apps", face: tileBorder, textColor: .white, shade: addButtonShade) { pickApps() }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.m)
                    .padding(.bottom, Theme.Spacing.l)
            }

            // An explicit way out — the hidden grabber and the scroll view make
            // swipe-to-dismiss too easy to miss.
            LightCloseButton { dismiss() }
                .padding(.top, Theme.Spacing.m)
                .padding(.trailing, Theme.Spacing.l)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        // The app forces dark at the root, so a light sheet has to say so.
        .preferredColorScheme(.light)
        .presentationDetents([.fraction(0.88)])
        .presentationDragIndicator(.hidden)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .adult:
                AdultContentSheet(turningOn: !store.blockConfig.blockAdultWebsites,
                                  enabledAt: store.blockConfig.adultWebsitesEnabledAt) {
                    toggleAdult()
                }

            case .remove(let icon):
                // Taking something out of Forbidden is undoing a permanent
                // decision, so it costs a hold rather than a tap.
                HoldConfirmSheet(
                    sticker: "Blocks_Adult Websites Sheet",
                    stickerHeight: 104,
                    stickerBottomInset: -Theme.Spacing.xl,
                    title: "Remove this app?",
                    subtitle: "It can be opened again unless another rule blocks it.",
                    idleCaption: "Press and hold to remove",
                    doneCaption: "Removed",
                    duration: 10
                ) {
                    remove(icon)
                }
            }
        }
        // Tempting / Allowed removals — a plain alert, replacing the side popover
        // that was rendering broken.
        .alert("Delete from \(rule.title)?",
               isPresented: Binding(get: { pendingRemoval != nil },
                                    set: { if !$0 { pendingRemoval = nil } }),
               presenting: pendingRemoval) { icon in
            Button("Delete", role: .destructive) { remove(icon); pendingRemoval = nil }
            Button("Cancel", role: .cancel) { pendingRemoval = nil }
        } message: { _ in
            Text("You can add it later in case you change your mind.")
        }
        // An app can only live in one lane. If a pick reached for one that's
        // already in another, it's left where it was and the user is told.
        .alert("Already in another list",
               isPresented: Binding(get: { conflict != nil },
                                    set: { if !$0 { conflict = nil } }),
               presenting: conflict) { _ in
            Button("OK", role: .cancel) { conflict = nil }
        } message: { clash in
            Text(conflictMessage(clash))
        }
    }

    /// The clash surfaced by the last pick. Names when the Simulator gives them;
    /// otherwise just the count, which is all opaque device tokens allow.
    private struct Conflict: Equatable {
        var count: Int
        var names: [String]
    }

    private func conflictMessage(_ clash: Conflict) -> String {
        let tail = "Each app can only be in one list. Take it out of the other one first."
        if !clash.names.isEmpty {
            let pretty = clash.names.map { AppCatalog.displayName(for: $0) }
            let list = ListFormatter.localizedString(byJoining: pretty)
            let verb = pretty.count == 1 ? "is" : "are"
            return "\(list) \(verb) already in another list. \(tail)"
        }
        let subject = clash.count == 1 ? "app is" : "apps are"
        return "\(clash.count) \(subject) already in another list. \(tail)"
    }

    // MARK: - Adult websites (Forbidden only)

    /// Content, not apps — which is why it sits in the rule that promises
    /// permanence. Its transparent card uses the Tempting red outline.
    private var adultRow: some View {
        HStack(spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.m) {
                Image("AuraBlockedAppsLock")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: Self.adultLockSide, height: Self.adultLockSide)

                VStack(alignment: .leading, spacing: RowType.labelGap) {
                    Text("Adult Websites")
                        .auraFont(.body, SheetType.cardTitle, .semibold)
                        .foregroundStyle(SheetType.titleColor)
                    Text("Blocks NSFW sites and private browsing.")
                        .auraFont(.body, SheetType.cardBlurb, .regular)
                        .foregroundStyle(SheetType.subtitleColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: Theme.Spacing.s)

            Toggle("", isOn: Binding(
                get: { store.blockConfig.blockAdultWebsites },
                set: { _ in
                    Haptics.impact(.light)
                    activeSheet = .adult
                }
            ))
            .labelsHidden()
            .tint(Theme.Color.signalGood)
        }
        .padding(Theme.Spacing.m)
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(LightSheet.rippleRed, lineWidth: 2)
                .allowsHitTesting(false)
        }
    }

    private var tileBorder: Color {
        switch rule {
        case .blocked: LightSheet.forbiddenLane
        case .distracting: LightSheet.rippleRed
        case .allowed: LightSheet.blue
        }
    }

    private var addButtonShade: Color {
        switch rule {
        case .blocked: .black
        case .distracting: LightSheet.drainRed
        case .allowed: LightSheet.blueShade
        }
    }

    // MARK: - Apps

    // 3 columns, like the Blocked Apps sheet and the Edit List grid.
    private let grid = [
        GridItem(.flexible(), alignment: .top),
        GridItem(.flexible(), alignment: .top),
        GridItem(.flexible(), alignment: .top),
    ]

    @ViewBuilder private var appsSection: some View {
        let icons = selection.iconSources
        if !icons.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                HStack {
                    Text("Apps (\(icons.count))")
                        .auraFont(.display, 17, .bold)
                        .foregroundStyle(SheetType.titleColor)
                    Spacer()
                    Button {
                        Haptics.impact(.light)
                        clearAll()
                    } label: {
                        Text("Clear All")
                            .auraFont(.body, SheetType.cardTitle, .bold)
                            .foregroundStyle(LightSheet.danger)
                    }
                    .buttonStyle(.plain)
                }

                LazyVGrid(columns: grid, alignment: .leading, spacing: Theme.Spacing.m) {
                    ForEach(icons, id: \.stableID) { icon in
                        appTile(icon)
                    }
                }
            }
        }
    }

    /// One app: the remove badge along the top, then the icon over its name — a
    /// transparent outlined card, with the minus above the icon.
    private func appTile(_ icon: AppIconSource) -> some View {
        VStack(spacing: 0) {
            HStack {
                Spacer(minLength: 0)
                minusBadge(icon)
            }
            AppTileLabel(source: icon, side: 64)
                .padding(.bottom, Theme.Spacing.s)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.Spacing.s)
        .padding(.top, Theme.Spacing.xs)
    }

    private func minusBadge(_ icon: AppIconSource) -> some View {
        Button {
            Haptics.impact(.light)
            // The permanent rule costs a hold on a sheet; the other two confirm
            // in a plain alert.
            if rule == .blocked { activeSheet = .remove(icon) } else { pendingRemoval = icon }
        } label: {
            Image(systemName: "minus")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(LightSheet.rippleRed)
                .frame(width: 22, height: 22)
                .overlay(Circle().strokeBorder(LightSheet.rippleRed, lineWidth: 1.5))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private static let adultLockSide: CGFloat = 44

    // MARK: - Actions

    /// Empties the lane. On Forbidden this skips the per-app hold — it's a
    /// deliberate sweep of the whole list, not an accidental unblock.
    private func clearAll() {
        Haptics.impact(.medium)
        withAnimation(.snappy) { store.blockConfig[rule] = .empty }
    }

    private func toggleAdult() {
        Haptics.impact(.medium)
        var config = store.blockConfig
        config.blockAdultWebsites.toggle()
        config.adultWebsitesEnabledAt = config.blockAdultWebsites ? .now : nil
        store.blockConfig = config
    }

    /// The system picker. Adding is allowed at any time and applies immediately.
    private func pickApps() {
        Task { @MainActor in
            let result = await store.screenTime.presentAppPicker(current: selection)
            guard !result.isEmpty else { return }
            var picked = AppSelection(token: result.token,
                                      appCount: result.appCount,
                                      categoryCount: result.categoryCount)
            picked.mockIconNames = result.mockIconNames

            // An app can only be in one lane. Anything this pick reaches for
            // that's already in another lane is left where it is: drop it from
            // the pick, per app, and tell the user rather than silently moving
            // it. Real tokens on device, catalogue names in the Simulator.
            var clashCount = 0
            var clashNames: [String] = []
            for other in BlockRule.allCases where other != rule {
                let lane = store.blockConfig[other]
                let shared = picked.overlap(with: lane)
                guard shared.count > 0 else { continue }
                clashCount += shared.count
                clashNames.append(contentsOf: shared.names)
                picked = picked.subtracting(lane)
            }
            if clashCount > 0 { conflict = Conflict(count: clashCount, names: clashNames) }

            // Everything picked already lived elsewhere: nothing new to add.
            guard !picked.isEmpty else { return }
            store.setSelection(picked, rule: rule)
            Haptics.impact(.light)
        }
    }

    private func remove(_ icon: AppIconSource) {
        Haptics.impact(.light)
        withAnimation(.snappy) { store.blockConfig[rule] = selection.removing(icon) }
    }
}

#Preview {
    Color.gray.sheet(isPresented: .constant(true)) {
        RuleSheet(rule: .distracting)
            .environment(HabitStore())
    }
}
