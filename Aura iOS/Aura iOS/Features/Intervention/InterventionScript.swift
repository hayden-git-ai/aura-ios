//
//  InterventionScript.swift
//  Aura iOS
//

import Foundation

/// Everything the fox says during one intervention, in one place.
///
/// A whole script is chosen when the intervention opens, not a line at a time.
/// Rotating per beat would have the fox change its manner of speaking halfway
/// through the same conversation.
struct InterventionScript {
    /// `%@` is the app that was opened.
    let challengeWithApp: String
    /// Used until the shield extension can tell us which app it was.
    let challengeGeneric: String
    let decline: String
    let accept: String

    let backedOut: String

    let howLong: String
    let nevermind: String

    /// `%d` is the price in coins.
    let pay: String
    let holdIdle: String
    let holdHolding: String
    let holdDone: String

    /// `%d` is the minutes bought.
    let paid: String

    let broke: String

    func challenge(app: String?) -> String {
        guard let app else { return challengeGeneric }
        return String(format: challengeWithApp, app)
    }

    func pay(coins: Int) -> String { String(format: pay, coins) }
    func holdIdle(coins: Int) -> String { String(format: holdIdle, coins) }
    func paid(minutes: Int) -> String { String(format: paid, minutes) }

    static let all: [InterventionScript] = [
        // The fox is dry and a little guilt-trippy: it acts hurt when you cave,
        // so the words match the slumped/crying animations. Lowercase on purpose,
        // so it reads spoken rather than corporate. Each line is written for the
        // pose it plays on (challenge = thinking, back-out = shades, how-long =
        // arms-crossed, pay = slumped, paid = crying).
        InterventionScript(
            challengeWithApp: "hey. you actually need %@ right now?",
            challengeGeneric: "hey. you actually need this right now?",
            decline: "nah, you're right",
            accept: "yeah, i do",
            backedOut: "good. that one's a win for us.",
            howLong: "ugh, fine. how long?",
            nevermind: "nah, actually nevermind",
            pay: "that's %d coins. this better be worth it.",
            holdIdle: "hold to pay %d",
            holdHolding: "keep holding…",
            holdDone: "sent",
            paid: "ow. %d minutes. i'll feel every one of those.",
            broke: "you're broke. go earn some coins and come back."
        ),
        InterventionScript(
            challengeWithApp: "be real. you need %@, or you're just bored?",
            challengeGeneric: "be real. you need this, or you're just bored?",
            decline: "nah, you're right",
            accept: "yeah, i do",
            backedOut: "see, that wasn't so hard. staying locked.",
            howLong: "of course you do. how long we talking?",
            nevermind: "nah, actually nevermind",
            pay: "%d coins. don't say i didn't warn you.",
            holdIdle: "hold to pay %d",
            holdHolding: "keep holding…",
            holdDone: "sent",
            paid: "fine. %d minutes. i'll just sit here then.",
            broke: "you're flat broke. come back when you've earned some coins."
        ),
        InterventionScript(
            challengeWithApp: "%@ again? c'mon. you actually need it?",
            challengeGeneric: "this again? c'mon. you actually need it?",
            decline: "nah, you're right",
            accept: "yeah, i do",
            backedOut: "good. i knew you had it in you.",
            howLong: "wow, okay. how long?",
            nevermind: "nah, actually nevermind",
            pay: "alright, %d coins. don't come crying to me.",
            holdIdle: "hold to pay %d",
            holdHolding: "keep holding…",
            holdDone: "sent",
            paid: "%d minutes... try not to enjoy it too much.",
            broke: "you've got zero coins. go earn some first."
        ),
    ]

    static var random: InterventionScript { all.randomElement() ?? all[0] }
}
