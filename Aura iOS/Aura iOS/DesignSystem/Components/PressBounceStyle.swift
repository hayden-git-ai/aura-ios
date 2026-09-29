//
//  PressBounceStyle.swift
//  Aura iOS
//
//  Lifted out of AddHabitFlowRoot, where it had ended up by accident. It's used
//  across the app and now also inside the Stats report extension, which can't
//  pull in a feature file to get at it.
//

import SwiftUI

/// Scale-on-press feedback for tappable cards (the FAB popover's method cards).
/// We can't use `.glassEffect(.interactive())` on a tappable card here — its own
/// gesture swallows the Button's tap — so the tactile "bounce" comes from the
/// button style instead, keeping the tap reliable.
struct PressBounceStyle: ButtonStyle {
    /// Baseline tactile response for interactive cards and icon controls. Turn
    /// it off only when the action already owns a more specific haptic.
    var hapticsEnabled = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.55), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed && hapticsEnabled { Haptics.impact(.light) }
            }
    }
}
