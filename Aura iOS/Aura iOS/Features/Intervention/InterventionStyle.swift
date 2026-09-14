//
//  InterventionStyle.swift
//  Aura iOS
//

import CoreGraphics
import Foundation

/// The shapes an intervention can take when you open a blocked app.
///
/// More than one can be on at once. A style is chosen at random per run, which
/// is the point of having several: the same conversation every time stops being
/// a moment of friction and becomes a button you learn to tap through.
enum InterventionStyle: String, CaseIterable, Codable, Identifiable {
    /// The fox asks whether you need it, then sells you the time. Built.
    case dialogue
    case breathing
    case mirror
    case message

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dialogue: return "Talk to Aura"
        case .breathing: return "Breathing pause"
        case .mirror: return "Mirror check"
        case .message: return "Text from Aura"
        }
    }

    var blurb: String {
        switch self {
        case .dialogue: return "Aura asks if you really need it."
        case .breathing: return "A guided breath first."
        case .mirror: return "A look in the mirror first."
        case .message: return "Aura texts, you reply."
        }
    }

    /// TODO: art per style, once the four have their own.
    var sticker: String {
        switch self {
        case .dialogue: return "InterventionTalkToAura"
        case .breathing: return "InterventionBreathingPause"
        case .mirror: return "InterventionMirrorCheck"
        case .message: return "InterventionTextFromAura"
        }
    }

    /// Whether the style opens with something before the fox speaks.
    var hasPreamble: Bool { self == .breathing || self == .mirror }

    /// Everything on, which is what a fresh install gets.
    static var defaults: Set<InterventionStyle> { Set(allCases) }
}

/// Shared geometry, so the mascot lands in the same place on every intervention
/// screen. A style changes what's said, not where the fox stands.
enum InterventionLayout {
    // Matches the conversation fox (InterventionView.foxHeight) so the breathing
    // preamble and the challenge that follows show the same mascot at the same
    // size in the same place — the breathing fox video is keyed to the same
    // standard geometry, so this frame lands it exactly where the others sit.
    static let foxHeight: CGFloat = 220
}
