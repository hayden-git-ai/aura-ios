//
//  SupabaseManager.swift
//  Aura iOS
//
//  The one Supabase client, and the auth + profile calls the app makes through
//  it. Identity lives here; policy and blocking do not.
//
//  Two populations sign in through this: web-funnel users who made their paid
//  account with email + password, and direct App Store users who create one with
//  Apple or Google. All three land on the same Supabase project and the same
//  `auth.users` row per person. See docs/auth/SUPABASE_AUTH_AND_SYNC_PLAN.md.
//
//  Only the publishable key ships here. It is public by design; the service-role
//  key never touches the app. RLS on `profiles` is what actually protects data.
//

import Foundation
import Supabase

final class SupabaseManager {
    static let shared = SupabaseManager()

    private static let projectURL = URL(string: "https://xafxoixbxaezijooutlw.supabase.co")!
    private static let publishableKey = "sb_publishable_J4DMctdqgssgfrnVEMwSXQ_LYSH59Lu"

    let client: SupabaseClient

    enum AccountOperationError: Error {
        case notAuthenticated
        case invalidImage
    }

    private init() {
        client = SupabaseClient(
            supabaseURL: Self.projectURL,
            supabaseKey: Self.publishableKey
        )
    }

    // MARK: - Session

    /// The signed-in user's id, or nil. Read from the cached session, no network.
    var currentUserID: UUID? { client.auth.currentUser?.id }

    /// Whether a session can be restored (refreshing it if needed). Called on
    /// launch to reconcile the local signed-in flag with reality.
    func hasValidSession() async -> Bool {
        (try? await client.auth.session) != nil
    }

    /// The current access token, refreshed if needed, or nil when signed out.
    /// The proof endpoint uses it to authenticate a signed-in user.
    func accessToken() async -> String? {
        (try? await client.auth.session)?.accessToken
    }

    // MARK: - Sign in

    /// Native Sign in with Apple. `idToken` is Apple's identity token; `nonce` is
    /// the RAW nonce whose SHA256 was handed to Apple in the request. Supabase
    /// re-hashes it and checks it against the token, so passing the raw value is
    /// correct.
    func signInWithApple(idToken: String, nonce: String) async throws {
        try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
    }

    /// Native Sign in with Google. `idToken` comes from GoogleSignIn; the access
    /// token is optional. `nonce` is the RAW nonce whose SHA256 was handed to
    /// Google, which embeds it in the token; Supabase re-hashes it and checks it,
    /// so passing the raw value is correct (same as Apple). Without it Supabase
    /// rejects the token with a nonce-mismatch. Opens the same session as the
    /// other two providers.
    func signInWithGoogle(idToken: String, accessToken: String?, nonce: String) async throws {
        try await client.auth.signInWithIdToken(
            credentials: .init(provider: .google, idToken: idToken, accessToken: accessToken, nonce: nonce)
        )
    }

    /// Email + password, the path returning web-funnel users use to reach the
    /// account they created at the paywall.
    func signInWithEmail(_ email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
    }

    /// Sends a password-reset email. For the "forgot password" link on the email
    /// sign-in screen.
    func sendPasswordReset(to email: String) async throws {
        try await client.auth.resetPasswordForEmail(email)
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    /// Permanently deletes the signed-in account and every row/object it owns.
    /// The client cannot delete its own `auth.users` row, so this calls the
    /// `delete-account` edge function (authenticated by the session JWT, which it
    /// attaches automatically); the function wipes the user's Storage folder and
    /// deletes the auth user, cascading `profiles` and `progress`. On success the
    /// session is signed out locally. Throws if the delete did not succeed, so the
    /// caller can keep the account and let the user retry.
    func deleteAccount() async throws {
        guard let uid = currentUserID else { throw AccountOperationError.notAuthenticated }
        try await deleteAccount(expectedUserID: uid)
    }

    func deleteAccount(expectedUserID: UUID) async throws {
        guard let scopedClient = await supportClient(for: expectedUserID) else {
            throw AccountOperationError.notAuthenticated
        }
        try await scopedClient.functions.invoke("delete-account")
        if currentUserID == expectedUserID { try? await client.auth.signOut() }
    }

    // MARK: - Web subscription (two-source entitlement)

    /// The `web-entitlement` function's reply. `active` is the answer; a non-nil
    /// `error` means the function reached us but couldn't confirm with web2wave, so
    /// the caller should trust its cache rather than this `active: false`.
    struct WebEntitlement: Decodable {
        let active: Bool
        let store: String?
        let expiresAt: String?
        let error: String?
    }

    /// Checks the signed-in user's WEB (Paddle/web2wave) subscription via the
    /// `web-entitlement` edge function, which holds the web2wave key server-side so
    /// the app never does. The session JWT is attached automatically. Returns nil
    /// when signed out or the call itself fails (network / function missing), so the
    /// caller can fall back to its cache; otherwise the decoded reply.
    func webEntitlement() async -> WebEntitlement? {
        guard currentUserID != nil else { return nil }
        do {
            let result: WebEntitlement = try await client.functions.invoke("web-entitlement")
            return result
        } catch {
            return nil
        }
    }

    private struct CancelFeedbackWrite: Encodable {
        let user_id: String
        let reason: String
        let notes: String?
    }

    /// Records why a user is canceling (best-effort). Inserted under their own id
    /// via RLS on `cancel_feedback`; the founder reads it server-side. No-op when
    /// signed out. Failure is swallowed — the cancel flow must never be blocked by
    /// the survey.
    func sendCancelFeedback(reason: String, notes: String?) async {
        guard let uid = currentUserID else { return }
        let trimmed = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let row = CancelFeedbackWrite(
            user_id: uid.uuidString,
            reason: reason,
            notes: (trimmed?.isEmpty ?? true) ? nil : trimmed)
        _ = try? await client.from("cancel_feedback").insert(row).execute()
    }

    // MARK: - Support chat

    private struct SupportSendBody: Encodable {
        let client_message_id: UUID
        let text: String
        let media_url: String?
        let media_mime: String?
        let media_name: String?
    }

    /// Sends a support message (text and/or one media attachment). Calls the
    /// `support-send` edge function, which persists it and relays it into Crisp.
    /// The function authenticates from the attached session JWT, so this is a safe
    /// no-op when signed out. Best-effort: a failure leaves the local copy the chat
    /// already kept, and the next send retries the relay.
    /// Returns whether the relay succeeded, so the chat can show a "Not delivered"
    /// state and offer a retry (matching iMessage) instead of silently dropping it.
    @discardableResult
    func sendSupportMessage(
        _ text: String, messageID: UUID, mediaURL: String? = nil, mediaMime: String? = nil, mediaName: String? = nil,
        expectedUserID: UUID,
    ) async -> Bool {
        guard let supportClient = await supportClient(for: expectedUserID) else { return false }
        do {
            _ = try await supportClient.functions.invoke(
                "support-send",
                options: FunctionInvokeOptions(
                    body: SupportSendBody(client_message_id: messageID, text: text,
                                          media_url: mediaURL, media_mime: mediaMime,
                                          media_name: mediaName)
                )
            )
            return true
        } catch {
            return false
        }
    }

    /// Uploads a support attachment to the private user-media bucket and returns a
    /// long-lived signed URL that Crisp can fetch to display it. Stored under the
    /// user's own folder; the signed URL (1 year) is what is shared onward. Returns
    /// nil when signed out or on failure.
    func uploadSupportAttachment(
        data: Data,
        fileExtension ext: String,
        contentType: String,
        expectedUserID: UUID
    ) async -> String? {
        guard let supportClient = await supportClient(for: expectedUserID) else { return nil }
        // Keep the client-side contract aligned with the private bucket and the
        // support-send function. UI importers are advisory; this guard also
        // covers camera/photo and retry paths.
        guard data.count <= 10 * 1024 * 1024 else { return nil }
        // AVAudioRecorder and some document providers report m4a using either
        // audio/m4a or audio/x-m4a. Storage uses the canonical MP4 audio type.
        let normalizedContentType = ["audio/m4a", "audio/x-m4a"].contains(contentType)
            ? "audio/mp4" : contentType
        let supportedMIME = normalizedContentType.hasPrefix("image/")
            || ["application/pdf", "text/plain",
                "audio/mp4", "audio/aac",
                "audio/mpeg", "audio/wav", "audio/x-wav"].contains(normalizedContentType)
        guard supportedMIME else { return nil }
        // Images are sanitized (capped, EXIF stripped, re-encoded) before storage;
        // HEIF/PNG and other supported images are normalized to JPEG. Non-image
        // attachments pass through (the bucket's MIME + size limits are the guard).
        var data = data
        var uploadExtension = ext
        var uploadContentType = normalizedContentType
        if normalizedContentType.hasPrefix("image/") {
            guard let clean = ImageSanitizer.sanitizedJPEG(from: data) else { return nil }
            data = clean
            uploadExtension = "jpg"
            uploadContentType = "image/jpeg"
        }
        let path = "\(expectedUserID.uuidString)/support/\(UUID().uuidString).\(uploadExtension)"
        do {
            try await supportClient.storage.from(Self.mediaBucket)
                .upload(path, data: data, options: FileOptions(contentType: uploadContentType, upsert: true))
            // Do not advance upload -> signed URL after the app has switched accounts.
            // The upload itself used the captured account's bearer and owner prefix.
            guard currentUserID == expectedUserID else { return nil }
            let signed = try await supportClient.storage.from(Self.mediaBucket)
                .createSignedURL(path: path, expiresIn: 60 * 60 * 24 * 365)
            return signed.absoluteString
        } catch {
            return nil
        }
    }

    /// One message in the support thread, as read back from the server. `id` is
    /// the durable row id, used by the chat to merge without duplicating. `sender`
    /// is "user" or "team". A media message carries `mediaURL` (+ mime/name).
    struct ChatMessage: Identifiable {
        let id: UUID
        let sender: String
        let text: String
        let date: Date
        let mediaURL: String?
        let mediaMime: String?
        let mediaName: String?
    }

    private struct ChatMessageRow: Decodable {
        let id: UUID; let sender: String; let text: String; let created_at: String
        let media_url: String?; let media_mime: String?; let media_name: String?
    }

    private static let timestampParser: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// The full support thread, both sides, oldest first. RLS scopes the read to
    /// the caller's own rows, so the whole conversation follows the account across
    /// devices. Empty when signed out or on error, so the chat keeps what it has.
    func fetchConversation(expectedUserID: UUID) async -> [ChatMessage] {
        guard let supportClient = await supportClient(for: expectedUserID) else { return [] }
        let rows: [ChatMessageRow]? = try? await supportClient.from("support_messages")
            .select("id,sender,text,created_at,media_url,media_mime,media_name")
            .eq("user_id", value: expectedUserID.uuidString)
            .order("created_at")
            .execute()
            .value
        return (rows ?? []).map { row in
            let date = Self.timestampParser.date(from: row.created_at)
                ?? ISO8601DateFormatter().date(from: row.created_at)
                ?? .now
            return ChatMessage(id: row.id, sender: row.sender, text: row.text, date: date,
                               mediaURL: row.media_url, mediaMime: row.media_mime, mediaName: row.media_name)
        }
    }

    /// A short-lived client whose database, Storage and Functions requests all use
    /// the same captured session token. The shared client follows auth changes, so
    /// it is unsafe for support work that can outlive an account switch.
    private func supportClient(for expectedUserID: UUID) async -> SupabaseClient? {
        guard let session = try? await client.auth.session,
              session.user.id == expectedUserID else { return nil }
        let accessToken = session.accessToken
        let options = SupabaseClientOptions(
            auth: .init(autoRefreshToken: false, accessToken: { accessToken }),
            // FunctionsClient does not use the database/Storage request adapter,
            // so bind the same captured bearer in its initial headers as well.
            global: .init(headers: ["Authorization": "Bearer \(accessToken)"])
        )
        return SupabaseClient(
            supabaseURL: Self.projectURL,
            supabaseKey: Self.publishableKey,
            options: options
        )
    }

    // MARK: - Profile

    /// Writes the portable identity fields to the caller's own profile row. The
    /// row is created for us by a signup trigger, so this is an upsert only to be
    /// safe against a first sign-in that predates the trigger. RLS scopes it to
    /// the authenticated user; `user_id` equals `auth.uid()` or the write is
    /// rejected.
    func upsertProfile(displayName: String?, email: String?) async throws {
        guard let uid = currentUserID else { throw AccountOperationError.notAuthenticated }
        try await upsertProfile(displayName: displayName, email: email, expectedUserID: uid)
    }

    func upsertProfile(displayName: String?, email: String?, expectedUserID: UUID) async throws {
        guard let scopedClient = await supportClient(for: expectedUserID) else {
            throw AccountOperationError.notAuthenticated
        }
        let row = ProfileWrite(
            user_id: expectedUserID.uuidString,
            display_name: displayName?.isEmpty == true ? nil : displayName,
            email: email?.isEmpty == true ? nil : email
        )
        try await scopedClient.from("profiles")
            .upsert(row, onConflict: "user_id")
            .execute()
    }

    /// Pulls the caller's profile row, or nil if there isn't one yet. Used on a
    /// fresh device after sign-in to restore name/email that live server-side.
    func fetchProfile() async throws -> Profile? {
        guard let uid = currentUserID else { return nil }
        return try await fetchProfile(expectedUserID: uid)
    }

    func fetchProfile(expectedUserID: UUID) async throws -> Profile? {
        guard let scopedClient = await supportClient(for: expectedUserID) else { return nil }
        return try await scopedClient.from("profiles")
            .select()
            .eq("user_id", value: expectedUserID.uuidString)
            .single()
            .execute()
            .value
    }

    // MARK: - Progress (day-log history)

    /// ISO8601 both ways, matching the app's local `DayLogFile`, so a record
    /// round-trips through the server unchanged.
    private static let progressEncoder: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
    }()
    private static let progressDecoder: JSONDecoder = {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }()

    /// The lifetime achievement counters that live outside the day-log. Merged
    /// by the app (max wins, since each only grows) rather than replaced.
    struct SyncStats: Codable, Equatable {
        var earnedMinutes: Int
        var healthyHabits: Int
        var reps: Int
        var focusMinutes: Int
        var baselineWeeklyScreenMinutes: Int?
        var habitCompletionCounts: [String: Int]
        var exerciseCompletionCounts: [String: Int]
        var healthCollectCount: Int
    }

    /// The caller's synced progress: the day-log and the achievement counters.
    /// Either is nil if there is no row yet or it can't be read. The app merges
    /// these with local rather than replacing.
    struct RemoteProgress {
        let records: [DayRecord]?
        let stats: SyncStats?
    }

    func fetchProgress() async throws -> RemoteProgress {
        guard let uid = currentUserID else { return RemoteProgress(records: nil, stats: nil) }
        return try await fetchProgress(expectedUserID: uid)
    }

    func fetchProgress(expectedUserID: UUID) async throws -> RemoteProgress {
        guard let scopedClient = await supportClient(for: expectedUserID) else {
            return RemoteProgress(records: nil, stats: nil)
        }
        let row: ProgressRow = try await scopedClient.from("progress")
            .select("day_log,stats")
            .eq("user_id", value: expectedUserID.uuidString)
            .single()
            .execute()
            .value
        let records = row.day_log.data(using: .utf8)
            .flatMap { try? Self.progressDecoder.decode([DayRecord].self, from: $0) }
        let stats = row.stats.data(using: .utf8)
            .flatMap { try? Self.progressDecoder.decode(SyncStats.self, from: $0) }
        return RemoteProgress(records: records, stats: stats)
    }

    /// Writes the caller's full day-log and counters together, in one upsert. The
    /// app pushes the merged superset, so this is a whole-value replace.
    func pushProgress(_ records: [DayRecord], stats: SyncStats) async throws {
        guard let uid = currentUserID else { throw AccountOperationError.notAuthenticated }
        try await pushProgress(records, stats: stats, expectedUserID: uid)
    }

    func pushProgress(_ records: [DayRecord], stats: SyncStats, expectedUserID: UUID) async throws {
        guard let scopedClient = await supportClient(for: expectedUserID) else {
            throw AccountOperationError.notAuthenticated
        }
        let logJSON = String(data: try Self.progressEncoder.encode(records), encoding: .utf8) ?? "[]"
        let statsJSON = String(data: try Self.progressEncoder.encode(stats), encoding: .utf8) ?? "{}"
        try await scopedClient.from("progress")
            .upsert(ProgressWrite(user_id: expectedUserID.uuidString, day_log: logJSON, stats: statsJSON),
                    onConflict: "user_id")
            .execute()
    }

    private struct ProgressRow: Decodable { let day_log: String; let stats: String }
    private struct ProgressWrite: Encodable { let user_id: String; let day_log: String; let stats: String }

    // MARK: - Library (habits + routines)

    /// The user's editable library, stamped with when it last changed. Unlike the
    /// day-log and counters, this is a mutable list resolved last-write-wins by
    /// `updatedAt`.
    struct SyncLibrary: Codable {
        var updatedAt: Date
        var habits: [Habit]
        var routines: [HabitRoutine]
        /// Wall-of-Wins metadata. The photos themselves live in Storage; this is
        /// only the index (id, habit, icon, date, filename).
        var wins: [Win] = []
    }

    /// Reads the library blob, or nil if there is no row/blob yet. Written to its
    /// own column so it never clobbers the day-log or counters (a partial upsert
    /// leaves other columns untouched).
    func fetchLibrary() async throws -> SyncLibrary? {
        guard let uid = currentUserID else { return nil }
        return try await fetchLibrary(expectedUserID: uid)
    }

    func fetchLibrary(expectedUserID: UUID) async throws -> SyncLibrary? {
        guard let scopedClient = await supportClient(for: expectedUserID) else { return nil }
        let row: LibraryRow = try await scopedClient.from("progress")
            .select("library")
            .eq("user_id", value: expectedUserID.uuidString)
            .single()
            .execute()
            .value
        return row.library.data(using: .utf8)
            .flatMap { try? Self.progressDecoder.decode(SyncLibrary.self, from: $0) }
    }

    func pushLibrary(_ library: SyncLibrary) async throws {
        guard let uid = currentUserID else { throw AccountOperationError.notAuthenticated }
        try await pushLibrary(library, expectedUserID: uid)
    }

    func pushLibrary(_ library: SyncLibrary, expectedUserID: UUID) async throws {
        guard let scopedClient = await supportClient(for: expectedUserID) else {
            throw AccountOperationError.notAuthenticated
        }
        let json = String(data: try Self.progressEncoder.encode(library), encoding: .utf8) ?? "{}"
        try await scopedClient.from("progress")
            .upsert(LibraryWrite(user_id: expectedUserID.uuidString, library: json), onConflict: "user_id")
            .execute()
    }

    private struct LibraryRow: Decodable { let library: String }
    private struct LibraryWrite: Encodable { let user_id: String; let library: String }

    // MARK: - Storage (win photos + avatar)

    /// One private bucket, owner-scoped by path: the first folder is the user id,
    /// which the Storage policies check against auth.uid(). Personal photos, so
    /// the bucket is private and reached only through the authenticated client,
    /// never a public URL.
    private static let mediaBucket = "user-media"

    private func winPath(_ winID: String, _ uid: UUID) -> String { "\(uid.uuidString)/wins/\(winID).jpg" }
    private func avatarPath(_ uid: UUID) -> String { "\(uid.uuidString)/avatar.jpg" }

    func uploadWinPhoto(winID: String, jpeg: Data) async throws {
        guard let uid = currentUserID else { throw AccountOperationError.notAuthenticated }
        try await uploadWinPhoto(winID: winID, jpeg: jpeg, expectedUserID: uid)
    }

    func uploadWinPhoto(winID: String, jpeg: Data, expectedUserID: UUID) async throws {
        guard let scopedClient = await supportClient(for: expectedUserID) else {
            throw AccountOperationError.notAuthenticated
        }
        // Cap dimensions + strip metadata at the storage boundary (camera frames
        // arrive full-resolution). A non-image never reaches the bucket.
        guard let clean = ImageSanitizer.sanitizedJPEG(from: jpeg) else {
            throw AccountOperationError.invalidImage
        }
        try await scopedClient.storage.from(Self.mediaBucket)
            .upload(winPath(winID, expectedUserID), data: clean,
                    options: FileOptions(contentType: "image/jpeg", upsert: true))
    }

    func downloadWinPhoto(winID: String) async -> Data? {
        guard let uid = currentUserID else { return nil }
        return await downloadWinPhoto(winID: winID, expectedUserID: uid)
    }

    func downloadWinPhoto(winID: String, expectedUserID: UUID) async -> Data? {
        guard let scopedClient = await supportClient(for: expectedUserID) else { return nil }
        return try? await scopedClient.storage.from(Self.mediaBucket)
            .download(path: winPath(winID, expectedUserID))
    }

    func deleteWinPhoto(winID: String) async {
        guard let uid = currentUserID else { return }
        await deleteWinPhoto(winID: winID, expectedUserID: uid)
    }

    func deleteWinPhoto(winID: String, expectedUserID: UUID) async {
        guard let scopedClient = await supportClient(for: expectedUserID) else { return }
        _ = try? await scopedClient.storage.from(Self.mediaBucket)
            .remove(paths: [winPath(winID, expectedUserID)])
    }

    func uploadAvatar(jpeg: Data) async throws {
        guard let uid = currentUserID else { throw AccountOperationError.notAuthenticated }
        try await uploadAvatar(jpeg: jpeg, expectedUserID: uid)
    }

    func uploadAvatar(jpeg: Data, expectedUserID: UUID) async throws {
        guard let scopedClient = await supportClient(for: expectedUserID) else {
            throw AccountOperationError.notAuthenticated
        }
        // Already downscaled upstream, but sanitize at the boundary too so every
        // stored image is consistently capped + metadata-free.
        guard let clean = ImageSanitizer.sanitizedJPEG(from: jpeg) else {
            throw AccountOperationError.invalidImage
        }
        try await scopedClient.storage.from(Self.mediaBucket)
            .upload(avatarPath(expectedUserID), data: clean,
                    options: FileOptions(contentType: "image/jpeg", upsert: true))
    }

    func downloadAvatar() async -> Data? {
        guard let uid = currentUserID else { return nil }
        return await downloadAvatar(expectedUserID: uid)
    }

    func downloadAvatar(expectedUserID: UUID) async -> Data? {
        guard let scopedClient = await supportClient(for: expectedUserID) else { return nil }
        return try? await scopedClient.storage.from(Self.mediaBucket)
            .download(path: avatarPath(expectedUserID))
    }

    func deleteAvatar() async {
        guard let uid = currentUserID else { return }
        await deleteAvatar(expectedUserID: uid)
    }

    func deleteAvatar(expectedUserID: UUID) async {
        guard let scopedClient = await supportClient(for: expectedUserID) else { return }
        _ = try? await scopedClient.storage.from(Self.mediaBucket)
            .remove(paths: [avatarPath(expectedUserID)])
    }

    // MARK: - Wire types

    /// What we read back. Progress columns are decoded but not yet used: real
    /// progress sync needs dayRecords, not these snapshots (see the plan doc).
    struct Profile: Decodable {
        let userID: String
        let displayName: String?
        let email: String?
        let avatarURL: String?

        enum CodingKeys: String, CodingKey {
            case userID = "user_id"
            case displayName = "display_name"
            case email
            case avatarURL = "avatar_url"
        }
    }

    private struct ProfileWrite: Encodable {
        let user_id: String
        let display_name: String?
        let email: String?
    }
}
