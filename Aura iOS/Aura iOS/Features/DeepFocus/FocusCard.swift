//
//  FocusCard.swift
//  Aura iOS
//

import SwiftUI

/// One card language for every card across the Deep Focus flow (the setup
/// screen's earn-estimate and Music/During Focus cards, the Complete
/// screen's earned/Focused Today cards) — flat `Theme.Color.surface` fill
/// plus a hairline stroke, so cards read as distinct blocks against the
/// screen's own flat background (and later, the user's own photo
/// background). `borderColor` can be overridden for the one legitimate case
/// that needs it — a Music option card showing itself as selected.
struct FocusCard<Content: View>: View {
    var borderColor: Color = Theme.Color.hairline
    /// Overridable for the Blocked sheet's disclaimer card, which needs to
    /// read as barely-there against the sheet's own translucent background
    /// rather than as a distinct, lighter surface.
    var fillColor: Color = Theme.Color.surface
    /// Overridable for the Music option cards, which need to hug their
    /// single-line content tightly rather than use the same generous
    /// padding as a full-width stat card.
    var padding: CGFloat = Theme.Spacing.l
    /// Opt-in Liquid Glass fill instead of the flat surface — used on the
    /// setup screen so the Reward/Music cards share the length pill's glass
    /// material. Selection is still shown by overriding `borderColor`.
    var glass: Bool = false
    /// Interactive Liquid Glass (glow under touch) — set on tappable glass
    /// cards (Music, Blocked Apps). Non-tappable glass (Reward) leaves it off.
    var interactive: Bool = false
    @ViewBuilder var content: Content

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
    }

    var body: some View {
        if glass {
            content
                .padding(padding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
                // Only draw a stroke when it carries meaning (a selected
                // Music card) — glass supplies its own edge otherwise.
                .overlay(
                    shape.strokeBorder(
                        borderColor == Theme.Color.hairline ? Color.clear : borderColor,
                        lineWidth: 1
                    )
                )
        } else {
            content
                .padding(padding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(fillColor, in: shape)
                .overlay(shape.strokeBorder(borderColor, lineWidth: 1))
        }
    }
}

/// The circle back/close button in the top-left (and top-right, for the
/// active screen's sound toggle) corner of the setup and active screens —
/// the same glass treatment used for every other circular button in the
/// app (the Blocked sheet's X, Emergency Unlock's close button, etc.)
/// rather than a one-off plain stroke.
struct FocusCircleButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                // The chrome grade — this is the dark-surface twin of
                // CircleIconButton, kept separate only for its glass face, and
                // it sits in the same corner as every other close button.
                .font(.system(size: CircleIconButton.Grade.chrome.glyph, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: CircleIconButton.Grade.chrome.diameter,
                       height: CircleIconButton.Grade.chrome.diameter)
                .glassEffect(.regular.interactive(), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

extension View {
}
