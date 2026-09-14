//
//  OnboardingChat.swift
//  Aura iOS
//
//  The onboarding fox chat, wearing the intervention thread's exact design via
//  the shared FoxChatChrome: the "Text From Aura" texting background, the
//  avatar-on-a-glass-pill header, blue fox bubbles, dark-glass user replies, the
//  typing indicator, and white reply pills.
//
//  Script-driven: a linear list of `ChatTurn`s. Each turn types its fox lines in
//  (with the typing indicator), then offers reply pills; tapping any pill appends
//  the user's bubble and advances to the next turn, all in ONE continuous thread.
//  A turn with no replies ends the thread on a CTA. Drives the diagnosis chat
//  (spec screens 5 Recognition + 6 Normalization).
//

import SwiftUI
import AudioToolbox

/// A five-star review shown as an in-thread card. PLACEHOLDER copy for the build
/// — swapped for real tester reviews before launch (see the onboarding honesty
/// gate). Not shipped as-is.
struct Testimonial: Equatable {
    let quote: String
    let name: String
    let age: Int
}

/// A fox bubble's emotional colour, Unrot's red(pain)/green(relief) trick adapted
/// to Aura's solid bubbles: the whole bubble carries the colour (in-text red
/// wouldn't read on our blue). `normal` = blue.
enum FoxTone: Equatable { case normal, pain, relief }

/// One fox line plus its tone. `ExpressibleByStringInterpolation` so plain
/// `"..."` and `"...\(name)"` both still work everywhere; only the gut-punch /
/// relief lines pass a tone explicitly.
struct ChatLine: ExpressibleByStringInterpolation, Equatable {
    let text: String
    var tone: FoxTone = .normal
    init(stringLiteral value: String) { self.text = value }
    init(stringInterpolation: DefaultStringInterpolation) {
        self.text = String(stringInterpolation: stringInterpolation)
    }
    init(_ text: String, _ tone: FoxTone = .normal) { self.text = text; self.tone = tone }
}

private struct ChatMsg: Identifiable, Equatable {
    let id = UUID()
    var text: String? = nil
    var isFox: Bool = true
    var tone: FoxTone = .normal
    /// When set, this message renders as a stack of review cards instead of text.
    var testimonials: [Testimonial]? = nil
    /// When set, this message renders an app-icon cluster (the adversary).
    var appIcons: [String]? = nil
}

/// One beat of the conversation: an optional opening `appIcons` cluster, the fox
/// types `lines`, an optional `testimonials` card stack, then `replies`. An empty
/// `replies` makes it the final turn — a CTA shows instead.
struct ChatTurn: Equatable {
    var appIcons: [String]? = nil
    var lines: [ChatLine]
    var testimonials: [Testimonial]? = nil
    /// Fox lines typed AFTER the testimonials (e.g. "wanna see how?").
    var linesAfter: [ChatLine] = []
    var replies: [String] = []
}

struct OnbChatThread: View {
    @Environment(OnboardingFlow.self) private var flow
    var showBack: Bool = true
    /// The conversation, played turn by turn into one accumulating thread.
    var script: [ChatTurn]
    /// CTA label used only when the final turn has no reply pills.
    var cta: String = "continue"
    /// Fires after the last turn (a final pill pick, or the CTA tap).
    var onContinue: () -> Void = {}

    @State private var msgs: [ChatMsg] = []
    @State private var typing = false
    @State private var turn = 0
    @State private var showReplies = false
    @State private var showCTA = false

    private static let bottomID = "onb.chat.bottom"

    var body: some View {
        ZStack {
            // Fixed day scene — the onboarding chat does NOT flip day/night (only
            // the in-app intervention thread does). One background for everything.
            chatBackground

            // The thread is full-bleed. Messages fill from the TOP down and only
            // scroll once they outgrow the space; then the newest stays in view
            // and the oldest scroll up UNDER the header. The header sits on a
            // frosted strip so messages blur behind the Aura pill + avatar. The
            // reply pills are a bottom inset with NO background — same scene.
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        stamp.padding(.bottom, Theme.Spacing.s)
                        ForEach(msgs) { bubble($0) }
                        if typing { typingBubble }
                        Color.clear.frame(height: 1).id(Self.bottomID)
                    }
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.vertical, Theme.Spacing.s)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollBounceBehavior(.basedOnSize)
                // Deterministic chat scroll: content stays TOP-aligned while it
                // fits, and SwiftUI keeps the bottom in view as it grows — the
                // oldest scroll up off the top. No reliance on manual scrollTo.
                .defaultScrollAnchor(.bottom, for: .sizeChanges)
                // The thread drives itself — block the user's touches so they
                // can't drag it, but leave programmatic auto-scroll working
                // (scrollDisabled would kill the auto-scroll too).
                .allowsHitTesting(false)
                .onChange(of: msgs) { _, _ in toBottom(proxy) }
                // The dots pin to the bottom instantly (no animated slide).
                .onChange(of: typing) { _, _ in toBottom(proxy, animated: false) }
                // The pills change the thread's height — wait for that layout
                // before pinning, or we'd scroll to the pre-shrink bottom.
                .onChange(of: showReplies) { _, shown in if shown { toBottom(proxy, delay: true) } }
                .onChange(of: showCTA) { _, shown in if shown { toBottom(proxy, delay: true) } }
                .safeAreaInset(edge: .top, spacing: 0) { topChrome }
                .safeAreaInset(edge: .bottom, spacing: 0) { bottomChrome }
            }
        }
        .preferredColorScheme(.light)
        .task { await play(0) }
    }

    /// The header on a frosted strip — messages scroll up and blur behind the
    /// Aura pill + avatar.
    private var topChrome: some View {
        ZStack(alignment: .topLeading) {
            FoxChatHeader()
            if showBack {
                FoxChatBackButton { flow.back() }
                    .padding(.leading, Theme.Spacing.l)
                    .padding(.top, Theme.Spacing.s)
            }
        }
        .frame(maxWidth: .infinity)
        .background {
            ZStack {
                // Slightly stronger blur (not maxed).
                Rectangle().fill(.ultraThinMaterial).opacity(0.65)
                // A slightly deeper scrim, darkest at the very top behind the
                // status bar (time / wifi / battery), fading down.
                LinearGradient(colors: [Color.black.opacity(0.33),
                                        Color.black.opacity(0.10),
                                        .clear],
                               startPoint: .top, endPoint: .bottom)
            }
            .mask(
                LinearGradient(
                    stops: [.init(color: .black, location: 0.0),
                            .init(color: .black, location: 0.55),
                            .init(color: .clear, location: 1.0)],
                    startPoint: .top, endPoint: .bottom)
            )
            .ignoresSafeArea(edges: .top)
        }
    }

    /// The reply pills / CTA — NO background, sitting on the same scene as the
    /// messages. Reserves its own space so the thread scrolls up above it.
    @ViewBuilder private var bottomChrome: some View {
        if showReplies || showCTA {
            bottomBar
                .padding(.top, Theme.Spacing.s)
                .padding(.bottom, Theme.Spacing.l)
        }
    }

    private var chatBackground: some View {
        Color.black
            .overlay(
                Image("Text Aura_Day View")
                    .resizable().scaledToFill()
                    .blur(radius: 1)
                    .clipped()
            )
            .ignoresSafeArea()
    }

    /// Keep the newest message in view. Does nothing while the thread still fits
    /// (content stays top-aligned); once it overflows, this follows the bottom.
    /// `delay` waits a beat for a layout change (the pills appearing) to settle
    /// before pinning.
    private func toBottom(_ p: ScrollViewProxy, delay: Bool = false, animated: Bool = true) {
        let pin = {
            if animated { withAnimation(.easeOut(duration: 0.25)) { p.scrollTo(Self.bottomID, anchor: .bottom) } }
            else { p.scrollTo(Self.bottomID, anchor: .bottom) }
        }
        guard delay else { pin(); return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            pin()
        }
    }

    // MARK: Timestamp

    private var stamp: some View {
        Text(stampLine)
            .frame(maxWidth: .infinity)
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

    // MARK: Bubbles

    @ViewBuilder private func bubble(_ m: ChatMsg) -> some View {
        if let cards = m.testimonials {
            reviewStack(cards)
                .transition(.scale(scale: 0.9, anchor: .bottomLeading).combined(with: .opacity))
        } else if let icons = m.appIcons {
            appIconCluster(icons)
                .transition(.scale(scale: 0.9, anchor: .bottomLeading).combined(with: .opacity))
        } else {
            HStack(spacing: 0) {
                if !m.isFox { Spacer(minLength: 64) }
                Text(m.text ?? "")
                    .auraFont(.body, 17, .medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.vertical, Theme.Spacing.m)
                    .background {
                        let shape = RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous)
                        if m.isFox { shape.fill(LightSheet.blue) } else { foxChatGlass(shape) }
                    }
                if m.isFox { Spacer(minLength: 64) }
            }
            .transition(.scale(scale: 0.82, anchor: m.isFox ? .bottomLeading : .bottomTrailing)
                .combined(with: .opacity))
        }
    }

    // MARK: App-icon cluster (the adversary attachment)

    private func appIconCluster(_ icons: [String]) -> some View {
        // A blue fox bubble that HUGS a 4x2 grid of small app icons (content-
        // sized, so it reads like the text bubbles, not a full-width block).
        let rows = stride(from: 0, to: icons.count, by: 4).map { Array(icons[$0..<min($0 + 4, icons.count)]) }
        return VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 22) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, name in
                        Image(name)
                            .resizable().interpolation(.high).scaledToFill()
                            .frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                }
            }
        }
        .padding(Theme.Spacing.l)
        .background(LightSheet.blue, in: RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Review cards (in-thread testimonial attachment)

    private func reviewStack(_ cards: [Testimonial]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            ForEach(Array(cards.enumerated()), id: \.offset) { _, c in reviewCard(c) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 72)
    }

    private func reviewCard(_ c: Testimonial) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(red: 1.0, green: 0.72, blue: 0.16))
                }
            }
            Text(c.quote)
                .auraFont(.body, 15, .semibold)
                .foregroundStyle(LightSheet.title)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(c.name), \(c.age)")
                .auraFont(.body, 13, .medium)
                .foregroundStyle(LightSheet.controlIdle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.l)
        .background(.white, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
    }

    private var typingBubble: some View {
        TypingDots()
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.m)
            .background { foxChatGlass(Capsule()) }
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.opacity)
    }

    // MARK: Bottom (reply pills or CTA)

    @ViewBuilder private var bottomBar: some View {
        if showCTA {
            LightPrimaryButton(title: cta) { onContinue() }
                .padding(.horizontal, Theme.Spacing.xl)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        } else if showReplies {
            VStack(alignment: .trailing, spacing: Theme.Spacing.s) {
                HStack(spacing: Theme.Spacing.xs) {
                    Text("tap to reply").auraFont(.body, RowType.subLabel, .semibold)
                    Image(systemName: "arrow.down").font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.45), radius: 6, y: 1)

                ForEach(Array(script[turn].replies.enumerated()), id: \.offset) { i, r in
                    Button { pick(i) } label: {
                        Text(r)
                            .auraFont(.body, 17, .semibold)
                            .foregroundStyle(LightSheet.blue)
                            .padding(.horizontal, Theme.Spacing.l)
                            .padding(.vertical, Theme.Spacing.m)
                            .background(.white, in: Capsule())
                    }
                    .buttonStyle(PressBounceStyle())
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, Theme.Spacing.xl)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    // MARK: Run

    /// Types a turn's fox lines, then either offers its pills or ends on a CTA.
    @MainActor private func play(_ i: Int) async {
        guard i < script.count else { return }
        if let icons = script[i].appIcons {
            typing = true   // appears in place — no wrapping animation to slide it
            try? await Task.sleep(for: .milliseconds(700))
            withAnimation(.snappy) {
                typing = false
                msgs.append(ChatMsg(appIcons: icons))
            }
            try? await Task.sleep(for: .milliseconds(360))
        }
        for line in script[i].lines { await fox(line) }
        if let cards = script[i].testimonials {
            typing = true   // appears in place — no wrapping animation to slide it
            try? await Task.sleep(for: .milliseconds(700))
            withAnimation(.snappy) {
                typing = false
                msgs.append(ChatMsg(testimonials: cards))
            }
            try? await Task.sleep(for: .milliseconds(260))
        }
        for line in script[i].linesAfter { await fox(line) }
        if script[i].replies.isEmpty {
            withAnimation(.snappy) { showCTA = true }
        } else {
            withAnimation(.snappy) { showReplies = true }
        }
    }

    /// Types, pauses, then sends — the fox reads as someone at the other end.
    @MainActor private func fox(_ line: ChatLine) async {
        withAnimation(.easeOut(duration: 0.2)) { typing = true }
        try? await Task.sleep(for: .milliseconds(min(1400, 420 + line.text.count * 22)))
        withAnimation(.snappy) {
            typing = false
            msgs.append(ChatMsg(text: line.text, isFox: true, tone: line.tone))
        }
        try? await Task.sleep(for: .milliseconds(260))
    }

    private func pick(_ i: Int) {
        Haptics.impact(.light)
        AudioServicesPlaySystemSound(1004)   // iMessage "sent" swoosh
        let reply = script[turn].replies[i]
        // Smooth, non-bouncy: dropping the reply-pill inset reflows the whole
        // thread, and a spring here makes every bubble overshoot/bounce.
        withAnimation(.easeOut(duration: 0.28)) {
            showReplies = false
            msgs.append(ChatMsg(text: reply, isFox: false))
        }
        Task { @MainActor in
            if turn + 1 < script.count {
                try? await Task.sleep(for: .milliseconds(450))
                turn += 1
                await play(turn)
            } else {
                // Let the final reply land before cutting away to the next screen.
                try? await Task.sleep(for: .milliseconds(1300))
                onContinue()
            }
        }
    }
}

// MARK: - Diagnosis chat (spec 5 Recognition + 6 Normalization, one thread)

/// The first stretch of the fox thread: he names the scroll loop back to the
/// user (recognition), then takes the blame off them (normalization). Copy is
/// the onboarding spec's, in texting register (no trailing periods on the short
/// bubbles). One continuous thread.
struct OnbDiagnosisChat: View {
    @Environment(OnboardingFlow.self) private var flow

    private var name: String {
        flow.firstName.isEmpty ? "there" : flow.firstName.lowercased()
    }

    var body: some View {
        OnbChatThread(
            showBack: false,
            script: [
                // 1. Recognition — name the loop back to them.
                ChatTurn(
                    lines: [
                        "ok \(name), real quick",
                        "this sound familiar?",
                        "you scroll",
                        "feel like garbage",
                        "swear you'll stop",
                        "scroll more",
                        "repeat",
                    ],
                    replies: ["yeah, that's me", "stop calling me out", "is it that bad?"]
                ),
                // 2. Normalization — take the shame off, no user count.
                ChatTurn(
                    lines: [
                        "good news first: this is fixable",
                        "this is just how most apps are built",
                        "everyone who finds me got caught in the same loop",
                        "it's called brainrot 🤢",
                    ],
                    replies: ["ok, go on", "that helps"]
                ),
                // 3. Self-trust — the gut line ("you can't trust yourself 💀").
                ChatTurn(
                    lines: [
                        "every time you say \"5 more minutes\"",
                        "and don't stop",
                        "you teach your brain one thing",
                        "that you can't trust yourself 💀",
                        "that's why you feel bad after",
                    ],
                    replies: ["ouchie", "ok that one hurt"]
                ),
                // 4. Failed solutions — arrow format, then the relief line.
                ChatTurn(
                    lines: [
                        "you've tried to fix this",
                        "screen time limits → you ignore them",
                        "app blockers → you delete them",
                        "deleting the app → you reinstall it",
                        "willpower → lol",
                        "but here's the thing",
                        "it's not your fault 🫶",
                    ],
                    replies: ["wait what", "go on", "i'm listening"]
                ),
                // 5. The adversary — app-icon cluster + "you. can't. stop. 💀".
                ChatTurn(
                    appIcons: ["AppIconTikTok", "AppIconInstagram", "AppIconYouTube", "AppIconSnapchat",
                               "AppIconX", "AppIconReddit", "AppIconFacebook", "AppIconThreads"],
                    lines: [
                        "these apps have thousands of engineers",
                        "phds in psychology",
                        "billions in funding",
                        "all to keep you scrolling",
                        "you. can't. stop. 🫠",
                        "it's not a fair fight",
                    ],
                    replies: ["that explains a lot", "i feel a bit better"]
                ),
                // 6. Proof — PLACEHOLDER reviews (real ones at launch).
                ChatTurn(
                    lines: ["people beat this all the time"],
                    testimonials: [
                        Testimonial(quote: "I used to scroll 6-7 hours a day. now I'm down to 2.", name: "Jordan", age: 21),
                        Testimonial(quote: "First app that didn't make me feel bad for using my phone.", name: "Mia", age: 27),
                        Testimonial(quote: "I got my mornings back. That alone was worth it.", name: "Sam", age: 24),
                    ],
                    linesAfter: ["and they all started right where you are"],
                    replies: ["where's that?"]
                ),
                // 7. Name the shared starting night, then hand into the loop demo.
                ChatTurn(
                    lines: ["a night you know too well 👀",
                            "let me show you"],
                    replies: ["ok, show me"]
                ),
            ],
            onContinue: { flow.advance() }
        )
    }
}
