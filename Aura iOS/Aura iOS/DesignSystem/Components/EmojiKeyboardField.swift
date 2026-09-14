//
//  EmojiKeyboardField.swift
//  Aura iOS
//

import SwiftUI
import UIKit

/// A hidden text field that forces the system's native emoji keyboard to
/// open — full search, categories, skin tones, and recents — instead of a
/// small hardcoded grid. Selecting an emoji is captured via the field's
/// delegate; the field itself is invisible and never shows typed text.
struct EmojiKeyboardField: UIViewRepresentable {
    @Binding var emoji: String
    @Binding var isActive: Bool

    func makeUIView(context: Context) -> EmojiOnlyTextField {
        let field = EmojiOnlyTextField()
        field.delegate = context.coordinator
        field.tintColor = .clear
        field.textColor = .clear
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        return field
    }

    func updateUIView(_ uiView: EmojiOnlyTextField, context: Context) {
        if isActive, !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !isActive, uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: EmojiKeyboardField
        init(_ parent: EmojiKeyboardField) { self.parent = parent }

        /// Every keystroke on an emoji keyboard is a complete emoji (possibly
        /// a multi-scalar cluster like a skin-toned or ZWJ sequence) — capture
        /// it directly rather than accumulating into the field's text.
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            guard !string.isEmpty else { return false }
            parent.emoji = string
            DispatchQueue.main.async {
                textField.text = ""
                self.parent.isActive = false
            }
            return false
        }

        /// Keeps `isActive` honest when the responder is resigned by something
        /// other than an emoji tap — the app-wide tap-away and scroll dismissal
        /// both resign directly, and without this the binding would stay `true`
        /// and `updateUIView` would immediately reopen the keyboard.
        func textFieldDidEndEditing(_ textField: UITextField) {
            guard parent.isActive else { return }
            DispatchQueue.main.async { self.parent.isActive = false }
        }
    }
}

/// Overrides `textInputMode` to hand back the system's emoji input mode
/// whenever it's available, so the field opens directly on the emoji
/// keyboard rather than the default alphabetic one.
final class EmojiOnlyTextField: UITextField {
    override var textInputMode: UITextInputMode? {
        for mode in UITextInputMode.activeInputModes where mode.primaryLanguage == "emoji" {
            return mode
        }
        return super.textInputMode
    }
}
