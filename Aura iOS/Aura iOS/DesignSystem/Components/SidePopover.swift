//
//  SidePopover.swift
//  Aura iOS
//

import SwiftUI
import UIKit

/// A real UIKit popover anchored to the view it's attached to, with the arrow
/// on a side you actually choose.
///
/// SwiftUI's `.popover` needs `presentationCompactAdaptation(.popover)` to be a
/// popover at all on iPhone, and even then treats `arrowEdge` as a hint — it
/// picks placement itself and will happily shove a bubble off-screen rather
/// than put it where you asked. `UIPopoverPresentationController` takes
/// `permittedArrowDirections` as an instruction, so the tail lands on the side
/// every time.
struct SidePopover<PopoverContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    var size: CGSize
    /// Where the arrow may attach. `.right` puts the bubble to the *left* of the
    /// anchor with its tail pointing right — the shape for a control sitting at
    /// a screen's trailing edge.
    var arrow: UIPopoverArrowDirection = .right
    /// The app forces dark at the window, and a UIKit presentation inherits the
    /// window's trait — not the SwiftUI `preferredColorScheme` of the sheet it
    /// was opened from. Without this the popover drew its dark material on a
    /// white sheet.
    var appearance: UIUserInterfaceStyle = .light
    @ViewBuilder var popoverContent: () -> PopoverContent

    func body(content: Content) -> some View {
        content.background(
            Anchor(isPresented: $isPresented, size: size, arrow: arrow,
                   appearance: appearance, content: popoverContent)
                // Matches the anchor to the view it's behind, so the arrow
                // points at the control rather than at a corner of it.
                .allowsHitTesting(false)
        )
    }

    private struct Anchor: UIViewControllerRepresentable {
        @Binding var isPresented: Bool
        let size: CGSize
        let arrow: UIPopoverArrowDirection
        let appearance: UIUserInterfaceStyle
        @ViewBuilder var content: () -> PopoverContent

        func makeUIViewController(context: Context) -> UIViewController {
            let host = UIViewController()
            host.view.backgroundColor = .clear
            return host
        }

        func updateUIViewController(_ host: UIViewController, context: Context) {
            context.coordinator.isPresented = $isPresented

            // Tracked, rather than read off `host.presentedViewController`.
            // UIKit will happily choose this anchor as the presenter for a
            // sheet SwiftUI puts up elsewhere in the hierarchy — and dismissing
            // "whatever this controller is presenting" then closed that sheet
            // the instant it opened.
            if isPresented, context.coordinator.presented == nil {
                let sheet = UIHostingController(rootView: content())
                sheet.modalPresentationStyle = .popover
                sheet.preferredContentSize = size
                sheet.view.backgroundColor = .clear
                sheet.overrideUserInterfaceStyle = appearance

                if let popover = sheet.popoverPresentationController {
                    popover.sourceView = host.view
                    popover.sourceRect = host.view.bounds
                    popover.permittedArrowDirections = arrow
                    popover.delegate = context.coordinator
                    // The presentation controller draws the material and the
                    // tail, so it needs the appearance too — setting it on the
                    // hosted content alone leaves a dark tail on a light bubble.
                    popover.containerView?.overrideUserInterfaceStyle = appearance
                    // Left to UIKit so the bubble and its tail get the system's
                    // own popover material — setting a flat colour here is what
                    // made it read as a custom panel with a native tail.
                }
                context.coordinator.presented = sheet
                host.present(sheet, animated: true)
            } else if !isPresented, let ours = context.coordinator.presented {
                context.coordinator.presented = nil
                ours.dismiss(animated: true)
            }
        }

        func makeCoordinator() -> Coordinator { Coordinator(isPresented: $isPresented) }

        final class Coordinator: NSObject, UIPopoverPresentationControllerDelegate {
            var isPresented: Binding<Bool>
            /// Only ever the popover this anchor put up.
            var presented: UIViewController?
            init(isPresented: Binding<Bool>) { self.isPresented = isPresented }

            /// Without this, UIKit adapts a popover to a full-screen sheet in
            /// compact width — the same thing SwiftUI does by default.
            func adaptivePresentationStyle(for controller: UIPresentationController,
                                           traitCollection: UITraitCollection) -> UIModalPresentationStyle {
                .none
            }

            /// Tapping outside dismisses UIKit-side; the binding has to follow
            /// or the popover can't be reopened.
            func presentationControllerDidDismiss(_ controller: UIPresentationController) {
                presented = nil
                isPresented.wrappedValue = false
            }
        }
    }
}

extension View {
    func sidePopover<Content: View>(isPresented: Binding<Bool>,
                                    size: CGSize,
                                    arrow: UIPopoverArrowDirection = .right,
                                    appearance: UIUserInterfaceStyle = .light,
                                    @ViewBuilder content: @escaping () -> Content) -> some View {
        modifier(SidePopover(isPresented: isPresented, size: size, arrow: arrow,
                             appearance: appearance, popoverContent: content))
    }
}
