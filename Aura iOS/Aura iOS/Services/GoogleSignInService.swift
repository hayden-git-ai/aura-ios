//
//  GoogleSignInService.swift
//  Aura iOS
//
//  Native Sign in with Google. Presents Google's sheet, hands the resulting id
//  token to Supabase (via SupabaseManager.signInWithGoogle), and reports the
//  name/email Google returned so the profile can be filled. The Supabase session
//  is the real outcome; GoogleSignIn is only the identity provider.
//

import CryptoKit
import Foundation
import GoogleSignIn
import UIKit

enum GoogleSignInService {
    /// The iOS OAuth client id. Public by design (it identifies the app to
    /// Google), so it lives in source like any other client id.
    private static let clientID =
        "509845153438-568v0jseqals794sj4iu6nf20ri0ghst.apps.googleusercontent.com"

    struct Result {
        let idToken: String
        let accessToken: String
        /// The RAW nonce whose SHA256 was handed to Google. Supabase re-hashes it
        /// and checks it against the token's nonce claim, so the raw value is what
        /// the caller passes on to Supabase.
        let nonce: String
        let name: String?
        let email: String?
    }

    enum Failure: Error { case noPresenter, noIDToken }

    /// Presents Google's sheet and returns the tokens plus profile basics.
    /// Throws on cancel or failure, which the caller treats as "stay put".
    ///
    /// Google embeds a nonce in the identity token, and Supabase rejects the
    /// token unless a matching nonce is passed alongside it. So we mint a nonce,
    /// hand Google its SHA256 (which lands in the token), and return the raw value
    /// for Supabase to check. Same contract as Sign in with Apple.
    @MainActor
    static func signIn() async throws -> Result {
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        guard let presenter = topViewController() else { throw Failure.noPresenter }

        let rawNonce = randomNonce()
        let result = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: presenter, hint: nil, additionalScopes: nil,
            nonce: sha256(rawNonce))
        guard let idToken = result.user.idToken?.tokenString else { throw Failure.noIDToken }

        return Result(idToken: idToken,
                      accessToken: result.user.accessToken.tokenString,
                      nonce: rawNonce,
                      name: result.user.profile?.name,
                      email: result.user.profile?.email)
    }

    /// A random URL-safe nonce. Its SHA256 goes to Google in the token; the raw
    /// value goes to Supabase, which re-hashes and compares.
    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        while result.count < length {
            var bytes = [UInt8](repeating: 0, count: 16)
            guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
                continue
            }
            for byte in bytes where result.count < length {
                result.append(charset[Int(byte) % charset.count])
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    @MainActor
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
