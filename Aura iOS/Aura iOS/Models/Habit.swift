//
//  Habit.swift
//  Aura iOS
//

import SwiftUI

/// How a habit is verified — this is the axis the Add-a-habit picker's method
/// tiles are built from (each case is one tile), not an activity type.
enum HabitCategory: String, CaseIterable, Codable, Identifiable {
    case photoTask   // Photo — snap proof, AI verifies
    case exercise    // Reps — camera counts your reps
    case focus       // Focus — a timed deep-work session
    case healthSync  // Health — claim Apple Health activity

    var id: String { rawValue }

    /// Order the method tiles appear in the picker.
    static var tileOrder: [HabitCategory] { [.photoTask, .exercise, .focus, .healthSync] }

    /// Titles + descriptors + emoji reuse the app's existing `QuickAction`
    /// copy verbatim — no invented text.
    var displayName: String {
        switch self {
        case .photoTask: return "Healthy Habits"
        case .exercise: return "Daily Exercise"
        case .focus: return "Deep Focus"
        case .healthSync: return "Passive Income"
        }
    }

    var tileDescriptor: String {
        switch self {
        case .photoTask: return "Snap a pic, Aura verifies your habit, earn coins"
        case .exercise: return "The more you move, the more you earn"
        case .focus: return "Start the timer, stay off your phone, earn coins"
        case .healthSync: return "Claim coins from your Apple Health Activity"
        }
    }

    var emoji: String {
        switch self {
        case .photoTask: return "📸"
        case .exercise: return "💪"
        case .focus: return "🔒"
        case .healthSync: return "❤️"
        }
    }

    // MARK: - Colour

    /// Each method owns a colour, and it follows you: the FAB card, the method
    /// screen's field, and the header of every habit inside it. Colour is the
    /// wayfinding — you always know which world you're in.
    var accent: Color {
        switch self {
        case .photoTask: return LightSheet.healthyHabitsMint
        case .exercise: return LightSheet.blue
        case .focus: return Color(hex: "5B4BE0")       // heads-down
        case .healthSync: return LightSheet.passiveIncomeGold
        }
    }

    /// The pale band above the arc — the accent tinted most of the way to the
    /// app's off-white, so a card reads as one object rather than a grey lid.
    var accentSoft: Color {
        switch self {
        case .photoTask: return LightSheet.healthyHabitsMintWash
        case .exercise: return LightSheet.blueWash
        case .focus: return Color(hex: "EFEDFF")
        case .healthSync: return LightSheet.passiveIncomeGoldWash
        }
    }

    /// The darker edge under a filled control in this colour.
    var accentShade: Color {
        switch self {
        case .photoTask: return LightSheet.healthyHabitsMintHeaderTop
        case .exercise: return LightSheet.blueShade
        case .focus: return Color(hex: "4436B8")
        case .healthSync: return LightSheet.passiveIncomeGoldShade
        }
    }

    /// The custom Aura-fox mascot icon shown on the FAB method cards.
    var tileIconAsset: String {
        switch self {
        case .photoTask: return "FoxPhotoProof"
        case .exercise: return "FoxCameraReps"
        case .focus: return "FoxDeepFocus"
        case .healthSync: return "FoxAppleHealth"
        }
    }

    /// The art for the places that show a method as *itself* — the FAB card,
    /// the method screen's hero, the Stats breakdown — as opposed to the places
    /// where it stands in for a habit that has no sticker of its own.
    ///
    /// All four have a drawn scene for this now. `tileIconAsset` stays behind as
    /// the stand-in for a HABIT with no sticker of its own, where a full scene at
    /// row size would read as a smudge.
    var heroIconAsset: String {
        switch self {
        case .photoTask: return "FoxPhotoProofHero"
        case .exercise: return "FoxCameraRepsHero"
        case .focus: return "FoxLockInHero"
        case .healthSync: return "FoxPassiveIncomeHero"
        }
    }

    /// How tall the hero art is drawn on the method's own screen.
    ///
    /// One number for every method that has its art, because the exports are
    /// normalised on the way in: whatever the drawing measured in Figma, it ends
    /// up filling the same 82% of its square. Sizing by the frame is then the
    /// same thing as sizing by the drawing, which is the only size anyone sees.
    ///
    /// It went the other way first — a height per method, worked out from how
    /// much of its own export each drawing happened to fill. That is a number
    /// nobody can maintain: every new piece of art needs it re-derived, and
    /// getting it wrong is invisible in code and obvious on screen.
    ///
    /// A method with no hero art yet falls back to the sheet default. A single
    /// small object blown up to hero size doesn't read as a hero, it reads as a
    /// mistake. All four have their art now, so nothing takes that branch — it
    /// stays for the next method, not for the last one.
    var heroHeight: CGFloat {
        heroIconAsset == tileIconAsset ? FocusHero.defaultStickerHeight : 156
    }
}

/// What kind of thing a habit is, for the filter row above the habit list.
/// Orthogonal to `HabitCategory`, which is how a habit is *verified*.
enum HabitTag: String, Codable, CaseIterable, Hashable {
    case focus, exercise, social, creative, home, health

    var label: String {
        switch self {
        case .focus: return "Focus"
        case .exercise: return "Exercise"
        case .social: return "Social"
        case .creative: return "Creative"
        case .home: return "Home"
        case .health: return "Health"
        }
    }
}

/// A single habit definition — the one source of truth for its reward and how
/// it's earned. `category` is the verification method; the rest are the
/// user-editable defaults surfaced in the Create/Edit builder.
///
/// Designed so a later SwiftData migration only means annotating this type
/// with `@Model` and swapping `HabitStore`'s internals — no call site changes.
struct Habit: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var category: HabitCategory
    /// Emoji shown in lists/pills. Falls back to `iconSystemName` when empty.
    var emoji: String
    var iconSystemName: String
    /// Custom Aura-fox icon asset, shown in the row's icon slot in place of the
    /// emoji/viewfinder. `nil` for user-created habits (they fall back to the
    /// viewfinder-framed emoji).
    var iconAsset: String?
    /// Accent color for the habit (hex).
    var colorHex: String
    /// For Photo habits: whether a focus session follows the snap (earn over
    /// time) vs. a flat one-shot reward. Always true for `.focus`.
    var requiresFocusSession: Bool
    /// Default session length in minutes for timed habits.
    var defaultFocusMinutes: Int
    /// Coins earned per hour focused — 5, 10, 15 or 20. Photo-only habits use
    /// `rewardMinutes` as a flat reward instead.
    var rewardRate: Double
    /// Flat reward (minutes) for a photo-only / one-shot habit.
    var rewardMinutes: Int
    /// Can only be earned once per day (resets at midnight).
    var oncePerDay: Bool
    var targetCount: Int?
    var isEnabled: Bool
    /// Which filter pill this sits under. Nil for habits someone built, which
    /// are found under "Created by me" instead.
    var tag: HabitTag?
    /// Built in the app rather than shipped with it.
    var isCustom: Bool
    var proofHint: String
    var proofExamples: [String]

    /// The habit as the USER would say it, for anything they post themselves.
    ///
    /// Habit names are instructions the app gives — "Make your bed", "Brush
    /// your teeth" — and reading one back on a card the user is sharing turns
    /// it into them telling their friends to make THEIR beds. One swap covers
    /// every case in the catalogue.
    var firstPersonName: String {
        name.replacingOccurrences(of: "your", with: "my")
            .replacingOccurrences(of: "Your", with: "My")
    }


    init(
        id: UUID = UUID(),
        name: String,
        category: HabitCategory,
        emoji: String = "",
        iconSystemName: String = "sparkles",
        iconAsset: String? = nil,
        colorHex: String = "00BFFF",
        requiresFocusSession: Bool = true,
        defaultFocusMinutes: Int = 45,
        rewardRate: Double = 10,
        rewardMinutes: Int = 15,
        oncePerDay: Bool = false,
        targetCount: Int? = nil,
        isEnabled: Bool = true,
        tag: HabitTag? = nil,
        isCustom: Bool = false,
        proofHint: String = "",
        proofExamples: [String] = []
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.emoji = emoji
        self.iconSystemName = iconSystemName
        self.iconAsset = iconAsset
        self.colorHex = colorHex
        self.requiresFocusSession = requiresFocusSession
        self.defaultFocusMinutes = defaultFocusMinutes
        self.rewardRate = rewardRate
        self.rewardMinutes = rewardMinutes
        self.oncePerDay = oncePerDay
        self.targetCount = targetCount
        self.isEnabled = isEnabled
        self.tag = tag
        self.isCustom = isCustom
        self.proofHint = proofHint
        self.proofExamples = proofExamples
    }

    var color: Color { Color(hex: colorHex) }

    /// Coins this habit pays — the hourly rate prorated over the session for
    /// timed habits, or the flat reward for photo-only ones.
    var earnedMinutes: Int {
        requiresFocusSession
            ? Int((Double(defaultFocusMinutes) * rewardRate / 60).rounded())
            : rewardMinutes
    }

    /// Examples for the Photo Proof retry screen, with a generic fallback.
    var resolvedProofExamples: [String] {
        proofExamples.isEmpty
            ? ["The item you're using", "Your workspace, set up", "You, mid-activity"]
            : proofExamples
    }
}
