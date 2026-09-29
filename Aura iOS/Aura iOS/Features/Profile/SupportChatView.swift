//
//  SupportChatView.swift
//  Aura iOS
//
//  The in-app support conversation — a single "Team Aura" thread reached from the
//  chat bubble on the Profile screen. Visually modelled on a native Messages
//  thread (dark ground, a contact header, incoming/outgoing bubbles, a bottom
//  composer).
//
//  Messages are cached locally and synchronized through Supabase/Crisp. The cache
//  is account-scoped so a signed-out or newly signed-in person never sees the
//  previous account's support conversation on a shared device.
//

import AVFoundation
import LinkPresentation
import Photos
import PhotosUI
import Speech
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The active window scene's screen bounds — the iOS 26 replacement for the
/// now-deprecated `UIScreen.main.bounds`. Falls back to a typical device size,
/// which never happens once a foreground scene exists.
@MainActor
private func activeScreenBounds() -> CGRect {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    return scene?.screen.bounds ?? CGRect(x: 0, y: 0, width: 393, height: 852)
}

// MARK: - Model

/// One message in the support thread. `Codable` so the local history persists;
/// the same shape is what a backend row would decode into. A message is either
/// text or one media attachment (`mediaURL` set; `mediaMime` decides rendering).
struct SupportMessage: Identifiable, Codable, Equatable {
    enum Sender: String, Codable { case team, me }
    var id: UUID = UUID()
    var sender: Sender
    var text: String
    var date: Date = .now
    /// The seeded welcome messages. Always pinned to the top of the thread, above
    /// the real conversation, so a historical reply (dated earlier than a fresh
    /// seed, e.g. after a reinstall) can never sort above the greeting.
    var isWelcome: Bool = false
    /// Attachment (image today; files/video/audio later). `mediaURL` is a remote
    /// URL; `mediaMime`/`mediaName` describe it.
    var mediaURL: String? = nil
    var mediaMime: String? = nil
    var mediaName: String? = nil
    /// The just-picked image bytes, shown instantly before/without a round trip.
    /// Deliberately excluded from `Codable`, so image bytes never bloat the local
    /// UserDefaults copy.
    var localImage: Data? = nil
    /// Local bytes for a non-image attachment (a voice note, video, or file) so it
    /// can play/preview instantly before the upload finishes. Transient, like
    /// `localImage` — never persisted.
    var localMedia: Data? = nil

    /// Delivery state for the user's own sends, so a failed relay can show a
    /// "Not delivered" hint with a retry, like iMessage. Team messages and the
    /// seeded welcome are always `.sent`.
    enum Delivery: String, Codable { case sending, sent, failed }
    var delivery: Delivery = .sent
    /// The durable server row represented by this message. Local optimistic sends
    /// keep their own UI id and gain this id when a refresh reconciles them.
    var serverID: UUID? = nil

    enum CodingKeys: String, CodingKey {
        case id, sender, text, date, isWelcome, mediaURL, mediaMime, mediaName, delivery, serverID
    }
}

// MARK: - Store

/// Owns the support thread: the seeded welcome (local, pinned to the top) plus
/// the real conversation, which lives on the server. `refresh()` pulls the whole
/// thread — both sides — so it follows the account across devices, and eases in a
/// genuinely new founder reply with a typing indicator. Sends are optimistic and
/// reconciled against their server copy on the next refresh. A local UserDefaults
/// copy is kept so the thread shows instantly on open, before the server load.
@MainActor
@Observable
final class SupportChatStore {
    /// Shared so the Profile badge and the chat read/write the same thread + unread
    /// state (the Profile FAB shows the count, the open chat clears it).
    static let shared = SupportChatStore()

    private(set) var messages: [SupportMessage]
    /// The only account whose local cache may currently be visible or mutated.
    private(set) var accountID: UUID?

    /// The newest message the user has actually seen (chat opened). Team replies
    /// after this count as unread. Observed, so the badge updates live.
    private var lastRead: Date

    /// Unread founder replies — the number the Profile badge shows. Welcome messages
    /// (re-seeded with a fresh date each launch) never count.
    var unreadCount: Int {
        messages.filter { $0.sender == .team && !$0.isWelcome && $0.date > lastRead }.count
    }

    /// Marks the whole thread read (called when the chat opens / while it's open).
    func markRead() {
        guard let accountID, accountID == SupabaseManager.shared.currentUserID else { return }
        let latest = messages.map(\.date).max() ?? Date()
        lastRead = max(latest, Date())
        defaults.set(lastRead, forKey: Self.readKey(for: accountID))
    }

    /// True while an incoming reply is being eased in: the typing indicator shows
    /// for a beat, then the message drops in. Only ever set for a reply that lands
    /// while the chat is open, never on history or the user's own send.
    private(set) var isTeamTyping = false

    /// Row ids already merged from the server, so a refresh only reacts to what is
    /// actually new.
    private var serverIDs = Set<UUID>()
    /// The first refresh loads history silently; only replies that arrive AFTER it
    /// get the typing animation.
    private var didInitialLoad = false
    /// Identifies the account generation currently refreshing. A revision, rather
    /// than a Bool, stops an old account's deferred cleanup clearing the new one.
    private var refreshInFlightRevision: UInt64?
    private var identityRevision: UInt64 = 0

    /// A synchronous identity snapshot for view-owned async work (photo export,
    /// document import, camera and permission callbacks). The account id alone is
    /// insufficient because signing out and back into the same account is a new
    /// ownership generation too.
    fileprivate struct IdentityContext: Equatable {
        let accountID: UUID?
        let revision: UInt64
    }

    fileprivate var identityContext: IdentityContext {
        IdentityContext(accountID: accountID, revision: identityRevision)
    }

    fileprivate func isCurrent(_ context: IdentityContext) -> Bool {
        identityContext == context
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        accountID = nil
        lastRead = .distantPast
        messages = Self.seed()
        // Deliberately do not adopt `aura.support.thread.v4` or
        // `aura.support.lastRead.v1`. There is no reliable way to prove which
        // account created those unowned values, so assigning them to the next
        // login would recreate the cross-account disclosure this store prevents.
    }

    /// Switches the visible/local thread synchronously before any async identity
    /// work begins. Nil means signed out and exposes only the static welcome copy.
    func switchAccount(to userID: UUID?) {
        guard accountID != userID else { return }
        identityRevision &+= 1
        accountID = userID
        isTeamTyping = false
        refreshInFlightRevision = nil
        didInitialLoad = false
        serverIDs = []
        lastRead = .distantPast

        guard let userID else {
            messages = Self.seed()
            return
        }

        lastRead = defaults.object(forKey: Self.readKey(for: userID)) as? Date ?? .distantPast
        if let data = defaults.data(forKey: Self.threadKey(for: userID)),
           let saved = try? JSONDecoder().decode([SupportMessage].self, from: data),
           !saved.isEmpty {
            // The welcome copy is NOT frozen in storage: re-derive it from the current
            // seed every load so edits to the greeting reach existing threads too. The
            // real conversation is kept as-is (a `.sending` left over from an app that
            // was killed mid-relay becomes `.failed`, so it shows a retry, not a lie).
            let real = saved
                .filter { !$0.isWelcome }
                .map { var m = $0; if m.delivery == .sending { m.delivery = .failed }; return m }
            messages = Self.seed() + real
            persist()
        } else {
            messages = Self.seed()
            persist()
        }
        serverIDs = Set(messages.compactMap(\.serverID))

        #if DEBUG
        // `-seedUnread` injects two unread founder replies so the profile FAB's
        // unread pill can be eyeballed without a live backend reply.
        if ProcessInfo.processInfo.arguments.contains("-seedUnread") {
            let base = Date()
            messages.append(SupportMessage(
                sender: .team, text: "hey, saw your message", date: base))
            messages.append(SupportMessage(
                sender: .team, text: "on it now, give me a sec", date: base.addingTimeInterval(1)))
            lastRead = .distantPast
        }
        #endif
    }

    /// Removes only the cache for an account whose server deletion succeeded.
    /// Other signed-in users and the ownerless legacy quarantine are untouched.
    func removeAccountCache(for userID: UUID) {
        defaults.removeObject(forKey: Self.threadKey(for: userID))
        defaults.removeObject(forKey: Self.readKey(for: userID))
        if accountID == userID { switchAccount(to: nil) }
    }

    private static func threadKey(for userID: UUID) -> String {
        "aura.support.thread.v5.\(userID.uuidString)"
    }

    private static func readKey(for userID: UUID) -> String {
        "aura.support.lastRead.v2.\(userID.uuidString)"
    }

    private var currentContext: (ownerID: UUID, revision: UInt64)? {
        guard let accountID, accountID == SupabaseManager.shared.currentUserID else { return nil }
        return (accountID, identityRevision)
    }

    private func isCurrent(ownerID: UUID, revision: UInt64) -> Bool {
        accountID == ownerID
            && identityRevision == revision
            && SupabaseManager.shared.currentUserID == ownerID
    }

    /// Appends the message locally and sends it through the `support-send` edge
    /// function, which persists it and relays it into the founders' Slack thread.
    /// The bubble tracks delivery: `.sending` while in flight, then `.sent` or
    /// `.failed` (which surfaces a "Not delivered" hint + retry).
    func send(_ text: String) {
        guard let context = currentContext else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var msg = SupportMessage(sender: .me, text: trimmed)
        msg.delivery = .sending
        messages.append(msg)
        persist()
        deliverText(id: msg.id, text: trimmed,
                    ownerID: context.ownerID, revision: context.revision)
    }

    /// Runs (or re-runs) the text relay for a message and records the outcome.
    private func deliverText(id: UUID, text: String, ownerID: UUID, revision: UInt64) {
        guard isCurrent(ownerID: ownerID, revision: revision) else { return }
        setDelivery(id, .sending)
        Task {
            guard isCurrent(ownerID: ownerID, revision: revision) else { return }
            let ok = await SupabaseManager.shared.sendSupportMessage(
                text, messageID: id, expectedUserID: ownerID)
            guard isCurrent(ownerID: ownerID, revision: revision) else { return }
            setDelivery(id, ok ? .sent : .failed)
        }
    }

    /// Sends one media attachment: shows it instantly (images preview from the
    /// picked bytes), uploads it, then relays the signed URL through `support-send`.
    /// The next refresh reconciles the optimistic copy with its server row by URL.
    func sendMedia(_ data: Data, mime: String, ext: String, filename: String) {
        guard let context = currentContext else { return }
        var msg = SupportMessage(sender: .me, text: "")
        if mime.hasPrefix("image/") { msg.localImage = data } else { msg.localMedia = data }
        msg.mediaMime = mime
        msg.mediaName = filename
        msg.delivery = .sending
        messages.append(msg)
        persist()
        deliverMedia(id: msg.id, data: data, mime: mime, ext: ext, filename: filename,
                     ownerID: context.ownerID, revision: context.revision)
    }

    /// Runs (or re-runs) the upload + relay for a media message, recording the
    /// outcome. A failed upload leaves the bubble `.failed` with its bytes retained
    /// (this session) so a retry can re-upload.
    private func deliverMedia(
        id: UUID, data: Data, mime: String, ext: String, filename: String,
        ownerID: UUID, revision: UInt64
    ) {
        guard isCurrent(ownerID: ownerID, revision: revision) else { return }
        setDelivery(id, .sending)
        Task {
            guard isCurrent(ownerID: ownerID, revision: revision) else { return }
            guard let url = await SupabaseManager.shared.uploadSupportAttachment(
                data: data, fileExtension: ext, contentType: mime,
                expectedUserID: ownerID) else {
                guard isCurrent(ownerID: ownerID, revision: revision) else { return }
                setDelivery(id, .failed)
                return
            }
            guard isCurrent(ownerID: ownerID, revision: revision) else { return }
            if let i = messages.firstIndex(where: { $0.id == id }) {
                messages[i].mediaURL = url
                persist()
            }
            let ok = await SupabaseManager.shared.sendSupportMessage(
                "", messageID: id, mediaURL: url, mediaMime: mime, mediaName: filename,
                expectedUserID: ownerID)
            guard isCurrent(ownerID: ownerID, revision: revision) else { return }
            setDelivery(id, ok ? .sent : .failed)
        }
    }

    /// Retries a failed send. Text always retries; media retries while its bytes are
    /// still in memory (images keep `localImage`, other media keep `localMedia`). A
    /// media message whose bytes are gone (e.g. after an app restart) can't re-send.
    func retry(_ id: UUID) {
        guard let context = currentContext else { return }
        guard let msg = messages.first(where: { $0.id == id }), msg.delivery == .failed else { return }
        if let mime = msg.mediaMime {
            guard let data = msg.localImage ?? msg.localMedia else { return }
            deliverMedia(id: id, data: data, mime: mime, ext: Self.ext(for: mime),
                         filename: msg.mediaName ?? "attachment",
                         ownerID: context.ownerID, revision: context.revision)
        } else {
            deliverText(id: id, text: msg.text,
                        ownerID: context.ownerID, revision: context.revision)
        }
    }

    /// A file extension for a mime, so a retry re-uploads with the right suffix.
    private static func ext(for mime: String) -> String {
        switch mime {
        case "audio/m4a", "audio/mp4", "audio/x-m4a": return "m4a"
        case let m where m.hasPrefix("image/"): return "jpg"
        default: return "dat"
        }
    }

    /// Sets a message's delivery state and persists (state is part of the local copy).
    private func setDelivery(_ id: UUID, _ state: SupportMessage.Delivery) {
        guard let i = messages.firstIndex(where: { $0.id == id }) else { return }
        let oldState = messages[i].delivery
        messages[i].delivery = state
        persist()
        guard oldState != state else { return }
        if state == .sent { Haptics.notify(.success) }
        if state == .failed { Haptics.notify(.error) }
    }

    /// Loads the whole thread from the server and merges what is new. History (the
    /// first load, plus the user's own messages) merges silently; a founder reply
    /// that arrives while the chat is open eases in behind the typing indicator.
    /// Safe to call repeatedly; a no-op when there is nothing new.
    func refresh() async {
        guard let context = currentContext,
              refreshInFlightRevision != context.revision else { return }
        refreshInFlightRevision = context.revision
        defer {
            if identityRevision == context.revision {
                refreshInFlightRevision = nil
                isTeamTyping = false
            }
        }

        let convo = await SupabaseManager.shared.fetchConversation(expectedUserID: context.ownerID)
        guard !Task.isCancelled,
              isCurrent(ownerID: context.ownerID, revision: context.revision) else { return }
        let fresh = convo.filter { !serverIDs.contains($0.id) }
        guard !fresh.isEmpty else { didInitialLoad = true; return }

        // Only a founder reply that lands after the first load animates.
        let isLive = didInitialLoad
        if isLive && fresh.contains(where: { $0.sender == "team" }) {
            isTeamTyping = true
            do {
                try await Task.sleep(for: .seconds(1.2))
            } catch {
                return
            }
            guard isCurrent(ownerID: context.ownerID, revision: context.revision) else { return }
        }

        for row in fresh {
            serverIDs.insert(row.id)
            let sender: SupportMessage.Sender = row.sender == "team" ? .team : .me
            // Reconcile an optimistic local send with its server copy: media by URL,
            // text by content. Keep the local image bytes so it does not re-fetch.
            if sender == .me,
               let i = messages.firstIndex(where: { m in
                   guard m.sender == .me, m.serverID == nil else { return false }
                   if let rurl = row.mediaURL { return m.mediaURL == rurl }
                   return m.mediaURL == nil && m.text == row.text
               }) {
                var replacement = SupportMessage(
                    id: messages[i].id, sender: .me, text: row.text, date: row.date,
                    mediaURL: row.mediaURL, mediaMime: row.mediaMime, mediaName: row.mediaName)
                replacement.localImage = messages[i].localImage
                replacement.localMedia = messages[i].localMedia
                replacement.serverID = row.id
                messages[i] = replacement
            } else {
                var message = SupportMessage(
                    id: row.id, sender: sender, text: row.text, date: row.date,
                    mediaURL: row.mediaURL, mediaMime: row.mediaMime, mediaName: row.mediaName)
                message.serverID = row.id
                messages.append(message)
            }
        }

        // Welcome messages stay pinned first; the rest sort by time.
        messages.sort { a, b in
            if a.isWelcome != b.isWelcome { return a.isWelcome }
            return a.date < b.date
        }
        isTeamTyping = false
        didInitialLoad = true
        persist()
    }

    private func persist() {
        guard let accountID else { return }
        if let data = try? JSONEncoder().encode(messages) {
            defaults.set(data, forKey: Self.threadKey(for: accountID))
        }
    }

    /// The welcome broadcast, written first-person from Hayden. Followed in the UI
    /// by the "Book a call with me" button that opens the Cal.com founder booking.
    private static func seed() -> [SupportMessage] {
        let base = Date()
        return [
            SupportMessage(sender: .team,
                           text: "Hey, it's Hayden. One of the founders of Aura",
                           date: base, isWelcome: true),
            SupportMessage(sender: .team,
                           text: "If something's broken, confusing, or you've got a cool idea, text me here. I read every message",
                           date: base.addingTimeInterval(1), isWelcome: true),
            SupportMessage(sender: .team,
                           text: "Or if you wanna hop on a video call we can do that too",
                           date: base.addingTimeInterval(2), isWelcome: true),
            SupportMessage(sender: .team,
                           text: "Grab a time with me below 👇",
                           date: base.addingTimeInterval(3), isWelcome: true),
        ]
    }
}

// MARK: - View

struct SupportChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var chat = SupportChatStore.shared
    @State private var draft = ""
    @FocusState private var composerFocused: Bool

    /// Whether there is a signed-in account. Messaging needs one (RLS scopes the
    /// thread to the user), so when signed out we prompt to sign in with a native
    /// alert rather than silently dropping messages. Booking a call still works
    /// without an account (it lives on the Profile screen too).
    @State private var signedIn = SupabaseManager.shared.currentUserID != nil
    @State private var showSignIn = false
    /// The sign-in prompt dialog shown to a signed-out visitor who taps the composer.
    @State private var showSignInPrompt = false
    // Media attachment (Messages-style): a recent-media store, the ordered
    // selection from the inline grid, and the two toggles for the + popup menu and
    // the inline grid / camera.
    #if DEBUG
    @State private var mediaStore = RecentMediaStore()
    #else
    @State private var mediaStore = RecentMediaStore(allowsVideos: false)
    #endif
    @State private var selectedAssets: [PHAsset] = []
    @State private var showAttachMenu = false
    @State private var showPhotosGrid = false
    @State private var showFullPicker = false
    @State private var showCamera = false
    @State private var showFileImporter = false
    @State private var cameraIdentityContext: SupportChatStore.IdentityContext?
    @State private var fileIdentityContext: SupportChatStore.IdentityContext?
    @State private var dictator = SpeechDictator()
    @State private var recorder = VoiceRecorder()
    /// A finished recording awaiting review (play back / delete / send).
    @State private var recordedPreview: URL?
    @State private var attachmentError: String?
    /// Booking / links open in an in-app browser (Cal.com booking, the founders card).
    @State private var browserLink: BrowserLink?
    /// Full-picker: whether the Collections (albums) tab is showing, and the name of
    /// the album currently feeding the grid (nil = the whole library / recents).
    @State private var showCollections = false
    @State private var activeAlbumTitle: String?
    /// Measured height of the bottom bar (input row + open sheet), used to inset the
    /// thread so its newest messages sit above the bar rather than behind it.
    @State private var bottomBarHeight: CGFloat = 0
    /// Live downward drag on the composer while the grid is open: it follows the
    /// finger and snaps back unless the drag passes the dismiss threshold.
    @State private var gridDragOffset: CGFloat = 0

    private let ground = Color(hex: "0B0B0C")

    // Native-composer corner radii, off the Theme.Radius scale by design (they
    // trace iMessage's own geometry). Named here so the value isn't repeated raw
    // across the composer pill, attach menu, and full-picker sheet (§2/§12).
    private static let composerCornerRadius: CGFloat = 22
    private static let sheetCornerRadius: CGFloat = 44

    /// The founder booking page. Lives here so the Profile "Talk to the founders"
    /// card and the in-chat button point at the exact same place.
    static let foundersBookingURL = URL(string: "https://cal.com/teamaura/founders")!

    var body: some View {
        ZStack(alignment: .top) {
            // The thread fills the whole screen (NOT inset by the bar) so bubbles
            // scroll all the way down and pass BEHIND the floating chrome. Its
            // content is inset instead (see the LazyVStack) so the newest message
            // rests above the bar. A frame inset here would clip bubbles at a hard
            // line — the "something behind the bar" that was cutting them off.
            thread

            // The only thing between the bubbles and the floating chrome: soft blur
            // bands (a blurred copy of the sky) at the top and bottom edges. The
            // bottom band rides up with the input bar when the sheet opens.
            blurBand(.top)
            blurBand(.bottom, cover: bottomBlurCover)
                .animation(.easeInOut(duration: 0.24), value: showPhotosGrid)

            header

            if showAttachMenu {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .onTapGesture {
                        Haptics.impact(.light)
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) { showAttachMenu = false }
                    }
            }

            // The bottom bar (input row + open photo sheet) is a bottom-pinned
            // OVERLAY, not a safe-area inset. An overlay grows UPWARD reliably (the
            // input rises, the sheet stays put at the bottom) and does not shrink the
            // ZStack, so the background never zooms. The thread is inset by its
            // measured height (below) so messages never hide behind it.
            if !showFullPicker {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    bottomBar
                        .offset(y: gridDragOffset)
                        // Sheet open: 16pt off the bottom edge, matching its 16pt
                        // side margins (equal spacing all around). Sheet closed: sit
                        // above the home indicator so the input isn't jammed at the
                        // edge and the + stays out of the home-gesture zone.
                        .padding(.bottom, showPhotosGrid ? Theme.Spacing.l : Self.homeIndicatorInset)
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .onAppear { bottomBarHeight = geo.size.height }
                                    .onChange(of: geo.size.height) { _, h in bottomBarHeight = h }
                            }
                        )
                }
                .ignoresSafeArea(.container, edges: .bottom)
            }

            if showFullPicker { fullPicker }
        }
        // Background as a layout-neutral modifier (NOT a ZStack child): a
        // `scaledToFill` image as a child stretches the ZStack wider than the
        // screen, which pushed the bubbles off both sides. There is no safe-area
        // inset here anymore, so this no longer corrupts the layout the way it did.
        .background {
            Image("Support Chat Background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { data, isVideo in stageCaptured(data, isVideo: isVideo) }
                .ignoresSafeArea()
        }
        .fileImporter(isPresented: $showFileImporter,
                      allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            guard let context = fileIdentityContext else { return }
            Task { await importFile(url, context: context) }
        }
        .inAppBrowser($browserLink)
        .toolbar(.hidden, for: .navigationBar)
        .onDisappear {
            dictator.stop()
            recorder.cancel()
            if let url = recordedPreview { try? FileManager.default.removeItem(at: url); recordedPreview = nil }
        }
        .onChange(of: chat.accountID) { _, accountID in
            resetComposerForAccountChange()
            signedIn = accountID != nil && accountID == SupabaseManager.shared.currentUserID
        }
        .onChange(of: recorder.autoFinishedURL) { _, url in
            guard let url else { return }
            recordedPreview = url
            recorder.clearAutoFinishedURL()
        }
        .fullScreenCover(isPresented: $showSignIn) {
            AccountSignInSheet(onSignedIn: {
                // HabitStore owns the authoritative identity switch. A stale sheet
                // callback must never recreate an account the app already cleared.
                let context = chat.identityContext
                guard let accountID = context.accountID,
                      accountID == SupabaseManager.shared.currentUserID else { return }
                signedIn = true
                Task { await chat.refresh() }
            })
        }
        // Messaging needs an account: prompt with a native iOS alert, styled
        // exactly like the app's other alerts (system default, no custom tint).
        // Signing in opens the account sheet.
        .alert("Sign in to message the founders", isPresented: $showSignInPrompt) {
            Button("Sign in") { showSignIn = true }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("You need an account to send messages to the founders.")
        }
        .alert("Attachment unavailable", isPresented: Binding(
            get: { attachmentError != nil },
            set: { if !$0 { attachmentError = nil } }
        )) {
            Button("OK", role: .cancel) { attachmentError = nil }
        } message: {
            Text(attachmentError ?? "Please try again.")
        }
        .task(id: chat.accountID) {
            // The booking card is fully static (bundled image + title), so no
            // link-preview prefetch is needed here anymore.
            // Reconcile the signed-in state with a real session check, then load
            // founder replies and poll lightly while the chat is visible so
            // answers land without reopening. `.task` cancels when the view goes.
            let context = chat.identityContext
            let hasSession = await SupabaseManager.shared.hasValidSession()
            guard !Task.isCancelled, chat.isCurrent(context) else { return }
            signedIn = hasSession
                && context.accountID != nil
                && context.accountID == SupabaseManager.shared.currentUserID
            // Signed out: surface the sign-in prompt right away.
            guard signedIn else {
                showSignInPrompt = true
                return
            }
            await chat.refresh()
            guard !Task.isCancelled, chat.isCurrent(context) else { return }
            chat.markRead()   // opening the chat clears the Profile unread badge
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(15))
                } catch {
                    return
                }
                await chat.refresh()
                guard !Task.isCancelled, chat.isCurrent(context) else { return }
                chat.markRead()   // replies that arrive while it's open stay read
            }
        }
    }

    /// Drafts and picked media belong to the account that created them. Clear them
    /// synchronously with the store's identity switch so they cannot be sent by the
    /// next account if a sign-in sheet changes identity over this view.
    private func resetComposerForAccountChange() {
        dictator.stop()
        recorder.cancel()
        if let url = recordedPreview { try? FileManager.default.removeItem(at: url) }
        recordedPreview = nil
        draft = ""
        selectedAssets = []
        showAttachMenu = false
        showPhotosGrid = false
        showFullPicker = false
        showCamera = false
        showFileImporter = false
        cameraIdentityContext = nil
        fileIdentityContext = nil
        activeAlbumTitle = nil
        composerFocused = false
    }

    // MARK: Header

    private var header: some View {
        ZStack {
            // Centered avatar sitting on the name pill — the intervention chrome.
            VStack(spacing: -Theme.Spacing.xs) {
                Image("AuraAppIcon")
                    .resizable().scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                    .zIndex(1)

                Text("Team Aura")
                    .auraFont(.body, 15, .semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.vertical, 5)
                    .background { foxChatGlass(Capsule()).overlay(Capsule().fill(Color.black.opacity(0.14))) }
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
            }

            HStack {
                headerCircleButton(systemName: "chevron.left", label: "Back") { dismiss() }
                Spacer()
                // Book a call with the founders. This uses the same approved,
                // engraved bell artwork as the routine controls elsewhere in Aura;
                // only its action and accessibility label are chat-specific.
                headerCircleButton(systemName: "bell", label: "Book a call") {
                    browserLink = BrowserLink(url: Self.foundersBookingURL)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.top, Theme.Spacing.xs)
        .padding(.bottom, Theme.Spacing.s)
    }

    /// The header's glass circle button — back and book-a-call share it so they are
    /// identical in size, material, and vertical position (only the glyph differs).
    private func headerCircleButton(systemName: String, label: String,
                                    action: @escaping () -> Void) -> some View {
        Button {
            Haptics.impact(.light)
            action()
        } label: {
            if systemName == "chevron.left" || systemName == "bell" {
                WoodButtonArtwork(role: systemName == "bell" ? .routine : .back)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            } else {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background { foxChatGlass(Circle()).overlay(Circle().fill(Color.black.opacity(0.14))) }
                .overlay(Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                // 40pt disc, 44pt hit area (Apple minimum), like OnbTopBar.
                .frame(width: 44, height: 44)
                .contentShape(Circle())
            }
        }
        .buttonStyle(PressBounceStyle(hapticsEnabled: false))
        .accessibilityLabel(label)
    }

    /// A real blur band at the top or bottom edge: a full-screen, gaussian-blurred
    /// copy of the SAME sky, aligned to the base background, masked to a soft ramp
    /// at that edge. Because it is an actual blur of the sky (not a translucent
    /// material laid over it) it keeps the colour and never reads as milky white,
    /// and because the copy is full-screen `scaledToFill` it lines up pixel-for-
    /// pixel with the background behind it. The thread scrolls beneath it and fades
    /// softly under the floating chrome.
    private func blurBand(_ edge: VerticalEdge, cover: CGFloat = 0.10) -> some View {
        let isTop = edge == .top
        // Color.clear owns the layout (screen-sized, neutral); the blurred sky fills
        // it via overlay and is clipped, so this decorative band can't stretch the
        // ZStack wider than the screen the way a bare `scaledToFill` image does.
        //
        // `cover` is how far (as a fraction of the height, from the edge) the blur
        // stays fully opaque before fading out. The bottom band raises its cover to
        // reach the top of the input bar when the sheet opens — so it spans the whole
        // area under the bar with no hard cutoff, only a soft fade above.
        let fade = min(1, cover + 0.06)
        return Color.clear
            .overlay {
                Image("Support Chat Background")
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 3, opaque: true)
            }
            .clipped()
            .mask(
                LinearGradient(
                    stops: [.init(color: .black, location: 0.0),
                            .init(color: .black, location: cover),
                            .init(color: .clear, location: fade)],
                    startPoint: isTop ? .top : .bottom,
                    endPoint: isTop ? .bottom : .top)
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }

    // MARK: Thread

    private var thread: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.s) {
                    dateDivider

                    ForEach(chat.messages) { message in
                        SupportBubble(message: message) {
                            Haptics.impact(.light)
                            chat.retry(message.id)
                        }
                            // Message content is personal; keep it out of replays.
                            .maskedInReplays()
                            .id(message.id)
                            .transition(reduceMotion
                                ? .opacity
                                : .move(edge: .bottom).combined(with: .opacity))
                        // The Cal.com booking link rides directly under the welcome's
                        // "Grab a time with me below" bubble, as a native rich link
                        // preview, so it always sits with that message.
                        if message.isWelcome, message.text == Self.bookingPromptText {
                            bookingLink
                        }
                    }
                    // "Delivered" only under the last send once it actually landed;
                    // a failed send shows its own "Not delivered" hint on the bubble.
                    if let last = chat.messages.last, last.sender == .me,
                       last.delivery == .sent, !chat.isTeamTyping {
                        Text("Delivered")
                            .auraFont(.body, 12, .semibold)
                            .foregroundStyle(.white)
                            // Tight outline + soft drop so white reads on the light sky.
                            .shadow(color: .black.opacity(0.55), radius: 1, y: 0.5)
                            .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.trailing, 4)
                    }
                    if chat.isTeamTyping {
                        TypingBubble()
                            .transition(.opacity)
                    }
                    // Anchor so we can pin to the newest message.
                    Color.clear.frame(height: 1).id(bottomAnchor)
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.top, 104)
                // Content inset (not a frame clip) so the newest message rests above
                // the bar while bubbles still scroll behind it.
                // The short seeded conversation is bottom-anchored like Messages.
                // Give it a little more room above the composer so the timestamp
                // and welcome copy rest higher instead of crowding the lower half.
                .padding(.bottom, bottomBarHeight + Theme.Spacing.xxl)
                .animation(.spring(response: 0.38, dampingFraction: 0.82), value: chat.messages.count)
                .animation(.easeOut(duration: 0.2), value: chat.isTeamTyping)
            }
            // `defaultScrollAnchor(.bottom)` opens the thread pinned to the newest
            // message AND re-pins to the bottom whenever the content size changes (a
            // new message, the typing bubble, or the bar growing as the sheet opens).
            // It does both jobs, so no manual `scrollTo` is needed — and an early
            // scrollTo on a not-yet-laid-out LazyVStack would just land mid-thread and
            // fight this anchor, which is exactly why the thread wasn't opening at the
            // bottom before.
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private let bottomAnchor = "support.thread.bottom"

    /// The bottom safe-area inset (home-indicator height), so the open grid can
    /// clear it. Reads the max across the app's windows (isKeyWindow can be false),
    /// with a sensible fallback.
    private static var homeIndicatorInset: CGFloat {
        let inset = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .map(\.safeAreaInsets.bottom)
            .max() ?? 0
        return inset > 0 ? inset : 34
    }

    private var dateDivider: some View {
        Text(Self.threadTimestamp(chat.messages.first?.date ?? .now))
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.55), radius: 1, y: 0.5)
            .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
            .padding(.bottom, Theme.Spacing.xs)
    }

    /// The thread's lead timestamp, iMessage-style: "Today 9:55 AM",
    /// "Yesterday 6:37 AM", otherwise "Sat, July 4 at 7:26 AM".
    private static func threadTimestamp(_ date: Date) -> String {
        let time = DateFormatter(); time.dateFormat = "h:mm a"
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today \(time.string(from: date))" }
        if cal.isDateInYesterday(date) { return "Yesterday \(time.string(from: date))" }
        let full = DateFormatter(); full.dateFormat = "EEE, MMMM d 'at' h:mm a"
        return full.string(from: date)
    }

    /// The exact welcome line the booking link rides under.
    static let bookingPromptText = "Grab a time with me below 👇"

    /// The founder-call CTA as a native iOS rich link preview of the Cal.com booking
    /// page (title, site, icon) — the same card iMessage renders for a pasted link.
    /// Left-aligned like an incoming message; tapping it opens the booking page.
    private var bookingLink: some View {
        // Same cap as the bubbles: never past the opposite side of the Dynamic Island.
        // Rendered fully from bundled assets (image + title) so it appears instantly,
        // offline, with no LinkPresentation network fetch. The banner is cal.com's own
        // OG image for this event, shipped as "Support Cal Booking".
        return RichLinkPreview(url: Self.foundersBookingURL, width: SupportBubble.maxContentWidth,
                               reservesImageSpace: true,
                               staticImageName: "Support Cal Booking",
                               staticTitle: "Talk to the founders | Team Aura | Cal.com")
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.impact(.light)
                browserLink = BrowserLink(url: Self.foundersBookingURL)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Theme.Spacing.xs)
    }

    // MARK: Composer

    /// The whole bottom bar: the input row with the photo sheet stacked beneath it.
    /// Pinned to the bottom by the body's overlay, so the sheet stays at the bottom
    /// edge (always fully on screen) while the input rides above it.
    @ViewBuilder private var bottomBar: some View {
        VStack(spacing: 8) {
            // The leading "+" is PERSISTENT across composer / recording / preview,
            // so it rotates smoothly into an "×" (and back) instead of the whole
            // bar being swapped. Only the trailing pill changes.
            HStack(alignment: .bottom, spacing: Theme.Spacing.s) {
                attachMenuButton
                trailingPill
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.top, Theme.Spacing.s)
            .padding(.bottom, Theme.Spacing.s)
            .onChange(of: composerFocused) { _, focused in
                if focused { withAnimation(.easeOut(duration: 0.2)) { showPhotosGrid = false } }
            }
            .animation(.spring(response: 0.44, dampingFraction: 0.86), value: selectedAssets.isEmpty)

            if showPhotosGrid && !audioMode { photoSheet }
        }
        // Signed out: the composer stays visible but inert; a tap anywhere on it
        // brings up the sign-in prompt instead of typing into a thread that has no
        // account to attach to.
        .overlay {
            if !signedIn {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Haptics.impact(.light)
                        showSignInPrompt = true
                    }
            }
        }
    }

    /// Whether a voice note is being recorded or reviewed (the leading "+" shows "×").
    private var audioMode: Bool { recorder.isRecording || recordedPreview != nil }

    /// The "×" action: cancel a recording, or delete a reviewed take.
    private func cancelAudio() {
        if recorder.isRecording { cancelVoice() }
        else if recordedPreview != nil { discardPreview() }
    }

    enum ComposerMode { case input, recording, preview }
    private var composerMode: ComposerMode {
        if recorder.isRecording { return .recording }
        if recordedPreview != nil { return .preview }
        return .input
    }

    /// The trailing pill. The dark-glass PILL is PERSISTENT (outside the `.id`); only
    /// the content inside swaps. The OUTGOING content is removed INSTANTLY
    /// (`removal: .identity`) so it never lingers under the incoming — no cross-fade
    /// of two overlapping bars. The INCOMING content scales up + fades in.
    private var trailingPill: some View {
        ZStack {
            contentForMode
                .id(composerMode)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.6).combined(with: .opacity),
                    removal: .identity))
        }
        .frame(maxWidth: .infinity)
        .background { composerPillBackground(cornerRadius: Self.composerCornerRadius) }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: composerMode)
    }

    @ViewBuilder private var contentForMode: some View {
        switch composerMode {
        case .input:
            inputContent
        case .recording:
            recordingContent
        case .preview:
            VoiceNotePreviewBar(url: recordedPreview, onSend: { sendPreview() })
        }
    }

    /// The recording content (the pill background is shared, see trailingPill): a
    /// live coral waveform + timer + stop.
    private var recordingContent: some View {
        let coral = Color(red: 0.99, green: 0.42, blue: 0.41)
        // Stop icon a deeper red; the disc a touch lighter behind it.
        let stopRed = Color(red: 0.82, green: 0.15, blue: 0.13)
        return HStack(spacing: 10) {
            WaveformBars(levels: recorder.levels, color: coral)
                .frame(height: 26)
                .frame(maxWidth: .infinity)
                .animation(.linear(duration: 0.05), value: recorder.levels)
            Text(clockLabel(recorder.elapsed))
                .font(.system(size: 15, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white)

            Button { stopToPreview() } label: {
                ZStack {
                    Circle().fill(Color(red: 0.8, green: 0.24, blue: 0.22).opacity(0.45))
                        .frame(width: 32, height: 32)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(stopRed).frame(width: 12, height: 12)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
    }

    /// The shared dark-glass pill background used by the composer/recording/preview bars.
    private func composerPillBackground(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return foxChatGlass(shape)
            .overlay(shape.fill(Color.black.opacity(0.14)))
            .overlay(shape.strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
    }

    /// Drag the composer down to dismiss the grid: it follows the finger and snaps
    /// back unless the drag passes the threshold.
    private var gridDismissDrag: some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { value in
                if showPhotosGrid { gridDragOffset = max(0, value.translation.height) }
            }
            .onEnded { value in
                guard showPhotosGrid else { return }
                if value.translation.height > 90 {
                    withAnimation(.easeOut(duration: 0.24)) { showPhotosGrid = false; gridDragOffset = 0 }
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { gridDragOffset = 0 }
                }
            }
    }

    /// The message pill. When attachments are staged it expands: their thumbnails
    /// sit above an inset divider, with the text field + send control below. The
    /// `+` stays outside to the left.
    private var inputContent: some View {
        VStack(spacing: 8) {
            if !selectedAssets.isEmpty {
                SelectedMediaStrip(store: mediaStore, selection: $selectedAssets)
                    .padding(.top, 8)
                Rectangle()
                    .fill(Color.white.opacity(0.14))
                    .frame(height: 0.5)
                    .padding(.horizontal, 16)
            }
            HStack(spacing: 6) {
                TextField("", text: $draft,
                          prompt: Text(selectedAssets.isEmpty ? "Message" : "Add comment or Send")
                            .foregroundStyle(.white.opacity(0.55)),
                          axis: .vertical)
                    .font(.system(size: 16.5))
                    .foregroundStyle(.white)
                    .tint(.white)
                    .focused($composerFocused)
                    .lineLimit(1...3)
                trailingControl
            }
            .padding(.leading, 16)
            .padding(.trailing, 6)
            .padding(.vertical, 6)
            .frame(minHeight: 44)
        }
        // Drag the message field down to close the photo sheet. Lives here (not on
        // the whole composer) so it can't swallow taps on the + / Camera / Photos.
        .simultaneousGesture(gridDismissDrag)
        .animation(.easeOut(duration: 0.15), value: canSend)
    }

    /// The collapsed photo sheet: an INSET rounded card (margins on the sides and
    /// bottom, all four corners rounded — like the Frozen Apps sheet), with the photo
    /// grid FILLING it right to the edges, about two and a half rows tall. A grabber
    /// floats over the top of the photos (no black strip). Drag it up to open the
    /// full picker, down to close.
    private var photoSheet: some View {
        let cardWidth = activeScreenBounds().width - 2 * Theme.Spacing.l
        let rows: CGFloat = 2.5
        let gridHeight = InlineMediaGrid.cellSide(width: cardWidth) * rows + 2 * 2
        return InlineMediaGrid(store: mediaStore, selection: $selectedAssets)
            // Pin the card to an explicit width and center it — the grid's scroll
            // view ignores horizontal padding, so `.frame(width:)` is what actually
            // insets it from the screen edges.
            .frame(width: cardWidth, height: gridHeight)
            .background(Color.black)
            // Strong radius, close to the device's own corner (~8pt inside it).
            .clipShape(RoundedRectangle(cornerRadius: Self.sheetCornerRadius, style: .continuous))
            .overlay(alignment: .top) {
                // A drag-handle strip at the very top: the grabber lives here and it
                // owns the drag, so dragging it moves/closes the SHEET rather than
                // scrolling the photos (those scroll on their own below it).
                Color.clear
                    .frame(height: 52)
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(Color.black.opacity(0.4))
                            .frame(width: 40, height: 5)
                            .padding(.top, 8)
                    }
                    .contentShape(Rectangle())
                    .highPriorityGesture(sheetDrag)
            }
            .frame(maxWidth: .infinity)
            .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
    }

    /// Drag the collapsed sheet up to open the full picker, or down to close it. The
    /// sheet follows the finger downward (via the shared `gridDragOffset` that moves
    /// the whole bar) so it slides down just like dragging the input bar.
    private var sheetDrag: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                gridDragOffset = max(0, value.translation.height)
            }
            .onEnded { value in
                if value.translation.height < -60 {
                    gridDragOffset = 0
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                        showPhotosGrid = false
                        showFullPicker = true
                    }
                } else if value.translation.height > 55 {
                    withAnimation(.easeOut(duration: 0.24)) { showPhotosGrid = false; gridDragOffset = 0 }
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { gridDragOffset = 0 }
                }
            }
    }

    /// The full-screen photo picker, opened by dragging the collapsed sheet up: the
    /// same black sheet grown to nearly full height, with a grabber, a title, and a
    /// Done control. Drag it back down to collapse to the short sheet.
    private var fullPicker: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 40, height: 5)
                    .padding(.top, 8).padding(.bottom, 14)

                Text(pickerTitle)
                    .auraFont(.body, 16, .semibold)
                    .foregroundStyle(.white)
                    .padding(.bottom, 14)

                // Clear · [Photos | Collections] segmented · done check — the
                // reference layout, in Aura's glass + blue design system.
                HStack(spacing: 8) {
                    Button { selectedAssets.removeAll() } label: {
                        Text("Clear")
                            .auraFont(.body, 15, .semibold)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .foregroundStyle(selectedAssets.isEmpty ? .white.opacity(0.3) : .white)
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background { foxChatGlass(Capsule()) }
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                    }
                    .disabled(selectedAssets.isEmpty)

                    Spacer(minLength: 0)

                    HStack(spacing: 4) {
                        pickerSegment("Photos", active: !showCollections) {
                            showCollections = false
                        }
                        pickerSegment("Collections", active: showCollections) {
                            showCollections = true
                            mediaStore.loadCollections()
                        }
                    }
                    .frame(width: 200)
                    .padding(3)
                    .background { foxChatGlass(Capsule()) }
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))

                    Spacer(minLength: 0)

                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) { showFullPicker = false }
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(LightSheet.blue))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)

                if showCollections {
                    CollectionsList(store: mediaStore) { album in
                        mediaStore.loadAssets(in: album.collection)
                        activeAlbumTitle = album.title
                        withAnimation(.easeOut(duration: 0.2)) { showCollections = false }
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    InlineMediaGrid(store: mediaStore, selection: $selectedAssets)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(height: activeScreenBounds().height * 0.88)
            .frame(maxWidth: .infinity)
            .background(Color.black)
            // Squircle (continuous) top corners, strong radius like the collapsed sheet.
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 44, topTrailingRadius: 44, style: .continuous))
            .simultaneousGesture(
                DragGesture(minimumDistance: 16).onEnded { value in
                    if value.translation.height > 90 {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                            showFullPicker = false
                            showPhotosGrid = true
                        }
                    }
                }
            )
        }
        .ignoresSafeArea(edges: .bottom)
        .transition(reduceMotion ? .opacity : .move(edge: .bottom))
    }

    private var pickerTitle: String {
        if !selectedAssets.isEmpty { return "\(selectedAssets.count) selected" }
        if showCollections { return "Collections" }
        return activeAlbumTitle ?? "Add photos"
    }

    private func pickerSegment(_ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .auraFont(.body, 14, .semibold)
                .foregroundStyle(.white.opacity(active ? 1 : 0.6))
                .lineLimit(1)
                // Equal-width segments so both highlight pills are the same size.
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background {
                    if active { Capsule().fill(Color.white.opacity(0.2)) }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(PressBounceStyle())
    }

    /// How far up (as a fraction of the screen height) the bottom blur stays opaque.
    /// When the sheet opens it reaches the top of the risen input bar so the blur
    /// spans the whole area beneath the bar rather than cutting off under it.
    private var bottomBlurCover: CGFloat {
        let base: CGFloat = 0.11
        guard showPhotosGrid else { return base }
        let screenH = activeScreenBounds().height
        let cardWidth = activeScreenBounds().width - 2 * Theme.Spacing.l
        let sheetHeight = InlineMediaGrid.cellSide(width: cardWidth) * 2.5 + 4 + Theme.Spacing.s
        return min(0.62, base + sheetHeight / screenH)
    }

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    /// The trailing control inside the input pill: a mic (tap to dictate) when
    /// empty, the blue send button once there is text or a selected attachment.
    /// While dictating, the mic stays (turns red + pulses) so you can tap to stop
    /// even as transcribed text streams in.
    @ViewBuilder private var trailingControl: some View {
        let recording = dictator.isRecording
        // Send shows only when there's something to send AND we're not mid-dictation.
        let showSend = canSend && !recording
        ZStack {
            Button { toggleDictation() } label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(recording ? Color(red: 1.0, green: 0.28, blue: 0.24)
                                               : .white.opacity(0.65))
                    .frame(width: 32, height: 32)
                    .symbolEffect(.pulse, options: .repeating, isActive: recording)
            }
            .buttonStyle(.plain)
            .scaleEffect(showSend ? 0.4 : 1)
            .opacity(showSend ? 0 : 1)
            .allowsHitTesting(!showSend)

            Button { sendTapped() } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 32)
                    .background(Capsule().fill(LightSheet.blue))
            }
            .scaleEffect(showSend ? 1 : 0.4)
            .opacity(showSend ? 1 : 0)
            .allowsHitTesting(showSend)
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.7), value: canSend)
        .animation(.easeOut(duration: 0.2), value: recording)
    }

    /// Starts or stops live dictation. Transcribed text streams into the draft,
    /// appended after whatever was already typed.
    private func toggleDictation() {
        Haptics.impact(.light)
        if dictator.isRecording {
            dictator.stop()
            return
        }
        let context = chat.identityContext
        Task {
            guard await dictator.requestAuthorization() else { return }
            guard !Task.isCancelled, chat.isCurrent(context), context.accountID != nil else { return }
            composerFocused = false
            let base = draft.trimmingCharacters(in: .whitespacesAndNewlines)
            dictator.start { text in
                guard chat.isCurrent(context) else { return }
                draft = base.isEmpty ? text : base + " " + text
            }
        }
    }

    // MARK: + / attachment menu (morphs, like the streak-freeze pill)

    private static let menuSpring: Animation = .spring(response: 0.36, dampingFraction: 0.82)

    /// One control in two states: a `+` circle that morphs into the Camera/Photos
    /// sheet on tap (frame + corner + content animate together, the streak-freeze
    /// technique). The footprint stays 44×44 so the input bar never shifts; the
    /// expanded sheet overflows up and to the right from the button's bottom-left.
    /// The production attachment contract includes camera/photos, voice notes,
    /// and imported files. The server validates the same MIME/size allowlist.
    private static let attachRowHeight: CGFloat = 52
    private var menuHeight: CGFloat {
        CGFloat(cameraAvailable ? 4 : 3) * Self.attachRowHeight
    }

    private var attachMenuButton: some View {
        // A fixed 44×44 footprint keeps the input bar from shifting; the morphing
        // control is an overlay whose FRAME animates (44 -> 250×menuHeight),
        // anchored bottom-left so it grows up and to the right.
        Color.clear
            .frame(width: 44, height: 44)
            .overlay(alignment: .bottomLeading) {
                Group {
                    if showAttachMenu {
                        VStack(spacing: 0) {
                            if cameraAvailable {
                                attachRow(icon: "camera.fill", label: "Camera") { selectCamera() }
                            }
                            attachRow(icon: "photo.fill", label: "Photos") { selectPhotos() }
                            attachRow(icon: "waveform", label: "Audio") { selectVoice() }
                            attachRow(icon: "doc.fill", label: "Files") { selectFiles() }
                        }
                    } else {
                        // One persistent control: the "+" opens the attach menu, and
                        // while recording/reviewing audio it rotates 45° into an "×"
                        // that cancels — the rotation animates in AND back out.
                        Button {
                            Haptics.impact(.light)
                            if audioMode {
                                // The rotation and the pill both animate implicitly.
                                cancelAudio()
                            } else {
                                composerFocused = false
                                withAnimation(Self.menuSpring) { showAttachMenu = true }
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.85))
                                .rotationEffect(.degrees(audioMode ? 45 : 0))
                                .animation(.spring(response: 0.3, dampingFraction: 0.72), value: audioMode)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(audioMode ? "Cancel" : "Add attachment")
                    }
                }
                .frame(width: showAttachMenu ? 250 : 44,
                       height: showAttachMenu ? menuHeight : 44,
                       alignment: showAttachMenu ? .topLeading : .center)
                .background {
                    foxChatGlass(RoundedRectangle(cornerRadius: Self.composerCornerRadius, style: .continuous))
                        .overlay(Color.black.opacity(showAttachMenu ? 0.34 : 0.14))
                }
                .clipShape(RoundedRectangle(cornerRadius: Self.composerCornerRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Self.composerCornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
            }
            .zIndex(100)
    }

    private func selectCamera() {
        withAnimation(Self.menuSpring) { showAttachMenu = false }
        cameraIdentityContext = chat.identityContext
        showCamera = true
    }

    private func selectPhotos() {
        withAnimation(Self.menuSpring) { showAttachMenu = false }
        composerFocused = false
        showCollections = false
        activeAlbumTitle = nil
        withAnimation(.easeOut(duration: 0.22)) { showPhotosGrid = true }
        Task { await mediaStore.load() }
    }

    private func selectFiles() {
        withAnimation(Self.menuSpring) { showAttachMenu = false }
        composerFocused = false
        fileIdentityContext = chat.identityContext
        showFileImporter = true
    }

    private func selectVoice() {
        withAnimation(Self.menuSpring) { showAttachMenu = false }
        composerFocused = false
        withAnimation(.easeOut(duration: 0.2)) { showPhotosGrid = false }
        let context = chat.identityContext
        Task {
            guard await recorder.requestPermission() else {
                attachmentError = "Microphone access is off. Turn it on in Settings to record a voice note."
                return
            }
            guard !Task.isCancelled, chat.isCurrent(context), context.accountID != nil else { return }
            // No withAnimation — `trailingPill` animates its scale/fade implicitly on
            // `composerMode`, exactly like the mic ⇄ send control does on `canSend`.
            recorder.start()
        }
    }

    /// Ends the take and opens the review bar (play back / delete / send); a tap too
    /// short to be a note is just discarded.
    private func stopToPreview() {
        Haptics.impact(.light)
        recordedPreview = recorder.finish()
    }

    /// Sends the reviewed voice note.
    private func sendPreview() {
        guard let url = recordedPreview else { return }
        Haptics.impact(.light)
        defer { try? FileManager.default.removeItem(at: url) }
        guard let data = try? Data(contentsOf: url) else {
            attachmentError = "Aura couldn't read that recording."
            recordedPreview = nil
            return
        }
        guard data.count <= 10 * 1024 * 1024 else {
            attachmentError = "Voice notes must be 10 MB or smaller."
            recordedPreview = nil
            return
        }
        recordedPreview = nil
        chat.sendMedia(data, mime: "audio/mp4", ext: "m4a", filename: "voice-note.m4a")
    }

    /// Throws the reviewed voice note away.
    private func discardPreview() {
        if let url = recordedPreview { try? FileManager.default.removeItem(at: url) }
        recordedPreview = nil
    }

    private func cancelVoice() {
        recorder.cancel()
    }

    /// Reads a picked file's bytes and sends it as one attachment. Images render as
    /// image bubbles; everything else as a tappable file chip.
    private func importFile(_ url: URL, context: SupportChatStore.IdentityContext) async {
        guard chat.isCurrent(context), context.accountID != nil else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            attachmentError = "Aura couldn't read that file."
            return
        }
        guard !Task.isCancelled, chat.isCurrent(context) else { return }
        let ext = url.pathExtension.isEmpty ? "dat" : url.pathExtension.lowercased()
        let rawMime = UTType(filenameExtension: ext)?.preferredMIMEType ?? "application/octet-stream"
        let mime = ["audio/m4a", "audio/x-m4a"].contains(rawMime) ? "audio/mp4" : rawMime
        let allowedExtensions = Set(["pdf", "txt", "m4a", "aac", "mp3", "wav", "jpg", "jpeg", "png", "heic", "heif"])
        guard allowedExtensions.contains(ext) else {
            attachmentError = "That file type isn't supported. Choose a PDF, text, audio, or image file."
            return
        }
        guard data.count <= 10 * 1024 * 1024 else {
            attachmentError = "Files must be 10 MB or smaller."
            return
        }
        chat.sendMedia(data, mime: mime, ext: ext, filename: url.lastPathComponent)
    }

    private func attachRow(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 26)
                Text(label).auraFont(.body, 17, .medium).foregroundStyle(.white)
                Spacer()
            }
            // Fixed row height so the menu's total height is an exact multiple of it —
            // the content centres in each row, giving equal top and bottom padding.
            .padding(.horizontal, 18)
            .frame(height: Self.attachRowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressBounceStyle())
    }

    private var canSend: Bool {
        !selectedAssets.isEmpty || !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Sends the selected media (each as its own message), plus any typed text.
    private func sendTapped() {
        Haptics.impact(.light)
        let context = chat.identityContext
        let caption = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let assets = selectedAssets
        selectedAssets = []
        draft = ""
        withAnimation(.easeOut(duration: 0.22)) { showPhotosGrid = false }
        if !assets.isEmpty { Task { await sendAssets(assets, context: context) } }
        if !caption.isEmpty { chat.send(caption) }
    }

    private func sendAssets(_ assets: [PHAsset], context: SupportChatStore.IdentityContext) async {
        guard chat.isCurrent(context), context.accountID != nil else { return }
        for asset in assets where asset.mediaType == .image {
            if let data = await mediaStore.exportImageJPEG(asset) {
                guard !Task.isCancelled, chat.isCurrent(context) else { return }
                chat.sendMedia(data, mime: "image/jpeg", ext: "jpg", filename: "photo.jpg")
            }
        }
    }

    /// An image camera capture, sent immediately.
    private func stageCaptured(_ data: Data, isVideo: Bool) {
        guard !isVideo else { return }
        guard let context = cameraIdentityContext,
              chat.isCurrent(context), context.accountID != nil else { return }
        cameraIdentityContext = nil
        chat.sendMedia(data, mime: "image/jpeg", ext: "jpg", filename: "photo.jpg")
    }
}

// MARK: - Camera capture

// MARK: - Speech to text

/// Live dictation for the composer: on-device speech recognition streamed into the
/// draft as you talk. Owns the mic tap + recognizer and cleans both up on stop.
/// Permissions: NSSpeechRecognitionUsageDescription + NSMicrophoneUsageDescription.
@MainActor
@Observable
final class SpeechDictator {
    private(set) var isRecording = false
    /// Set when we can't dictate (permission denied or recognizer unavailable), so
    /// the UI can nudge the user to Settings instead of silently doing nothing.
    private(set) var denied = false

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let engine = AVAudioEngine()

    /// Asks for speech + mic permission (once); returns whether both are granted.
    func requestAuthorization() async -> Bool {
        let speech = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard speech == .authorized else { denied = true; return false }
        let mic = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { cont.resume(returning: $0) }
        }
        denied = !mic
        return mic
    }

    /// Starts streaming the running transcript to `onText`. Safe to call only after
    /// `requestAuthorization()` returned true.
    func start(onText: @escaping (String) -> Void) {
        guard let recognizer, recognizer.isAvailable, !isRecording else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let req = SFSpeechAudioBufferRecognitionRequest()
            req.shouldReportPartialResults = true
            request = req

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            // Capture `req` (not self) in the audio-thread tap to avoid touching
            // main-actor state off the main thread.
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                req.append(buffer)
            }
            engine.prepare()
            try engine.start()
            isRecording = true

            task = recognizer.recognitionTask(with: req) { [weak self] result, error in
                Task { @MainActor in
                    if let result { onText(result.bestTranscription.formattedString) }
                    if error != nil || (result?.isFinal ?? false) { self?.stop() }
                }
            }
        } catch {
            stop()
        }
    }

    func stop() {
        guard isRecording else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

// MARK: - Voice notes

/// Records a voice note to a temp `.m4a` (AAC). Exposes `isRecording` + `elapsed`
/// for the recording bar; `finish()` returns the file, `cancel()` discards it.
@MainActor
@Observable
final class VoiceRecorder {
    private(set) var isRecording = false
    private(set) var elapsed: TimeInterval = 0
    /// A rolling window of recent input amplitudes (0...1) for a live waveform.
    private(set) var levels: [CGFloat] = []
    static let levelCount = 34

    private var recorder: AVAudioRecorder?
    private var ticker: Timer?
    private var fileURL: URL?
    private(set) var autoFinishedURL: URL?

    /// Requests mic permission (once); returns whether it's granted.
    func requestPermission() async -> Bool {
        await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { cont.resume(returning: $0) }
        }
    }

    func start() {
        guard !isRecording else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.duckOthers, .defaultToSpeaker])
        try? session.setActive(true)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        guard let rec = try? AVAudioRecorder(url: url, settings: settings) else { return }
        rec.isMeteringEnabled = true
        guard rec.record(forDuration: 120) else { return }
        recorder = rec
        fileURL = url
        elapsed = 0
        levels = Array(repeating: 0.05, count: Self.levelCount)
        isRecording = true
        ticker = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            // Strongify before the hop: capturing the weak `self` optional into the
            // Task is a mutable capture in concurrent code (a Swift 6 error). A
            // strong, immutable `self` (a @MainActor class, so Sendable) is fine.
            guard let self else { return }
            Task { @MainActor in self.sample() }
        }
    }

    /// Reads the current input level and scrolls it into the waveform window.
    private func sample() {
        guard let rec = recorder else { return }
        elapsed = rec.currentTime
        if elapsed >= 120 {
            let url = fileURL
            stopInternal()
            autoFinishedURL = url
            return
        }
        rec.updateMeters()
        // dBFS (~ -60...0) → a lively 0...1 amplitude.
        let power = rec.averagePower(forChannel: 0)
        let amp = CGFloat(max(0, min(1, pow(10, power / 20) * 1.8)))
        levels.append(max(0.05, amp))
        if levels.count > Self.levelCount { levels.removeFirst(levels.count - Self.levelCount) }
    }

    /// Stops and returns the recorded file, or nil if it was too short to be useful.
    func finish() -> URL? {
        let long = elapsed >= 0.5
        stopInternal()
        guard long, let url = fileURL else { cancelFile(); return nil }
        return url
    }

    func cancel() {
        stopInternal()
        cancelFile()
    }

    func clearAutoFinishedURL() { autoFinishedURL = nil }

    private func cancelFile() {
        if let url = fileURL { try? FileManager.default.removeItem(at: url) }
        fileURL = nil
    }

    private func stopInternal() {
        ticker?.invalidate(); ticker = nil
        recorder?.stop(); recorder = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

/// mm:ss (zero-padded, iMessage-style 00:00) for the recording timer / duration.
private func clockLabel(_ seconds: TimeInterval) -> String {
    let s = Int(seconds.rounded())
    return String(format: "%02d:%02d", s / 60, s % 60)
}

/// The thin-bar waveform used by both the recording bar and the voice-note bubble
/// (iMessage style). `levels` are 0...1 heights; bars before `playedFraction` are
/// solid, the rest dimmed. Bars stretch to fill the given width.
private struct WaveformBars: View {
    let levels: [CGFloat]
    var playedFraction: Double = 1
    var color: Color = .white

    var body: some View {
        GeometryReader { geo in
            let n = max(levels.count, 1)
            let spacing: CGFloat = 2
            let barW = max(1.6, (geo.size.width - spacing * CGFloat(n - 1)) / CGFloat(n))
            let played = Int(playedFraction * Double(n))
            HStack(alignment: .center, spacing: spacing) {
                ForEach(levels.indices, id: \.self) { i in
                    Capsule()
                        .fill(color.opacity(i < played ? 1 : 0.32))
                        .frame(width: barW, height: max(2, geo.size.height * levels[i]))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
        }
    }
}

/// A stable pseudo-waveform for a note whose audio hasn't decoded yet, derived from
/// its id so it looks like real audio and stays identical across renders.
private func staticWaveform(for id: UUID, count: Int) -> [CGFloat] {
    let seed = UInt64(bitPattern: Int64(id.hashValue))
    return (0..<count).map { i in
        var x = seed &+ UInt64(i) &* 0x9E3779B97F4A7C15
        x ^= x >> 30; x = x &* 0xBF58476D1CE4E5B9; x ^= x >> 27
        let r = Double(x % 1000) / 1000.0
        let env = 0.4 + 0.6 * abs(sin(Double(i) / Double(count) * .pi * 2.3))
        return CGFloat(max(0.14, min(1, (0.28 + 0.72 * r) * env)))
    }
}

/// The REAL amplitude envelope of an audio clip, downsampled to `buckets` bars —
/// the same idea as Apple's voice-note waveform. Decodes the bytes, takes the RMS
/// of each segment, and normalises to the loudest. Returns nil if it can't decode.
/// `nonisolated` so it can run off the main actor (the decode is CPU work).
private nonisolated func audioWaveform(from data: Data, buckets: Int) -> [CGFloat]? {
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString + ".m4a")
    guard (try? data.write(to: tmp)) != nil else { return nil }
    defer { try? FileManager.default.removeItem(at: tmp) }
    guard let file = try? AVAudioFile(forReading: tmp) else { return nil }
    let format = file.processingFormat
    let frames = AVAudioFrameCount(file.length)
    guard frames > 0,
          let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
          (try? file.read(into: buf)) != nil,
          let samples = buf.floatChannelData?[0] else { return nil }

    let n = Int(buf.frameLength)
    guard n > 0 else { return nil }
    let per = max(1, n / buckets)
    var rms: [Float] = []
    var peak: Float = 0.0001
    for b in 0..<buckets {
        let start = b * per
        let end = min(n, start + per)
        var sum: Float = 0
        var i = start
        while i < end { let v = samples[i]; sum += v * v; i += 1 }
        let value = end > start ? (sum / Float(end - start)).squareRoot() : 0
        peak = max(peak, value)
        rms.append(value)
    }
    return rms.map { CGFloat(max(0.08, min(1, $0 / peak))) }
}

/// A camera sheet that captures images supported by the attachment contract.
private struct CameraPicker: UIViewControllerRepresentable {
    var onCaptured: (Data, Bool) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = ["public.image"]
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage,
                      let jpeg = image.jpegData(compressionQuality: 0.8) {
                parent.onCaptured(jpeg, false)
            }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Audio message bubble

/// A voice-note bubble: play/pause, a progress line, and a running time. Plays
/// from the local bytes when present (a note you just sent), otherwise streams the
/// uploaded file. Blue on the user's side, dark glass on Aura's.
private struct AudioMessagePlayer: View {
    let message: SupportMessage
    let isMe: Bool

    @State private var player: AVAudioPlayer?
    @State private var playing = false
    @State private var current: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var ticker: Timer?
    /// The clip's real amplitude envelope once decoded; a stable placeholder until.
    @State private var computedBars: [CGFloat]?

    /// Reloads when the uploaded URL arrives, but playback prefers local bytes.
    private var sourceKey: String { message.mediaURL ?? message.id.uuidString }

    var body: some View {
        HStack(spacing: 10) {
            Button { toggle() } label: {
                Circle()
                    .fill(.white)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: playing ? "pause.fill" : "play.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(isMe ? LightSheet.blue : Color(white: 0.22))
                            .offset(x: playing ? 0 : 1)     // optical centering of the triangle
                    }
            }
            .buttonStyle(.plain)
            .disabled(player == nil)

            WaveformBars(levels: bars, playedFraction: progressFraction, color: .white)
                .frame(height: 26)
                .frame(maxWidth: .infinity)

            Text(clockLabel(playing || current > 0 ? current : duration))
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.85))
                .frame(minWidth: 34, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(width: 224)
        .background {
            let shape = RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous)
            if isMe { shape.fill(LightSheet.blue) } else { foxChatGlass(shape) }
        }
        .task(id: sourceKey) { await prepare() }
        .onDisappear { stop() }
    }

    /// The real decoded envelope once ready, else a stable per-id placeholder.
    private var bars: [CGFloat] { computedBars ?? staticWaveform(for: message.id, count: 34) }

    private var progressFraction: Double {
        duration > 0 ? min(1, current / duration) : 0
    }

    private func prepare() async {
        guard player == nil else { return }
        var data = message.localMedia
        if data == nil, let s = message.mediaURL, let url = URL(string: s) {
            data = try? await URLSession.shared.data(from: url).0
        }
        guard let data, let p = try? AVAudioPlayer(data: data) else { return }
        p.prepareToPlay()
        player = p
        duration = p.duration
        // Decode the real envelope off the main thread, then swap it in.
        let bytes = data
        if let real = await Task.detached(priority: .utility, operation: {
            audioWaveform(from: bytes, buckets: 34)
        }).value {
            computedBars = real
        }
    }

    private func toggle() {
        guard let player else { return }
        Haptics.impact(.light)
        if player.isPlaying {
            player.pause(); playing = false; stopTicker()
        } else {
            try? AVAudioSession.sharedInstance().setCategory(.playback, options: .duckOthers)
            try? AVAudioSession.sharedInstance().setActive(true)
            player.play(); playing = true; startTicker()
        }
    }

    private func startTicker() {
        stopTicker()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            Task { @MainActor in
                guard let p = player else { return }
                current = p.currentTime
                if !p.isPlaying {
                    playing = false
                    current = 0
                    stopTicker()
                }
            }
        }
    }

    private func stopTicker() { ticker?.invalidate(); ticker = nil }

    private func stop() {
        player?.stop(); playing = false; stopTicker()
    }
}

// MARK: - Voice-note preview

/// The review pill shown after a recording stops (iMessage style): play/pause +
/// waveform + duration + send. Delete is the shared leading "×" (see bottomBar).
private struct VoiceNotePreviewBar: View {
    /// Optional so this can live PERMANENTLY in the pill's ZStack (scaled/hidden when
    /// there's no take), the way mic and send both always exist. Nil = nothing loaded.
    let url: URL?
    var onSend: () -> Void

    @State private var player: AVAudioPlayer?
    @State private var playing = false
    @State private var current: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var bars: [CGFloat] = []
    @State private var ticker: Timer?

    var body: some View {
        HStack(spacing: 10) {
            Button { toggle() } label: {
                Image(systemName: playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.white.opacity(0.18)))
                    .offset(x: playing ? 0 : 1)
            }
            .buttonStyle(.plain)
            .disabled(player == nil)

            WaveformBars(levels: bars.isEmpty ? Array(repeating: 0.3, count: 30) : bars,
                         playedFraction: duration > 0 ? min(1, current / duration) : 0,
                         color: .white)
                .frame(height: 24)
                .frame(maxWidth: .infinity)

            Text(clockLabel(playing || current > 0 ? current : duration))
                .font(.system(size: 14, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.14)))

            Button(action: onSend) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 32)
                    .background(Capsule().fill(LightSheet.blue))
            }
            .buttonStyle(.plain)
        }
        // Play sits as close to the left edge as send is to the right (both 6pt).
        // The pill background is shared by trailingPill, so it isn't drawn here.
        .padding(.leading, 6)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .task(id: url) { await prepare() }
        .onDisappear { stop() }
    }

    private func prepare() async {
        // Reset when there's no take (the pill keeps this view mounted but empty).
        guard let url, let data = try? Data(contentsOf: url) else {
            stop(); player = nil; duration = 0; current = 0; bars = []
            return
        }
        if let p = try? AVAudioPlayer(data: data) {
            p.prepareToPlay(); player = p; duration = p.duration
        }
        if let real = await Task.detached(priority: .utility, operation: {
            audioWaveform(from: data, buckets: 30)
        }).value { bars = real }
    }

    private func toggle() {
        guard let player else { return }
        Haptics.impact(.light)
        if player.isPlaying {
            player.pause(); playing = false; stopTicker()
        } else {
            try? AVAudioSession.sharedInstance().setCategory(.playback, options: .duckOthers)
            try? AVAudioSession.sharedInstance().setActive(true)
            player.play(); playing = true; startTicker()
        }
    }

    private func startTicker() {
        stopTicker()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            Task { @MainActor in
                guard let p = player else { return }
                current = p.currentTime
                if !p.isPlaying { playing = false; current = 0; stopTicker() }
            }
        }
    }

    private func stopTicker() { ticker?.invalidate(); ticker = nil }
    private func stop() { player?.stop(); playing = false; stopTicker() }
}

// MARK: - Collections list

/// The Collections tab of the full picker: the user's albums, each a tappable row
/// with a cover, name and count. Picking one loads it into the photo grid.
private struct CollectionsList: View {
    let store: RecentMediaStore
    let onPick: (MediaCollection) -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            if store.collections.isEmpty {
                Text("No albums yet")
                    .auraFont(.body, 15, .medium)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 48)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(store.collections) { album in
                        Button { onPick(album) } label: {
                            CollectionRow(store: store, album: album)
                        }
                        .buttonStyle(PressBounceStyle())
                        Rectangle().fill(Color.white.opacity(0.08)).frame(height: 0.5).padding(.leading, 86)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

private struct CollectionRow: View {
    let store: RecentMediaStore
    let album: MediaCollection
    @State private var cover: UIImage?

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                if let cover {
                    Image(uiImage: cover).resizable().scaledToFill()
                } else {
                    Rectangle().fill(Color.white.opacity(0.08))
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(album.title).auraFont(.body, 16, .medium).foregroundStyle(.white)
                Text("\(album.count)").auraFont(.body, 13, .regular).foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .task(id: album.id) {
            if let asset = album.cover {
                cover = await store.thumbnail(for: asset, size: CGSize(width: 120, height: 120))
            }
        }
    }
}

// MARK: - Rich link preview

/// A rich link preview card — image on top, title + host on a light bar below, the
/// same shape iMessage renders for a pasted link. It's a custom SwiftUI card (rather
/// than `LPLinkView`) so it renders at an EXACT width with the preview image kept;
/// `LPLinkView` drops the image once it's constrained narrower than its own wide
/// layout. It still uses `LPMetadataProvider` for the real title and preview image.
private struct RichLinkPreview: View {
    let url: URL
    let width: CGFloat
    /// Reserve the image band up front (with a placeholder while it loads) so a
    /// link KNOWN to have an image never resizes as its metadata arrives. Left off
    /// for arbitrary message links, whose image presence isn't known ahead of time.
    let reservesImageSpace: Bool
    /// When set, the card renders entirely from bundled assets (a shipped preview
    /// image + fixed title) and never touches the network — instant, offline, and
    /// no waiting on LinkPresentation. Used for the fixed founders' booking link.
    let isStatic: Bool

    @State private var image: UIImage?
    @State private var title: String?

    init(url: URL, width: CGFloat, reservesImageSpace: Bool = false,
         staticImageName: String? = nil, staticTitle: String? = nil) {
        self.url = url
        self.width = width
        self.reservesImageSpace = reservesImageSpace
        self.isStatic = staticImageName != nil
        // A static card paints from a bundled image + fixed title on the first frame.
        // Otherwise seed from cache so a prefetched link still paints immediately
        // (no grow-in); an uncached link starts compact and fills in when it loads.
        let staticImage = staticImageName.flatMap { UIImage(named: $0) }
        _image = State(initialValue: staticImage ?? Self.imageCache[url])
        _title = State(initialValue: staticTitle ?? Self.cache[url]?.title)
    }

    /// Cached metadata (+ image) so the card renders immediately, no grow-in.
    static var cache: [URL: LPLinkMetadata] = [:]
    static var imageCache: [URL: UIImage] = [:]

    static func prefetch(_ url: URL) {
        guard cache[url] == nil else { return }
        LPMetadataProvider().startFetchingMetadata(for: url) { metadata, _ in
            guard let metadata else { return }
            DispatchQueue.main.async { cache[url] = metadata }
            metadata.imageProvider?.loadObject(ofClass: UIImage.self) { obj, _ in
                if let img = obj as? UIImage { DispatchQueue.main.async { imageCache[url] = img } }
            }
        }
    }

    private var host: String { (url.host ?? "").replacingOccurrences(of: "www.", with: "") }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The image band shows the preview image once loaded. When the link is
            // known to have one (`reservesImageSpace`) the band is reserved up front
            // with a placeholder, so the card never grows; otherwise an imageless
            // link just collapses to a compact title + host card.
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(width: width, height: (width * 0.54).rounded())
                    .clipped()
            } else if reservesImageSpace {
                Rectangle().fill(Color(white: 0.86))
                    .frame(width: width, height: (width * 0.54).rounded())
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title ?? host)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(host)
                    .font(.system(size: 13))
                    .foregroundStyle(.black.opacity(0.5))
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(width: width, alignment: .leading)
            .background(Color(white: 0.82))
        }
        .frame(width: width)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .task(id: url) { if !isStatic { await load() } }
    }

    private func load() async {
        if let img = Self.imageCache[url] { image = img }
        let metadata: LPLinkMetadata
        if let cached = Self.cache[url] {
            metadata = cached
        } else if let fetched = try? await LPMetadataProvider().startFetchingMetadata(for: url) {
            Self.cache[url] = fetched
            metadata = fetched
        } else {
            return
        }
        title = metadata.title
        guard image == nil, let provider = metadata.imageProvider else { return }
        provider.loadObject(ofClass: UIImage.self) { obj, _ in
            guard let img = obj as? UIImage else { return }
            Task { @MainActor in
                Self.imageCache[url] = img
                self.image = img
            }
        }
    }
}

// MARK: - Bubble

/// One message bubble, sided by sender. Incoming (team) is a flat dark-gray
/// bubble on the left; outgoing (me) is Aura blue on the right — matching the
/// reference. Timestamp rides under the bubble on the same side.
private struct SupportBubble: View {
    let message: SupportMessage
    var onRetry: (() -> Void)? = nil
    @Environment(\.openURL) private var openURL

    /// iMessage's bubble corner radius (off the Theme.Radius scale by design).
    private static let bubbleRadius: CGFloat = 18

    private var isMe: Bool { message.sender == .me }
    private var failed: Bool { isMe && message.delivery == .failed }
    /// A failed send is retryable when we still have what it takes to resend: text
    /// is always in hand; media needs its bytes (an image kept `localImage`; a
    /// message whose bytes are gone after a restart can't be re-uploaded).
    private var canRetry: Bool {
        guard failed else { return false }
        return message.mediaMime == nil || message.localImage != nil || message.localMedia != nil
    }
    /// A media message is one that carries ANY media signal — including a mime
    /// alone, before its bytes/URL resolve. Without the mime check a video (or a
    /// still-uploading / failed attachment) would fall through to an empty text
    /// bubble, which is exactly the blank pill we don't want.
    private var hasMedia: Bool {
        message.localImage != nil || message.mediaURL != nil || message.mediaMime != nil
    }
    private var isImage: Bool {
        message.localImage != nil || (message.mediaMime?.hasPrefix("image/") ?? false)
    }
    private var isAudio: Bool { message.mediaMime?.hasPrefix("audio/") ?? false }
    /// Nothing to render at all: no media and no visible text. Guards against a
    /// stale or malformed message ever showing as an empty bubble.
    private var isEmpty: Bool {
        !hasMedia && message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Detects a link in the message text so it can render as a rich card (and be
    /// tappable), the way any messaging app previews a URL you send. Shared across
    /// bubbles; the type is cheap but not free to build, so it's made once.
    private static let linkDetector = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.link.rawValue)

    /// The first http(s) link in the message, if any.
    private var detectedURL: URL? {
        guard !hasMedia, let detector = Self.linkDetector else { return nil }
        let text = message.text
        let full = NSRange(text.startIndex..., in: text)
        guard let match = detector.firstMatch(in: text, options: [], range: full),
              let url = match.url, url.scheme?.hasPrefix("http") == true else { return nil }
        return url
    }

    /// True when the message is JUST the link (nothing else worth showing as text),
    /// so the card stands alone like a sent link in iMessage. Compared loosely,
    /// since a typed "cal.com/x" has no scheme while the detected URL does.
    private func isBareLink(_ url: URL) -> Bool {
        func normalized(_ s: String) -> String {
            var t = s.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            for prefix in ["https://", "http://"] where t.hasPrefix(prefix) { t.removeFirst(prefix.count) }
            if t.hasPrefix("www.") { t.removeFirst(4) }
            if t.hasSuffix("/") { t.removeLast() }
            return t
        }
        return normalized(message.text) == normalized(url.absoluteString)
    }

    /// iMessage rule: a bubble's far edge never passes the OPPOSITE side of the
    /// Dynamic Island (≈ screen centre + half the island's width), measured from the
    /// thread's leading inset. The link card uses the same cap.
    @MainActor
    static var maxContentWidth: CGFloat {
        activeScreenBounds().width / 2 + 62 - Theme.Spacing.l
    }

    var body: some View {
        if isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .trailing, spacing: 3) {
                HStack(spacing: 0) {
                    if isMe { Spacer(minLength: 0) }
                    content.frame(maxWidth: Self.maxContentWidth, alignment: isMe ? .trailing : .leading)
                    if !isMe { Spacer(minLength: 0) }
                }
                if failed { failedHint }
            }
            .frame(maxWidth: .infinity, alignment: isMe ? .trailing : .leading)
        }
    }

    /// The iMessage-style "Not delivered" line under a failed send, tappable to
    /// retry when a retry is actually possible. NOTE: a non-retryable pill must NOT
    /// use `.disabled` — that fades the whole chip, so it wouldn't match the
    /// retryable one. Instead the tap is only wired when a retry can happen.
    private var failedHint: some View {
        let chip = HStack(spacing: 5) {
            Image(systemName: "exclamationmark.circle.fill")
            Text(canRetry ? "Not delivered. Tap to retry" : "Not delivered")
        }
        .auraFont(.caption, 12, .semibold)
        // Bright red on the same dark glass as Aura's own bubbles, identical in both
        // states so the chip always matches the thread and reads over the bright sky.
        .foregroundStyle(Color(red: 1.0, green: 0.28, blue: 0.24))
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background { foxChatGlass(Capsule()) }

        return Group {
            if canRetry {
                Button { onRetry?() } label: { chip }.buttonStyle(.plain)
            } else {
                chip
            }
        }
        .padding(.trailing, 4)
        .padding(.top, 1)
    }

    @ViewBuilder private var content: some View {
        if hasMedia {
            if isImage { imageBubble }
            else if isAudio { AudioMessagePlayer(message: message, isMe: isMe) }
            else { fileBubble }
        } else if let url = detectedURL {
            linkMessage(url)
        } else {
            textBubble
        }
    }

    /// A message containing a link: the rich preview card (tappable), with the
    /// text bubble kept above it unless the message was nothing but the link.
    private func linkMessage(_ url: URL) -> some View {
        VStack(alignment: isMe ? .trailing : .leading, spacing: 6) {
            if !isBareLink(url) { textBubble }
            RichLinkPreview(url: url, width: Self.maxContentWidth)
                .contentShape(Rectangle())
                .onTapGesture {
                    Haptics.impact(.light)
                    openURL(url)
                }
        }
    }

    /// Aura (incoming) wears the intervention dark glass; the user keeps blue.
    @ViewBuilder private func bubbleBackground<S: Shape>(_ shape: S) -> some View {
        if isMe { shape.fill(LightSheet.blue) } else { foxChatGlass(shape) }
    }

    private var textBubble: some View {
        Text(message.text)
            .auraFont(.body, 15, .medium)
            .foregroundStyle(.white)
            // Floor the text width so a very short (or empty) message can't collapse
            // into a tall thin oval — the shortest bubble stays a proper pill.
            .frame(minWidth: 26)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background { bubbleBackground(RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous)) }
    }

    private var imageBubble: some View {
        Group {
            if let data = message.localImage, let ui = UIImage(data: data) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else if let s = message.mediaURL, let url = URL(string: s) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    case .failure: placeholder(failed: true)
                    default: placeholder(failed: false)
                    }
                }
            } else {
                placeholder(failed: true)
            }
        }
        .frame(width: 220, height: 220)
        .clipShape(RoundedRectangle(cornerRadius: Self.bubbleRadius, style: .continuous))
    }

    private func placeholder(failed: Bool) -> some View {
        ZStack {
            Rectangle().fill(Color.white.opacity(0.08))
            if failed {
                Image(systemName: "photo").font(.system(size: 28)).foregroundStyle(.white.opacity(0.4))
            } else {
                ProgressView().tint(.white)
            }
        }
    }

    /// Non-image attachments (a file/audio/video an operator sends). A tappable
    /// chip that opens the file; full inline players come in a later phase.
    private var fileBubble: some View {
        let name = message.mediaName ?? "Attachment"
        let chip = HStack(spacing: 10) {
            Image(systemName: "paperclip").font(.system(size: 18, weight: .semibold))
            Text(name).font(.system(size: 15, weight: .medium)).lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background { bubbleBackground(RoundedRectangle(cornerRadius: Self.bubbleRadius, style: .continuous)) }
        return Group {
            if let s = message.mediaURL, let url = URL(string: s) {
                Link(destination: url) { chip }
            } else {
                chip
            }
        }
    }
}

// MARK: - Typing indicator

/// The three-dot "typing" bubble, styled like an incoming message. Shown for a
/// beat right before a real reply lands, so the reply eases in instead of
/// snapping onto the screen.
private struct TypingBubble: View {
    @State private var animating = false

    var body: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(0.55))
                        .frame(width: 7, height: 7)
                        .opacity(animating ? 1 : 0.3)
                        .animation(
                            .easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.2),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background { foxChatGlass(RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous)) }
            Spacer(minLength: 44)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { animating = true }
    }
}

#Preview {
    SupportChatView()
}
