//
//  HapticsService.swift
//  Aura iOS
//
//  The onboarding haptic vocabulary (OB.Haptic) behind a protocol. Live wraps the
//  UIFeedbackGenerator family; decorative haptics are suppressed when the user
//  reduces motion/haptics, but informational success/warning/error still fire.
//  Repo ships zero haptics today; this is the whole set. One haptic per event.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Canonical haptic events (Tokens §11).
enum OBHaptic {
    case tick     // selection: option/chip/slider step/toggle
    case soft     // tap-to-continue, screen advance
    case rigid    // reel/counter land, grid recolor snap
    case heavy    // ignition, commitment flood
    case success  // permission granted, plan ready, purchase success
    case warning  // cost turns warning, denial recovery
    case error    // purchase failed, plan step failed

    /// Informational haptics still fire when decorative ones are suppressed.
    var isInformational: Bool {
        switch self {
        case .success, .warning, .error: return true
        default: return false
        }
    }
}
