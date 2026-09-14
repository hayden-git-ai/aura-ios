//
//  PhotoProofFlowRoot.swift
//  Aura iOS
//

import SwiftUI

/// Owns the Photo Proof flow's screens — a plain in-place content swap
/// (mirroring the Deep Focus / Exercise flow roots). Presented as a
/// `fullScreenCover` from the FAB's Photo Proof row. On a verified photo it
/// starts a Home-screen habit timer (`HabitStore.startHabitSession`) that
/// grants the habit's reward when it ends; the streak celebration only shows on
/// the first completed habit of the day.
struct PhotoProofFlowRoot: View {
    /// When launched from the habit picker, jump straight to the camera for
    /// this habit (skipping the standalone setup screen).
    var startHabit: Habit? = nil
    /// Session length chosen in the habit's session sheet; falls back to the
    /// habit's default when launched instantly.
    var startMinutes: Int? = nil

    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// No retry stage: a failed photo never leaves the camera. The verdict and
    /// the retake both happen on the frozen frame inside `PhotoProofCameraView`,
    /// which is where the photo is.
    ///
    /// A pass does leave, because the celebration is about the person rather
    /// than the picture. On the first habit of the day it leads into the streak
    /// screen, so that run shows two screens back to back: this photo worked,
    /// and then the streak it kept alive. They say different things.
    private enum Stage {
        case select
        case camera(Habit, Int)
        /// Carries the frame so the win can still be filed when the user
        /// acknowledges. Not the verifier's sentence: on a pass it only ever
        /// restates the habit's own tip, and the screen says something better.
        case success(Habit, Int, UIImage?)
        case streak(Habit, Int)
    }

    @State private var stage: Stage = .select
    @State private var didApplyStart = false

    var body: some View {
        Group {
            switch stage {
            case .select:
                PhotoProofSetupView(
                    onStart: { habit, minutes in
                        withAnimation(.easeInOut(duration: 0.25)) { stage = .camera(habit, minutes) }
                    },
                    onClose: { dismiss() }
                )
            case .camera(let habit, let minutes):
                PhotoProofCameraView(
                    habit: habit,
                    minutes: minutes,
                    onClose: { dismiss() },
                    onPassed: { _, image in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            stage = .success(habit, minutes, image)
                        }
                    }
                )
            case .success(let habit, let minutes, let image):
                ProofSuccessView(
                    habit: habit,
                    minutes: minutes,
                    onContinue: { handlePass(habit: habit, minutes: minutes, image: image) }
                )
            case .streak(let habit, let minutes):
                StreakCelebrationView(
                    currentStreak: store.streak.currentStreak,
                    // A quick habit's coins land when this is tapped, but the
                    // success screen a moment ago already showed the number on
                    // its own card, so the button doesn't have to announce it.
                    // That leaves "Start Habit Timer" as the only label in the
                    // app that names an action, which is right: it's the only
                    // one where something still has to happen.
                    buttonTitle: habit.requiresFocusSession ? "Start Habit Timer" : "Let's go!",
                    // The only footnote left in the app. A focus habit is the
                    // one case where the button does something whose result
                    // isn't visible yet, so it's the one case worth a line of
                    // explanation. Everywhere else the coins have landed and
                    // saying so is words under a button.
                    footnote: habit.requiresFocusSession
                        ? "Your apps will unlock once the timer ends."
                        : nil,
                    onButton: { startAndDismiss(habit: habit, minutes: minutes) }
                )
            }
        }
        .onAppear {
            if let startHabit, !didApplyStart {
                didApplyStart = true
                stage = .camera(startHabit, startMinutes ?? startHabit.defaultFocusMinutes)
            }
        }
    }

    private func handlePass(habit: Habit, minutes: Int, image: UIImage?) {
        // Filed before anything else: the wall is the record that this happened,
        // and the frame only exists until this view goes away.
        if let image {
            store.addWin(image: image,
                         habit: habit.name,
                         icon: habit.iconAsset ?? habit.category.tileIconAsset)
        }
        // A focus habit isn't done yet — the photo bought the right to start a
        // timer. The day, and the streak, are booked when that timer ends, in
        // `HabitStore.tick`. Only a quick habit is finished right here.
        guard !habit.requiresFocusSession else {
            startAndDismiss(habit: habit, minutes: minutes)
            return
        }
        var firstToday = store.completeHabitToday(habit: habit)
        #if DEBUG
        // `-streak` forces the celebration through. It only fires on the day's
        // first habit, so once one has been logged the screen is unreachable
        // until tomorrow, which makes it impossible to iterate on.
        if ProcessInfo.processInfo.arguments.contains("-streak") { firstToday = true }
        #endif
        if firstToday {
            withAnimation(.easeInOut(duration: 0.25)) { stage = .streak(habit, minutes) }
        } else {
            startAndDismiss(habit: habit, minutes: minutes)
        }
    }

    private func startAndDismiss(habit: Habit, minutes: Int) {
        if habit.requiresFocusSession {
            // Focus habit: start the home-screen timer that grants length ×
            // rate when it ends.
            let reward = Int((Double(minutes) * habit.rewardRate / 60).rounded())
            store.startHabitSession(habitName: habit.name, habitId: habit.id, rewardMinutes: reward,
                                    sessionMinutes: minutes, method: habit.category)
        } else {
            // Quick habit: snap once, reward granted instantly — no timer.
            store.grantScreenTime(minutes: habit.rewardMinutes, method: habit.category)
        }
        dismiss()
    }
}
