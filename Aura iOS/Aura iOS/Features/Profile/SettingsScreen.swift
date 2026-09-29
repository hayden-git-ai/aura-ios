//
//  SettingsScreen.swift
//  Aura iOS
//

import SwiftUI

/// Settings, presented full-screen from the Profile gear. The rows that used to
/// live on the Profile tab: preferences, support/legal links, social, and the
/// debug shortcuts. Same light surface and white-card treatment as Apps and
/// Profile. `AuraLink` (the outbound URLs) lives in `AuraLink.swift`.
struct SettingsScreen: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    @State private var showEditProfile = false
    /// Turning Hard Mode OFF opens the hold-to-confirm sheet (it undoes a
    /// commitment), so the toggle only flips off once the hold completes.
    @State private var confirmingExitHardMode = false
    @State private var showInterventions = false
    @State private var showSubscription = false
    /// "Report a bug" and "Contact us" open the in-app founders chat (a real
    /// two-way channel) instead of a one-way web form.
    @State private var showSupportChat = false
    @State private var showSignIn = false
    @State private var showSignOutConfirm = false
    @State private var showDeleteConfirm = false
    @State private var deleting = false
    @State private var deleteError: String?
    #if DEBUG
    /// The quest-completion screen being previewed from the debug section.
    @State private var debugScreen: DebugScreen?
    #endif

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Aura version \(v) (\(b))"
    }

    /// Art-slot sizes, named per DESIGN.md §2/§12 rather than inlined. The two
    /// social glyphs differ so each reads balanced in the 56pt disc.
    private static let rowIconSize: CGFloat = 38
    private static let socialDiscSize: CGFloat = 56
    private static let instagramGlyphSize: CGFloat = 38
    private static let tiktokGlyphSize: CGFloat = 23
    /// The close chip: a 36pt disc inside a 44pt (Apple minimum) hit area.
    private static let closeDiscSize: CGFloat = 36

    var body: some View {
        ZStack(alignment: .top) {
            LightSheet.ground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    header

                    // Account: identity, billing, and the session. Only the last
                    // row(s) change with sign-in state.
                    sectionHeader("Account", store.isSignedIn
                        ? "Signed in as \(store.email.isEmpty ? store.displayName : store.email)."
                        : "Sign in to save your progress.")
                        // Subtitle shows the email; keep it out of session replays.
                        .maskedInReplays()
                    VStack(spacing: Theme.Spacing.m) {
                        card {
                            navRow(sticker: "NavProfileSticker", title: "Profile",
                                   value: store.displayName) {
                                showEditProfile = true
                            }
                        }
                        // The Profile row shows the display name.
                        .maskedInReplays()
                        card {
                            navRow(sticker: "SettingsManageSubscription", title: "Manage subscription") {
                                showSubscription = true
                            }
                        }
                        if store.isSignedIn {
                            card {
                                navRow(sticker: "SettingsName", title: "Sign out") {
                                    showSignOutConfirm = true
                                }
                            }
                            card {
                                navRow(sticker: "SettingsBugReport",
                                       title: deleting ? "Deleting…" : "Delete account") {
                                    if !deleting { showDeleteConfirm = true }
                                }
                            }
                        } else {
                            card {
                                navRow(sticker: "SettingsName", title: "Sign in") {
                                    showSignIn = true
                                }
                            }
                        }
                    }

                    sectionHeader("Preferences", "How Aura reminds you, and how strict it is.")
                    VStack(spacing: Theme.Spacing.m) {
                        remindersCard
                        hardModeCard
                        card {
                            navRow(sticker: "SettingsInterventionStyle", title: "Intervention style") {
                                showInterventions = true
                            }
                        }
                    }
                    sectionHeader("Support", "Need help? Reach out or leave us feedback!")
                    VStack(spacing: Theme.Spacing.m) {
                        card {
                            navRow(sticker: "SettingsHelp", title: "Help") {
                                openURL(AuraLink.help)
                            }
                        }
                        card {
                            navRow(sticker: "SettingsRequestFeature", title: "Request a feature") {
                                openURL(AuraLink.requestFeature)
                            }
                        }
                        card {
                            navRow(sticker: "SettingsBugReport", title: "Report a bug") {
                                showSupportChat = true
                            }
                        }
                        card {
                            navRow(sticker: "SettingsContactUs", title: "Contact us") {
                                showSupportChat = true
                            }
                        }
                    }

                    sectionHeader("Legal", "Privacy and terms.")
                    VStack(spacing: Theme.Spacing.m) {
                        card {
                            navRow(sticker: "SettingsPrivacyPolicy", title: "Privacy Policy") {
                                openURL(AuraLink.privacy)
                            }
                        }
                        card {
                            navRow(sticker: "SettingsTermsConditions", title: "Terms & Conditions") {
                                openURL(AuraLink.terms)
                            }
                        }
                    }

                    sectionHeader("Follow us", "Come say hi, or send Aura to a friend.")
                    socialRow

                    #if DEBUG
                    debugSection
                    #endif

                    Text(appVersion)
                        .auraFont(.body, SheetType.subtitle, .medium)
                        .foregroundStyle(LightSheet.subtitle)
                        .frame(maxWidth: .infinity)
                        .padding(.top, Theme.Spacing.s)
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, TabTopCardMetrics.topInset)
                .padding(.bottom, Theme.Layout.scrollBottomClearance)
            }
            .ignoresSafeArea(edges: .top)
        }
        .sheet(isPresented: $showInterventions) { InterventionStyleSheet() }
        .fullScreenCover(isPresented: $showEditProfile) { ProfileEditScreen() }
        .fullScreenCover(isPresented: $showSignIn) { AccountSignInSheet() }
        .alert("Sign out?", isPresented: $showSignOutConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Sign out", role: .destructive) {
                Haptics.impact(.medium)
                Task { await store.signOut() }
            }
        } message: {
            Text("Your habits stay on this device. Sign back in any time to sync across devices.")
        }
        .alert("Delete account?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Haptics.impact(.medium)
                deleting = true
                Task {
                    do {
                        try await store.deleteAccount()
                    } catch {
                        deleteError = "Something went wrong deleting your account. Check your connection and try again."
                    }
                    deleting = false
                }
            }
        } message: {
            Text("This permanently deletes your Aura account and its stored progress and photos. It does not cancel your subscription. Some support, payment, and legally required records may be retained as explained in the Privacy Policy. This can't be undone.")
        }
        .alert("Couldn't delete account",
               isPresented: Binding(get: { deleteError != nil },
                                    set: { if !$0 { deleteError = nil } })) {
            Button("OK", role: .cancel) { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
        .sheet(isPresented: $showSubscription) { ManageSubscriptionSheet() }
        .fullScreenCover(isPresented: $showSupportChat) { SupportChatView() }
        // Leaving Hard Mode is a 10s hold: it hands back the weekly pass and lets
        // Aura be deleted again, so an instant toggle-off would be the bypass Hard
        // Mode exists to remove.
        .sheet(isPresented: $confirmingExitHardMode) {
            HoldConfirmSheet(
                sticker: "SettingsDifficulty",
                title: "Leave Hard Mode?",
                subtitle: "Your weekly Scroll Pass comes back, and Aura can be deleted again.",
                idleCaption: "Press and hold to leave",
                doneCaption: "Hard Mode off",
                duration: 10
            ) {
                store.hardMode = false
            }
            .auraSheet([.fraction(0.62)])
        }
        #if DEBUG
        .fullScreenCover(item: $debugScreen) { screen in
            debugScreenView(screen)
        }
        #endif
    }

    // MARK: - Header

    /// The screen title, same sticker treatment as the tabs, with a close
    /// control on the right to dismiss back to Profile.
    private var header: some View {
        HStack(alignment: .center) {
            StrokedNumber(text: "Settings",
                          font: Typography.displayUIFont(size: SheetType.hero, weight: .black),
                          fill: .black,
                          stroke: .white,
                          outlineWidth: 3)
                .fixedSize()
                .shadow(color: .black.opacity(0.22), radius: 5, y: 2)

            Spacer(minLength: Theme.Spacing.s)

            Button { dismiss() } label: {
                WoodButtonArtwork(role: .close)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(PressBounceStyle())
        }
    }

    #if DEBUG
    // MARK: - Debug

    /// Developer-only controls, compiled out of release builds. Kept at the
    /// bottom of the list so it's out of the way but always reachable on a
    /// simulator or TestFlight build.
    private var debugSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            sectionHeader("Debug", "Simulator-only shortcuts. Never ships to the App Store.")
            VStack(spacing: Theme.Spacing.m) {
                card {
                    VStack(spacing: 0) {
                        debugRow(symbol: "bitcoinsign.circle.fill",
                                 title: "Add 100 coins",
                                 value: "\(store.coinBalance) now") {
                            store.debugAddCoins(100)
                        }
                        debugDivider
                        debugRow(symbol: "bitcoinsign.circle",
                                 title: "Clear coins",
                                 value: "\(store.coinBalance) now") {
                            store.debugClearCoins()
                        }
                        debugDivider
                        debugRow(symbol: "hourglass.bottomhalf.filled",
                                 title: "Clear screen time",
                                 value: store.isUnlocked ? "\(store.secondsRemaining / 60)m left" : "empty") {
                            store.debugClearScreenTime()
                        }
                    }
                }
                // Quest-completion screens, previewed in isolation. Only Photo
                // Proof has a real failure screen. The other three just dismiss on
                // a short attempt.
                card {
                    VStack(spacing: 0) {
                        debugRow(symbol: "checkmark.circle.fill", title: "Photo Proof · Success (Focus)") { debugScreen = .proofSuccessFocus }
                        debugDivider
                        debugRow(symbol: "checkmark.circle.fill", title: "Photo Proof · Success (Quick)") { debugScreen = .proofSuccessQuick }
                        debugDivider
                        debugRow(symbol: "xmark.circle.fill", title: "Photo Proof · Failure") { debugScreen = .proofFailure }
                        debugDivider
                        debugRow(symbol: "flame.fill", title: "Photo Proof · Streak") { debugScreen = .proofStreak }
                    }
                }
                card {
                    VStack(spacing: 0) {
                        debugRow(symbol: "checkmark.circle.fill", title: "Camera Reps · Success") { debugScreen = .repsSuccess }
                        debugDivider
                        debugRow(symbol: "flame.fill", title: "Camera Reps · Streak") { debugScreen = .repsStreak }
                    }
                }
                card {
                    VStack(spacing: 0) {
                        debugRow(symbol: "checkmark.circle.fill", title: "Lock In · Success") { debugScreen = .focusSuccess }
                        debugDivider
                        debugRow(symbol: "flame.fill", title: "Lock In · Streak") { debugScreen = .focusStreak }
                    }
                }
                card {
                    VStack(spacing: 0) {
                        debugRow(symbol: "checkmark.circle.fill", title: "Passive Income · Success") { debugScreen = .healthSuccess }
                        debugDivider
                        debugRow(symbol: "flame.fill", title: "Passive Income · Streak") { debugScreen = .healthStreak }
                    }
                }
            }
        }
    }

    /// A settings row that leads with an SF Symbol rather than a fox sticker, so
    /// debug entries don't need bespoke art.
    private func debugRow(symbol: String, title: String, value: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.s) {
                HStack(spacing: Theme.Spacing.m) {
                    Image(systemName: symbol)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(LightSheet.blue)
                        .frame(width: Self.rowIconSize, height: Self.rowIconSize)
                    Text(title)
                        .auraFont(.body, RowType.label, .semibold)
                        .foregroundStyle(RowType.labelColor)
                }
                Spacer(minLength: Theme.Spacing.s)
                if let value {
                    Text(value)
                        .auraFont(.body, RowType.value, .medium)
                        .foregroundStyle(RowType.valueColor)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(LightSheet.subtitle)
            }
            .padding(.vertical, Theme.Spacing.m)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressBounceStyle())
    }

    private var debugDivider: some View {
        Divider().overlay(LightSheet.divider)
    }

    /// The quest-completion screens reachable from the debug section. Only Photo
    /// Proof has a real failure screen. A short attempt on the other three just
    /// dismisses the flow, so there's nothing there to preview.
    enum DebugScreen: String, Identifiable {
        case proofSuccessFocus, proofSuccessQuick, proofFailure, proofStreak
        case repsSuccess, repsStreak
        case focusSuccess, focusStreak
        case healthSuccess, healthStreak
        var id: String { rawValue }
    }

    /// Builds each screen with mock data the same way its real flow does. Scripts
    /// are picked with `.random` inside the views, so a preview shows a random
    /// line each time, as it would in the app.
    @ViewBuilder
    private func debugScreenView(_ screen: DebugScreen) -> some View {
        let close: () -> Void = { debugScreen = nil }
        let habit = Habit(name: "Read a book", category: .photoTask, iconAsset: "FoxHabitJournal")
        switch screen {
        case .proofSuccessFocus:
            // Default habit requires a focus session: the "Start Habit Timer" variant.
            ProofSuccessView(habit: habit, minutes: 45, onContinue: close)
                .environment(store)
        case .proofSuccessQuick:
            // A quick habit is paid on the spot: the coins + "Claim Reward" variant.
            ProofSuccessView(habit: Habit(name: "Read a book", category: .photoTask,
                                          requiresFocusSession: false),
                             minutes: 45, onContinue: close)
                .environment(store)
        case .proofFailure:
            ProofFailureView(
                habit: habit,
                verdict: ProofVerdict(passed: false,
                                      reason: "that's just your desk, i can't find the book.",
                                      fix: "get the book open and in the frame, then try again."),
                onRetake: close,
                onClose: close
            )
        case .proofStreak:
            StreakCelebrationView(currentStreak: 7, buttonTitle: "Let's go!", onButton: close)
        case .repsSuccess:
            ExerciseSuccessView(exercise: Exercise.all[0], reps: 12, coins: 12, onContinue: close)
                .environment(store)
        case .repsStreak:
            StreakCelebrationView(currentStreak: 7, buttonTitle: "Let's go!", onButton: close)
        case .focusSuccess:
            // The one success screen that reads the store (streak + longest session).
            FocusSuccessView(session: DeepFocusSession(durationMinutes: 45, earnedMinutes: 45, date: .now),
                             onContinue: close)
                .environment(store)
        case .focusStreak:
            StreakCelebrationView(currentStreak: 7, buttonTitle: "Let's go!", onButton: close)
        case .healthSuccess:
            // No dedicated view: Passive Income builds SunburstSuccessView inline
            // (mirroring AppleHealthView), so the preview matches the real screen.
            SunburstSuccessView(
                // Art gradient replicating Passive Income's real health-success rays.
                rayLighter: Color(hex: "FFDCE3"),
                rayDarker: Color(hex: "FFC3CF"),
                iconCentre: 0.26,
                artHalfHeight: 124,
                art: { SuccessCelebrationArt() },
                title: "Free coins.",
                blurb: "You already did it. Might as well get paid.",
                coins: 24,
                method: .healthSync,
                ctaTitle: "Claim Reward",
                detail: AnyView(
                    VStack(spacing: Theme.Spacing.s) {
                        HStack(spacing: Theme.Spacing.s) {
                            EarnStatTile(icon: { EarnTileIcon(asset: "FoxAppleHealth") },
                                         value: "\(store.healthCollectCount)", label: "Times collected")
                            EarnStatTile(icon: { EarnTileIcon(asset: "EarnCardIcon") },
                                         value: "+24", label: "Coins earned")
                            EarnStatTile(icon: { EarnTileIcon(asset: "StreakFlame") },
                                         value: "\(store.streak.currentStreak)", label: "Day streak")
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        EarnHighlightCard(icon: { EarnHighlightGem() },
                                          text: "Free coins for staying healthy!")
                    }
                ),
                onContinue: close
            )
        case .healthStreak:
            StreakCelebrationView(currentStreak: 7, buttonTitle: "Let's go!", onButton: close)
        }
    }
    #endif

    // MARK: - Scaffolding

    private func sectionHeader(_ title: String, _ subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: RowType.labelGap) {
            Text(title)
                // Section headers match Apps/Stats/Profile at `banner` (20), a rung
                // above the 15pt field/sub-group `sectionHeader` role.
                .auraFont(.display, SheetType.banner, .bold)
                .foregroundStyle(SheetType.titleColor)
            if let subtitle {
                Text(subtitle)
                    .auraFont(.body, SheetType.subtitle, .regular)
                    .foregroundStyle(LightSheet.subtitleDark)
            }
        }
        .padding(.bottom, -Theme.Spacing.s)
    }

    /// The shared white settings card: rounded, bottom drop edge, soft shadow.
    private func card<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(spacing: 0) { content() }
            .padding(.horizontal, Theme.Spacing.m)
            .bottomDropCard(radius: Theme.Radius.card)
    }

    // MARK: - Rows

    private func rowLabel(sticker: String, title: String) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(sticker)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: Self.rowIconSize, height: Self.rowIconSize)
            Text(title)
                .auraFont(.body, RowType.label, .semibold)
                .foregroundStyle(RowType.labelColor)
        }
    }

    /// Reminders as a single toggle card (no sheet): one switch drives both the
    /// habit nudges and the screen-time-low notifications. The subtext names only
    /// the habit nudges, since the screen-time reminders aren't delivered yet.
    private var remindersCard: some View {
        card {
            HStack(spacing: Theme.Spacing.s) {
                HStack(spacing: Theme.Spacing.m) {
                    Image("SettingsReminders")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: Self.rowIconSize, height: Self.rowIconSize)

                    VStack(alignment: .leading, spacing: RowType.labelGap) {
                        Text("Reminders")
                            .auraFont(.body, RowType.label, .semibold)
                            .foregroundStyle(RowType.labelColor)
                        Text("Daily nudges to stay on track.")
                            .auraFont(.body, RowType.subLabel, .regular)
                            .foregroundStyle(RowType.subLabelColor)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: Theme.Spacing.s)

                Toggle("", isOn: remindersBinding)
                    .labelsHidden()
                    .tint(Theme.Color.signalGood)
            }
            .padding(.vertical, Theme.Spacing.m)
            .contentShape(Rectangle())
        }
    }

    /// One switch for every reminder. It reads and writes the habit-reminder flag,
    /// and keeps the (not-yet-delivered) screen-time flag in lockstep so both light
    /// up together once that path is wired.
    private var remindersBinding: Binding<Bool> {
        Binding(
            get: { store.remindersEnabled },
            set: { on in
                Haptics.impact(.light)
                store.remindersEnabled = on
                store.screenTimeRemindersEnabled = on
            }
        )
    }

    /// Hard Mode as a toggle card, built on the Settings card so it lines up with
    /// the nav rows above it: sticker, title over a one-line blurb, then a toggle.
    /// On is an instant tap; off routes through the hold-confirm sheet, so the
    /// switch only actually flips off once the hold completes (`confirmingExitHardMode`).
    private var hardModeCard: some View {
        card {
            HStack(spacing: Theme.Spacing.s) {
                // Mirrors `rowLabel`: same sticker slot, same title size/colour as
                // every other settings row, with a subtext line added under it.
                HStack(spacing: Theme.Spacing.m) {
                    Image("SettingsDifficulty")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: Self.rowIconSize, height: Self.rowIconSize)

                    VStack(alignment: .leading, spacing: RowType.labelGap) {
                        Text("Hard Mode")
                            .auraFont(.body, RowType.label, .semibold)
                            .foregroundStyle(RowType.labelColor)
                        Text("No bypasses, no deleting Aura.")
                            .auraFont(.body, RowType.subLabel, .regular)
                            .foregroundStyle(RowType.subLabelColor)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: Theme.Spacing.s)

                Toggle("", isOn: hardModeBinding)
                    .labelsHidden()
                    .tint(Theme.Color.signalGood)
            }
            // Same vertical rhythm as `navRow`.
            .padding(.vertical, Theme.Spacing.m)
            .contentShape(Rectangle())
        }
    }

    private var hardModeBinding: Binding<Bool> {
        Binding(
            get: { store.hardMode },
            set: { on in
                if on {
                    Haptics.impact(.light)
                    store.hardMode = true
                } else {
                    confirmingExitHardMode = true
                }
            }
        )
    }

    private func navRow(sticker: String, title: String, value: String? = nil, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.impact(.light)
            action()
        } label: {
            HStack(spacing: Theme.Spacing.s) {
                rowLabel(sticker: sticker, title: title)
                Spacer(minLength: Theme.Spacing.s)
                if let value {
                    Text(value)
                        .auraFont(.body, RowType.value, .medium)
                        .foregroundStyle(RowType.valueColor)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(LightSheet.subtitle)
            }
            .padding(.vertical, Theme.Spacing.m)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressBounceStyle())
    }

    // MARK: - Social

    private var socialRow: some View {
        HStack(spacing: Theme.Spacing.l) {
            Spacer(minLength: 0)

            socialDisc { openURL(AuraLink.instagram) } content: {
                Image("SettingsInstagramIcon")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: Self.instagramGlyphSize, height: Self.instagramGlyphSize)
            }

            socialDisc { openURL(AuraLink.tiktok) } content: {
                Image("SettingsTikTokIcon")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: Self.tiktokGlyphSize, height: Self.tiktokGlyphSize)
            }

            ShareLink(item: AuraLink.site) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(LightSheet.title)
                    .frame(width: Self.socialDiscSize, height: Self.socialDiscSize)
                    .background(LightSheet.chromeOnLight, in: Circle())
            }
            .buttonStyle(PressBounceStyle())

            Spacer(minLength: 0)
        }
    }

    private func socialDisc<C: View>(action: @escaping () -> Void, @ViewBuilder content: () -> C) -> some View {
        Button(action: action) {
            content()
                .frame(width: Self.socialDiscSize, height: Self.socialDiscSize)
                .background(LightSheet.chromeOnLight, in: Circle())
        }
        .buttonStyle(PressBounceStyle())
    }
}

#Preview {
    SettingsScreen()
        .environment(HabitStore())
}
