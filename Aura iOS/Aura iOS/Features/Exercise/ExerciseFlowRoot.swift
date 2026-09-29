//
//  ExerciseFlowRoot.swift
//  Aura iOS
//

import SwiftUI

/// Owns which of the Exercise flow's screens is showing — a plain in-place
/// content swap (not push/pop), mirroring `DeepFocusFlowRoot`. Presented as a
/// `fullScreenCover` from the FAB's Exercise row. Finishing an exercise grants
/// the earned screen time and dismisses back to the Home (Gate) screen — the
/// earned-reward display on Home is a separate, later pass.
struct ExerciseFlowRoot: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// When launched from the habit picker, jump straight to this exercise's
    /// camera (skipping the select screen).
    var startExercise: Exercise? = nil

    private enum Stage {
        case select
        case camera(Exercise)
        case success(Exercise, Int, Int)
        case streak
    }

    @State private var stage: Stage = .select
    @State private var didApplyStart = false
    @State private var didFinish = false
    @State private var didClaim = false

    var body: some View {
        Group {
            switch stage {
            case .select:
                ExerciseSelectView(
                    onStart: { exercise in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            stage = .camera(exercise)
                        }
                    },
                    onClose: { dismiss() }
                )
            case .camera(let exercise):
                ExerciseCameraView(
                    exercise: exercise,
                    onClose: { dismiss() },
                    onFinish: { reps, earnedMinutes in
                        guard !didFinish else { return }
                        didFinish = true
                        // Nothing earned means nothing to celebrate. Finishing a
                        // set short of the threshold is a real thing to do and
                        // it shouldn't be met with a party.
                        guard earnedMinutes > 0 else {
                            store.addExerciseSession(earnedMinutes: 0, reps: reps)
                            Haptics.notify(.error)
                            dismiss()
                            return
                        }
                        // Logged before the success screen so its ranking counts
                        // this set.
                        store.recordExerciseDone(exercise)
                        withAnimation(.easeInOut(duration: 0.25)) {
                            stage = .success(exercise, reps, earnedMinutes)
                        }
                    }
                )
            case .success(let exercise, let reps, let earned):
                ExerciseSuccessView(exercise: exercise, reps: reps, coins: earned) {
                    guard !didClaim else { return }
                    didClaim = true
                    store.addExerciseSession(earnedMinutes: earned, reps: reps)
                    if store.completeHabitToday() {
                        withAnimation(.easeInOut(duration: 0.25)) { stage = .streak }
                    } else {
                        dismiss()
                    }
                }
            case .streak:
                // Paid by `addExerciseSession` above, before this screen
                // exists. Same as Lock In: the button only closes, and there is
                // nothing left to footnote.
                StreakCelebrationView(
                    currentStreak: store.streak.currentStreak,
                    buttonTitle: "Let's go!",
                    onButton: { dismiss() }
                )
            }
        }
        .onAppear {
            if let startExercise, !didApplyStart {
                didApplyStart = true
                stage = .camera(startExercise)
            }
        }
    }
}

#Preview {
    ExerciseFlowRoot()
        .environment(HabitStore())
        .preferredColorScheme(.dark)
}
