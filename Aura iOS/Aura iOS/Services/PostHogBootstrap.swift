//
//  PostHogBootstrap.swift
//  Aura iOS
//
//  One-time PostHog (product analytics) init. Written behind `#if canImport(PostHog)`
//  so the app compiles now and switches on the moment the `posthog-ios` Swift
//  package is added to the target (same pattern as Sentry/RevenueCat/Superwall).
//
//  Optional analytics starts only after explicit Settings consent.
//  Session replay is disabled for this release candidate.
//

import Foundation

enum PostHogBootstrap {
    /// The PostHog project API key (`phc_...`, a client key, safe to ship).
    /// Empty = disabled.
    static let apiKey = "phc_zRY75VexSStPSmbLudq3oEqxubEdF6wiXJTqazyXycaQ"
    /// The project's ingestion host. US Cloud by default; use the EU host if the
    /// project lives in the EU region.
    static let host = "https://us.i.posthog.com"

    static let consentKey = "aura.privacy.analyticsConsent.v1"
    private static var started = false

    static func start() {
        setEnabled(UserDefaults.standard.bool(forKey: consentKey))
    }

    /// Revocation stops capture and closes queues immediately. Consent is device
    /// scoped; analytics never identifies or attaches the Aura account.
    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: consentKey)
        #if canImport(PostHog)
        guard enabled else {
            if started {
                PostHogSDK.shared.optOut()
                PostHogSDK.shared.close()
                started = false
            }
            return
        }
        guard !started, !apiKey.isEmpty else { return }
        let config = PostHogConfig(projectToken: apiKey, host: host)
        config.personProfiles = .identifiedOnly
        config.sessionReplay = false
        PostHogSDK.shared.setup(config)
        PostHogSDK.shared.optIn()
        started = true
        #endif
    }
}

#if canImport(PostHog)
import PostHog
#endif
