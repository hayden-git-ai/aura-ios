//
//  QuestExplainers.swift
//  Aura iOS
//

import SwiftUI

/// The words for every "how this works" sheet, in one place.
///
/// Copy separated from the sheet that draws it, so rewriting a line means
/// editing this file rather than hunting through four screens — and so the four
/// quests are written next to each other, where an inconsistency between them
/// is visible.
struct Explainer {
    let title: String
    let subtitle: String
    /// Blocking keeps its existing explainer art; Earn and camera sheets omit it.
    var hero: String? = nil
    let accent: Color
    let steps: [StepsExplainerSheet.Step]
    var footnote: String? = nil
}

enum QuestExplainer {
    /// The quest's own, so a `?` anywhere can find the right words from the
    /// category it already has.
    static func forCategory(_ category: HabitCategory) -> Explainer {
        switch category {
        case .photoTask: photoProof
        case .exercise: cameraReps
        case .focus: lockIn
        case .healthSync: passiveIncome
        }
    }

    static let coins = Explainer(
        title: "How Aura Coins Work",
        subtitle: "Earn minutes for the apps you want back.",
        accent: LightSheet.blue,
        steps: [
            StepsExplainerSheet.Step(
                title: "Earn coins by completing quests",
                copy: "Photo Proof, Camera Reps, Lock In and Passive Income quests all pay out in Aura coins."),
            StepsExplainerSheet.Step(
                title: "One coin = one minute of screentime",
                copy: "Every coin you earn is worth a minute of screentime."),
            StepsExplainerSheet.Step(
                title: "Spend coins in the Screentime Store",
                copy: "Buy as much time as you want with the coins you've collected."),
            StepsExplainerSheet.Step(
                title: "Your coin balance resets at midnight",
                copy: "Your balance resets every day, so make sure to spend them before they're gone."),
        ]
    )

    /// The three rules, in the order they appear on the screen. Every app you
    /// pick sits in exactly one of them, so "why is this blocked?" always has a
    /// single answer.
    static let blocking = Explainer(
        title: "How Blocking Works",
        subtitle: "Aura keeps distracting apps behind a simple rule.",
        hero: "FoxHowItWorks",
        accent: LightSheet.blue,
        steps: [
            StepsExplainerSheet.Step(
                title: "Forbidden",
                copy: "Apps you want gone for good. Nothing opens these, and only you can see this list."),
            StepsExplainerSheet.Step(
                title: "Distracting",
                copy: "Apps you earn back. They stay locked until you buy screen time with the coins you earn from completing quests."),
            StepsExplainerSheet.Step(
                title: "Productive",
                copy: "The apps that are good for you. Aura keeps these open and never blocks them."),
            StepsExplainerSheet.Step(
                title: "Time runs out, they lock again",
                copy: "When your screentime ends, Aura blocks the apps automatically. You don’t have to do anything."),
        ],
        footnote: "Apps not blocking properly? Reload Aura."
    )

    static let photoProof = Explainer(
        title: "How Healthy Habits Work",
        subtitle: "Show Aura you started, then earn coins.",
        accent: HabitCategory.photoTask.accent,
        steps: [
            StepsExplainerSheet.Step(
                title: "Pick a habit",
                copy: "Choose from the list, or create your own."),
            StepsExplainerSheet.Step(
                title: "Take a photo of yourself doing it",
                copy: "Aura checks that your photo matches the habit you chose."),
            StepsExplainerSheet.Step(
                title: "Quick habits pay right away",
                copy: "One photo gets you coins, once per day."),
            StepsExplainerSheet.Step(
                title: "Focus habits pay when the timer ends",
                copy: "Your apps stay locked while the timer runs. Longer sessions earn more coins."),
        ]
    )

    static let cameraReps = Explainer(
        title: "How Daily Exercises Work",
        subtitle: "Move in front of your camera and earn as you go.",
        accent: HabitCategory.exercise.accent,
        steps: [
            StepsExplainerSheet.Step(
                title: "Pick an exercise and a goal",
                copy: "Choose push-ups, squats, sit-ups, pull-ups, jumping jacks, or lunges."),
            StepsExplainerSheet.Step(
                title: "Prop your phone up so it can see you",
                copy: "The camera counts your reps as you go. Nothing gets recorded."),
            StepsExplainerSheet.Step(
                title: "Hit your goal",
                copy: "Your reps only start counting once you reach the number you set."),
            StepsExplainerSheet.Step(
                title: "Every rep after that earns coins",
                copy: "The more you do, the more coins you get."),
        ]
    )

    static let lockIn = Explainer(
        title: "How Deep Focus Works",
        subtitle: "Stay focused while Aura keeps your apps locked.",
        accent: HabitCategory.focus.accent,
        steps: [
            StepsExplainerSheet.Step(
                title: "Set how long you want to focus",
                copy: "Pick anything from 5 minutes to 4 hours."),
            StepsExplainerSheet.Step(
                title: "Your apps lock the moment you start",
                copy: "No photo needed. Just you and the timer."),
            StepsExplainerSheet.Step(
                title: "Stay off your phone",
                copy: "If you leave early, the session ends and you don't earn any Aura coins."),
            StepsExplainerSheet.Step(
                title: "Finish and the coins are yours",
                copy: "Earn coins the second the timer hits zero."),
        ]
    )

    static let passiveIncome = Explainer(
        title: "How Passive Income Works",
        subtitle: "Your everyday activity can earn coins too.",
        accent: HabitCategory.healthSync.accent,
        steps: [
            StepsExplainerSheet.Step(
                title: "Connect Apple Health",
                copy: "Aura only reads your activity. Nothing leaves your phone."),
            StepsExplainerSheet.Step(
                title: "Move like you normally would",
                copy: "Steps, workouts, mindful minutes, and calories all count."),
            StepsExplainerSheet.Step(
                title: "Collect what you've earned",
                copy: "Each type of activity pays at its own rate. Tap Collect to claim your coins."),
            StepsExplainerSheet.Step(
                title: "It keeps filling up",
                copy: "Anything you do after collecting shows up next time you check."),
        ],
        // Also under the metric list, but only when every metric reads zero —
        // someone missing one of five would never see it there.
        footnote: "Not seeing your activity? Check Aura's access in Settings → Privacy & Security → Health."
    )
}

/// The `?` that opens one.
///
/// Sits beside the close button on each quest's screen. Chrome, not a primary
/// action — someone who knows the quest should be able to ignore it.
struct ExplainerButton: View {
    let explainer: Explainer
    /// Dark screens need the light-on-dark treatment; the light sheets take the
    /// default.
    var onDark = false
    /// The blue field, which has its own disc — see `chromeOnBlue`.
    var onBlue = false
    /// A stronger disc than the presets, for chrome over a dark illustration.
    var discFill: Color? = nil
    /// Passed straight through to the sheet — a screen whose explainer also
    /// offers an action.
    var secondaryTitle: String?
    var secondaryAction: (() async -> Bool)?

    @State private var showing = false

    var body: some View {
        CircleIconButton(sticker: "FoxSettingsHelp",
                         fill: discFill ?? (onBlue ? LightSheet.chromeOnBlue
                             : onDark ? LightSheet.chromeOnCamera : LightSheet.chromeOnLight),
                         bounces: false) {
            showing = true
        }
        .sheet(isPresented: $showing) {
            StepsExplainerSheet(title: explainer.title, subtitle: explainer.subtitle, hero: explainer.hero,
                                steps: explainer.steps, accent: explainer.accent,
                                footnote: explainer.footnote,
                                secondaryTitle: secondaryTitle,
                                secondaryAction: secondaryAction)
        }
    }
}
