//
//  ExerciseModels.swift
//  Aura iOS
//

import Foundation

/// How hard an exercise is, which also picks its gem icon. Fox art per exercise
/// proved too costly to draw, so the whole method now leans on two shared gems
/// (emerald / diamond) keyed off the Easy / Hard split.
enum ExerciseDifficulty: String, CaseIterable, Hashable {
    case easy, medium, hard

    var label: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }

    /// Sort order for the list: easy at the top, hard at the bottom.
    var rank: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    /// Medium is retained for stored-data compatibility but now belongs to the
    /// Hard presentation and uses the same diamond sticker.
    var iconAsset: String {
        switch self {
        case .easy: return "CameraRepsEasy"
        case .medium: return "CameraRepsHard"
        case .hard: return "CameraRepsHard"
        }
    }
}

/// One camera-verified exercise the user can perform to earn screen time.
/// The earn *rate* (minutes per rep / per held second) is user-editable and
/// lives in `HabitStore` — this type only carries the defaults and the small
/// threshold before earning kicks in (the video's "5 reps to start earning").
struct Exercise: Identifiable, Hashable {
    /// Stable key used to persist the user's edited rate in the store.
    let id: String
    let name: String
    let iconSystemName: String
    /// Difficulty tier — drives both the gem icon and the picker's filter tabs.
    let difficulty: ExerciseDifficulty
    /// Reps required before any minutes are earned.
    let unitsToStartEarning: Int
    /// Coins earned per rep. One flat coin across the board; user-editable.
    let defaultMinutesPerUnit: Double
    /// How to set up and perform it, shown on the exercise's own screen. The
    /// counter only sees what the camera sees, so framing is half the advice.
    let formTip: String

    /// Gem icon for this exercise, keyed off its difficulty tier.
    var iconAsset: String { difficulty.iconAsset }

    /// Singular noun for the thing being counted.
    var unitNoun: String { "rep" }

    /// The unit, agreeing with a count. One place rather than a ternary at
    /// every call site, which is how "1 reps" gets shipped.
    func unitNoun(for count: Int) -> String {
        count == 1 ? unitNoun : unitNoun + "s"
    }

    /// Minutes earned for `units` performed at the given rate — nothing until
    /// the goal is reached, then `units × rate` (no cap). Rounded to the
    /// nearest whole minute for display/grant. `goal` overrides the built-in
    /// `unitsToStartEarning` default when the user has set their own target.
    func earnedMinutes(forUnits units: Int, rate: Double, goal: Int? = nil) -> Int {
        let threshold = goal ?? unitsToStartEarning
        guard units >= threshold else { return 0 }
        return max(0, Int((Double(units) * rate).rounded()))
    }

    /// Human-readable goal value.
    static func goalDisplay(_ value: Int) -> String {
        "\(value) \(value == 1 ? "rep" : "reps")"
    }

    static let all: [Exercise] = [
        Exercise(id: "pushups", name: "Push-ups", iconSystemName: "figure.strengthtraining.traditional", difficulty: .hard, unitsToStartEarning: 5, defaultMinutesPerUnit: 1.0, formTip: "Phone on the floor a few feet away. I need your head and hips in frame."),
        Exercise(id: "squats", name: "Squats", iconSystemName: "figure.cross.training", difficulty: .easy, unitsToStartEarning: 5, defaultMinutesPerUnit: 1.0, formTip: "Back up till you fit. A rep lands when you stand up."),
        Exercise(id: "situps", name: "Sit-ups", iconSystemName: "figure.core.training", difficulty: .hard, unitsToStartEarning: 5, defaultMinutesPerUnit: 1.0, formTip: "Phone on the floor beside you, tilted up. Shoulders and knees in frame."),
        Exercise(id: "jumpingjacks", name: "Jumping Jacks", iconSystemName: "figure.mixed.cardio", difficulty: .easy, unitsToStartEarning: 10, defaultMinutesPerUnit: 1.0, formTip: "Back up further than feels necessary. Arms have to stay in frame."),
        Exercise(id: "lunges", name: "Lunges", iconSystemName: "figure.strengthtraining.functional", difficulty: .hard, unitsToStartEarning: 5, defaultMinutesPerUnit: 1.0, formTip: "A few steps back. Both legs stay in frame the whole way down."),
    ]
}
