//
//  MessageThreadView.swift
//  Aura iOS
//

import SwiftUI
import FamilyControls
import ManagedSettings

/// The intervention as a text thread with the fox.
///
/// The only style that isn't a preamble onto the shared conversation: here the
/// thread *is* the conversation. Every beat the other styles show as a screen —
/// the challenge, the duration, the price — arrives as a message, and your
/// answers are replies you tap and then watch yourself send.
///
/// That's the whole reason it works. Choosing "30 mins" from a row of buttons is
/// a setting; watching "30 mins" appear in your own bubble is something you
/// said.
struct MessageThreadView: View {
    var appName: String?
    var appToken: ApplicationToken?
    var onFinish: () -> Void

    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private struct Message: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let isAura: Bool
    }

    private struct Reply: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let action: Action

        enum Action: Equatable {
            case backOut
            case insist
            case pick(Int)
        }
    }

    @State private var messages: [Message] = []
    @State private var replies: [Reply] = []
    @State private var isTyping = false
    /// Chosen but not yet paid for. Drives the hold button at the foot of the
    /// thread — picking is a reply, paying is a commitment.
    @State private var pending: Int?
    /// Set once the fox says you're broke, so the thread waits on a "Got it" tap
    /// to close instead of vanishing on its own.
    @State private var broke = false
    /// The run's script, rolled once when the thread opens. Same idea as the
    /// dialogue style's `InterventionScript` — a daily user shouldn't read the
    /// exact same texts every time.
    @State private var thread = ThreadScript.random

    /// Measured heights, so the auto-scroll only fires when the thread actually
    /// overflows — otherwise `scrollTo` bounces content that already fits.
    @State private var contentHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0

    private static let durations = [10, 20, 30]

    /// One full run of the thread. Three rotate at random, the same way the
    /// dialogue style's `InterventionScript.all` does. Only the fox's lines
    /// vary; the user's reply buttons and the hold captions stay constant.
    private struct ThreadScript {
        let opener: String
        let challengeWithApp: String   // %@ = the app
        let challengeGeneric: String
        let insistReply: String        // the "yeah" button — must fit the challenge
        let stayLocked: String         // when you back out
        let concede: String            // when you insist
        let howLong: String
        let coins: String              // %d = coins to hold-send
        let paid: String               // %d = minutes bought
        let broke: String
        let payFail: String

        func challenge(_ app: String?) -> String {
            app.map { String(format: challengeWithApp, $0) } ?? challengeGeneric
        }

        static let all: [ThreadScript] = [
            ThreadScript(
                opener: "hey. it's Aura. we need to talk.",
                challengeWithApp: "be real, you actually need %@ right now?",
                challengeGeneric: "be real, you actually need this right now?",
                insistReply: "yeah, i do",
                stayLocked: "good. staying locked. don't scare me like that.",
                concede: "wow ok. you do you i guess 😬",
                howLong: "how long we talking?",
                coins: "that's %d coins. hold down to send em",
                paid: "%d mins then. don't say i didn't try 😔",
                broke: "lol you're broke. go earn some coins first",
                payFail: "hm, that didn't send. try again"
            ),
            ThreadScript(
                opener: "hey. don't ignore me.",
                challengeWithApp: "you're seriously about to open %@ right now?",
                challengeGeneric: "you're seriously about to open this right now?",
                insistReply: "yeah, i am",
                stayLocked: "phew. ok. staying locked then.",
                concede: "wow. betrayed by my own human 😔",
                howLong: "alright. how long?",
                coins: "cool. %d coins. hold to send em",
                paid: "%d mins. i'll just be over here withering.",
                broke: "you literally have no coins lol. go earn some first",
                payFail: "that didn't go through. try again"
            ),
            ThreadScript(
                opener: "hey. it's me again.",
                challengeWithApp: "be honest. you actually need %@, or nah?",
                challengeGeneric: "be honest. you actually need this, or nah?",
                insistReply: "yeah, i do",
                stayLocked: "good. knew i could count on you. staying locked.",
                concede: "ok wow. rude. fine. 😐",
                howLong: "how much time you want?",
                coins: "%d coins then. hold to send em over",
                paid: "%d mins. don't come crying to me when it's gone.",
                broke: "you've got zero coins lol. go earn some first",
                payFail: "hmm didn't send. try again"
            ),
        ]

        static var random: ThreadScript { all.randomElement() ?? all[0] }
    }

    var body: some View {
        ZStack {
            TextAuraBackground()

            VStack(spacing: 0) {
                header

                ScrollViewReader { scroll in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                            stamp
                                .padding(.bottom, Theme.Spacing.s)

                            ForEach(messages) { message in
                                bubble(message)
                            }

                            // Keyed to the message count so each appearance is
                            // a *new* view. Sharing one identity across the
                            // whole thread meant SwiftUI animated it from its
                            // last position — so the second indicator slid down
                            // from where the previous message had been instead
                            // of fading in on its own line.
                            if isTyping { typingBubble.id(messages.count) }

                            if !replies.isEmpty { replyBlock }

                            // Anchor for the auto-scroll.
                            Color.clear.frame(height: 1).id(Self.bottom)
                        }
                        .padding(.horizontal, Theme.Spacing.l)
                        .padding(.top, Theme.Spacing.l)
                        .padding(.bottom, Theme.Spacing.xxxl)
                        .background(GeometryReader { g in
                            Color.clear.preference(key: ContentHeightKey.self, value: g.size.height)
                        })
                    }
                    // The thread is usually shorter than the screen, so the
                    // auto-scroll-to-bottom had nowhere to go and rubber-banded —
                    // every bubble sprang up and back. No bounce when it fits.
                    .scrollBounceBehavior(.basedOnSize)
                    .onPreferenceChange(ContentHeightKey.self) { contentHeight = $0 }
                    .background(GeometryReader { g in
                        Color.clear
                            .onAppear { viewportHeight = g.size.height }
                            .onChange(of: g.size.height) { _, h in viewportHeight = h }
                    })
                    .onChange(of: messages) { _, _ in scrollToEnd(scroll) }
                    .onChange(of: replies) { _, _ in scrollToEnd(scroll) }
                    .onChange(of: isTyping) { _, _ in scrollToEnd(scroll) }
                    // A bottom inset, not a VStack sibling: as a sibling, removing
                    // the bar grew the scroll view by its height and snapped the
                    // bottom-anchored bubbles up. As a safe-area inset the scroll
                    // view keeps its frame and the content stays put.
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        if let pending {
                            commitBar(pending)
                        } else if broke {
                            gotItBar
                        }
                    }
                }
            }
        }
        // The message thread is also full-bleed waterfall art, so its status
        // bar must use white content rather than the light-sheet treatment.
        .preferredColorScheme(.dark)
        .task { await open() }
    }

    private static let bottom = "thread.bottom"

    private func scrollToEnd(_ scroll: ScrollViewProxy) {
        // Only scroll when the thread overflows; on a short thread scrollTo has
        // nowhere to go and its elastic return reads as every bubble bouncing.
        guard contentHeight > viewportHeight else { return }
        withAnimation(.easeOut(duration: 0.25)) { scroll.scrollTo(Self.bottom, anchor: .bottom) }
    }

    // MARK: - Header

    /// The contact header: avatar, name, chevron. Tapping it does nothing on
    /// purpose — it's set dressing, and a dead end is better than a detour in
    /// the middle of a decision.
    private var header: some View {
        // Negative spacing so the avatar sits *on* the pill rather than above
        // it, and a zIndex so it stays in front — a VStack draws later children
        // on top, which would otherwise clip the fox's chin.
        VStack(spacing: -Theme.Spacing.xs) {
            // The app icon, filling the whole avatar. A contact photo is the
            // sender's own image, not a glyph sitting on a tinted disc.
            Image("AuraAppIcon")
                .resizable()
                .scaledToFill()
                .frame(width: Self.avatarDisc, height: Self.avatarDisc)
                .clipShape(Circle())
                // The same hairline the name pill wears, so the two read as one
                // header rather than an image resting on a card.
                .overlay(Circle().strokeBorder(LightSheet.divider, lineWidth: 1))
                .zIndex(1)

            Text("Aura")
                .auraFont(.body, Self.bubbleType, .bold)
                .foregroundStyle(.white)
                // Centred in a slightly wider pill, no chevron.
                .frame(width: 100)
                .padding(.vertical, Theme.Spacing.xs)
            // The same dark glass as Home's Quests card (day/night wash + white
            // sheen), with a hairline border so the pill has an edge on the photo.
            .background {
                Capsule()
                    .fill(Color.black.opacity(HomeDaylight.isDay() ? 0.58 : 0.45))
                    .overlay(Capsule().fill(Color.white.opacity(0.08)))
            }
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Spacing.m)
        .padding(.bottom, Theme.Spacing.l)
    }

    private static let avatarDisc: CGFloat = 64

    /// One `AttributedString`, not two `Text`s added together — `auraFont`
    /// returns `some View` rather than `Text`, so the `+` overload isn't
    /// available (and is deprecated in iOS 26 besides).
    private var stamp: some View {
        Text(stampLine)
            .frame(maxWidth: .infinity)
            // White with a shadow so the timestamp reads over the photo.
            .shadow(color: .black.opacity(0.45), radius: 6, y: 1)
    }

    private var stampLine: AttributedString {
        var line = AttributedString("Today \(Self.clock.string(from: .now))")
        line.font = Typography.body(size: RowType.subLabel, weight: .regular)
        line.foregroundColor = .white
        if let today = line.range(of: "Today") {
            line[today].font = Typography.body(size: RowType.subLabel, weight: .bold)
        }
        return line
    }

    private static let clock: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    // MARK: - Bubbles

    /// The dark glass the Aura pill wears — a day/night wash with a white sheen —
    /// applied to any shape. Reused by the user's bubbles and the typing indicator.
    @ViewBuilder private func glassBackground<S: Shape>(_ shape: S) -> some View {
        shape
            .fill(Color.black.opacity(HomeDaylight.isDay() ? 0.58 : 0.45))
            .overlay(shape.fill(Color.white.opacity(0.08)))
    }

    private func bubble(_ message: Message) -> some View {
        // A `Spacer` on the opposite side rather than a `maxWidth` frame.
        // `.frame(maxWidth:)` makes the bubble *expand* to that width when the
        // row offers more, which left short replies stranded mid-row instead of
        // flush against their edge.
        HStack(spacing: 0) {
            if !message.isAura { Spacer(minLength: Self.bubbleGutter) }

            Text(message.text)
                .auraFont(.body, Self.bubbleType, .medium)
                .foregroundStyle(.white)
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.vertical, Theme.Spacing.m)
                // Aura keeps her blue bubble; your own replies wear the same dark
                // glass as the pill, with white text and no border.
                .background {
                    let shape = RoundedRectangle(cornerRadius: Self.bubbleRadius, style: .continuous)
                    if message.isAura {
                        shape.fill(LightSheet.blue)
                    } else {
                        glassBackground(shape)
                    }
                }

            if message.isAura { Spacer(minLength: Self.bubbleGutter) }
        }
            // Scales up from its own corner. `.move(edge:)` slides the bubble
            // in across the full width of the row, so a right-aligned reply
            // appeared to travel from the far side of the screen.
            .transition(.scale(scale: 0.82,
                               anchor: message.isAura ? .bottomLeading : .bottomTrailing)
                .combined(with: .opacity))
    }

    private var typingBubble: some View {
        TypingDots()
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.m)
            .background { glassBackground(Capsule()) }
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.opacity)
    }

    /// Aura's own bubble radius, not a fixed 20: the app rounds by role, and a
    /// bubble is a card that happens to be short.
    private static let bubbleRadius = Theme.Radius.hero
    /// How much of the row the far side keeps, which is what caps a bubble's
    /// width without pinning it to a fixed one.
    private static let bubbleGutter: CGFloat = 64

    /// The one role the body scale doesn't cover. Its rungs top out at 15,
    /// which is a card title — a message is running text, and at 15 the thread
    /// read as a settings list. iMessage sets 17 and so does the reference.
    private static let bubbleType: CGFloat = 17

    // MARK: - Replies

    private var replyBlock: some View {
        VStack(alignment: .trailing, spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.xs) {
                Text("Tap to reply")
                    .auraFont(.body, RowType.subLabel, .semibold)
                Image(systemName: "arrow.down")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.45), radius: 6, y: 1)

            ForEach(replies) { reply in
                Button { send(reply) } label: {
                    Text(reply.text)
                        .auraFont(.body, Self.bubbleType, .semibold)
                        .foregroundStyle(LightSheet.blue)
                        .padding(.horizontal, Theme.Spacing.l)
                        .padding(.vertical, Theme.Spacing.m)
                        .background(.white, in: Capsule())
                }
                .buttonStyle(PressBounceStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.top, Theme.Spacing.s)
        .transition(.opacity)
    }

    // MARK: - The conversation

    private func open() async {
        await aura(thread.opener)
        await aura(thread.challenge(appName))
        offer([
            Reply(text: "nah, you're right", action: .backOut),
            Reply(text: thread.insistReply, action: .insist),
        ])
    }

    private func send(_ reply: Reply) {
        Haptics.impact(.light)
        withAnimation(.snappy) {
            replies = []
            messages.append(Message(text: reply.text, isAura: false))
        }

        Task { @MainActor in
            switch reply.action {
            case .backOut:
                await aura(thread.stayLocked)
                try? await Task.sleep(for: .milliseconds(900))
                finish()

            case .insist:
                // Broke check first: if there's nothing to spend, the fox goes
                // straight to "you're broke" — no conceding, no "how long", since
                // both would imply a purchase that can't happen.
                guard store.coinBalance >= Self.durations[0] else {
                    await aura(thread.broke)
                    withAnimation(.snappy) { broke = true }
                    return
                }
                await aura(thread.concede)
                await aura(thread.howLong)
                offer(Self.durations
                        .filter { store.coinBalance >= $0 }
                        .map { Reply(text: "\($0) mins", action: .pick($0)) }
                      + [Reply(text: "actually nevermind", action: .backOut)])

            case .pick(let minutes):
                await aura(String(format: thread.coins, minutes))
                withAnimation(.snappy) { pending = minutes }
            }
        }
    }

    /// Types, pauses, then sends — so the fox reads as someone at the other end
    /// rather than a script dumping its lines at once.
    @MainActor
    private func aura(_ text: String) async {
        withAnimation(.easeOut(duration: 0.2)) { isTyping = true }
        try? await Task.sleep(for: .milliseconds(min(1400, 420 + text.count * 22)))
        withAnimation(.snappy) {
            isTyping = false
            messages.append(Message(text: text, isAura: true))
        }
        try? await Task.sleep(for: .milliseconds(260))
    }

    /// Shown when you're broke: there's nothing to buy, so the thread just needs
    /// a way out. The same "Got it" the dialogue style's broke state uses.
    private var gotItBar: some View {
        LightPrimaryButton(title: "Got it") {
            Haptics.impact(.light)
            finish()
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, Theme.Spacing.l)
        .padding(.bottom, Theme.Spacing.l)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    /// The thread's ending: the same hold every other commitment in the app
    /// takes, pinned under the conversation.
    private func commitBar(_ minutes: Int) -> some View {
        VStack(spacing: Theme.Spacing.m) {
            HoldToConfirmButton(
                tint: LightSheet.danger,
                idleCaption: "hold to send",
                holdingCaption: "keep holding…",
                doneCaption: "sent",
                // On the photo, not a light sheet: white caption with a shadow and
                // a softer track, so the hold reads the way the rest does.
                idleCaptionColor: .white,
                captionShadow: true,
                trackColor: .white.opacity(0.28),
                coins: minutes,
                duration: 3
            ) {
                pay(minutes)
            }

            // Reaching the hold shouldn't trap you at it.
            Button("actually, i'm good") {
                Haptics.impact(.light)
                // Ease, not spring: `.snappy` overshoots, so removing the bar's bottom
        // inset sprung the whole thread past and back — a visible bounce.
        withAnimation(.easeInOut(duration: 0.3)) { pending = nil }
                Task { @MainActor in
                    messages.append(Message(text: "actually, i'm good", isAura: false))
                    await aura(thread.stayLocked)
                    try? await Task.sleep(for: .milliseconds(900))
                    finish()
                }
            }
            .auraFont(.body, SheetType.cardTitle, .semibold)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.45), radius: 6, y: 1)
            .frame(height: CircleIconButton.minimumTarget)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, Theme.Spacing.l)
        .padding(.bottom, Theme.Spacing.l)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func pay(_ minutes: Int) {
        // Ease, not spring: `.snappy` overshoots, so removing the bar's bottom
        // inset sprung the whole thread past and back — a visible bounce.
        withAnimation(.easeInOut(duration: 0.3)) { pending = nil }
        Task { @MainActor in
            guard InterventionPurchase.buy(minutes: minutes, from: store) else {
                await aura(thread.payFail)
                try? await Task.sleep(for: .milliseconds(900))
                finish()
                return
            }
            // The "paid" sign-off every other style shows at the .spent beat,
            // here as one last text in the thread's own voice.
            await aura(String(format: thread.paid, minutes))
            try? await Task.sleep(for: .milliseconds(1100))
            finish()
        }
    }

    private func offer(_ options: [Reply]) {
        withAnimation(.snappy) { replies = options }
    }

    private func finish() {
        onFinish()
        dismiss()
    }
}

/// The thread content's measured height, so the auto-scroll can tell whether the
/// conversation actually overflows the screen.
private struct ContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

#Preview {
    MessageThreadView(appName: "Instagram", appToken: nil) {}
        .environment(HabitStore())
}
