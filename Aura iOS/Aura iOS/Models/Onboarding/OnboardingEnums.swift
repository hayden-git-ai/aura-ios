//
//  OnboardingEnums.swift
//  Aura iOS
//
//  Enumerated answers collected during onboarding. rawValue = stable analytics
//  option id (never free-text copy). Display strings + personalization copy are
//  taken verbatim from the master implementation prompt (Screens 06–41).
//

import Foundation

// MARK: - Primary goal (Screen 06 → reflection Screen 07)

enum PrimaryGoal: String, Codable, CaseIterable, Identifiable {
    case time, focus, sleep, discipline, presence, stopScrolling
    var id: String { rawValue }

    var label: String {
        switch self {
        case .time:          return "My time"
        case .focus:         return "My focus"
        case .sleep:         return "My sleep"
        case .discipline:    return "My discipline"
        case .presence:      return "My presence with people"
        case .stopScrolling: return "I just need to stop scrolling"
        }
    }

    /// Screen 07 — one concise reflection per goal.
    var reflection: String {
        switch self {
        case .time:          return "You want your hours to feel like yours again."
        case .focus:         return "You want to finish a thought without reaching for your phone."
        case .sleep:         return "You want the day to end without one more scroll."
        case .discipline:    return "You want your actions to match what you said you'd do."
        case .presence:      return "You want to be where your life is actually happening."
        case .stopScrolling: return "You're tired of looking up and wondering where the time went."
        }
    }
}

// MARK: - Daily scrolling estimate (Screen 08 → reflection Screen 09)

enum ScreenTimeEstimate: String, Codable, CaseIterable, Identifiable {
    case under1, oneToTwo, twoToThree, threeToFour, fourToFive, fiveToSeven, sevenPlus, notSure
    var id: String { rawValue }

    var label: String {
        switch self {
        case .under1:      return "Under 1 hour"
        case .oneToTwo:    return "1 to 2 hours"
        case .twoToThree:  return "2 to 3 hours"
        case .threeToFour: return "3 to 4 hours"
        case .fourToFive:  return "4 to 5 hours"
        case .fiveToSeven: return "5 to 7 hours"
        case .sevenPlus:   return "7+ hours"
        case .notSure:     return "I'm not sure"
        }
    }

    /// Conservative midpoint hours for projections. `notSure` yields nil — no
    /// numeric projection until real Screen Time data is available.
    var midpointHours: Double? {
        switch self {
        case .under1:      return 0.5
        case .oneToTwo:    return 1.5
        case .twoToThree:  return 2.5
        case .threeToFour: return 3.5
        case .fourToFive:  return 4.5
        case .fiveToSeven: return 6.0
        case .sevenPlus:   return 7.5
        case .notSure:     return nil
        }
    }

    /// Screen 09 — reflection banded by hours.
    var reflection: String {
        switch midpointHours {
        case .none:
            return "We'll replace the guess with your real Screen Time in a minute."
        case .some(let h) where h < 3:
            return "It adds up faster than it feels."
        case .some(let h) where h < 5:
            return "That's a serious part of every waking day."
        default:
            return "That's almost a second job, with nothing to show for it."
        }
    }
}

// MARK: - Primary consequence (Screen 10 → reflection Screen 11)

enum PrimaryConsequence: String, Codable, CaseIterable, Identifiable {
    case loseHours, avoidTasks, cantFocus, scrollInsteadOfSleep, feelWorse, lessPresent, allOfIt
    var id: String { rawValue }

    var label: String {
        switch self {
        case .loseHours:            return "I lose hours without noticing"
        case .avoidTasks:           return "I avoid what I need to do"
        case .cantFocus:            return "I can't focus for long"
        case .scrollInsteadOfSleep: return "I scroll when I should be sleeping"
        case .feelWorse:            return "I feel worse afterward"
        case .lessPresent:          return "I'm less present with people"
        case .allOfIt:              return "Honestly, all of it"
        }
    }

    /// Screen 11 — direct reflection.
    var reflection: String {
        switch self {
        case .loseHours:            return "The worst part isn't the phone. It's realizing the day moved without you."
        case .avoidTasks:           return "Scrolling gives the task somewhere to hide."
        case .cantFocus:            return "Every check makes it harder to return to the thing that mattered."
        case .scrollInsteadOfSleep: return "The day ends, but the feed keeps going."
        case .feelWorse:            return "The relief lasts seconds. The regret stays longer."
        case .lessPresent:          return "Your attention is often somewhere your life isn't."
        case .allOfIt:              return "This isn't one bad habit. It's where your time goes by default."
        }
    }
}

// MARK: - Vulnerable time (Screen 12 → drives protection + reminder recs)

enum VulnerableTime: String, Codable, CaseIterable, Identifiable {
    case afterWaking, workingStudying, spareMinute, evening, inBed, allDay
    var id: String { rawValue }

    var label: String {
        switch self {
        case .afterWaking:     return "Right after I wake up"
        case .workingStudying: return "While working or studying"
        case .spareMinute:     return "Whenever I have a spare minute"
        case .evening:         return "In the evening"
        case .inBed:           return "In bed"
        case .allDay:          return "All day"
        }
    }

    /// Second-person phrase for reuse in reminder copy (Screen 41).
    var phrase: String {
        switch self {
        case .afterWaking:     return "right after you wake up"
        case .workingStudying: return "while you're working or studying"
        case .spareMinute:     return "whenever you have a spare minute"
        case .evening:         return "in the evening"
        case .inBed:           return "in bed"
        case .allDay:          return "all day"
        }
    }

    /// Screen 29 — recommended protection window derived from the vulnerable time.
    var recommendedProtection: ProtectionTiming {
        switch self {
        case .afterWaking:     return .startOfDay
        case .workingStudying: return .workStudy
        case .evening:         return .evening
        case .inBed:           return .bedtime
        case .spareMinute, .allDay: return .always
        }
    }
}

// MARK: - Previous attempts (Screen 13, multi-select)

enum PreviousAttempt: String, Codable, CaseIterable, Identifiable {
    case screenTimeLimits, deletingApps, anotherBlocker, turningOffNotifications, willpower, nothingYet
    var id: String { rawValue }

    var label: String {
        switch self {
        case .screenTimeLimits:        return "Screen Time limits"
        case .deletingApps:            return "Deleting the apps"
        case .anotherBlocker:          return "Another blocker"
        case .turningOffNotifications: return "Turning off notifications"
        case .willpower:               return "Willpower"
        case .nothingYet:              return "Nothing yet"
        }
    }
}

// MARK: - Protection timing (Screen 29)

enum ProtectionTiming: String, Codable, CaseIterable, Identifiable {
    case startOfDay, workStudy, evening, bedtime, always
    var id: String { rawValue }

    var label: String {
        switch self {
        case .startOfDay: return "From the start of my day"
        case .workStudy:  return "During work or study"
        case .evening:    return "In the evening"
        case .bedtime:    return "At bedtime"
        case .always:     return "Always, until I earn access"
        }
    }
}

// MARK: - Earning methods (Screen 32, multi-select)

enum EarningMethod: String, Codable, CaseIterable, Identifiable {
    case photoProof, exercise, deepFocus, appleHealth, customHabits
    var id: String { rawValue }

    var label: String {
        switch self {
        case .photoProof:   return "Healthy Habits"
        case .exercise:     return "Daily Exercise"
        case .deepFocus:    return "Deep Focus"
        case .appleHealth:  return "Passive Income"
        case .customHabits: return "Custom Habits"
        }
    }

    /// Same copy already used for these habit types elsewhere in the app
    /// (`QuickAction.all`'s subtitles, `Habit.HabitKind.tileDescriptor`) —
    /// not invented here.
    var detail: String {
        switch self {
        case .photoProof:   return "Snap a pic, Aura verifies your habit, earn coins"
        case .exercise:     return "The more you move, the more you earn"
        case .deepFocus:    return "Start the timer, stay off your phone, earn coins"
        case .appleHealth:  return "Claim coins from your Apple Health Activity"
        case .customHabits: return "Create actions that fit your actual life."
        }
    }

    /// Same emoji already used for these habit types elsewhere in the app
    /// (`Habit.HabitKind.emoji`, `QuickAction.all`) — not invented here.
    var emoji: String {
        switch self {
        case .photoProof:   return "📸"
        case .exercise:     return "💪"
        case .deepFocus:    return "🔒"
        case .appleHealth:  return "❤️"
        case .customHabits: return "✨"
        }
    }
}

// MARK: - Post-scroll feelings (Part 2, multi-select)

enum PostScrollFeeling: String, Codable, CaseIterable, Identifiable {
    case guilty, empty, anxious, wastingLife, lowEnergy, foggyThoughts, regretful
    var id: String { rawValue }

    var label: String {
        switch self {
        case .guilty:        return "Guilty"
        case .empty:         return "Empty"
        case .anxious:       return "Anxious"
        case .wastingLife:   return "Like I'm wasting my life"
        case .lowEnergy:     return "Low energy"
        case .foggyThoughts: return "Foggy thoughts"
        case .regretful:     return "Regretful"
        }
    }

    var emoji: String {
        switch self {
        case .guilty:        return "😣"
        case .empty:         return "😶"
        case .anxious:       return "😰"
        case .wastingLife:   return "⌛"
        case .lowEnergy:     return "🪫"
        case .foggyThoughts: return "😶‍🌫️"
        case .regretful:     return "😔"
        }
    }

    /// Adjective-style fragment for the "you won't feel X, Y, or Z" reflection
    /// copy (Part 2's post-scroll-feelings recap) — reads naturally mid-
    /// sentence, unlike `label` (the question-screen option text).
    var flowingPhrase: String {
        switch self {
        case .guilty:        return "guilty"
        case .empty:         return "empty"
        case .anxious:       return "anxious"
        case .wastingLife:   return "like you're wasting your life"
        case .lowEnergy:     return "low on energy"
        case .foggyThoughts: return "foggy"
        case .regretful:     return "regretful"
        }
    }
}

// MARK: - Daily commitment (Screen 40)

enum DailyCommitment: String, Codable, CaseIterable, Identifiable {
    case oneHabit, twoHabits, thirtyMinFocus, customTarget
    var id: String { rawValue }

    var label: String {
        switch self {
        case .oneHabit:       return "One completed habit"
        case .twoHabits:      return "Two completed habits"
        case .thirtyMinFocus: return "30 minutes of real focus"
        case .customTarget:   return "A custom daily target"
        }
    }
}

// MARK: - Reminder preference (Screen 41)

enum ReminderChoice: String, Codable, CaseIterable, Identifiable {
    case recommended, custom, off
    var id: String { rawValue }
}

// MARK: - Subscription selection (Screen 49)

enum SelectedPlan: String, Codable, CaseIterable, Identifiable {
    case annual, weekly
    var id: String { rawValue }
}

// MARK: - Permission + purchase outcomes (service-reported, persisted)

enum PermissionStatus: String, Codable {
    case notDetermined, authorized, denied, restricted
}

enum PurchaseOutcome: String, Codable {
    case success, pending, cancelled, failed, unverified, restored
}

enum SubscriptionStatus: String, Codable {
    case none, active, expired
}
