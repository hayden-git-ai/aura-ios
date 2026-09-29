//
//  AppsView.swift
//  Aura iOS
//

import SwiftUI

/// Apps tab root. Four sections: the state card, what's blocked at this
/// moment, and the three rules.
///
/// Replaces the schedules / limits / breaks / presets screen. There is one
/// always-on block set now, split by promise rather than by time — see
/// docs/blocks/BLOCKS_BUILD_SPEC.md.
struct AppsView: View {
    @Environment(HabitStore.self) private var store
    @Environment(NavChrome.self) private var navChrome

    @State private var openRule: BlockRule?
    @State private var showBlockedApps = false
    @State private var showHelp = false

    var body: some View {
        ZStack {
            // Flat app ground — no gradient.
            LightSheet.bg
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    header

                    VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                        blockingNowSection
                        rulesSection
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.xxl)
                    // The Emergency Pass moved into the Blocked Apps sheet, so the
                    // screen bottoms out on the standard tab-bar clearance like the
                    // other scrolling tabs — the cards run clean to the bottom.
                    .padding(.bottom, Theme.Layout.scrollBottomClearance)
                }
            }
            .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, y in
                navChrome.track(y)
            }
            .ignoresSafeArea(edges: .top)
        }
        .sheet(item: $openRule) { rule in
            RuleSheet(rule: rule)
        }
        .sheet(isPresented: $showBlockedApps) {
            BlockedNowSheet(icons: store.blockedNowIcons)
        }
        .sheet(isPresented: $showHelp) {
            BlockingHelpSheet(onReload: { await store.refreshShield() })
        }
        // The shield can be cleared by a restart or by a Screen Time change made
        // outside the app, so the screen that reports on it re-asserts it.
        .task { await store.refreshShield() }
    }

    // MARK: - Header

    /// Just the help disc now, top-right. The standalone Reload Aura button is
    /// gone — reload lives inside this explainer's sheet (and on Stats), so it
    /// doesn't need to sit on the screen and crowd the cards.
    private var header: some View {
        HStack {
            // Sticker treatment: black fill, white contour, soft drop shadow —
            // same language as the streak numeral and the help glyph.
            StrokedNumber(text: "Apps",
                          font: Typography.displayUIFont(size: SheetType.hero, weight: .black),
                          fill: .black,
                          stroke: .white,
                          outlineWidth: 3)
                .fixedSize()
                .shadow(color: .black.opacity(0.22), radius: 5, y: 2)
            Spacer()
            // Shared wooden help button; the help sheet action is unchanged.
            Button {
                Haptics.impact(.light)
                showHelp = true
            } label: {
                WoodButtonArtwork(role: .help)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(PressBounceStyle(hapticsEnabled: false))
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, TabTopCardMetrics.topInset)
    }

    // MARK: - Blocking Now

    /// State, not configuration — the rules below say what *would* be blocked,
    /// this says what is. No card behind it: the icons are the content, and a
    /// panel around them was a container for its own sake.
    private var blockingNowSection: some View {
        // `s`, not `l`: the scroll content below carries `s` of its own top
        // padding (room for the tiles' shadow), so this plus that equals the `l`
        // gap the "Your apps" header has to its cards.
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            // Tappable: opens the Blocked Apps sheet, which now also holds the
            // Emergency Pass.
            Button {
                Haptics.impact(.light)
                showBlockedApps = true
            } label: {
                HStack(spacing: Theme.Spacing.xs) {
                    sectionHeader("Frozen Apps")
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(SheetType.titleColor.opacity(0.35))
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            if store.blockedNowIcons.isEmpty {
                emptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.l) {
                        ForEach(Array(store.blockedNowIcons.enumerated()), id: \.offset) { idx, icon in
                            FrozenAppTile(icon: icon, side: 56,
                                          tilt: Self.frozenTilts[idx % Self.frozenTilts.count])
                        }
                    }
                    // The icicles hang below each tile, so the content needs real
                    // bottom room or the scroll view clips their tips.
                    .padding(.top, Theme.Spacing.s)
                    // The drips live inside the tile now, so no extra bottom room.
                    .padding(.bottom, Theme.Spacing.xs)
                }
                // Out of the screen's inset and back in on the content, so the
                // row scrolls off the true edge like the old presets rail.
                .padding(.horizontal, -Theme.Spacing.xl)
                .contentMargins(.horizontal, Theme.Spacing.xl, for: .scrollContent)

    
            }
        }
    }

    /// The app, dimmed with the lock sticker centred on it, in a light gray tile
    /// — the icon alone said "app", not "locked app".
    /// A little hand-placed lean per tile, so the frozen apps read like game
    /// pieces on a shelf rather than a straight grid.
    private static let frozenTilts: [Double] = [-5, 4, -3, 5, -4, 3]

    /// The app's empty state — art, a bold line, a quiet one — and the quiet one
    /// is where the reload lives in words.
    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.m) {
            VStack(spacing: Theme.Spacing.xs) {
                Text(store.isDistractingLifted ? "All apps are open" : "Nothing frozen yet")
                    .auraFont(.display, SheetType.sectionHeader, .bold)
                    .foregroundStyle(SheetType.titleColor)
                Text(store.isDistractingLifted
                     ? "They freeze again when your time runs out."
                     : "Pick apps to freeze below.")
                    .auraFont(.body, RowType.subLabel, .medium)
                    .foregroundStyle(RowType.subLabelColor)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.l)
    }

    // MARK: - The three rules

    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            sectionHeader("Your apps")

            // Full-width cards stacked down the page: the lane's name over a row
            // of its apps, so each card reads as the list it is.
            VStack(spacing: Theme.Spacing.m) {
                ruleCard(.blocked)
                ruleCard(.distracting)
                ruleCard(.allowed)
            }
        }
    }

    /// One lane: its name over a row of its apps, tappable into the lane sheet.
    /// The card itself is `LaneCard`, shared with the How Blocking Works sheet so
    /// the two render identically and can't drift.
    private func ruleCard(_ rule: BlockRule) -> some View {
        let selection = store.blockConfig[rule]
        return LaneCard(rule: rule,
                        selection: selection,
                        subtitle: ruleSubtitle(rule, selection: selection)) {
            Haptics.impact(.light)
            openRule = rule
        }
    }

    /// The count line under the lane's name: how many apps it holds, plus a note
    /// that Always Blocked keeps its apps out of sight.
    private func ruleSubtitle(_ rule: BlockRule, selection: AppSelection) -> String {
        let n = selection.iconSources.count
        if n == 0 { return "No apps yet" }
        let apps = "\(n) app\(n == 1 ? "" : "s")"
        return rule == .blocked ? "\(apps) · Hidden" : apps
    }

    /// Shipped as an obvious "not yet" rather than a hole where a section goes.
    /// It needs a DeviceActivityMonitor extension to apply a shield at bedtime
    /// while the app is closed, and that doesn't exist yet.
    // MARK: - Bits

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            // `banner` (20), so a section header clearly outranks the 19pt lane-card
            // titles nested under it (the screen title, outlined at 30, still leads).
            .auraFont(.display, SheetType.banner, .bold)
            .foregroundStyle(SheetType.titleColor)
    }
}

#Preview {
    AppsView()
        .environment(HabitStore())
}
