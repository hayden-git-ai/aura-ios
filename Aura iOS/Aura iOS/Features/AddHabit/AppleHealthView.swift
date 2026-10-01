//
//  AppleHealthView.swift
//  Aura iOS
//

import SwiftUI

/// The Apple Health sheet. When connected (the default until HealthKit is
/// wired), shows today's earnable metrics with collectable screen time; when
/// disconnected, shows the Sync prompt. Presented directly from the FAB's
/// Apple Health method card.
struct AppleHealthView: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var showToast = false
    @State private var reloadPhase: ReloadPhase = .idle
    @State private var showStreak = false
    /// Coins just collected, and whether that was the day's first habit — held
    /// so the success screen can show the number and know where to go next.
    @State private var collected: CollectedCoins?
    @State private var collectedWasFirstToday = false
    @State private var pulse = false

    // Collect animation

    var body: some View {
        VStack(spacing: 0) {
            if store.isHealthConnected {
                connected
            } else {
                connectPrompt
            }
        }
        .background {
            if store.isHealthConnected {
                EarnMethodIllustratedBackground()
            } else {
                MethodScreenBackground(
                    height: MethodScreenBackground.heroCentred(
                        stickerHeight: HabitCategory.healthSync.heroHeight),
                    color: LightSheet.healthPermissionPink
                )
            }
        }
        .preferredColorScheme(.dark)
        .overlay(alignment: .top) { toast }
        // Health totals only ever grow through the day, so the sheet reads them
        // fresh each time it opens rather than trusting what it had.
        .task { if store.isHealthConnected { await store.refreshHealth() } }
        // The same beat the other three quests get on a first completion. It
        // was the one quest that could start a streak in silence.
        // The set of coins, before the streak. Collecting used to go straight
        // from the pop animation to the streak screen, or to nothing at all on
        // the day's second habit, so Passive Income was the one method that
        // could pay out in silence.
        .fullScreenCover(item: Binding(
            get: { collected },
            set: { if $0 == nil { collected = nil } }
        )) { payout in
            SunburstSuccessView(
                iconCentre: 0.26,
                artHalfHeight: 124,
                art: { SuccessCelebrationArt() },
                title: payout.script.title,
                blurb: payout.script.body(payout.amount),
                coins: payout.amount,
                method: .healthSync,
                ctaTitle: "Claim Reward",
                detail: AnyView(
                    VStack(spacing: Theme.Spacing.s) {
                        HStack(spacing: Theme.Spacing.s) {
                            // How many times you've collected, all time — the
                            // Passive Income parallel to Photo Proof's Times done.
                            // The success screen's own heart, which already wears
                            // the sticker treatment.
                            EarnStatTile(icon: { EarnTileIcon(asset: "FoxAppleHealth") },
                                         value: "\(store.healthCollectCount)", label: "Times collected")
                            EarnStatTile(icon: { EarnTileIcon(asset: "EarnCardIcon") },
                                         value: "+\(payout.amount)", label: "Coins earned")
                            EarnStatTile(icon: { EarnTileIcon(asset: "StreakFlame") },
                                         value: "\(store.streak.currentStreak)", label: "Day streak")
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        // One plain line for any collect — naming a category
                        // broke the moment you swept up several at once.
                        EarnHighlightCard(icon: { EarnHighlightGem() },
                                          text: "Free coins for staying healthy!")
                    }
                )
            ) {
                collected = nil
                if collectedWasFirstToday { showStreak = true }
            }
        }
        .fullScreenCover(isPresented: $showStreak) {
            // Was "Claim Reward" over a footnote reading "already banked",
            // which are two statements that cannot both be true. Collect paid
            // out before this cover appeared; the button only closes.
            StreakCelebrationView(
                currentStreak: store.streak.currentStreak,
                buttonTitle: "Let's go!",
                onButton: { showStreak = false }
            )
        }
    }

    /// Gray-circle icon button matching the light sheet's close button.
    // MARK: - Connected (metrics)

    private var connected: some View {
        VStack(spacing: 0) {
            methodHeader

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                        connectedRow
                        metricList
                    }
                    footer
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.xxl)
                .padding(.bottom, Theme.Spacing.xl)
            }

        }
        .overlay(alignment: .topLeading) {
            CircleIconButton(symbol: "xmark", fill: LightSheet.chromeOnBlue,
                             glyphColor: .white, bounces: false) {
                dismiss()
            }
                .padding(.leading, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.l)
        }
        .overlay(alignment: .topTrailing) {
            ExplainerButton(explainer: QuestExplainer.passiveIncome, onBlue: true)
                .padding(.trailing, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.l)
        }
    }

    private var methodHeader: some View {
        EarnMethodIllustratedHeader {
            EarnMethodRewardRibbon(
                asset: "PassiveIncomeRewardRibbon",
                accessibilityLabel: "Live life, Earn coins!"
            )
        }
    }

    /// The connected badge — a pulsing dot and the status text.
    private var connectedRow: some View {
        HStack(spacing: Theme.Spacing.s) {
            Circle()
                .fill(Theme.Color.signalGood)
                .frame(width: 7, height: 7)
                .scaleEffect(pulse ? 1.28 : 1)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                        pulse = true
                    }
                }
            Text("Connected to Apple Health")
                .auraFont(.body, RowType.label, .bold)
                .foregroundStyle(LightSheet.title)

            Spacer(minLength: Theme.Spacing.s)

            // On the status line rather than in the corner: refreshing is about
            // this row's claim being current, so it belongs beside it. Bare and
            // white — a disc up here would be a third circle on a row that
            // already has a status dot.
            Button {
                ReloadPhase.run($reloadPhase) {
                    _ = await store.refreshHealth()
                    // The read worked either way — HealthKit answers a query it
                    // can't satisfy with zero, not an error.
                    return true
                } onFinish: { _ in
                    // A toast on every reload, same as Blocks — the confirmation
                    // is that it refreshed, not that it found something new.
                    showConfirmation()
                }
            } label: {
                // Same glyph sequence as the Blocks explainer's Reload Aura —
                // arrow, spinner, tick — so a reload looks the same wherever
                // it is.
                ReloadGlyph(phase: reloadPhase, tint: LightSheet.title)
                    .frame(width: CircleIconButton.minimumTarget,
                           height: CircleIconButton.minimumTarget,
                           alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(reloadPhase != .idle)
        }
    }

    private var metricList: some View {
        VStack(spacing: Theme.Spacing.m) {
            ForEach(store.healthMetrics, id: \.id) { metric in
                metricRow(metric)
            }
        }
    }

    /// Gold fallback for metrics that do not have a Figma sticker.
    private var healthGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "FFD865"), LightSheet.passiveIncomeGold],
            startPoint: .top, endPoint: .bottom
        )
    }

    private func metricRow(_ metric: HealthMetric) -> some View {
        let active = metric.hasActivity && metric.pendingMinutes > 0
        return Button {
            collect(metric)
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                metricGlyph(metric)
                    .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: RowType.labelGap) {
                    Text(metric.name)
                        .auraFont(.body, RowType.label, .semibold)
                        .foregroundStyle(RowType.labelColor)
                    HStack(spacing: 4) {
                        Image("AuraCoinIcon")
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                        Text(metric.rateLabel.replacingOccurrences(of: " min / ", with: "/"))
                            .auraFont(.body, RowType.subLabel, .medium)
                            .foregroundStyle(LightSheet.subtitle)
                    }
                }

                Spacer(minLength: Theme.Spacing.s)

                if active {
                    VStack(spacing: 2) {
                        Text("Collect")
                            .auraFont(.body, RowType.subLabel, .bold)
                            .foregroundStyle(LightSheet.passiveIncomeGoldShade)
                        CoinBadge(text: "\(metric.pendingMinutes)")
                    }
                } else {
                    Text("No activity")
                        .auraFont(.body, RowType.value, .medium)
                        .foregroundStyle(RowType.valueColor)
                }
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.s)
            .bottomDropCard(radius: Theme.Radius.card, shade: LightSheet.whiteShadeOnColour)
        }
        .buttonStyle(PressBounceStyle())
        .disabled(!active)
    }

    /// The metric's fox sticker (or red-gradient SF-symbol fallback) — no circle
    /// behind it.
    @ViewBuilder
    private func metricGlyph(_ metric: HealthMetric) -> some View {
        if let iconAsset = metric.iconAsset {
            Image(iconAsset)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                // One size for all five. Calories was shrunk to 46 because its
                // old artwork was drawn bigger inside the same canvas than the
                // others were; the pipeline now normalises every sticker to the
                // same ink height, so the exception was correcting a difference
                // that no longer exists.
                .frame(width: 56, height: 56)
        } else {
            Image(systemName: metric.iconSystemName)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .fontWeight(.bold)
                .frame(width: 28, height: 28)
                .foregroundStyle(healthGradient)
        }
    }

    // MARK: - Collect animation

    /// Each metric is its own claim target, so the remaining cards stay
    /// available when the reward screen closes.
    private func collect(_ metric: HealthMetric) {
        guard metric.hasActivity, metric.pendingMinutes > 0 else { return }
        Haptics.impact(.light)
        collectedWasFirstToday = store.collectHealth(metric.id)
        store.recordHealthCollect()
        collected = CollectedCoins(amount: metric.pendingMinutes, script: .random)
    }


    /// Shown only when every metric reads zero.
    ///
    /// Which is the one moment it helps: a denial and a day you haven't moved
    /// are indistinguishable to us — HealthKit reports read access as "not
    /// determined" whatever the user chose — so this has to help the person who
    /// said no without accusing the person who just hasn't walked anywhere. Any
    /// row showing a number proves access is fine, and then it's noise.
    @ViewBuilder
    private var footer: some View {
        if store.healthMetrics.allSatisfy({ $0.pendingMinutes == 0 && !$0.hasActivity }) {
            HStack(alignment: .top, spacing: Theme.Spacing.s) {
                Image(systemName: "info.circle")
                    .font(.system(size: RowType.label))
                    .foregroundStyle(LightSheet.subtitleDark)
                // Settings → Privacy & Security → Health, not the old
                // Settings → Health → Data Access & Devices, which hasn't been
                // the path for several iOS versions.
                Text("Not seeing your activity? Check Aura's access in Settings → Privacy & Security → Health.")
                    .auraFont(.body, RowType.subLabel, .medium)
                    .foregroundStyle(LightSheet.subtitleDark)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Disconnected (sync prompt)

    private var connectPrompt: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                CircleIconButton(symbol: "xmark", glyphColor: LightSheet.subtitleDark,
                                 bounces: false) {
                    dismiss()
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.l)

            Spacer()

            VStack(spacing: Theme.Spacing.l) {
                HealthConnectHero()

                VStack(spacing: Theme.Spacing.s) {
                    Text("Connect to Apple Health")
                        .auraFont(.display, SheetType.title, .bold)
                        .foregroundStyle(.white)
                    Text("Sync Apple Health to earn screen time from your everyday activity.")
                        .auraFont(.body, SheetType.subtitle, .regular)
                        .foregroundStyle(LightSheet.onColour)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Theme.Spacing.xl)
            }

            Spacer()

            // Answers the question that's actually holding the thumb over the
            // button. Both halves are true today: the share set passed to
            // `requestAuthorization` is empty, and the numbers go straight to
            // the local day log. Revisit the second line if earnings ever sync
            // to a server.
            // Plain words: "reads" and "writes to Health" is how the API talks,
            // not how the person holding the phone thinks about it.
            Text("Aura just looks at your activity. It never changes anything in Health, and nothing leaves your phone.")
                .auraFont(.body, RowType.subLabel, .medium)
                .foregroundStyle(LightSheet.onColour)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.m)

            Button {
                Task {
                    await store.connectHealth()
                    Haptics.notify(store.isHealthConnected ? .success : .error)
                }
            } label: {
                // The same white capsule as the Collect button on the other
                // side of this sheet — white face, the field's own pink for the
                // label, and the opaque edge every white face on colour uses.
                Text("Continue")
                    .font(SheetType.ctaFont)
                    .foregroundStyle(LightSheet.healthPermissionPink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
            }
            .buttonStyle(PillPressButtonStyle(face: .white,
                                               shade: LightSheet.whiteShadeOnColour,
                                               lip: 5))
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.l)
        }
    }

    // MARK: - Refresh + toast

    /// Pulls today's totals again, then says so.
    ///
    /// The read was always real — `refreshHealth` runs actual HealthKit
    /// queries — but the toast fired on the same frame as the tap, before any
    /// of them had returned. "Activity is up to date" was a claim made
    /// independently of whether anything had been fetched.
    /// Only when there was something to read. "Activity is up to date" over five
    /// rows of zeros confirms nothing — and it'd fire just as happily with the
    /// permission denied, which is the one case where the footer needs to be
    /// what the user sees.
    private func showConfirmation() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { showToast = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(2400))
            withAnimation(.easeInOut(duration: 0.55)) { showToast = false }
        }
    }

    /// The confirmation, in the app's own language.
    ///
    /// It was a white capsule with a hand-rolled soft shadow, which is a
    /// treatment Aura uses nowhere else — every white face here sits on a drop
    /// edge. On this pink field that edge is the opaque one, the same rule the
    /// Collect button and the metric cards follow.
    private var toast: some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: RowType.label, weight: .bold))
                .foregroundStyle(Theme.Color.signalGood)
            Text("Activity is up to date")
                .auraFont(.body, RowType.label, .semibold)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.s)
        // The Blocked Apps pill's dark nav material — the same confirmation chip
        // wherever a reload lands.
        .background {
            Capsule().fill(Color.black.opacity(0.74))
                .overlay(Capsule().fill(Color.white.opacity(0.08)))
        }
        .overlay { Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 1) }
        // In line with the header controls (the X and explainer), centred
        // between the corner buttons rather than dropped below them.
        .padding(.top, Theme.Spacing.xl)
        // A short drop, not a flight from -160. It's a confirmation, not an
        // arrival.
        .offset(y: showToast ? 0 : -Theme.Spacing.xl)
        .opacity(showToast ? 1 : 0)
        .allowsHitTesting(false)
    }
}



/// Wraps the collected total so it can drive an `item:` cover.
///
/// `id` is STORED, not computed. As `var id: UUID { UUID() }` it minted a new
/// identity on every access, so SwiftUI saw the item change on every render and
/// would have torn the cover down and rebuilt it underneath the user.
///
/// The script rides along for the same reason: drawn fresh at each use, the
/// title came from one script and the line from another, and a fox that changes
/// its manner of speaking halfway down a screen isn't a character. Picked once,
/// when the coins land.
private struct CollectedCoins: Identifiable {
    let id = UUID()
    let amount: Int
    let script: HealthSuccessScript
    /// The category that paid the most this collect — drives the highlight line.
    var topKind: HealthMetricKind? = nil
}

/// What the fox says when Health pays out.
///
/// A different job from the other two. Photo Proof and Camera Reps congratulate
/// you for something you just did on purpose; this is money that accumulated
/// while you were getting on with your day, and the joke is that you didn't do
/// anything for it. Congratulating somebody on their step count the way you'd
/// congratulate them on twelve push-ups would ring false.
private struct HealthSuccessScript {
    let title: String
    let body: (Int) -> String

    /// Every line has to work for all five metrics. Steps, Run/Walk, Exercise
    /// Minutes, Mindful Minutes and Calories Burned all pay out through this
    /// one screen, so anything that names a body part or an activity ("you
    /// already did the walking", "your legs did the work") is wrong four times
    /// out of five. What they have in common is only that the person didn't set
    /// out to earn anything, so that's what the joke is about.
    static let all: [HealthSuccessScript] = [
        HealthSuccessScript(title: "free coins, basically.",
                            body: { _ in "you already did the work, might as well get paid." }),
        HealthSuccessScript(title: "well, look at that.",
                            body: { coins in "\(coins) coins just for existing. i'm not mad about it." }),
        HealthSuccessScript(title: "easiest coins around.",
                            body: { _ in "your day did all the work, so go ahead and take them." }),
        HealthSuccessScript(title: "these are all yours.",
                            body: { coins in "\(coins) coins you basically earned by accident." }),
    ]

    static var random: HealthSuccessScript { all.randomElement() ?? all[0] }
}
