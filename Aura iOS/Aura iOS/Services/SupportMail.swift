//
//  SupportMail.swift
//  Aura iOS
//

import MessageUI
import SwiftUI
import UIKit

/// The support address and what gets sent to it.
///
/// The Contact Support link used to be a bare `mailto:` handed to `openURL`
/// with a hand-built URL and no body. Two routes now: the in-app composer when
/// there's a mail account, and the system handler otherwise — `canSendMail`
/// only answers for Apple Mail, so the second route is what reaches a
/// third-party client set as the default.
enum SupportMail {
    static let address = "help@downloadaura.app"

    /// What a streak dispute needs to be answerable.
    ///
    /// Without the run, the freezes and the log size, "my streak was wrong"
    /// can't be checked against anything — support would have to ask for all of
    /// it and wait a day for the reply.
    struct Context {
        var streak: Int
        var freezes: Int
        var daysLogged: Int
    }

    static let subject = "Streak issue"

    static func body(_ context: Context) -> String {
        let device = UIDevice.current
        let bundle = Bundle.main.infoDictionary
        let version = bundle?["CFBundleShortVersionString"] as? String ?? "?"
        let build = bundle?["CFBundleVersion"] as? String ?? "?"
        return """
        Tell us what happened:



        —— the bits we need to look it up ——
        Streak: \(context.streak) days
        Freezes: \(context.freezes)
        Days logged: \(context.daysLogged)
        Aura \(version) (\(build))
        \(device.systemName) \(device.systemVersion)
        """
    }

    /// `mailto:` for the fallback route. Percent-encoding is required — an
    /// unescaped newline in the body silently invalidates the whole URL.
    static func url(_ context: Context) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body(context)),
        ]
        return components.url
    }

    static var canCompose: Bool { MFMailComposeViewController.canSendMail() }
}
