//
//  Haptics.swift
//  Aura iOS
//

import CoreHaptics
import UIKit

/// Every haptic in the app goes through here, so feedback stays consistent and
/// the Core Haptics engine is set up once rather than per screen.
///
/// The UIKit generators cover the taps and confirmations. Core Haptics is only
/// used for what they can't do: a sustained rumble while something is working.
/// Everything degrades to silence on hardware without a Taptic Engine.
enum Haptics {

    // MARK: - Discrete

    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat = 1) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred(intensity: intensity)
    }

    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }

    // MARK: - Core Haptics

    private static var engine: CHHapticEngine?
    private static var rumble: CHHapticAdvancedPatternPlayer?

    private static var supportsHaptics: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    /// Starts the engine on first use and keeps it warm. Restarts itself if the
    /// system stops it (a phone call, backgrounding), which otherwise leaves
    /// every later haptic silently dead.
    private static func makeEngine() -> CHHapticEngine? {
        guard supportsHaptics else { return nil }
        if let engine { return engine }

        do {
            let new = try CHHapticEngine()
            new.isAutoShutdownEnabled = true
            new.stoppedHandler = { _ in engine = nil }
            new.resetHandler = {
                try? engine?.start()
            }
            try new.start()
            engine = new
            return new
        } catch {
            return nil
        }
    }

    /// A single tap with hand-set weight and crispness — for the moment the
    /// card touches the reader, where a stock impact style is either too soft
    /// or too blunt.
    static func transient(intensity: Float, sharpness: Float) {
        guard let engine = makeEngine() else {
            impact(.rigid)
            return
        }

        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: 0
        )

        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            impact(.rigid)
        }
    }

    /// A low continuous hum, for the stretch where the screen is animating and
    /// the hand would otherwise feel nothing. Safe to call twice; the previous
    /// rumble is stopped first.
    static func startRumble(intensity: Float = 0.25, sharpness: Float = 0.1, duration: TimeInterval = 30) {
        guard let engine = makeEngine() else { return }
        stopRumble()

        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: 0,
            duration: duration
        )

        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            rumble = try engine.makeAdvancedPlayer(with: pattern)
            try rumble?.start(atTime: CHHapticTimeImmediate)
        } catch {
            rumble = nil
        }
    }

    static func stopRumble() {
        try? rumble?.stop(atTime: CHHapticTimeImmediate)
        rumble = nil
    }

    // MARK: - Ringing

    /// The two-buzz-and-wait cadence of an incoming call, repeating until the
    /// task is cancelled.
    ///
    /// Built from `startRumble` rather than a string of taps: a call vibration
    /// is a sustained buzz, and discrete impacts read as notifications instead.
    /// Cancelling stops mid-buzz, so answering doesn't leave the phone humming.
    static func ring() async {
        defer { stopRumble() }
        while !Task.isCancelled {
            for _ in 0..<2 {
                startRumble(intensity: 1, sharpness: 0.35, duration: Ring.buzz)
                try? await Task.sleep(for: .seconds(Ring.buzz))
                stopRumble()
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .seconds(Ring.gap))
                guard !Task.isCancelled else { return }
            }
            try? await Task.sleep(for: .seconds(Ring.rest))
        }
    }

    /// Timed off iOS's own alert cadence: two short buzzes, then a long wait.
    private enum Ring {
        static let buzz: TimeInterval = 0.42
        static let gap: TimeInterval = 0.22
        static let rest: TimeInterval = 1.4
    }
}
