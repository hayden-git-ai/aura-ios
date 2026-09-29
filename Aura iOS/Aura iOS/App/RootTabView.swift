//
//  RootTabView.swift
//  Aura iOS
//

import SwiftUI
import UIKit

/// Captures the Home "Earn" card's frame so the earn-method popover — presented
/// up at the tab-shell level so it can dim the nav too — can grow out of it.
struct EarnAnchorKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

extension Notification.Name {
    static let auraPurchasedTimeReady = Notification.Name("aura.purchased-time.ready")
}

enum AuraTab: CaseIterable {
    case home, apps, earn, stats, profile

    var label: String {
        switch self {
        case .home: return "Home"
        case .apps: return "Apps"
        case .earn: return "Earn"
        case .stats: return "Stats"
        case .profile: return "Profile"
        }
    }

    /// The tab's accent — the colour of its raised platform when it's selected.
    var accent: Color {
        switch self {
        case .home: return LightSheet.blue
        case .apps: return Color(hex: "FF3B30")   // Defense red
        case .earn: return LightSheet.blue
        case .stats: return Color(hex: "34C759")  // green
        case .profile: return Color(hex: "8B5CF6") // purple
        }
    }

    /// The nav's own drawn set. Home and Stats used to borrow habit stickers
    /// (`FoxHabitMakeBed`, `FoxHabitJournal`), which is why the row never read
    /// as a family and why editing a habit's art would have silently changed
    /// the tab bar.
    ///
    /// `.earn` is the centre disc and draws `EarnCardIcon` itself, so this
    /// value is never used for it.
    var sticker: String {
        switch self {
        case .home: return "AuraNavHome"
        case .apps: return "AuraNavBlockLock"
        case .earn: return "AuraCoinIcon"
        case .stats: return "AuraNavStats"
        case .profile: return "AuraNavProfileFox"
        }
    }
}

/// Custom floating capsule nav — not a styled `TabView`. Native tab bars
/// target true edge-to-edge, full-width bars in recent iOS, which fights an
/// inset, capsule-shaped, icon-only bar. This gives full control over width,
/// corner radius, and suppressing label slots.
struct RootTabView: View {
    @State private var showSessionConflict = false
    /// `-blocks` opens straight onto the Apps tab. RootGate already treats it
    /// as "skip onboarding"; this is the half that picks the tab.
    @State private var selectedTab: AuraTab = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-blocks") { return .apps }
        if ProcessInfo.processInfo.arguments.contains("-stats") { return .stats }
        if ProcessInfo.processInfo.arguments.contains("-profilereview") { return .profile }
        #endif
        return .home
    }()

    @State private var showAddHabit = false
    @State private var pendingLaunch: HabitLaunch?
    @State private var listCategory: HabitCategory?
    @Environment(HabitStore.self) private var store
    @State private var showHealthSheet = false
    @State private var navChrome = NavChrome()
    #if DEBUG
    @State private var debugSuccess: HabitCategory?
    @State private var purchasePreviewOwner = StorePurchasePreviewOwner()
    #endif
    /// `-intervene` opens the blocked-app intervention on launch, so the flow
    /// can be walked before the shield extension exists to trigger it.
    @State private var showIntervention = ProcessInfo.processInfo.arguments.contains("-intervene")
        || ProcessInfo.processInfo.arguments.contains("-breathe")
        || ProcessInfo.processInfo.arguments.contains("-mirror")
        || ProcessInfo.processInfo.arguments.contains("-message")
    /// `-breathe` forces the breathing style rather than letting the picker choose.
    private let forcedStyle: InterventionStyle? = {
        if ProcessInfo.processInfo.arguments.contains("-breathe") { return .breathing }
        if ProcessInfo.processInfo.arguments.contains("-mirror") { return .mirror }
        if ProcessInfo.processInfo.arguments.contains("-message") { return .message }
        return nil
    }()
    #if DEBUG
    /// `-health` opens the Apple Health sheet on launch; `-health_fresh` also
    /// forgets that the permission sheet was ever shown, so it lands on the
    /// connect screen rather than the metrics list.
    private var debugHealthJump: Bool {
        ProcessInfo.processInfo.arguments.contains("-health")
            || ProcessInfo.processInfo.arguments.contains("-health_fresh")
    }
    #endif
    @Environment(\.scenePhase) private var scenePhase

    @State private var showFocusSetup = false
    @State private var focusConfig: DeepFocusConfig?

    /// `primeEarn` opens the earn-method popover on first appearance — used for
    /// the post-onboarding first-earn nudge (RootGate hands off here).
    init(primeEarn: Bool = false) {
        #if DEBUG
        _showAddHabit = State(initialValue: primeEarn || ProcessInfo.processInfo.arguments.contains("-earnreview"))
        #else
        _showAddHabit = State(initialValue: primeEarn)
        #endif
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                // Earn opens the method popover instead of swapping content,
                // so it never becomes the selected tab.
                case .home, .earn: HomeView(onEarn: { toggleAddHabit() })
                case .apps: AppsView()
                case .stats: StatsView()
                case .profile: ProfileScreen()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Centre button pulled out to see the bar without it. NOTE: nothing
            // else opens the earn popover, so it is unreachable while this is
            // the case.
            AuraTabBar(items: AuraTab.allCases.filter { $0 != .earn },
                       selection: $selectedTab,
                       centre: .earn,
                       onCentre: { toggleAddHabit() },
                       profileImageData: store.profileImageData,
                       // Home rides over artwork; the flat-white tabs go darker.
                       onLight: selectedTab != .home,
                       shrink: navChrome.shrink)
                .disabled(showAddHabit)
        }
        // The earn-method popover + dimming scrim overlay the entire shell
        // (nav included, so it darkens too) and grow out of the Home "Earn"
        // card, whose frame is captured up here via EarnAnchorKey. The popover
        // stays permanently mounted (hit-testing gated) and animates via plain
        // scale/opacity so open AND close both animate deterministically.
        .overlayPreferenceValue(EarnAnchorKey.self) { anchor in
            GeometryReader { proxy in
                let earnRect = anchor.map { proxy[$0] }
                ZStack {
                    scrim
                    methodPopover(growAnchor: growAnchor(for: earnRect, in: proxy.size))
                }
            }
            .ignoresSafeArea()
        }
        .background(Theme.Color.background.ignoresSafeArea())
        .environment(navChrome)
        #if DEBUG
        .environment(ProcessInfo.processInfo.arguments.contains("-storepurchasepreview")
            ? purchasePreviewOwner.store : store)
        #endif
        // A tab that doesn't scroll must never inherit a hidden bar from one
        // that does.
        .onChange(of: selectedTab) { _, _ in navChrome.reset() }
        .onReceive(NotificationCenter.default.publisher(for: .auraPurchasedTimeReady)) { _ in
            showAddHabit = false
            selectedTab = .home
        }
        .fullScreenCover(item: $listCategory) { category in
            AddHabitFlowRoot(startCategory: category, onLaunch: { launch in
                // Dismiss the list first, then present the earn flow (two
                // covers can't cross-fade, so sequence them).
                listCategory = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    guard !store.isSessionRunning else { showSessionConflict = true; return }
                    pendingLaunch = launch
                }
            })
        }
        .fullScreenCover(item: $pendingLaunch) { launch in
            launchView(launch)
        }
        #if DEBUG
        .task {
            guard debugHealthJump else { return }
            if ProcessInfo.processInfo.arguments.contains("-health_fresh") {
                store.isHealthConnected = false
            }
            showHealthSheet = true
        }
        #endif
        .fullScreenCover(isPresented: $showIntervention) {
            // One style is built, so this is the dialogue either way — but it
            // goes through the store's picker so adding the others changes
            // nothing here.
            InterventionView(appName: "Instagram",
                             style: forcedStyle ?? store.interventionStyle) {}
        }
        .fullScreenCover(isPresented: $showHealthSheet) {
            AppleHealthView()
        }
        #if DEBUG
        // `-success` walks the coins-bearing success screen through all four
        // method colours, one per tap. Every real route to it is blocked in the
        // Simulator: Photo Proof seeds no quick habits, Camera Reps needs reps
        // from a camera that isn't there, and Passive Income has nothing to
        // collect. Three of the four button colours had never been rendered.
        .fullScreenCover(item: $debugSuccess) { method in
            // Lock In has its own screen, so `-success focus` shows that one
            // rather than the generic shape. One debug door for all four beats
            // a second cover on the same view, which SwiftUI would not present.
            if method == .focus {
                FocusSuccessView(
                    session: DeepFocusSession(durationMinutes: 90, earnedMinutes: 23, date: .now)
                ) { debugSuccess = nil }
            } else {
            EarnSuccessView(
                art: { EarnSuccessArt(asset: method.tileIconAsset) },
                title: "Look at you go.",
                blurb: "12 coins. You earned these by accident.",
                coins: 12,
                method: method,
                ctaTitle: "Claim Reward"
            ) {
                // Advances rather than closing, so one launch shows all four in
                // the order they sit on the FAB: blue, orange, violet, pink.
                let order = HabitCategory.tileOrder
                let next = (order.firstIndex(of: method) ?? 0) + 1
                debugSuccess = next < order.count ? order[next] : nil
            }
            }
        }
        // `-focusdone` jumps to the Lock In celebration. Reaching it for real
        // means sitting through a whole session.
        .task {
            let args = ProcessInfo.processInfo.arguments
            guard let i = args.firstIndex(of: "-success") else { return }
            // `-success` alone starts at Photo Proof; `-success exercise` jumps
            // straight to one.
            let named = i + 1 < args.count ? HabitCategory(rawValue: args[i + 1]) : nil
            debugSuccess = named ?? .photoTask
        }
        #endif
        .fullScreenCover(isPresented: $showFocusSetup) {
            FocusTimerSetupView(
                onStart: { config in
                    // Dismiss the setup screen, then present the running timer
                    // (two covers can't cross-fade, so sequence them).
                    showFocusSetup = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        guard !store.isSessionRunning else { showSessionConflict = true; return }
                        focusConfig = config
                    }
                },
                onClose: { showFocusSetup = false }
            )
        }
        .fullScreenCover(item: $focusConfig) { config in
            DeepFocusFlowRoot(config: config)
        }
        // A Lock In outlives this app being killed — the countdown stays on the
        // Lock Screen either way — so coming back has to land on the running
        // session rather than on Home with no way to stop it.
        .task { resumeFocusSessionIfRunning() }
        // Routines are re-laid at launch, so one saved while notifications were
        // denied starts firing the moment they are turned on rather than
        // staying silent forever.
        .task { await RoutineStore.rescheduleAll() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { resumeFocusSessionIfRunning() }
        }
        // Home's earn animation waits on this. Every earn flow lives behind one
        // of the covers above, so without it the count-up runs while the user
        // is still looking at the streak screen.
        .onChange(of: anyFlowPresented) { _, presented in
            store.isFlowPresented = presented
        }
        .alert("Finish your current session first", isPresented: $showSessionConflict) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You can run one habit or focus session at a time. Finish or end it before starting another.")
        }
    }

    /// Whether any full-screen flow is currently over Home.
    private var anyFlowPresented: Bool {
        listCategory != nil || pendingLaunch != nil || showIntervention
            || showHealthSheet || showFocusSetup || focusConfig != nil
    }

    /// Puts the focus screen back up for a session the store is still running.
    ///
    /// The config it was set up with isn't kept — only what the session needs to
    /// finish — so this rebuilds the parts that screen actually reads. Music and
    /// the app selection are lost on a restart, which is worth knowing but not
    /// worth persisting a whole config for.
    private func resumeFocusSessionIfRunning() {
        guard let session = store.activeFocusSession, focusConfig == nil else { return }
        focusConfig = DeepFocusConfig(
            lengthMinutes: session.lengthMinutes,
            isUntimed: session.isOpenEnded,
            earnRate: session.earnRate
        )
    }

    // MARK: - Add-a-habit

    @ViewBuilder
    private func launchView(_ launch: HabitLaunch) -> some View {
        switch launch {
        case .photo(let habit, let minutes): PhotoProofFlowRoot(startHabit: habit, startMinutes: minutes)
        case .reps(let exercise): ExerciseFlowRoot(startExercise: exercise)
        }
    }

    private func toggleAddHabit() {
        Haptics.impact(.light)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
            showAddHabit.toggle()
        }
    }

    /// Tapping a method card: close the popover, then open its selection sheet —
    /// Deep Focus and Apple Health have their own sheets, everything else opens
    /// the habit list.
    private func selectMethod(_ category: HabitCategory) {
        Haptics.impact(.light)
        guard category == .healthSync || !store.isSessionRunning else {
            showAddHabit = false
            Haptics.notify(.error)
            showSessionConflict = true
            return
        }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            showAddHabit = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            switch category {
            case .focus: showFocusSetup = true
            case .healthSync: showHealthSheet = true
            default: listCategory = category
            }
        }
    }

    /// Permanently mounted and gated on hit-testing, like the grid it dims.
    /// Inserted and removed with a transition it stays interactive for the
    /// whole close animation, so a tap on Home during that window lands on the
    /// departing scrim and toggles the popover straight back open.
    private var scrim: some View {
        Color.black.opacity(0.55)
            .ignoresSafeArea()
            .onTapGesture { toggleAddHabit() }
            .opacity(showAddHabit ? 1 : 0)
            .animation(.spring(response: 0.4, dampingFraction: 0.82), value: showAddHabit)
            .allowsHitTesting(showAddHabit)
    }

    private func methodPopover(growAnchor: UnitPoint) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: Theme.Spacing.s), GridItem(.flexible())],
            spacing: Theme.Spacing.s
        ) {
            ForEach(Array(HabitCategory.tileOrder.enumerated()), id: \.element.id) { _, category in
                methodCard(category)
            }
        }
        .padding(.horizontal, Theme.Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        // The whole grid grows out of the Earn card's location + fades. Property
        // animations run in BOTH directions deterministically (unlike per-child
        // removal transitions in a LazyVGrid, which don't reliably fire).
        .scaleEffect(showAddHabit ? 1 : 0.5, anchor: growAnchor)
        .opacity(showAddHabit ? 1 : 0)
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: showAddHabit)
        // Invisible + non-interactive when closed so taps pass through to the
        // content beneath.
        .allowsHitTesting(showAddHabit)
    }

    /// The popover's growth origin as a UnitPoint in the shell's coordinate
    /// space — the center of the Earn card, or the screen center as a fallback
    /// (e.g. before the card's frame resolves, or on a non-Home tab).
    private func growAnchor(for rect: CGRect?, in size: CGSize) -> UnitPoint {
        guard let rect, size.width > 0, size.height > 0 else { return .center }
        return UnitPoint(x: rect.midX / size.width, y: rect.midY / size.height)
    }

    /// Approved artwork with independently rendered curved lettering.
    private func methodCard(_ category: HabitCategory) -> some View {
        let asset: String = switch category {
        case .photoTask: "EarnMethodHabits"
        case .exercise: "EarnMethodExercise"
        case .focus: "EarnMethodFocus"
        case .healthSync: "EarnMethodIncome"
        }
        return Button {
            selectMethod(category)
        } label: {
            Image(asset)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .overlay { EarnCardLettering(category: category).allowsHitTesting(false) }
                .cardShadow()
                .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous))
        }
        .buttonStyle(PressBounceStyle())
        .accessibilityLabel(category.displayName)
        .accessibilityHint(category.tileDescriptor)
    }

}

#if DEBUG
/// SwiftUI may recreate RootTabView values often. Only the retained State owner
/// allocates the isolated preview store, so discarded initializers have no effects.
@MainActor
private final class StorePurchasePreviewOwner {
    lazy var store: HabitStore = {
        let fixtureID = UUID().uuidString
        let fixture = HabitStore(accountDependencies: .init(
            rootURL: FileManager.default.temporaryDirectory.appendingPathComponent("StorePurchasePreview-" + fixtureID),
            defaults: UserDefaults(suiteName: "StorePurchasePreview." + fixtureID)!,
            currentUserID: { nil }, deleteRemote: { _ in }, shouldFail: { _ in false }),
            startRuntimeServices: false)
        fixture.grantScreenTime(minutes: 30)
        fixture.startPreviewClock()
        return fixture
    }()
}
#endif

#Preview {
    RootTabView()
        .environment(HabitStore())
        .preferredColorScheme(.dark)
}


/// Uses the same outlined type and shadow tokens as the achievement numbers.
private struct EarnCardLettering: View {
    let category: HabitCategory

    private var words: [String] {
        switch category {
        case .photoTask: ["Healthy", "Habits"]
        case .exercise: ["Daily", "Exercise"]
        case .focus: ["Deep", "Focus"]
        case .healthSync: ["Passive", "Income"]
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let scale = geometry.size.width / 958
            let font = Typography.displayUIFont(size: 148 * scale, weight: .black)
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                EarnOutlinedTitle(text: word, font: font)
                    .position(x: geometry.size.width / 2,
                              y: (CGFloat(index == 0 ? 220 : 375) - 36) * scale - font.capHeight / 2 + Theme.Spacing.xs)
            }
        }
        .accessibilityHidden(true)
    }
}
