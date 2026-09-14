//
//  AppGate.swift
//  Aura iOS
//
//  The app entry gate. Routes first run: onboarding funnel → (paywall) → the
//  Setup handoff (permissions) → the app. The old RootGate + Part1/Part2
//  onboarding has been removed; this is the only gate.
//
//  DEBUG launch args:
//   -home        skip straight to the app
//   -onboarding  reset and show the onboarding funnel from the start
//   -questions   jump straight into the Phase 4 question stretch
//   -setup       skip onboarding and show the Setup handoff again
//

import SwiftUI

struct AppGate: View {
    @Environment(HabitStore.self) private var store
    @AppStorage("aura.onboarding.completed") private var onboardingDone = false
    @AppStorage("aura.setup.completed") private var setupDone = false
    @State private var onboarding = OnboardingFlow()
    @State private var setup = SetupFlow()
    /// Production ships the shortened launch onboarding. DEBUG screen-preview args
    /// flip this so they render the full v2 flow (which can show every step).
    @State private var previewFullFlow = false
    @State private var showReturningSignIn = false
    @State private var checkingReturningAccount = false
    @State private var retryReturningAccount = false

    var body: some View {
        TimelineView(.everyMinute) { context in
            Group {
                if store.accountPersistenceFailed {
                    accountRecoveryView
                } else if debugProto {
                    // Jump straight into the real Phase 4 question stretch.
                    OnboardingFlowView()
                        .environment(onboarding)
                        .transition(.opacity)
                } else if checkingReturningAccount {
                    ZStack {
                        HomeBackground()
                        ProgressView("Checking your plan…")
                            .auraFont(.body, SheetType.cardTitle, .regular)
                            .tint(.white)
                            .foregroundStyle(.white)
                    }
                } else if debugHome || (onboardingDone && subscribed && setupDone) {
                    RootTabView()
                        .transition(.opacity)
                } else if !onboardingDone {
                    // Production: the shortened 12-screen launch onboarding. The full
                    // v2 flow (OnboardingFlowView) stays available for DEBUG previews.
                    if previewFullFlow {
                        OnboardingFlowView()
                            .environment(onboarding)
                            .transition(.opacity)
                    } else {
                        LaunchOnboardingFlowView()
                            .environment(onboarding)
                            .transition(.opacity)
                    }
                } else if !subscribed {
                    // Onboarding is done but there's no active subscription: the
                    // paywall stands between the funnel and the app. (Placeholder
                    // until onboarding screen 32 is built.)
                    SubscriptionGateView()
                        .transition(.opacity)
                } else {
                    SetupFlowView()
                        .environment(setup)
                        .transition(.opacity)
                }
            }
            .preferredColorScheme(preferredColorScheme(at: context.date))
        }
        .task {
            configureRoutesForLaunch()
        }
        .fullScreenCover(isPresented: $showReturningSignIn) {
            AccountSignInSheet(onSignedIn: finishReturningSignIn)
        }
        .alert("Couldn't check your plan", isPresented: $retryReturningAccount) {
            Button("Try again", action: finishReturningSignIn)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please try again to continue with your account.")
        }
        .onChange(of: store.accountPersistenceFailed) { _, failed in
            if failed {
                showReturningSignIn = false
                retryReturningAccount = false
                checkingReturningAccount = false
            }
        }
        .onChange(of: setup.step) { _, step in
            // Authentication is already complete for returning users; all device
            // permissions and app selection steps remain required.
            guard !store.accountPersistenceFailed, step == .signIn, store.isSignedIn else { return }
            if setup.goingBack { setup.back() } else { setup.advance() }
        }
    }

    /// Keep every account surface inaccessible until its local data is safe.
    private var accountRecoveryView: some View {
        VStack(spacing: 20) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.largeTitle)
                .accessibilityHidden(true)
            Text("Couldn't open your account")
                .font(.title2.bold())
            Text(store.accountPersistenceMessage ?? "Aura couldn't safely open your account data. Please try again.")
                .multilineTextAlignment(.center)
            Button("Try again") {
                store.retryPendingAccountTransition()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private func finishReturningSignIn() {
        guard !store.accountPersistenceFailed, store.isSignedIn, let account = SupabaseManager.shared.currentUserID else { return }
        checkingReturningAccount = true
        showReturningSignIn = false
        Task { @MainActor in
            let resolved = await store.refreshEntitlementForSignIn()
            defer { checkingReturningAccount = false }
            guard !store.accountPersistenceFailed, store.isSignedIn, SupabaseManager.shared.currentUserID == account else { return }
            guard resolved != nil else {
                retryReturningAccount = true
                return
            }
            // Authentication skips the acquisition questions, never the paid
            // entitlement check or this device's setup requirements.
            onboardingDone = true
        }
    }

    private func configureRoutesForLaunch() {
        onboarding.onSignInRequested = {
            guard !store.accountPersistenceFailed else { return }
            showReturningSignIn = true
        }
        onboarding.onFinish = {
            guard !store.accountPersistenceFailed else { return }
            withAnimation(.easeInOut(duration: 0.35)) { onboardingDone = true }
        }
        setup.onFinish = {
            guard !store.accountPersistenceFailed else { return }
            withAnimation(.easeInOut(duration: 0.35)) { setupDone = true }
        }

        #if DEBUG
        configureDebugRoute(arguments: ProcessInfo.processInfo.arguments)
        #endif
    }

    #if DEBUG
    private func configureDebugRoute(arguments args: [String]) {
        // Any debug jump into a specific onboarding screen previews the FULL v2
        // flow, so the launch renderer never lands on a step it doesn't include.
        let onboardingJumps = ["-questions", "-proto", "-reclaim", "-science", "-reviews",
                               "-reviewdrop", "-doom", "-habits", "-commit", "-loading",
                               "-loopdemo", "-demo", "-welcome", "-chat", "-plan"]
        if args.contains(where: onboardingJumps.contains) {
            previewFullFlow = true
            onboarding.steps = OnboardingFlow.fullSteps
        }
        if args.contains("-onboarding") { onboardingDone = false; setupDone = false }
        if args.contains("-questions") || args.contains("-proto") { onboarding.step = .qGoal }
        if args.contains("-reclaim") { onboardingDone = false; setupDone = false; onboarding.step = .qReclaim }
        if args.contains("-science") { onboardingDone = false; setupDone = false; onboarding.step = .qScience }
        if args.contains("-reviews") { onboardingDone = false; setupDone = false; onboarding.step = .qReviews }
        if args.contains("-reviewdrop") { onboardingDone = false; setupDone = false; onboarding.step = .qReviewDrop }
        if args.contains("-doom") {
            onboardingDone = false; setupDone = false; onboarding.step = .qDoomProfile
            if onboarding.feelings.isEmpty { onboarding.feelings = ["Bad sleep", "No focus / procrastination"] }
            if onboarding.worstTime == nil { onboarding.worstTime = "Evenings" }
        }
        if args.contains("-habits") { onboardingDone = false; setupDone = false; onboarding.step = .qHabits }
        if args.contains("-commit") { onboardingDone = false; setupDone = false; onboarding.step = .qDailyGoal }
        if args.contains("-loading") { onboardingDone = false; setupDone = false; onboarding.step = .qLoading }
        if args.contains("-loopdemo") { onboardingDone = false; setupDone = false; onboarding.step = .loopDemo }
        if args.contains("-demo") { onboardingDone = false; setupDone = false; onboarding.step = .demoFreeze }
        if args.contains("-welcome") { onboardingDone = false; setupDone = false; onboarding.step = .welcome }
        if args.contains("-chat") {
            onboardingDone = false; setupDone = false; onboarding.step = .chat
            if onboarding.name.isEmpty { onboarding.name = "Hayden" }
        }
        if args.contains("-plan") {
            onboardingDone = false; setupDone = false; onboarding.step = .qCustomPlan
            if onboarding.name.isEmpty { onboarding.name = "Hayden" }
            if onboarding.goal == nil { onboarding.goal = "Improve focus" }
            if onboarding.feelings.isEmpty { onboarding.feelings = ["Bad sleep", "No focus / procrastination"] }
            if onboarding.worstTime == nil { onboarding.worstTime = "Evenings" }
            if onboarding.skips.isEmpty { onboarding.skips = ["The gym", "Sleep"] }
            if onboarding.dailyMinutes == nil { onboarding.dailyMinutes = 60 }
            if store.favoriteHabitIds.isEmpty {
                for habit in store.proofHabits.prefix(2) {
                    store.favoriteHabitIds.insert(habit.id)
                }
            }
        }
        if args.contains("-setup") { onboardingDone = true; setupDone = false }
        if args.contains("-paywall") { onboardingDone = true; setupDone = false }
    }
    #endif

    /// Keep the app's established light appearance. The setup bookends follow the
    /// same 7am/7pm rule as HomeBackground so their system chrome always contrasts.
    private func preferredColorScheme(at date: Date) -> ColorScheme {
        if checkingReturningAccount { return HomeDaylight.isDay(date) ? .light : .dark }
        guard isShowingSetup else { return .light }
        switch setup.step {
        case .welcome, .allSet: return HomeDaylight.isDay(date) ? .light : .dark
        default: return .light
        }
    }

    private var isShowingSetup: Bool {
        !debugProto && !debugHome && onboardingDone && subscribed && !setupDone
    }

    /// The account has an active subscription, or a debug bypass is set. Debug
    /// (`-subscribed`) lets device builds walk past the gate before RevenueCat is
    /// wired; the Simulator's Mock already reports subscribed.
    private var subscribed: Bool { !debugPaywall && (store.isSubscribed || debugSubscribed) }

    /// Force the paywall on for a visual look, even in the Simulator where the
    /// Mock reports subscribed. Pair is set up in `.task`.
    private var debugPaywall: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-paywall")
        #else
        false
        #endif
    }

    private var debugSubscribed: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-subscribed")
            || ProcessInfo.processInfo.arguments.contains("-home")
        #else
        false
        #endif
    }

    private var debugHome: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-home")
        #else
        false
        #endif
    }

    private var debugProto: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-proto")
        #else
        false
        #endif
    }
}
