//
//  FocusSuccessView.swift
//  Aura iOS
//

import SwiftUI

/// The session is over.
///
/// The other three methods end on a number, because that's the whole of what
/// happened: you took a photo, you did some reps, your steps added up. A focus
/// session has a shape as well as a size, and the shape is the interesting part.
/// How long you went, when you went, and whether that was a lot for you are
/// three different facts and none of them fit on a button.
///
/// Unlike the other three success screens, this one gets the streak screen's
/// treatment: the rotating sunburst (in a light purple, the focus hue's answer
/// to the streak's peach) with the same progressive blur, and the padlock icon
/// sitting where the streak fox does with the rays fanning out from behind it.
/// The three tiles and the highlight then sit under the copy, over the field.
struct FocusSuccessView: View {
    let session: DeepFocusSession
    var onContinue: () -> Void

    @Environment(HabitStore.self) private var store
    @State private var script = FocusSuccessScript.random

    /// The light-purple answer to the streak sunburst's peach.
    private static let rayLighter = Color(hex: "EAE3FB")
    private static let rayDarker = Color(hex: "D5C9F5")

    var body: some View {
        SunburstSuccessView(
            rayLighter: Self.rayLighter,
            rayDarker: Self.rayDarker,
            // Nudged up a touch from the fox's spot to leave room for the tiles.
            iconCentre: 0.26,
            artHalfHeight: 124,
            art: { SuccessCelebrationArt() },
            title: script.title,
            blurb: script.line(minutes: session.durationMinutes,
                               coins: session.earnedMinutes),
            coins: session.earnedMinutes,
            method: .focus,
            detail: AnyView(detail),
            onContinue: onContinue
        )
    }

    /// Lock In's three facts — the fullest of the four success screens — over the
    /// shared stat tiles and highlight card.
    private var detail: some View {
        VStack(spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.s) {
                // The Focus Length sticker from the Lock In setup sheet.
                EarnStatTile(icon: { EarnTileIcon(asset: "FoxLockInFocusLength") },
                             value: durationText, label: "Time focused")
                // The chest from Home's Quests card.
                EarnStatTile(icon: { EarnTileIcon(asset: "EarnCardIcon") },
                             value: "+\(session.earnedMinutes)", label: "Coins earned")
                EarnStatTile(icon: { EarnTileIcon(asset: "StreakFireIcon") },
                             value: "\(store.streak.currentStreak)", label: "Day streak")
            }
            .fixedSize(horizontal: false, vertical: true)

            EarnHighlightCard(icon: { EarnHighlightGem() }, text: highlight)
        }
    }

    // MARK: - The three facts

    private var durationText: String { Self.duration(session.durationMinutes) }

    private static func duration(_ m: Int) -> String {
        guard m >= 60 else { return "\(m)m" }
        let h = m / 60, rest = m % 60
        return rest == 0 ? "\(h)h" : "\(h)h \(rest)m"
    }

    /// Where this session ranks, or failing that, how many there have been.
    ///
    /// Always something, so the row never disappears and the screen doesn't
    /// change height depending on how good you were. It used to return nil past
    /// fifth, which kept the copy honest and made the layout jump.
    ///
    /// The fallback is a count rather than a worse rank. "Your 34th longest
    /// session" is a true sentence that reads as an insult; "34 sessions and
    /// counting" is the same fact pointed the other way.
    private var highlight: String {
        let longer = store.deepFocusSessions
            .filter { $0.id != session.id && $0.durationMinutes > session.durationMinutes }
            .count
        switch longer {
        case 0: return "Your longest session ever"
        case 1: return "Your 2nd longest session of all time"
        case 2: return "Your 3rd longest session of all time"
        case 3...4: return "Your \(longer + 1)th longest session of all time"
        default: return "\(max(store.deepFocusSessions.count, 1)) sessions and counting"
        }
    }
}

/// What the fox says when a session ends.
///
/// Same register as the others, aimed at the one thing that actually happened
/// here: the phone sat there and nobody picked it up. The joke is always about
/// the not-touching, because that's the whole product.
struct FocusSuccessScript {
    let title: String
    /// Minutes and coins, so a line can name either or neither.
    let body: (Int, Int) -> String

    func line(minutes: Int, coins: Int) -> String { body(minutes, coins) }

    static let all: [FocusSuccessScript] = [
        FocusSuccessScript(title: "the phone survived.",
                           body: { _, _ in "and so did you, which is the impressive part." }),
        FocusSuccessScript(title: "look at that.",
                           body: { m, _ in "\(m) whole minutes and you didn't touch it once." }),
        FocusSuccessScript(title: "who taught you that?",
                           body: { m, _ in "\(m) minutes and not one peek at your phone." }),
        FocusSuccessScript(title: "fine, i'm impressed.",
                           body: { m, c in "\(m) minutes for \(c) coins. worth it, right?" }),
    ]

    static var random: FocusSuccessScript { all.randomElement() ?? all[0] }
}
