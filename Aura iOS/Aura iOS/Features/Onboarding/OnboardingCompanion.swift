//
//  OnboardingCompanion.swift
//  Aura iOS
//
//  The fox-companion beats (Duolingo pattern, Aura skin): the fox on the blue
//  hill with a light speech bubble whose text types itself out, and the
//  notification handoff that carries the user from the questions into the fox
//  chat — a dark scrim with one lit notification (styled like the reference)
//  that they tap.
//
//  Statement screens carry ONLY a back arrow — no progress bar. The bar belongs
//  to the question screens.
//

import SwiftUI
import AudioToolbox

// MARK: - Typewriter (character reveal — same as the intervention screens)

/// Types each line character-by-character, exactly like the Talk-to-Aura /
/// Mirror-Check intervention: a 320ms beat before the line, then 22ms per
/// character. Multiple lines type in sequence with a pause between them.
/// `onAllDone` fires after the last line.
struct TypewriterLines: View {
    let lines: [String]
    var charInterval: Double = 0.022
    var lead: Double = 0.32
    /// The hold after a line finishes typing scales with how long that line
    /// takes to read (words / `wordsPerMinute`) plus `pauseCushion`, so a short
    /// quip moves on quickly and a long line gets room to land. Clamped to
    /// [`minPause`, `maxPause`] so nothing feels rushed or stalls.
    var wordsPerMinute: Double = 200
    var pauseCushion: Double = 0.6
    var minPause: Double = 1.0
    var maxPause: Double = 3.0
    var alignment: HorizontalAlignment = .center
    var maxWidth: CGFloat = 300
    var onAllDone: () -> Void = {}

    @State private var shown = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    var body: some View {
        Text(displayedText)
            .multilineTextAlignment(alignment == .center ? .center : .leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: maxWidth, alignment: alignment == .center ? .center : .leading)
            .accessibilityLabel(fullText)
            .task(id: taskID) { await run() }
    }

    private var skipsAnimation: Bool { reduceMotion || voiceOverEnabled }
    private var fullText: String { lines.joined(separator: " ") }
    private var displayedText: String {
        skipsAnimation ? fullText : (shown.isEmpty ? " " : shown)
    }
    private var taskID: String {
        "\(skipsAnimation)|\(lines.joined(separator: "|"))"
    }

    /// Estimated reading time for a line, plus a cushion, clamped.
    private func pause(after line: String) -> Double {
        let words = Double(max(1, line.split(separator: " ").count))
        let readTime = words / (wordsPerMinute / 60)
        return min(maxPause, max(minPause, readTime + pauseCushion))
    }

    private func run() async {
        if skipsAnimation {
            shown = fullText
            onAllDone()
            return
        }

        for (i, line) in lines.enumerated() {
            shown = ""
            try? await Task.sleep(for: .seconds(lead))
            if Task.isCancelled { return }
            for character in line {
                shown.append(character)
                try? await Task.sleep(for: .seconds(charInterval))
                if Task.isCancelled { return }
            }
            if i < lines.count - 1 {
                try? await Task.sleep(for: .seconds(pause(after: line)))
                if Task.isCancelled { return }
            }
        }
        onAllDone()
    }
}


// MARK: - Companion scaffold (rock-pillar scene + fox + line below him)

// Home-sized fox (260 + Home shadow), feet planted on the pillar's flat top.
private let kFoxHeight: CGFloat = 260

/// The shared onboarding shell for the intro AND question screens: the rock-
/// pillar scene, the fox on the platform, his line typing out BELOW him
/// (intervention char typewriter, white + double shadow, no bubble), then
/// optional `content` (a text field / option cards), then the CTA. Pass
/// `progress` to show the bar (question screens); nil hides it (statements).
struct CompanionScaffold<Content: View, Bottom: View>: View {
    var showBack: Bool = true
    var progress: Double? = nil
    let lines: [String]
    var onAllDone: () -> Void = {}
    @ViewBuilder var content: () -> Content
    @ViewBuilder var bottom: () -> Bottom

    var body: some View {
        ZStack {
            // Drawn via a Color.clear overlay + clip so the oversized scaledToFill
            // image fills + centres WITHOUT expanding the layout (an unframed
            // scaledToFill widens everything and shoves the content off-centre).
            // The chrome below keeps its safe-area insets.
            Color.clear
                .overlay {
                    Image("Onboarding_Question Background (2)")
                        .resizable().scaledToFill()
                }
                .clipped()
                .ignoresSafeArea()

            // Progressive blur down the lower screen — two layers of increasing
            // blur, each faded in with a gradient mask, starting just above the
            // question text so the fox/scene up top stay sharp.
            blurredBackground(radius: 2, from: 0.40, to: 0.64)
            blurredBackground(radius: 5, from: 0.64, to: 0.90)

            VStack(spacing: 0) {
                OnbTopBar(showBack: showBack, progress: progress, onSky: true)

                // Fox on the pillar — 260 + Home shadow, lifted so his feet land
                // on the flat top.
                LoopingVideoView(resource: "InterventionTalkFox")
                    .frame(height: kFoxHeight)
                    .frame(maxWidth: .infinity)
                    .background(alignment: .bottom) {
                        // Exactly Home's day contact shadow.
                        Ellipse()
                            .fill(Color.black.opacity(0.12))
                            .frame(width: kFoxHeight * 0.51, height: kFoxHeight * 0.136)
                            .offset(y: -13)
                    }
                    // y offset (not padding) lifts fox + shadow without moving
                    // the line / input below.
                    .offset(x: 4, y: -4)
                    .padding(.top, Theme.Spacing.xl)

                // His line below him — intervention style, no bubble.
                TypewriterLines(lines: lines, maxWidth: 500, onAllDone: onAllDone)
                    .auraFont(.display, SheetType.heroCompact, .bold)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.55), radius: 4, y: 1)
                    .shadow(color: .black.opacity(0.5), radius: 16, y: 3)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.l)

                content()
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.xl)

                Spacer()
                bottom()
                    .padding(.horizontal, Theme.Spacing.xl)
                Spacer().frame(height: Theme.Spacing.xl)
            }
        }
    }

    /// A blurred copy of the background, faded in over [`from`, `to`] of the
    /// screen height so the blur builds up progressively down the page.
    private func blurredBackground(radius: CGFloat, from: CGFloat, to: CGFloat) -> some View {
        Color.clear
            .overlay {
                Image("Onboarding_Question Background (2)")
                    .resizable().scaledToFill()
                    .blur(radius: radius)
            }
            .clipped()
            .mask(
                LinearGradient(
                    stops: [.init(color: .clear, location: from),
                            .init(color: .black, location: to)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .ignoresSafeArea()
    }
}

// MARK: - Meet (companion intro — one screen)

struct OnbMeetView: View {
    @Environment(OnboardingFlow.self) private var flow
    /// Gates the CTA until the fox has finished talking.
    @State private var ready = false
    var body: some View {
        CompanionScaffold(
            showBack: false,
            progress: nil,
            lines: [
                "hey, i'm Aura",
                "i'll help you block the apps that distract you the most",
                "don't worry, i'll give them back",
                "you just have to do healthy habits first",
                "think of me as your slightly pushy friend",
                "you'll thank me later. probably...",
            ],
            onAllDone: { ready = true },
            content: { EmptyView() },
            bottom: {
                LightPrimaryButton(title: "Continue",
                                   face: .white, textColor: LightSheet.title, shade: LightSheet.whiteShadeOnColour,
                                   enabled: ready) { flow.advance() }
            }
        )
    }
}

// MARK: - Handoff (last question → chat, via a tapped notification)

struct OnbHandoffView: View {
    @Environment(OnboardingFlow.self) private var flow
    @State private var showScrim = false
    @State private var bounce = false

    private var name: String {
        flow.firstName.isEmpty ? "there" : flow.firstName.lowercased()
    }
    private var lines: [String] {
        ["ok \(name), we should talk", "don't panic. i'll just text you"]
    }

    var body: some View {
        ZStack {
            // Both lines type out, then the notification drops.
            CompanionScaffold(
                progress: nil,
                lines: lines,
                onAllDone: {
                    // Hold on the last line long enough to read it, then drop the
                    // notification with a message-received sound.
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(1.6))
                        AudioServicesPlaySystemSound(1007)
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            showScrim = true
                        }
                    }
                },
                content: { EmptyView() },
                bottom: { EmptyView() }
            )

            if showScrim {
                Color.black.opacity(0.82)
                    .ignoresSafeArea()
                    .transition(.opacity)

                VStack(spacing: 0) {
                    notification
                        .padding(.horizontal, Theme.Spacing.l)
                        .onTapGesture {
                            Haptics.impact(.light)
                            flow.advance()
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))

                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundStyle(.white)
                            .offset(y: bounce ? -6 : 0)
                        Text("Aura sent you a message, tap on it")
                            .auraFont(.body, 16, .semibold)
                            .foregroundStyle(.white)
                    }
                    .padding(.top, Theme.Spacing.l)

                    Spacer()
                }
                .padding(.top, Theme.Spacing.s)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                        bounce = true
                    }
                }
            }
        }
    }

    // The one lit element on the scrim — a white iOS-style notification card,
    // matching the reference: app icon, bold name, "now", preview line.
    private var notification: some View {
        HStack(alignment: .top, spacing: 12) {
            Image("AuraAppIcon")
                .resizable().interpolation(.high).scaledToFill()
                .frame(width: 42, height: 42)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5))
                // The delivering-app badge, like iOS shows on a text: the green
                // Messages tile in the bottom-right corner.
                .overlay(alignment: .bottomTrailing) { messagesBadge.offset(x: 5, y: 5) }

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Aura")
                        .auraFont(.body, 15, .bold)
                        .foregroundStyle(.black)
                    Spacer(minLength: 8)
                    Text("now")
                        .auraFont(.body, 13, .regular)
                        .foregroundStyle(.black.opacity(0.45))
                }
                Text("real quick, \(name)")
                    .auraFont(.body, 15, .regular)
                    .foregroundStyle(.black.opacity(0.9))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                // Off-white (iOS notification grey) so the white Aura tile reads.
                .fill(Color(red: 0.91, green: 0.91, blue: 0.93))
                .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
        )
    }

    /// The real Messages app icon shown in the corner (it carries its own green
    /// tile — no backing behind it).
    private var messagesBadge: some View {
        Image("MessagesIcon")
            .resizable().interpolation(.high).scaledToFit()
            .frame(width: 20, height: 20)
            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
    }
}
