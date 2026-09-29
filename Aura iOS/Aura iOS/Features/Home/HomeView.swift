//
//  HomeView.swift
//  Aura iOS
//

import SwiftUI
// `requestReview` lives in StoreKit, not SwiftUI.
import StoreKit
import UIKit

/// Home tab root. Three states: an active habit timer (Photo Proof session
/// counting down until apps unlock), the unlocked countdown, or the locked
/// "earn time" prompt.
struct HomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var purchaseCountupSeconds: Int?
    @State private var showPurchaseActivationError = false
    @State private var purchaseRetry = 0
    @Environment(\.displayScale) private var displayScale
    /// The countdown above the fox.
    private static let countdownSize: CGFloat = 34
    @Environment(HabitStore.self) private var store
    /// iOS decides whether its own prompt actually appears; this only asks.
    @Environment(\.requestReview) private var requestReview

    /// Opens the earn-method popover (presented up in RootTabView so it can dim
    /// the nav) — triggered by the Earn action card.
    var onEarn: () -> Void = {}

    @State private var showStore = false
    @State private var showBlockedApps = false
    @State private var showSessionControls = false
    /// The streak screen for a habit timer that ran out while nobody was in a
    /// flow. Local, so the store's flag can be cleared the moment it's taken.
    @State private var showSessionStreak = false
    @State private var showRatingAsk = false
    @State private var showStreak = false
    @State private var earnChipAmount: Int?
    @State private var earnChipOffset: CGSize = .zero
    /// The chip's own measured size, so it can be pushed clear of the number by
    /// exactly its own width whatever the amount is.
    @State private var earnChipSize: CGSize = .zero
    @State private var earnChipScale: CGFloat = 0.4
    @State private var earnChipFade: Double = 0

    /// The bonus amount from a power-up just claimed, shown in a rising pop.
    @State private var powerUpBonusShown: Int?

    var body: some View {
        ZStack {
            HomeBackground()

            VStack(spacing: 0) {
                Image("AuraLogo")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(height: 64)
                    .padding(.top, Theme.Spacing.m)

                // A running focus session no longer takes the screen over —
                // the countdown above the fox says the same thing without
                // hiding Home. Its Pause/End controls moved to a sheet, opened
                // by tapping the countdown.
                VStack(spacing: 0) {
                    Spacer()
                    focal
                    Spacer()
                }
                .padding(.bottom, Theme.Layout.navBarClearance)
            }
            // Streak badge pinned to the screen's top-right, level with the
            // centered logo — flame over its count.
            .overlay(alignment: .topTrailing) {
                // Top padding is set so the flame circle's center lands level
                // with the AURA logo's center (logo: 64pt tall, 12pt top pad →
                // center at y 44; circle is 52pt → 18 + 26 = 44). The streak
                // number hangs below.
                Button {
                    Haptics.impact(.light)
                    showStreak = true
                } label: {
                    StreakBadge(count: store.streak.currentStreak)
                }
                .buttonStyle(PressBounceStyle(hapticsEnabled: false))
                .padding(.top, Theme.Spacing.l)
                .padding(.trailing, Theme.Spacing.xl)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Full screen, not a sheet: buying screen time is its own flow and
        // the purchase animation needs the top of the screen.
        .fullScreenCover(isPresented: $showStore) {
            ScreentimeStoreView()
        }
        .fullScreenCover(isPresented: $showStreak) {
            StreakScreen()
        }
        .sheet(isPresented: $showRatingAsk) {
            RatingAskSheet(
                onYes: {
                    showRatingAsk = false
                    store.markRated()
                    // A beat, so Apple's prompt doesn't land on top of a sheet
                    // still animating out.
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.5))
                        requestReview()
                    }
                },
                onNo: { showRatingAsk = false }
            )
            .presentationDetents([.fraction(0.52)])
            .presentationDragIndicator(.hidden)
        }
        // A focus habit's day is booked when its timer ends, not when its photo
        // passed, so this celebration has no flow to live in. It surfaces here,
        // on the screen the user is already looking at.
        .fullScreenCover(isPresented: $showSessionStreak) {
            StreakCelebrationView(
                currentStreak: store.streak.currentStreak,
                buttonTitle: "Let's go!"
            ) {
                showSessionStreak = false
                // The coins landed at the same moment. Their animation waited
                // for this screen to get out of the way.
                playPendingEarn()
            }
        }
        .sheet(isPresented: $showBlockedApps) {
            BlockedNowSheet(icons: store.blockedNowIcons)
        }
        .sheet(isPresented: $showSessionControls) {
            if let session = store.activeHabitSession {
                HabitSessionSheet(
                    session: session,
                    now: store.now,
                    onTogglePause: { store.toggleHabitSessionPause() },
                    onEnd: {
                        store.endHabitSession()
                        showSessionControls = false
                    }
                )
            }
        }
        // Same reason as Stats: the fox, the arc, the sticker-outlined streak
        // numeral and the earn grid are all fixed geometry that type grows
        // inside, not layout that reflows around it.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .task(id: purchasePresentationKey) {
            await presentPendingScreenTime()
        }
        .alert("Couldn't start screentime", isPresented: $showPurchaseActivationError) {
            Button("Try again") { purchaseRetry += 1 }
            Button("Later", role: .cancel) {}
        } message: {
            Text("Your purchased minutes are saved. You can try again without spending more coins.")
        }
    }

    /// Whether the Distracting apps are shut right now — the one thing that sets
    /// the fox's mood. True only when they're NOT lifted (no bought time / in a
    /// session) AND there are actually distracting apps to lock. Forbidden apps
    /// stay blocked forever, so they're deliberately left out.
    private var distractingBlockedNow: Bool {
        store.pendingScreenTimePurchase == nil && !store.isDistractingLifted
            && !store.blockConfig[.distracting].iconSources.isEmpty
    }

    /// The centered focal — a big "time left" number, one status line, and the
    /// stats pill right beneath. The mascot drops in around this later.
    private var focal: some View {
        let blockedNow = store.blockedNowIcons
        // The fox holds the focal slot in every state. Two moods: while the
        // DISTRACTING apps are shut it runs the 30s "blocked" loop (a transparent
        // HEVC clip); the moment they're open (time bought, or nothing distracting
        // left to lock) it drops back to the tired flipbook. Forbidden apps are
        // always blocked, so only Distracting sets the mood.
        return Group {
            if distractingBlockedNow {
                LoopingVideoView(resource: "HomeBlockedFox")
            } else {
                TiredFoxFrameAnimation(fps: 30)
            }
        }
        // 260 frame, shadow sized off it (0.51 × 0.136). Both moods share it.
        .frame(height: 260)
        .frame(maxWidth: .infinity)
        // One solid contact shadow grounding either fox on the rock platform.
        .background(alignment: .bottom) {
            Ellipse()
                .fill(Color.black.opacity(HomeDaylight.isDay() ? 0.12 : 0.30))
                .frame(width: 260 * 0.51, height: 260 * 0.136)
                .offset(y: -13)
        }
        .offset(x: 4)
        // Sit the fox in the middle of the rock platform.
        .offset(y: -4)
        // The status pill floats ABOVE the fox and the cards float BELOW it, both
        // as OVERLAYS — so neither changes the focal's height. The focal is the fox
        // alone (a fixed 260 frame), which is exactly why the fox never moves when
        // the cards change size.
        .overlay(alignment: .top) {
            statusStack(blockedNow: blockedNow)
                .alignmentGuide(.top) { $0[.bottom] + 13 }
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: Theme.Spacing.xxl) {
                earnGoalBar
                actionCards
            }
            .alignmentGuide(.bottom) { $0[.top] - 10 }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        // The focal is the fox alone (centered), with the cards floating below it.
        // Lift the whole thing so the fox sits in the upper-middle and the cards
        // clear the nav.
        .offset(y: -70)
    }

    /// The floating status block above the fox: what's on the clock, then what's
    /// locked. Both parts come and go on their own.
    @ViewBuilder
    private func statusStack(blockedNow: [AppIconSource]) -> some View {
        VStack(spacing: Theme.Spacing.s) {
            ForEach(Array(displayedCountdowns.enumerated()), id: \.offset) { _, countdown in
                let isSession: Bool = {
                    if case .untilFocusEnds = countdown { return true }
                    return false
                }()
                VStack(spacing: RowType.labelGap) {
                    Text(countdown.caption)
                        .auraFont(.body, 13, .bold)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.45), radius: 3, y: 1)

                    // Same sticker numeral as the streak count — UIKit-drawn,
                    // since SwiftUI Text can't stroke.
                    StrokedNumber(
                        text: countdown.seconds == 0 && store.pendingScreenTimePurchase != nil ? "00:00" : countdown.clock,
                        font: Typography.displayUIFont(size: Self.countdownSize, weight: .black, tabular: true),
                        fill: HomeDaylight.isDay() ? .white : .black,
                        stroke: HomeDaylight.isDay() ? UIColor(Theme.Color.background) : .white,
                        outlineWidth: Self.countdownSize * StrokedNumeral.outlineRatio
                    )
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                }
                // Only a focus session has anything to open — bought time just
                // burns down.
                .contentShape(Rectangle())
                .onTapGesture {
                    guard isSession else { return }
                    Haptics.impact(.light)
                    showSessionControls = true
                }
            }

            if !blockedNow.isEmpty && store.pendingScreenTimePurchase == nil && !store.isUnlocked
                && store.activeHabitSession == nil && store.activeFocusSession == nil {
                BlockedNowPill(icons: blockedNow) { showBlockedApps = true }
            }
        }
    }

    private func purchasedSecondsRemaining(at date: Date) -> Int {
        guard let deadline = store.unlockEndsAt else { return 0 }
        return max(0, Int(ceil(deadline.timeIntervalSince(date))))
    }

    private var displayedCountdowns: [GateCountdown] {
        var countdowns: [GateCountdown] = []
        let pending = store.pendingScreenTimePurchase != nil
        if pending {
            countdowns.append(.untilAppsLock(seconds: purchaseCountupSeconds ?? purchasedSecondsRemaining(at: Date())))
        } else if purchasedSecondsRemaining(at: store.now) > 0 {
            countdowns.append(.untilAppsLock(seconds: purchasedSecondsRemaining(at: store.now)))
        }
        if let existing = store.gateCountdown, case .untilFocusEnds = existing {
            countdowns.append(existing)
        }
        return countdowns
    }

    private var canPresentPurchasedTime: Bool {
        scenePhase == .active && !showStore && !showStreak && !showSessionStreak
            && !showRatingAsk && !showBlockedApps && !showSessionControls
            && !store.isFlowPresented
    }

    private var purchasePresentationKey: String {
        "\(store.pendingScreenTimePurchase?.id.uuidString ?? "none")-\(canPresentPurchasedTime)-\(purchaseRetry)"
    }

    @MainActor
    private func presentPendingScreenTime() async {
        guard canPresentPurchasedTime, let purchase = store.pendingScreenTimePurchase else { return }
        do {
            // Let the store cover finish dismissing before Home owns the reward.
            try await Task.sleep(for: .milliseconds(350))
            try Task.checkCancellation()
            guard canPresentPurchasedTime else { return }
            let start = purchasedSecondsRemaining(at: Date())
            let began = Date()
            let duration = reduceMotion ? 0.15 : 1.0
            purchaseCountupSeconds = start
            defer { purchaseCountupSeconds = nil }
            while true {
                try Task.checkCancellation()
                guard canPresentPurchasedTime,
                      store.pendingScreenTimePurchase?.id == purchase.id else { return }
                let progress = min(1, Date().timeIntervalSince(began) / duration)
                let eased = 1 - pow(1 - progress, 3)
                let target = purchasedSecondsRemaining(at: Date()) + purchase.minutes * 60
                purchaseCountupSeconds = start + Int(Double(target - start) * eased)
                if progress >= 1 { break }
                try await Task.sleep(for: .milliseconds(16))
            }
            if store.activatePendingScreenTimePurchase(id: purchase.id) {
                Haptics.notify(.success)
            } else if store.pendingScreenTimePurchase?.id == purchase.id {
                showPurchaseActivationError = true
                Haptics.notify(.error)
            }
        } catch {
            // Leaving Home/backgrounding cancels only presentation, never payment.
        }
    }

    /// Spendable balance above a separate, earnings-only daily progress bar.
    /// Not in a card — it sits directly on the home art, Brainrot-style.
    private var earnGoalBar: some View {
        let coins = store.coinBalance

        return VStack(spacing: Theme.Spacing.m) {
            // Centered coin + number.
            HStack(spacing: Theme.Spacing.s) {
                Image("AuraCoinIcon")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                    // Glints straddling the coin's edge, half on and half off.
                    .overlay {
                        ZStack {
                            IceSparkle(size: 17, delay: 0.0).position(x: 44.64, y: 12.24)
                            IceSparkle(size: 11, delay: 0.8).position(x: 10.13, y: 43.05)
                        }
                        .frame(width: 56, height: 56)
                    }

                // The same sticker numeral as the streak count and countdown.
                StrokedNumber(text: "\(coins)",
                              font: Typography.displayUIFont(size: 48, weight: .black, tabular: true),
                              fill: HomeDaylight.isDay() ? .white : .black,
                              stroke: HomeDaylight.isDay() ? UIColor(Theme.Color.background) : .white,
                              outlineWidth: 4)
                    .fixedSize()
                    .overlay(alignment: .topTrailing) { earnChip }
            }

            chargeBar(coins: store.todayEarnedCoins, claimed: store.claimedPowerUps)
        }
        .overlay(alignment: .top) { powerUpPop }
        .onAppear {
            drainPendingStreak()
            playPendingEarn()
        }
        #if DEBUG
        // `-rating` opens the ask on Home. Reaching it for real means a first
        // ever habit or a two-week streak, neither of which is a thing you can
        // arrange in a Simulator. Goes straight to the sheet without touching
        // the counters, so it can be opened as often as you like.
        .task {
            guard ProcessInfo.processInfo.arguments.contains("-rating") else { return }
            try? await Task.sleep(for: .seconds(0.6))
            showRatingAsk = true
        }
        #endif
        .onChange(of: store.pendingStreakCelebration) { _, _ in drainPendingStreak() }
        .onChange(of: store.pendingRatingAsk) { _, _ in drainPendingRating() }
        .onChange(of: showSessionStreak) { _, showing in
            // The streak screen is the one thing that queues ahead of both.
            guard !showing else { return }
            drainPendingRating()
        }
        #if DEBUG
        // `-earn 8` credits eight coins a beat after Home settles, so the
        // count-up can be watched without a camera, a 30-minute timer, or
        // Health data the Simulator doesn't have.
        .task {
            let args = ProcessInfo.processInfo.arguments
            guard let i = args.firstIndex(of: "-earn"), i + 1 < args.count,
                  let amount = Int(args[i + 1]) else { return }
            try? await Task.sleep(for: .seconds(1.2))
            store.grantScreenTime(minutes: amount)
        }
        #endif
        .onChange(of: store.pendingEarnPulse) { _, _ in playPendingEarn() }
        .onChange(of: store.todayEarnedCoins, initial: true) { _, _ in checkPowerUps() }
        .onChange(of: store.isFlowPresented) { _, presented in
            guard !presented else { return }
            // The cover takes about a third of a second to get out of the way.
            // Starting underneath it wastes the first half of the count.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.45))
                drainPendingStreak()
                playPendingEarn()
            }
        }
    }

    /// The "+8" that rises off the counter and fades.
    ///
    /// Lifted from the reference, where the amount earned floats up out of the
    /// number it was just added to. It says what the count-up alone can't: not
    /// just that the figure moved, but by how much.
    @ViewBuilder
    private var earnChip: some View {
        if let amount = earnChipAmount {
            Text("+\(amount)")
                .auraFont(.body, SheetType.cardTitle, .bold)
                .foregroundStyle(Theme.Color.earnBar)
                .fixedSize()
                .background {
                    GeometryReader { geo in
                        Color.clear.preference(key: EarnChipSizeKey.self, value: geo.size)
                    }
                }
                .onPreferenceChange(EarnChipSizeKey.self) { earnChipSize = $0 }
                // Parked wholly OUTSIDE the number, off its top-right corner.
                //
                // `.overlay(alignment: .topTrailing)` on its own lines the
                // chip's trailing edge up with the number's, so a two-character
                // chip lay across the number's last digit. These two guides
                // move the anchor to the chip's own leading and bottom edges
                // instead, which puts that corner of the chip on that corner of
                // the number and leaves the figure clear.
                .scaleEffect(earnChipScale, anchor: .bottomLeading)
                // Measured, not guessed. `.overlay(alignment: .topTrailing)`
                // parks the chip's RIGHT edge on the number's right edge, so
                // it lies across the last digit. Pushing it right by its own
                // width moves its LEFT edge there instead, and pushing it up
                // by its own height puts its bottom on the number's top: the
                // chip's bottom-left corner on the number's top-right corner,
                // clear of the figure at any amount from "+8" to "+120".
                //
                // Alignment guides were the obvious way to do this and they
                // silently dropped the view. This is boring and it renders.
                .offset(x: earnChipSize.width + Self.chipGap + earnChipOffset.width,
                        y: -earnChipSize.height - Self.chipGap + earnChipOffset.height)
                .opacity(earnChipFade)
                .allowsHitTesting(false)
        }
    }

    /// Plays the pulse the store is holding, if Home is actually on screen.
    ///
    /// Draining it here rather than in the store is what makes the whole thing
    /// work: the coins land during the flow, the pulse waits, and it is spent
    /// the first time Home is in front of somebody.
    /// Takes the streak celebration the store is holding, if Home is in front.
    private func drainPendingStreak() {
        guard store.pendingStreakCelebration,
              !store.isFlowPresented, !showStore, !showStreak, !showSessionStreak
        else { return }
        store.pendingStreakCelebration = false
        showSessionStreak = true
    }

    /// Takes the rating ask, but only once nothing else wants the screen.
    ///
    /// Deliberately last. A first-ever habit fires the streak celebration, the
    /// earn count-up and this, all off the same completion, and asking somebody
    /// to rate the app in the middle of their reward is how you get the honest
    /// answer you didn't want.
    private func drainPendingRating() {
        guard store.pendingRatingAsk,
              !store.isFlowPresented, !showStore, !showStreak,
              !showSessionStreak, !showRatingAsk,
              store.pendingEarnPulse == nil, earnChipAmount == nil
        else { return }
        store.pendingRatingAsk = false
        store.recordRatingAsk()
        showRatingAsk = true
    }

    private func playPendingEarn() {
        // `showSessionStreak` too: the streak screen is full-screen, and a
        // count-up playing behind it is a count-up nobody sees.
        guard !store.isFlowPresented, !showStore, !showStreak, !showSessionStreak,
              let pending = store.pendingEarnPulse else { return }
        store.pendingEarnPulse = nil

        earnChipOffset = .zero
        earnChipScale = 0.5
        earnChipFade = 0
        // Mounted invisible one beat before it is revealed. Its position comes
        // from its own measured width, and that measurement only lands after a
        // layout pass, so a chip shown on the same frame it mounts renders once
        // at the wrong place and then snaps to the right one. That snap was the
        // jank.
        earnChipAmount = pending.amount

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(20))

            Haptics.impact(.light)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                earnChipScale = 1
                earnChipFade = 1
            }

            // Starts where the spring finishes rather than halfway through it.
            // Two curves driving the same view at once is a wobble, not a move.
            try? await Task.sleep(for: .seconds(0.3))
            // Straight up, and unhurried. The sideways component read as the
            // chip being flicked away; a vertical drift reads as it lifting off
            // the number it came from. Long enough to watch it go rather than
            // to notice it has gone.
            withAnimation(.easeOut(duration: 1.1)) {
                earnChipOffset = CGSize(width: 0, height: -34)
                earnChipFade = 0
            }

            #if DEBUG
            // `-earnhold` freezes the chip where it lands so its position can
            // be measured instead of guessed at. The whole thing is over in
            // under a second, which is faster than a Simulator screenshot.
            if ProcessInfo.processInfo.arguments.contains("-earnhold") { return }
            #endif

            try? await Task.sleep(for: .seconds(1.1))
            earnChipAmount = nil
            // Last in the queue, always. Being asked to rate the app while the
            // coins are still counting up is being interrupted mid-reward.
            drainPendingRating()
        }
    }

    /// A hair of daylight between the chip and the corner it hangs off, so the
    /// two don't touch.
    private static let chipGap: CGFloat = 3

    /// A four-level charge bar — one segment per power-up at 25/50/75/100 coins.
    /// Each fills as coins are earned and stays filled when spent; a claimed
    /// power-up keeps a gold ring so you can see which levels you've hit today.
    private func chargeBar(coins: Int, claimed: Set<Int>) -> some View {
        let levels = 4
        let per = 25
        let green = Theme.Color.earnBar
        let barH: CGFloat = 16
        let nodeD: CGFloat = 40
        let skullD: CGFloat = 40
        return GeometryReader { proxy in
            let gap: CGFloat = 4
            // Leave half a node of room at each end so the skull and the final
            // node sit fully on-screen instead of being clamped inward — that
            // clamp is what made the spacing read as uneven.
            let inset = nodeD / 2
            let usableW = proxy.size.width - inset * 2
            let segW = (usableW - gap * CGFloat(levels - 1)) / CGFloat(levels)
            ZStack {
                // Recessed track + a two-tone gradient fill, each segment outlined
                // in white.
                HStack(spacing: gap) {
                    ForEach(0..<levels, id: \.self) { i in
                        let lower = i * per
                        let fill = min(1, max(0, Double(coins - lower) / Double(per)))
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.Color.earnTrack)
                            Capsule()
                                .fill(LinearGradient(colors: [green.lightened(by: 0.18), green, green.darkened(by: 0.10)],
                                                     startPoint: .top, endPoint: .bottom))
                                .frame(width: segW * fill)
                        }
                        .frame(width: segW, height: barH)
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Color.white, lineWidth: 3))
                    }
                }
                .padding(.horizontal, inset)

                // Power-up nodes on each seam (25/50/75/100), evenly spaced. The
                // last one lands on the bar's right end, not clamped inside it.
                ForEach(0..<levels, id: \.self) { i in
                    let x = inset + CGFloat(i + 1) * segW + CGFloat(i) * gap
                    powerUpNode(reached: coins >= (i + 1) * per,
                                claimed: claimed.contains((i + 1) * per), diameter: nodeD)
                        .position(x: x, y: proxy.size.height / 2)
                }

                // A skull marks the start (zero), one even step left of the first
                // node.
                Image("PowerUpSkull")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: skullD, height: skullD)
                    .position(x: inset - gap, y: proxy.size.height / 2)
            }
        }
        .frame(height: 30)
    }

    /// All four milestones share the approved coin-pouch sticker.
    private func powerUpNode(reached: Bool, claimed: Bool, diameter: CGFloat) -> some View {
        Image("PowerUpCoinPouch")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: diameter, height: diameter)
            .saturation(reached ? 1 : 0)
            .accessibilityLabel(claimed ? "Power-up claimed" : reached ? "Power-up unlocked" : "Power-up locked")
    }

    /// The rising "Power up +N" pop shown when a threshold is claimed.
    @ViewBuilder private var powerUpPop: some View {
        if let bonus = powerUpBonusShown {
            HStack(spacing: 5) {
                Image("PowerUpCoinPouch")
                    .resizable().scaledToFit().frame(width: 28, height: 28)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(.yellow)
                Text("Power up  +\(bonus)")
                    .auraFont(.body, 14, .black)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(Color.black.opacity(0.6))
                    .overlay(Capsule().strokeBorder(Color.yellow.opacity(0.6), lineWidth: 1))
            )
            .offset(y: -46)
            .transition(.scale(scale: 0.6).combined(with: .opacity))
        }
    }

    /// Claims any power-up thresholds the balance just reached, and pops the
    /// bonus. The store guards against re-claiming, so this is safe to call on
    /// every coin change.
    private func checkPowerUps() {
        guard let bonus = store.claimReachedPowerUps() else { return }
        Haptics.impact(.heavy)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) { powerUpBonusShown = bonus }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeOut(duration: 0.35)) { powerUpBonusShown = nil }
        }
    }

    /// The two action tiles beneath the prompt — Quests / Scroll.
    private var actionCards: some View {
        HStack(spacing: Theme.Spacing.m) {
            // Earn opens the method popover, which grows from this card — its
            // frame is published via EarnAnchorKey for RootTabView to read.
            Button(action: onEarn) {
                actionCard(title: "Quests", iconAsset: "EarnCardIcon", palette: LightSheet.Achievement.coins, isPhone: false)
            }
            .buttonStyle(PressBounceStyle())
            .anchorPreference(key: EarnAnchorKey.self, value: .bounds) { $0 }

            // Scroll opens the Screentime Store (spend earned coins). Stays
            // open during a running session — buying again tops the timer up.
            Button {
                Haptics.impact(.light)
                showStore = true
            } label: {
                actionCard(title: "Scroll", iconAsset: "ScrollCardIcon", palette: LightSheet.Achievement.reps, isPhone: true)
            }
            .buttonStyle(PressBounceStyle(hapticsEnabled: false))
        }
    }

    private func actionCard(title: String, iconAsset: String, palette: LightSheet.Achievement.Palette, isPhone: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
        return shape
            .fill(LinearGradient(colors: [palette.top, palette.bottom],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .aspectRatio(16.0 / 10.5, contentMode: .fit)
            .overlay {
                GeometryReader { geometry in
                    let size = geometry.size
                    let artworkSide = size.height * (isPhone ? 1.276 : 1.3)
                    let artworkCenter = CGPoint(x: size.width * 0.5,
                                                y: size.height * 0.87 + Theme.Spacing.s)
                    ZStack(alignment: .topLeading) {
                        Image(isPhone ? "HomeScrollPattern" : "HomeQuestsPattern")
                            .resizable()
                            .interpolation(.high)
                            .frame(width: size.width, height: size.height)
                            .opacity(0.24)
                            .accessibilityHidden(true)
                        Image(iconAsset)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(width: artworkSide, height: artworkSide)
                            .position(artworkCenter)
                        StrokedNumber(
                            text: title,
                            font: Typography.displayUIFont(size: SheetType.title + Theme.Spacing.xs, weight: .bold),
                            fill: .black, stroke: .white,
                            outlineWidth: (SheetType.title + Theme.Spacing.xs) * StrokedNumeral.outlineRatio)
                        .fixedSize()
                        .shadow(color: .black.opacity(LightSheet.Achievement.numeralShadowOpacity),
                                radius: LightSheet.Achievement.numeralShadowRadius,
                                y: LightSheet.Achievement.numeralShadowDrop)
                        .frame(width: size.width, alignment: .center)
                        .padding(.top, Theme.Spacing.s - 2 / displayScale)
                    }
                }
            }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.6), .white.opacity(0.05)],
                                   startPoint: .top, endPoint: .bottom), lineWidth: 1)
            }
            .illustratedCardShadow()
    }


}

#Preview {
    HomeView()
        .environment(HabitStore())
        .preferredColorScheme(.dark)
}


/// Carries the earn chip's measured size up to the card.
private struct EarnChipSizeKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}
