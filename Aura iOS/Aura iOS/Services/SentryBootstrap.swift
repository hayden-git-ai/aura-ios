//
//  SentryBootstrap.swift
//  Aura iOS
//
//  One-time Sentry (crash + error monitoring) init, called first at launch so it
//  captures crashes during the rest of startup. Written behind `#if canImport(Sentry)`
//  so the app compiles now and switches on the moment the `sentry-cocoa` Swift
//  package is added to the target (same pattern as RevenueCat/Superwall).
//
//  Privacy: crash reports are deliberately kept ANONYMOUS — not linked to a user
//  identity. `sendDefaultPii` is off (no IP / user data auto-collected) and we never
//  call `SentrySDK.setUser`, so diagnostics stay unlinked. Performance tracing is
//  left off (crash + errors only). Sentry is disclosed as a diagnostics processor in
//  the privacy policy and the App Store data-safety label.
//

import Foundation

enum SentryBootstrap {
    /// The Sentry DSN (a client key, safe to ship in the app). Empty = disabled.
    static let dsn = "https://3affec96315ab3d8db33b9c7154616a1@o4512069111775232.ingest.us.sentry.io/4512069152210944"

    static func start() {
        #if canImport(Sentry)
        guard !dsn.isEmpty else { return }
        SentrySDK.start { options in
            options.dsn = dsn
            // No IP address or user data auto-collected.
            options.sendDefaultPii = false
            options.attachStacktrace = true
            // Crash + error monitoring only; no performance tracing.
            #if DEBUG
            options.environment = "debug"
            #else
            options.environment = "production"
            #endif
            // Intentionally never set a user: crashes stay unlinked to identity.
        }
        #endif
    }
}

#if canImport(Sentry)
import Sentry
#endif
