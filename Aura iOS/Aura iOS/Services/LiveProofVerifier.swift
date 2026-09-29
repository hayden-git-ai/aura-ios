//
//  LiveProofVerifier.swift
//  Aura iOS
//

import Foundation
import UIKit

/// Judges photo proof by asking our own endpoint, which asks the model.
///
/// Never talks to Google directly. The key lives on the endpoint (see
/// `server/`) because a key inside an iOS binary is a key anyone can extract,
/// and the first thing that happens after that is somebody else's traffic on
/// your bill.
final class LiveProofVerifier: ProofVerifier {
    private let endpoint: URL
    private let session: URLSession

    init(endpoint: URL, timeout: TimeInterval = 15) {
        self.endpoint = endpoint

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        // No caching, ever. These are photographs of somebody's home, their
        // face, their gym — there is no version of keeping them that helps.
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: configuration)
    }

    func verify(image: UIImage, habit: Habit) async -> ProofVerdict {
        guard let jpeg = ProofImage.encoded(image) else { return fallback }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.appKey, forHTTPHeaderField: "x-aura-key")
        // When signed in, authenticate as the user: the endpoint then counts the
        // daily quota per account rather than per device. Do not attach the
        // device identifier to an authenticated request; signed-out requests use
        // it for the separate device-scoped quota instead.
        if let token = await SupabaseManager.shared.accessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue(Self.deviceID, forHTTPHeaderField: "x-aura-device")
        }
        request.httpBody = try? JSONEncoder().encode(
            Payload(image: jpeg.base64EncodedString(),
                    hint: habit.proofHint,
                    habitName: habit.name)
        )
        guard request.httpBody != nil else { return fallback }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return fallback
            }
            return try Self.decodeVerdict(from: data)
        } catch {
            // Offline, timed out, endpoint down, response we couldn't read.
            // All the same thing from here: nothing judged the photo.
            return fallback
        }
    }

    static func decodeVerdict(from data: Data) throws -> ProofVerdict {
        let verdict = try JSONDecoder().decode(Response.self, from: data)
        let blocked = verdict.blocked ?? false
        return ProofVerdict(passed: verdict.passed && !blocked,
                            reason: verdict.reason.isEmpty ? nil : verdict.reason,
                            fix: (verdict.fix ?? "").isEmpty ? nil : verdict.fix,
                            isBlocked: blocked)
    }

    /// A retryable unavailable result. It does not describe the photo because
    /// no verifier actually judged it.
    private var fallback: ProofVerdict {
        ProofVerdict(passed: false,
                     reason: "i couldn't check that photo right now.",
                     fix: "try again when Aura can verify it.",
                     isFallback: true)
    }

    /// Shared key the endpoint checks before it will spend anything on Gemini.
    ///
    /// Deliberately not treated as a secret, because it can't be one: it ships
    /// in the binary and can be pulled out of it. Its job is to make the URL on
    /// its own worthless, so a leaked or scraped endpoint costs nothing. Real
    /// authentication is App Attest, or a signed-in user once accounts exist.
    ///
    /// Rotating it is two steps and no App Store release is needed for the
    /// server half: `supabase secrets set AURA_APP_KEY=…`, then ship the app
    /// with the new value.
    private static let appKey = "ClHTUMwZoDXBbHmo3W5xg0qXiR5ERZNcIbKAp2Bvj9M"

    /// What the daily ceiling is counted against.
    ///
    /// `identifierForVendor` rather than anything of the user's: it's the same
    /// for every Aura install on a phone, it resets if they delete the app, and
    /// it identifies a device to us and nobody else. No account, no advertising
    /// identifier, nothing that follows them anywhere.
    private static let deviceID: String =
        UIDevice.current.identifierForVendor?.uuidString ?? "unknown"

    private struct Payload: Encodable {
        let image: String
        let hint: String
        let habitName: String
    }

    private struct Response: Decodable {
        let passed: Bool
        let reason: String
        /// Optional so a build on an older deploy still decodes. The field was
        /// added after the first one; a required key here would have turned
        /// every verdict into a fallback until the function caught up.
        let fix: String?
        /// Absent on every ordinary verdict, so optional for the same reason.
        let blocked: Bool?
    }
}
