//
//  FocusTimerActiveView.swift
//  Aura iOS
//

import SwiftUI

/// Screen 3 — the running countdown. A 1-second `Timer` ticks
/// `remainingSeconds` down from the configured length; hitting zero logs the
/// session and hands a completed `DeepFocusSession` back to the flow root.
/// No pausing — a focus session is either running or it's been left. Tapping
/// the X doesn't end the session directly; it raises a "Leave Early?"
/// confirmation first.
struct FocusTimerActiveView: View {
    let config: DeepFocusConfig
    var onEndEarly: () -> Void
    var onComplete: (DeepFocusSession) -> Void

    /// The session's anchors live on the store, not here: view state dies
    /// with the view, and the Live Activity has to outlive this screen. All
    /// that's left locally is `now`, which only drives what's on screen.
    @Environment(HabitStore.self) private var store
    @State private var now = Date()
    @State private var timer: Timer?
    @State private var showLeaveConfirm = false

    // Tapping the background toggles this — an immersive mode that leaves
    // just the ring and countdown on screen. The X/sound buttons and the
    // Blocked Apps capsule stay in the hierarchy always (never conditionally
    // removed) and animate via offset + opacity, the same technique as the
    // Apps screen's reload toast, so the slide is symmetric in both directions.
    @State private var isChromeVisible = true

    @Environment(\.scenePhase) private var scenePhase

    private var untimed: Bool { config.isUntimed }

    private var session: ActiveFocusSession? { store.activeFocusSession }

    private var elapsedSeconds: Int { session?.elapsedSeconds(at: now) ?? 0 }
    private var remainingSeconds: Int { session?.remainingSeconds(at: now) ?? 0 }

    private var countdownLabel: String { Self.clockLabel(for: untimed ? elapsedSeconds : remainingSeconds) }

    private static func clockLabel(for seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    /// How the fox and timer sit against the scene art. Fractions of the screen,
    /// tuned by eye to the day/night backgrounds (which share a composition).
    private static let foxSize: CGFloat = 165
    /// Where the fox's seat lands — the middle of the meadow's grass clearing.
    private static let patchBaseY: CGFloat = 0.785
    /// The timer's sky slot, between the sun/moon and the treetop. The moon sits
    /// lower than the sun, so night drops the timer to stay in the gap.
    private static func timerY(day: Bool) -> CGFloat { day ? 0.18 : 0.24 }

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width, H = geo.size.height
            let day = HomeDaylight.isDay()
            ZStack {
                // The countdown, up in the sky between the sun/moon and the tree.
                countdown
                    .position(x: W * 0.5, y: H * Self.timerY(day: day))

                // A soft contact shadow on the grass, a separate ground ellipse
                // (not a background of the fox — the sitting fox's wide base would
                // hide that) so it peeks out under the seat. Behind the fox.
                Ellipse()
                    .fill(Color.black.opacity(day ? 0.17 : 0.32))
                    .frame(width: Self.foxSize * 0.64, height: Self.foxSize * 0.15)
                    .position(x: W * 0.5, y: H * Self.patchBaseY - Self.foxSize * 0.03)

                // The meditating fox — small, seated on the grass clearing. Its
                // base sits ~0.89 down its own frame, so it's offset up from the
                // patch line to land the seat on the grass.
                LoopingVideoView(resource: "LockInFox")
                    .frame(width: Self.foxSize, height: Self.foxSize)
                    .position(x: W * 0.5, y: H * Self.patchBaseY - Self.foxSize * 0.39)

                // The stop button stays pinned to the bottom.
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    stopButton.padding(.bottom, Theme.Spacing.l)
                }
            }
            .frame(width: W, height: H)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { LockInBackground() }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.35)) {
                isChromeVisible.toggle()
            }
        }
        .onAppear { startTimer() }
        .onDisappear { timer?.invalidate() }
        // Coming back from the background: re-read the clock straight away
        // rather than waiting up to a second for the next tick.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { tick() }
        }
        .sheet(isPresented: $showLeaveConfirm) {
            LeaveFocusConfirmSheet(onConfirmLeave: endEarly)
        }
    }

    /// The countdown as a sticker numeral — the same outlined face as the Home
    /// streak count, sized to carry the screen on its own now that the progress
    /// ring is gone.
    private var countdown: some View {
        StrokedNumber(
            text: countdownLabel,
            font: Typography.displayUIFont(size: 76, weight: .black, tabular: true),
            // Day: white fill, dark outline. Night: black fill, white outline —
            // the same day/night treatment as the streak number and the Home timer.
            fill: HomeDaylight.isDay() ? .white : .black,
            stroke: HomeDaylight.isDay() ? UIColor(Theme.Color.background) : .white,
            outlineWidth: 5,
            tracking: 6
        )
        .fixedSize()
        .shadow(color: .black.opacity(0.4), radius: 3, y: 4)
    }

    /// The one control that ends the session: a white disc with a red stop
    /// square, centered at the bottom.
    private var stopButton: some View {
        Button {
            // Timed sessions confirm before forfeiting; an untimed (Extreme Focus)
            // session has no "early" — stopping finishes it, banking the
            // minutes focused so far.
            if untimed { complete() } else { showLeaveConfirm = true }
        } label: {
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 84, height: 84)
                RoundedRectangle(cornerRadius: Theme.Radius.micro, style: .continuous)
                    .fill(Theme.Color.signalWarning)
                    .frame(width: 30, height: 30)
            }
            // Lifts the disc off the backdrop — it'll be carrying a photo
            // background before long, where a flat white circle would sit dead
            // on the image.
            .shadow(color: .black.opacity(0.28), radius: 14, y: 6)
        }
        .buttonStyle(PressBounceStyle())
        .offset(y: isChromeVisible ? 0 : 140)
        .opacity(isChromeVisible ? 1 : 0)
        .allowsHitTesting(isChromeVisible)
    }

    private func startTimer() {
        timer?.invalidate()
        // Resuming, not starting, when the store already has one: coming back
        // to a session that outlived this screen must not restart its clock.
        if store.activeFocusSession == nil {
            store.startFocusSession(lengthMinutes: config.lengthMinutes,
                                    isUntimed: untimed,
                                    earnRate: config.earnRate)
        }
        now = .now
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            tick()
        }
    }

    /// Moves the clock and checks for the end. Nothing counts itself down —
    /// both labels are derived from `now`, so a spell in the background
    /// corrects itself the moment this runs again.
    /// Moves the on-screen clock, and notices when the store has settled the
    /// session — which it may have done while this screen wasn't on top.
    private func tick() {
        now = .now
        guard let payout = store.focusSessionPayout else { return }
        timer?.invalidate()
        store.clearFocusSessionPayout()
        onComplete(DeepFocusSession(durationMinutes: config.lengthMinutes,
                                    earnedMinutes: payout, date: .now))
    }

    /// The stop button on an untimed session: it has no "early", so stopping is
    /// finishing, and the minutes sat through get banked.
    private func complete() {
        timer?.invalidate()
        let elapsed = elapsedSeconds
        let earned = store.finishFocusSession(banking: true)
        onComplete(DeepFocusSession(durationMinutes: elapsed / 60,
                                    earnedMinutes: earned, date: .now))
    }

    private func endEarly() {
        timer?.invalidate()
        store.finishFocusSession(banking: false)
        onEndEarly()
    }
}

/// The lock-in timer's field — a full-bleed illustration, aspect-filled over
/// black. Swaps between a Day and Night variant on the user's local time, using
/// the same `HomeDaylight` boundary as Home so the two screens are never in
/// disagreement about whether it's day. Re-checked each minute so it flips on
/// its own at the boundary.
private struct LockInBackground: View {
    var body: some View {
        TimelineView(.everyMinute) { context in
            let asset = HomeDaylight.isDay(context.date) ? "Lock In_Day View" : "Lock In_Night View"
            Color.black
                .overlay(
                    Image(asset)
                        .resizable()
                        .scaledToFill()
                )
                .ignoresSafeArea()
        }
    }
}

#Preview {
    FocusTimerActiveView(config: DeepFocusConfig(), onEndEarly: {}, onComplete: { _ in })
        .environment(HabitStore())
        .preferredColorScheme(.dark)
}
