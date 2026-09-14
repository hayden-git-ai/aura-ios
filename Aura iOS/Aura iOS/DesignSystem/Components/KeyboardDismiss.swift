//
//  KeyboardDismiss.swift
//  Aura iOS
//
//  One place that guarantees the keyboard can always be closed: a tap anywhere
//  outside a field, an interactive scroll, or the field's own return key. Nothing
//  in the app should ever leave the keyboard up with no way down.
//

import SwiftUI
import UIKit

extension UIApplication {
    /// Resigns whatever currently holds the keyboard, from anywhere — no
    /// reference to the specific field needed.
    func endEditingEverywhere() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// Installs a single tap recognizer on the key window that dismisses the
/// keyboard on any tap landing outside a text field.
///
/// `cancelsTouchesInView = false` and a delegate that recognises simultaneously
/// are what keep it invisible to everything else: buttons, rows and scroll
/// gestures all still fire, and tapping straight from one field into another
/// still moves the caret rather than closing the keyboard between them. One
/// window carries every sheet and cover on iPhone, so attaching here reaches
/// them too.
private struct GlobalKeyboardDismissal: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let probe = UIView(frame: .zero)
        // Purely a handle for finding the window — it must never eat a touch.
        probe.isUserInteractionEnabled = false
        DispatchQueue.main.async { context.coordinator.attach(to: probe.window) }
        return probe
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // The window can arrive after the first layout, so keep offering it.
        DispatchQueue.main.async { context.coordinator.attach(to: uiView.window) }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var attached: UIWindow?

        func attach(to window: UIWindow?) {
            guard let window, attached !== window else { return }
            attached = window
            let tap = UITapGestureRecognizer(target: self, action: #selector(dismiss))
            tap.cancelsTouchesInView = false
            tap.delegate = self
            window.addGestureRecognizer(tap)
        }

        @objc private func dismiss() {
            UIApplication.shared.endEditingEverywhere()
        }

        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
    }
}

extension View {
    /// Tap-anywhere-outside dismissal plus scroll-to-dismiss, applied once at the
    /// top of the hierarchy so every screen, sheet and cover inherits both.
    func dismissesKeyboardGlobally() -> some View {
        background(GlobalKeyboardDismissal())
            .scrollDismissesKeyboard(.immediately)
    }

    /// A keyboard accessory row with one Done button, for multiline fields where
    /// Return inserts a newline and so can't itself close the keyboard. The
    /// global tap and scroll still work; this is the explicit button on top.
    func keyboardDoneToolbar() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { UIApplication.shared.endEditingEverywhere() }
                    .fontWeight(.semibold)
            }
        }
    }
}
