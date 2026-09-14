//
//  SafariView.swift
//  Aura iOS
//

import SafariServices
import SwiftUI

/// An in-app browser (SFSafariViewController) so links open OVER Aura and the user
/// swipes/Done back in — they never leave the app. Present with `.sheet(item:)`
/// using `BrowserLink`.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.barCollapsingEnabled = true
        let vc = SFSafariViewController(url: url, configuration: config)
        vc.dismissButtonStyle = .close
        return vc
    }

    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}

/// A URL wrapper so a link can drive `.sheet(item:)` (URL isn't Identifiable).
struct BrowserLink: Identifiable {
    let id = UUID()
    let url: URL
}

extension View {
    /// Presents `url` in the in-app browser when non-nil.
    func inAppBrowser(_ link: Binding<BrowserLink?>) -> some View {
        sheet(item: link) { SafariView(url: $0.url).ignoresSafeArea() }
    }
}
