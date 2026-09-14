//
//  ExerciseSuccessView.swift
//  Aura iOS
//

import SwiftUI

/// The set is done and it paid.
///
/// `ProofSuccessView`'s twin, down to the spacer weighting and the payout card,
/// so finishing a set and passing a photo land the same way. Camera Reps used
/// to go straight from the viewfinder to the streak screen (or to nothing at
/// all, on the second habit of a day), which meant the one method where you
/// actually broke a sweat was the one with no moment at the end of it.
///
/// Terminal by design: no back, no close. There is one thing to do from here.
struct ExerciseSuccessView: View {
    let exercise: Exercise
    let reps: Int
    let coins: Int
    var onContinue: () -> Void

    @Environment(HabitStore.self) private var store
    /// Picked once on appear so it can't change under the user mid-animation.
    @State private var script = ExerciseSuccessScript.random

    /// The light-orange answer to the streak sunburst's peach — Camera Reps' own
    /// hue, matching what Lock In does in purple.
    private static let rayLighter = Color(hex: "FFE7C8")
    private static let rayDarker = Color(hex: "FFD29B")

    var body: some View {
        SunburstSuccessView(
            rayLighter: Self.rayLighter,
            rayDarker: Self.rayDarker,
            // Same as the other success screens now that they all carry a detail.
            iconCentre: 0.26,
            artHalfHeight: 124,
            art: { SuccessCelebrationArt() },
            title: script.title,
            blurb: script.line(reps: reps, coins: coins, exercise: exercise),
            coins: coins,
            method: .exercise,
            detail: AnyView(detail),
            onContinue: onContinue
        )
    }

    /// Three facts, like Lock In: what you did, what it paid, and the streak,
    /// plus this exercise's all-time ranking.
    private var detail: some View {
        let rank = store.exerciseRank(exercise)
        return VStack(spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.s) {
                // The dumbbell sticker "Hit the gym" wears.
                EarnStatTile(icon: { EarnTileIcon(asset: "FoxHabitGym") },
                             value: "\(reps)", label: "Reps done")
                EarnStatTile(icon: { EarnTileIcon(asset: "EarnCardIcon") },
                             value: "+\(coins)", label: "Coins earned")
                EarnStatTile(icon: { EarnTileIcon(asset: "StreakFireIcon") },
                             value: "\(store.streak.currentStreak)", label: "Day streak")
            }
            .fixedSize(horizontal: false, vertical: true)

            EarnHighlightCard(icon: { EarnHighlightGem() },
                              text: earnRankHighlight(rank: rank.rank, total: rank.total, noun: "exercise"))
        }
    }
}

/// What the fox says when a set is done.
///
/// The same register as `ProofSuccessScript`: a friend who's pleased for you and
/// makes a joke about it anyway. Warmth first, joke second, never at their
/// expense.
///
/// These get to be a shade more impressed than the photo ones. Passing a photo
/// proves you started something; finishing a set means you actually did it, and
/// the fox should sound like it noticed the difference.
struct ExerciseSuccessScript {
    let title: String
    /// Takes the counts so the fox can say the numbers back. "You did 12"
    /// lands where "nice work" doesn't, because only one of them proves it
    /// watched.
    let body: (Int, Int, Exercise) -> String

    func line(reps: Int, coins: Int, exercise: Exercise) -> String {
        body(reps, coins, exercise)
    }

    static let all: [ExerciseSuccessScript] = [
        ExerciseSuccessScript(
            title: "ok, that's a real set.",
            body: { reps, _, ex in "\(reps) \(ex.unitNoun(for: reps)), and i counted every one of them." }
        ),
        ExerciseSuccessScript(
            title: "look at you go.",
            body: { reps, _, ex in "\(reps) of them. you're showing off now." }
        ),
        ExerciseSuccessScript(
            title: "alright, respect.",
            body: { reps, _, ex in "\(reps) \(ex.unitNoun(for: reps)) is more than most people would do." }
        ),
        ExerciseSuccessScript(
            title: "ok, who are you?",
            body: { reps, _, ex in "\(reps) \(ex.unitNoun(for: reps)) done, and the coins are yours." }
        ),
    ]

    static var random: ExerciseSuccessScript { all.randomElement() ?? all[0] }
}
