//
//  ProofSuccessView.swift
//  Aura iOS
//

import SwiftUI

/// The photo passed.
///
/// A full white screen rather than a panel over the shot, because the moment
/// belongs to the person and not to the evidence. It's also the only shape with
/// room for the fox to react, and a mascot that never reacts to anything is
/// just a logo.
///
/// Terminal by design: no back, no close. There is one thing to do from here
/// and the button does it.
struct ProofSuccessView: View {
    let habit: Habit
    /// Minutes chosen for the session, for what a focus habit is going to pay.
    let minutes: Int
    var onContinue: () -> Void

    @Environment(HabitStore.self) private var store
    /// Picked once when the screen appears, so it can't change under the user
    /// mid-animation. Same reason `InterventionScript` picks a whole script up
    /// front rather than a line at a time.
    @State private var script = ProofSuccessScript.random

    /// What this run is worth. A focus habit earns its rate across the session
    /// it's about to start; a quick habit earns flat, right now.
    private var payout: Int {
        habit.requiresFocusSession
            ? Int((Double(minutes) * habit.rewardRate / 60).rounded())
            : habit.rewardMinutes
    }

    var body: some View {
        SunburstSuccessView(
            iconCentre: 0.26,
            artHalfHeight: 124,
            art: { SuccessCelebrationArt() },
            title: script.title,
            blurb: script.line(focus: habit.requiresFocusSession),
            // Only a quick habit has actually earned anything by now.
            coins: habit.requiresFocusSession ? nil : payout,
            method: habit.category,
            ctaTitle: habit.requiresFocusSession ? "Start Habit Timer" : "Claim Reward",
            // Restored: a focus habit hasn't been paid yet, so name what the
            // timer will pay under the button.
            footnote: habit.requiresFocusSession
                ? "You will earn \(payout) coins once the timer ends"
                : nil,
            detail: AnyView(detail),
            onContinue: onContinue
        )
    }

    @ViewBuilder
    private var habitCompletionIcon: some View {
        if let asset = habit.iconAsset {
            EarnTileIcon(asset: asset)
        } else {
            // Legacy/custom habits without a sticker retain their own symbol;
            // the verification method's camera does not identify the habit.
            Image(systemName: habit.iconSystemName)
                .resizable()
                .scaledToFit()
                .frame(height: 32)
                .frame(width: 40, height: 40)
                .foregroundStyle(.white)
        }
    }

    /// Times done, the reward, and the streak — plus the all-time habit ranking,
    /// matching the other screens.
    private var detail: some View {
        let rank = store.habitRank(habit)
        return VStack(spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.s) {
                // The habit's own sticker and its all-time completion count.
                EarnStatTile(icon: { habitCompletionIcon },
                             value: "\(store.timesDone(habit))", label: "Times done")
                EarnStatTile(icon: { EarnTileIcon(asset: "EarnCardIcon") },
                             value: "+\(payout)", label: "Coins earned")
                EarnStatTile(icon: { EarnTileIcon(asset: "StreakFlame") },
                             value: "\(store.streak.currentStreak)", label: "Day streak")
            }
            .fixedSize(horizontal: false, vertical: true)

            EarnHighlightCard(icon: { EarnHighlightGem() },
                              text: earnRankHighlight(rank: rank.rank, total: rank.total, noun: "habit"))
        }
    }
}

/// What the fox says when a photo passes.
///
/// The verifier's own sentence used to sit here, and it was the wrong content:
/// "book open in frame, clearly readable" is the tip card read back to you.
/// Confirming what you already know is not a reward. What belongs here is the
/// fox reacting and then pointing at what happens next.
///
/// Written as the payoff to the doubt. The fox in `InterventionScript` opens
/// with "Be real with me…" and "Do you actually need this right now?", so the
/// natural thing for it to say when you prove something is that it's convinced,
/// and it should sound like it cost the fox something to admit.
///
/// A set rather than one line, and picked whole rather than per-field, for the
/// same reasons the intervention scripts are: a line you see every single day
/// stops landing, and a fox that swaps its manner of speaking halfway through a
/// screen isn't a character.
///
/// The register is a friend who's actually pleased for you and makes a joke
/// about it anyway. Warmth first, joke second, and never at their expense.
///
/// Two wrong versions came before this one and both are worth naming. "Proof
/// accepted" and "the hard bit starts now" were a form and a coach, neither of
/// which is a person. Then "oh you're serious" and "you earned them, I guess"
/// overcorrected into someone who doesn't like you much. Sarcasm from a friend
/// lands because the affection under it is not in question; the same line from
/// a stranger is just rude, and an app is a stranger until it proves otherwise.
///
/// No slang doing the heavy lifting. Brand-mouth slang is the cringe, and it
/// ages in months. What carries these is timing and naming the actual thing:
/// "I'll hold your apps" and "enjoy the scroll, you earned it" are funny
/// because they're literally true of what the app is about to do.
struct ProofSuccessScript {
    let title: String
    /// A focus habit has a timer still to run. The photo bought the right to
    /// start, not the reward.
    let focusLine: String
    /// A quick habit is already paid by the time this shows.
    let quickLine: String

    func line(focus: Bool) -> String { focus ? focusLine : quickLine }

    static let all: [ProofSuccessScript] = [
        ProofSuccessScript(
            title: "well, look at you.",
            focusLine: "go do your thing, i'll be right here.",
            quickLine: "there you go. that's a win for both of us."
        ),
        ProofSuccessScript(
            title: "knew you had it in you.",
            focusLine: "the timer's up next, so keep your eyes off that phone.",
            quickLine: "the coins are all yours. go on and enjoy them."
        ),
        ProofSuccessScript(
            title: "wow, ok, you did it.",
            focusLine: "now comes the boring part. the timer starts next.",
            quickLine: "here's your coins, don't spend them all at once."
        ),
        ProofSuccessScript(
            title: "fine, i'm impressed.",
            focusLine: "start the timer whenever you're ready for it.",
            quickLine: "go buy yourself some screen time, you earned it."
        ),
    ]

    static var random: ProofSuccessScript { all.randomElement() ?? all[0] }
}
