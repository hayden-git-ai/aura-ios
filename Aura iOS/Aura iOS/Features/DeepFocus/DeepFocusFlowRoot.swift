//
//  DeepFocusFlowRoot.swift
//  Aura iOS
//

import SwiftUI

/// The active half of the Deep Focus flow — the running timer, then the streak
/// celebration. Selection now happens upstream in `FocusTimerSetupView` (a
/// sheet); this is presented as a `fullScreenCover` once the user commits, so
/// it starts already running with the chosen `config`. A session that finishes
/// naturally is logged and the whole flow dismisses immediately.
struct DeepFocusFlowRoot: View {
    /// The committed setup, carried in from the selection sheet.
    let config: DeepFocusConfig

    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private enum Stage {
        case active(DeepFocusConfig)
        case success(DeepFocusSession)
        case streak
    }

    @State private var stage: Stage

    init(config: DeepFocusConfig) {
        self.config = config
        _stage = State(initialValue: .active(config))
    }

    var body: some View {
        Group {
            switch stage {
            case .active(let config):
                FocusTimerActiveView(
                    config: config,
                    onEndEarly: { dismiss() },
                    onComplete: { session in
                        // Already logged and paid by the store, which settles
                        // the session whether or not this screen is up. Nothing
                        // earned means nothing to celebrate.
                        guard session.earnedMinutes > 0 else { dismiss(); return }
                        withAnimation(.easeInOut(duration: 0.25)) { stage = .success(session) }
                    }
                )
                .preferredColorScheme(.dark)
            case .success(let session):
                FocusSuccessView(session: session) {
                    if store.completeHabitToday() {
                        withAnimation(.easeInOut(duration: 0.25)) { stage = .streak }
                    } else {
                        dismiss()
                    }
                }
            case .streak:
                // "Let's go!", not "Done". The session was settled and paid
                // before this screen opened, so the button has nothing to do
                // but close, and "Done" is the label on a settings sheet.
                //
                // No footnote. The two that carry one on Photo Proof are
                // telling you something you'd otherwise have to guess at (the
                // timer has to run first, or the coins landed instantly).
                // Here there is nothing left to explain.
                StreakCelebrationView(
                    currentStreak: store.streak.currentStreak,
                    buttonTitle: "Let's go!",
                    onButton: { dismiss() }
                )
            }
        }
    }
}

#Preview {
    DeepFocusFlowRoot(config: DeepFocusConfig())
        .environment(HabitStore())
        .preferredColorScheme(.dark)
}
