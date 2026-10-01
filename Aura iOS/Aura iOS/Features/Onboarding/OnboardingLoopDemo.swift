//
//  OnboardingLoopDemo.swift
//  Aura iOS
//
//  Phase 2 beat: the doomscroll loop. You flick the feed ONCE and then just watch —
//  the screen scrolls itself while the clock burns from 10:30 to 11:30, the self-talk
//  curdles from "just a quick scroll" into "oh no, too late," and Aura's real
//  screen-time nudges slide in and get ignored. At the end the fox delivers the
//  verdict: an hour gone, nothing done. One gesture, minimal effort — by design.
//
//  The phone is the hero: a real-looking "brainrot" feed where the apps are the
//  accounts — each post is an app (instagram, tiktok, youtube…) whispering at the
//  user to keep scrolling — with aura the one honest voice among them. The peeking
//  fox watches over the top. The escalation rides the background, the clock, and the
//  button, so the feed itself stays believably normal while everything sours.
//

import SwiftUI

struct OnbLoopDemoView: View {
    @Environment(OnboardingFlow.self) private var flow

    @State private var scroll: CGFloat = 0
    @State private var revealed = Self.initialVerdictRevealed
    @State private var activeReminder: ScreenTimeReminder?
    @State private var firedReminders: Set<ScreenTimeReminder> = []
    /// Once they've flicked once, the feed scrolls itself the rest of the way.
    @State private var autoScrolling = false
    @State private var autoTask: Task<Void, Never>?
    /// The verdict screen's interactive "take the hour back" flow.
    @State private var revealStage: RevealStage = .loss
    @State private var hourProgress: CGFloat = 0   // 0 = 11:30, 1 = 10:30
    @State private var linesReady = false          // the fox has finished typing this stage
    @State private var confettiStart: Date?        // fires when the clock hits 10:30
    @State private var clockFaded = false           // the clock fades out after the burst

    private static var initialVerdictRevealed: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-verdict")
        #else
        false
        #endif
    }

    private let startMinutes = 22 * 60 + 30      // 10:30 PM
    private let endMinutes = 23 * 60 + 30        // 11:30 PM
    private let warnMinutes = 23 * 60            // 11:00 PM
    private let redMinutes = 23 * 60 + 15        // 11:15 PM — last 15 min go red
    // Vivid clock colours — the app's signal tokens read washed-out on the night sky.
    private let clockGreen = Color(hex: "22E06A")
    private let clockOrange = Color(hex: "FF9E1B")
    private let clockRed = LightSheet.rippleRed
    /// The feed's measured full height (reported by LoopPhone) and the visible feed
    /// window, so the scroll runs exactly to the bottom of the content.
    @State private var feedContentHeight: CGFloat = 0
    // Larger than the on-screen window on purpose: the scroll stops this far short of
    // the very end of the content, so the last post's MEDIA bleeds to the bottom edge
    // instead of resting on its (dark) caption/timestamp zone.
    private let feedVisibleHeight: CGFloat = 540
    /// The scroll distance that burns the whole hour = scroll-to-the-bottom. Falls
    /// back to a sane default until the feed has been measured once.
    private var maxScroll: CGFloat {
        feedContentHeight > feedVisibleHeight ? feedContentHeight - feedVisibleHeight : 1800
    }
    /// The phone's natural size; `phoneScale` blows the whole mockup up uniformly
    /// (via scaleEffect) so nothing inside it can break, and the reserved frame
    /// grows with it so the layout still accounts for the extra size.
    private let phoneW: CGFloat = 230
    private let phoneH: CGFloat = 458
    private let phoneScale: CGFloat = 1.0
    /// The screen-time nudges that fall inside the one-hour window — pulled straight
    /// from the app's real `ScreenTimeReminder` set, so this is literal future pacing.
    private let demoReminders: [ScreenTimeReminder] = [.min15, .min45]

    /// Minutes past midnight, tied to how far they've doom-scrolled.
    private var minutes: Int {
        startMinutes + Int((min(scroll, maxScroll) / maxScroll) * 60)
    }

    /// The same time as the big clock, formatted for the phone's status bar.
    private var clockString: String {
        let h24 = minutes / 60, m = minutes % 60
        let h12 = h24 % 12 == 0 ? 12 : h24 % 12
        return String(format: "%d:%02d", h12, m)
    }

    private enum Phase { case calm, warning, late }

    private var phase: Phase {
        if minutes >= redMinutes { return .late }   // last 15 min: red + "it's late" self-talk
        if minutes >= warnMinutes { return .warning }
        return .calm
    }

    /// Clock colour on its own thresholds: green → orange at 11:00 → red for the
    /// final 15 minutes (11:15+).
    private var phaseColor: Color {
        if minutes >= redMinutes { return clockRed }
        if minutes >= warnMinutes { return clockOrange }
        return clockGreen
    }

    private var deception: String {
        switch phase {
        case .calm:    return "Just a few minutes. Then I'll sleep."
        case .warning: return "One more. Then I'm actually going to sleep."
        case .late:    return "How is it already this late?"
        }
    }

    var body: some View {
        ZStack {
            // The doomscroll lives on the night scene; the verdict crosses to the
            // intro screen's brighter sky — the hopeful turn.
            if revealed {
                revealGround.ignoresSafeArea()
            } else {
                ground.ignoresSafeArea()
            }

            if revealed {
                revealView.transition(.opacity)
            } else {
                scrollView.transition(.opacity)
            }
        }
    }

    /// The verdict wears the intro (companion) screen's background so the loop
    /// closes where onboarding opened — same image + progressive blur as
    /// `CompanionScaffold`.
    private var revealGround: some View {
        ZStack {
            Color.clear
                .overlay {
                    Image("Onboarding_Question Background (2)")
                        .resizable().scaledToFill()
                }
                .clipped()
                .ignoresSafeArea()
            revealBlur(2, from: 0.40, to: 0.64)
            revealBlur(5, from: 0.64, to: 0.90)
        }
    }

    private func revealBlur(_ radius: CGFloat, from: CGFloat, to: CGFloat) -> some View {
        Color.clear
            .overlay {
                Image("Onboarding_Question Background (2)")
                    .resizable().scaledToFill()
                    .blur(radius: radius)
            }
            .clipped()
            .mask(
                LinearGradient(stops: [.init(color: .clear, location: from),
                                       .init(color: .black, location: to)],
                               startPoint: .top, endPoint: .bottom)
            )
            .ignoresSafeArea()
    }

    /// The night-sky background — kept clean and vivid (no phase tint).
    private var ground: some View {
        ZStack {
            Color.black
            Image("LoopDemoBackground")
                .resizable().interpolation(.high).scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            // Subtle dark wash for a touch more depth + text contrast.
            Color.black.opacity(0.22)
        }
    }

    // MARK: - The interactive scroll

    private var scrollView: some View {
        VStack(spacing: 0) {
            OnbTopBar(showBack: true, progress: nil, onSky: true)

            Spacer().frame(height: Theme.Spacing.l)

            // The clock + self-talk lead the screen — a stronger spot than under the
            // phone: you read the time, THEN watch it burn.
            LoopTime(minutes: minutes, color: phaseColor, size: 48)
                .shadow(color: .black.opacity(0.35), radius: 6, y: 2)

            Spacer().frame(height: Theme.Spacing.xs)

            // Reserve a constant two-line height so the phone below never shifts when
            // the line curdles from one line to two (or back).
            Text(deception)
                .auraFont(.body, SheetType.banner, .semibold)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
                .frame(width: 330, height: 56, alignment: .top)
                .shadow(color: .black.opacity(0.35), radius: 5, y: 2)

            // Generous flexible gap so the fox + phone breathe well below the text.
            Spacer(minLength: 88)

            ZStack(alignment: .top) {
                LoopPhone(scroll: scroll,
                          reminder: activeReminder,
                          dimmed: !autoScrolling && scroll < 1,
                          onContentHeight: { feedContentHeight = $0 },
                          statusTime: clockString)
                    .frame(width: phoneW, height: phoneH)
                    .contentShape(Rectangle())
                    .gesture(scrollGesture)
                    // Scale the WHOLE mockup uniformly so nothing inside can break,
                    // and reserve the scaled footprint so the layout stays honest.
                    .scaleEffect(phoneScale)
                    .frame(width: phoneW * phoneScale, height: phoneH * phoneScale)

                // The fox peeking over the top edge of the phone, same soft shadow
                // as the welcome screen's peeking fox.
                Image("Aura Fox_Peeking (2)")
                    .resizable().interpolation(.high).scaledToFit()
                    .frame(width: 104)
                    .foxShadow()
                    .offset(x: 0, y: -62)
                    .allowsHitTesting(false)
            }

            Spacer(minLength: Theme.Spacing.l)
        }
    }

    /// They only scroll ONCE. A single upward flick hands off to `beginAutoScroll`,
    /// which drives the feed the rest of the way so they just watch the hour vanish —
    /// deliberately low-effort for a short-attention audience mid-onboarding.
    private var scrollGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onEnded { g in
                guard !revealed, !autoScrolling else { return }
                // Any upward intent starts it; a downward drag is ignored.
                guard g.predictedEndTranslation.height < -20 || g.translation.height < -20 else { return }
                beginAutoScroll()
            }
    }

    /// Advances `scroll` to the end over a fixed time so the clock, the feed and the
    /// nudges all move together. One source of truth (real intermediate `scroll`
    /// values) keeps everything in sync even as a banner slides in over the feed.
    private func beginAutoScroll() {
        guard !autoScrolling else { return }
        autoScrolling = true
        Haptics.impact(.soft)
        autoTask = Task { @MainActor in
            let start = scroll
            // Steady, unhurried pace (~195 pt/s) so the nudges have room to read,
            // clamped so it never drags on even for a long feed.
            let duration = min(13.0, max(9.0, Double(maxScroll - start) / 195.0))
            let fps = 30.0
            let frameNs = UInt64(1_000_000_000 / fps)
            let steps = max(1, Int(duration * fps))
            for i in 1...steps {
                try? await Task.sleep(nanoseconds: frameNs)
                if revealed { return }
                scroll = start + (maxScroll - start) * CGFloat(i) / CGFloat(steps)
                onScrollChange()
            }
        }
    }

    /// Fires each screen-time nudge as its threshold passes, then the verdict at the end.
    private func onScrollChange() {
        for reminder in demoReminders where !firedReminders.contains(reminder) {
            let threshold = maxScroll * CGFloat(reminder.minutes) / 60
            if scroll >= threshold {
                firedReminders.insert(reminder)
                showReminder(reminder)
            }
        }
        if scroll >= maxScroll && !revealed {
            Haptics.notify(.error)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) { revealed = true }
        }
    }

    /// Slides an Aura notification down over the feed, then auto-dismisses it — the
    /// user scrolls right past it, which is exactly the behaviour the app later fixes.
    /// If one is still up, it slides fully OUT before the next slides IN (never a
    /// straight text swap).
    private func showReminder(_ reminder: ScreenTimeReminder) {
        Haptics.impact(.medium)
        Task { @MainActor in
            if activeReminder != nil {
                withAnimation(.easeIn(duration: 0.3)) { activeReminder = nil }
                try? await Task.sleep(nanoseconds: 380_000_000)   // let it clear
            }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { activeReminder = reminder }
            try? await Task.sleep(nanoseconds: 3_200_000_000)
            if activeReminder == reminder {
                withAnimation(.easeIn(duration: 0.3)) { activeReminder = nil }
            }
        }
    }

    // MARK: - The verdict (interactive: take the hour back)

    private enum RevealStage { case loss, invite, reclaimed }

    /// The clock reads 11:30 at rest and rolls to 10:30 as they drag it back.
    private var draggedMinutes: Int {
        endMinutes - Int((hourProgress * 60).rounded())
    }

    /// The clock colour crossfades red (11:30) → green (10:30) with the drag.
    private func reclaimColor(_ p: CGFloat) -> Color {
        let t = min(1, max(0, p))
        return Color(red: 1.0 + (0.13 - 1.0) * t,
                     green: 0.23 + (0.88 - 0.23) * t,
                     blue: 0.19 + (0.42 - 0.19) * t)
    }

    private var revealLines: [String] {
        switch revealStage {
        case .loss:      return ["An hour, gone.", "Night after night."]
        case .invite:    return ["But, it doesn't have to be that way.",
                                 "You can break the brainrot loop.",
                                 "Start now. Take your time back."]
        case .reclaimed: return ["Feels better, right?", "My job is to help you take your time back.",
                                 "Here's how I do it.", "Come on, I'll show you."]
        }
    }

    /// When a stage's lines finish typing: the loss auto-advances into the invite;
    /// the invite/reclaimed only reveal their control once the fox is done talking.
    private func handleLinesDone() {
        switch revealStage {
        case .loss:
            // Hold on the loss (same reading-time beat TypewriterLines holds
            // BETWEEN lines) before the fox pivots to hope — otherwise the last
            // line advances the instant it finishes typing.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2.2))
                withAnimation(.easeInOut(duration: 0.4)) { revealStage = .invite }
            }
        case .invite:
            withAnimation(.easeOut(duration: 0.3)) { linesReady = true }
        case .reclaimed:
            // The fox's bridge lines have finished — head into the demos.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.0))
                flow.advance()
            }
        }
    }

    private func completeReclaim() {
        Haptics.notify(.success)
        confettiStart = Date()          // fire the burst from the clock
        linesReady = false
        withAnimation(.easeInOut(duration: 0.4)) { revealStage = .reclaimed }
        // Once the burst has popped, retire the clock — its job is done.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.2))
            withAnimation(.easeInOut(duration: 0.7)) { clockFaded = true }
        }
    }

    private var revealView: some View {
        ZStack {
        VStack(spacing: 0) {
            OnbTopBar(showBack: true, progress: nil, onSky: true)

            // Fox planted on the pillar — same 260 height + contact-shadow ellipse
            // + offset as the intro scaffold, so the feet land on the flat top.
            // (`.id` forces the video to reload when the resource swaps.)
            LoopingVideoView(resource: revealStage == .reclaimed ? "InterventionEncourageFox"
                                                                 : "ProofFailureFox")
                .id(revealStage == .reclaimed)
                .frame(height: 260)
                .frame(maxWidth: .infinity)
                .background(alignment: .bottom) {
                    Ellipse()
                        .fill(Color.black.opacity(0.12))
                        .frame(width: 260 * 0.51, height: 260 * 0.136)
                        .offset(y: -13)
                }
                .offset(x: 4, y: -4)
                .padding(.top, Theme.Spacing.xl)

            // The fox's line, typed in line by line — EXACT intro styling/position
            // (heroCompact bold, white + double shadow, maxWidth 500, padding-top l).
            TypewriterLines(lines: revealLines, maxWidth: 500, onAllDone: handleLinesDone)
                .auraFont(.display, SheetType.heroCompact, .bold)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.55), radius: 4, y: 1)
                .shadow(color: .black.opacity(0.5), radius: 16, y: 3)
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.l)
                .frame(height: 84, alignment: .top)   // reserve so the clock never jumps

            // The interactive clock + (once the fox finishes) the drag sticker.
            VStack(spacing: Theme.Spacing.m) {
                LoopTime(minutes: draggedMinutes, color: reclaimColor(hourProgress), size: 46)
                    .opacity(clockFaded ? 0 : 1)

                if revealStage == .invite && linesReady {
                    VStack(spacing: Theme.Spacing.s) {
                        HourDragControl(progress: $hourProgress, onComplete: completeReclaim)
                        Text("drag the clock back to 10:30")
                            .auraFont(.body, SheetType.subtitle, .semibold)
                            .foregroundStyle(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.5), radius: 6, y: 1)
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .transition(.opacity)
                }
            }
            .padding(.top, Theme.Spacing.l)

            Spacer()

            // No button on the reveal — the fox's bridge lines carry into the demos.
            Spacer().frame(height: Theme.Spacing.xl)
        }

        // Confetti bursts from the clock the moment the hour is reclaimed.
        if confettiStart != nil {
            ConfettiBurst(start: confettiStart, originY: 0.56)
                .allowsHitTesting(false)
        }
        }
    }
}

/// The draggable "take the hour back" sticker on a track. Drag it from the 11:30
/// end (right) to the 10:30 end (left); `progress` runs 0 → 1. PLACEHOLDER sticker
/// art (a rewind-clock chip) — swap for the real sticker.
private struct HourDragControl: View {
    @Binding var progress: CGFloat
    var onComplete: () -> Void

    private let stickerSize: CGFloat = 58   // same knob size as the onboarding timer slider
    @State private var committed: CGFloat = 0
    @State private var done = false

    var body: some View {
        GeometryReader { geo in
            let trackW = max(1, geo.size.width - stickerSize)
            ZStack(alignment: .leading) {
                // Track: onboarding-slider height (14), same recessed fill as the
                // age-picker highlight (black 0.42); inset by half a sticker so the
                // clock overhangs the ends.
                Capsule()
                    .fill(Color.black.opacity(0.42))
                    .frame(height: 14)
                    .padding(.horizontal, stickerSize / 2)
                    .frame(maxHeight: .infinity, alignment: .center)
                sticker
                    .offset(x: (1 - progress) * trackW)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        guard !done else { return }
                        progress = min(1, max(0, committed - g.translation.width / trackW))
                    }
                    .onEnded { _ in
                        guard !done else { return }
                        if progress >= 0.6 {
                            done = true
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { progress = 1 }
                            committed = 1
                            onComplete()
                        } else {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { progress = 0 }
                            committed = 0
                        }
                    }
            )
        }
        .frame(height: stickerSize)
    }

    private var sticker: some View {
        Image("Achievement_TimeFocused")
            .resizable().interpolation(.high).scaledToFit()
            .frame(width: stickerSize, height: stickerSize)
            .rotationEffect(.degrees(12))   // slight tilt to the right
            .shadow(color: .black.opacity(0.28), radius: 8, y: 3)
    }
}

// MARK: - Confetti

/// A one-shot confetti burst that fires up-and-out from a point (`originY` as a
/// fraction of screen height — the clock) the moment `start` is set. Drawn in a
/// full-screen Canvas so nothing clips; simple projectile physics (up-fan + gravity).
private struct ConfettiBurst: View {
    var start: Date?
    var originY: CGFloat = 0.5

    private let gravity: CGFloat = 720
    private let lifetime: TimeInterval = 2.4
    private let pieces: [Piece] = (0..<46).map { _ in Piece.random() }

    var body: some View {
        GeometryReader { geo in
            let origin = CGPoint(x: geo.size.width / 2, y: geo.size.height * originY)
            TimelineView(.animation) { tl in
                Canvas { ctx, _ in
                    guard let start else { return }
                    let t = tl.date.timeIntervalSince(start)
                    guard t >= 0, t < lifetime else { return }
                    let ct = CGFloat(t)
                    let fadeStart = lifetime * 0.6
                    let alpha = t < fadeStart ? 1 : max(0, 1 - (t - fadeStart) / (lifetime - fadeStart))
                    for p in pieces {
                        let x = origin.x + p.vx * ct
                        let y = origin.y + p.vy * ct + 0.5 * gravity * ct * ct
                        ctx.drawLayer { layer in
                            layer.opacity = alpha
                            layer.translateBy(x: x, y: y)
                            layer.rotate(by: .radians(p.spin * t))
                            let rect = CGRect(x: -p.w / 2, y: -p.h / 2, width: p.w, height: p.h)
                            layer.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(p.color))
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
    }

    private struct Piece {
        var vx: CGFloat, vy: CGFloat, spin: Double, w: CGFloat, h: CGFloat, color: Color
        static let palette: [Color] = [
            Color(hex: "22E06A"), Color(hex: "4A5DF9"), Color(hex: "FFD600"),
            Color(hex: "FF7A00"), Color(hex: "FF3B30"), Color(hex: "D300C5"), .white,
        ]
        static func random() -> Piece {
            let a = Double.random(in: (-Double.pi * 0.88)...(-Double.pi * 0.12))  // upward fan
            let s = CGFloat.random(in: 200...560)
            return Piece(
                vx: CGFloat(cos(a)) * s,
                vy: CGFloat(sin(a)) * s,
                spin: Double.random(in: -7...7),
                w: CGFloat.random(in: 5...9),
                h: CGFloat.random(in: 9...15),
                color: palette.randomElement()!
            )
        }
    }
}

// MARK: - The clock (big bare text, no pill)

private struct LoopTime: View {
    let minutes: Int
    let color: Color
    var size: CGFloat = 42

    private var parts: (time: String, suffix: String) {
        let h24 = minutes / 60, m = minutes % 60
        let h12 = h24 % 12 == 0 ? 12 : h24 % 12
        return (String(format: "%d:%02d", h12, m), h24 >= 12 ? "PM" : "AM")
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(parts.time)
                .auraFont(.display, size, .heavy)
                .contentTransition(.numericText())
            Text(parts.suffix)
                .auraFont(.display, size * 0.52, .heavy)
                .opacity(0.9)
        }
        .foregroundStyle(color)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: color)
    }
}

// MARK: - Story-ring avatar (shared by the stories strip and the feed posts)


// Shared story-avatar geometry: the outer ring diameter, and the ring width / gap /
// inner icon size derived from it (so the ringless "Your story" avatar can match the
// app-icon circles exactly).
private let storyRingSize: CGFloat = 48
private func storyRingWidth(_ size: CGFloat) -> CGFloat { max(1.5, size * 0.05) }
private func storyGap(_ size: CGFloat) -> CGFloat { max(1.5, size * 0.05) }
private func storyInner(_ size: CGFloat) -> CGFloat { size - 2 * (storyRingWidth(size) + storyGap(size)) }

/// The one horizontal inset every element on the phone screen shares, so left and
/// right edges line up down the whole feed.
private let feedInset: CGFloat = 5

// The feed renders in dark mode (like Instagram) even though the onboarding screen
// around it stays light.
private let feedBG = Color(hex: "0C1014")     // kit background/default
private let feedText = Color(hex: "F7F9F9")   // kit text/default
/// Translucent dark material shared by the carousel "Slides" pill and the reel
/// sound button (reads over any media).
private let feedPillBG = Color.black.opacity(0.45)

/// Instagram's system typeface (SF Pro) — used for the IN-PHONE feed text only, so
/// the mockup reads like the real app (the surrounding screen keeps Aura's font).
private extension View {
    func igFont(_ size: CGFloat, _ weight: Font.Weight) -> some View {
        self.font(.system(size: size, weight: weight))
    }
}

/// A coolicons line icon, rendered as a tintable template at a given size.
private func coolIcon(_ name: String, _ size: CGFloat, flipX: Bool = false) -> some View {
    Image(name)
        .renderingMode(.template)
        .resizable().interpolation(.high).scaledToFit()
        .frame(width: size, height: size)
        .scaleEffect(x: flipX ? -1 : 1, y: 1)
}

/// Story-ringed avatar for the parody accounts: an emoji on a brand-ish colour,
/// since the feed images are full scenes rather than profile headshots.
private struct AccountAvatar: View {
    let image: String
    var size: CGFloat = 30
    var ringed: Bool = true
    /// Live variant of the kit's Story Bar: same gradient ring, but a dark inner disc
    /// (68/78) and a smaller bordered picture (50/78) — reads distinctly from new-story.
    var live: Bool = false
    /// Post/reel header variant — the kit's "User / Post Header & Comments List": the
    /// picture is inset 8.82% (82.36%) with a #DBDFE4 border, no dark base.
    var header: Bool = false
    var body: some View {
        // Reproduces the kit component geometry (78-unit ref for Story Bar; the picture
        // fraction differs per component): Story Bar new-story = 68/78, live = 50/78,
        // Post Header = inset 8.82%.
        let picSize: CGFloat = {
            if !ringed { return size }
            if live { return size * 50 / 78 }                  // Story Bar live
            if header { return size * (1 - 2 * 0.0882) }        // Post Header (inset 8.82%)
            return size * (1 - 2 * 0.0581)                      // User / Profile (inset 5.81%)
        }()
        let borderWidth = max(0.5, size * 0.02)
        ZStack {
            if live {
                Circle().fill(Color(hex: "0C1014"))
                    .frame(width: size * 68 / 78, height: size * 68 / 78)
            }
            Image(image)
                .resizable().interpolation(.high).scaledToFill()
                .frame(width: picSize, height: picSize)
                .clipShape(Circle())
                .overlay {
                    // Picture border — black (merges with the dark gap so it reads
                    // as a slightly wider gap between picture and ring).
                    if ringed {
                        Circle().strokeBorder(feedBG, lineWidth: borderWidth)
                    }
                }
            if ringed {
                Image("StoryRing")
                    .resizable().interpolation(.high).scaledToFit()
                    .frame(width: size, height: size)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Instagram "Follow" button: filled (dark chip) for suggested posts, outline for
/// reels. Uses the top-bar chip colour for the fill.
private struct FollowButton: View {
    enum Kind { case filled, outline }
    let kind: Kind
    var body: some View {
        Text("Follow")
            .igFont(9, .semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                if kind == .filled {
                    RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color(hex: "25292E"))
                } else {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.85), lineWidth: 1)
                }
            }
    }
}

/// A neutral "you" avatar (grey silhouette), so aura never appears inside the
/// brainrot app — the feed is meant to trigger, not to introduce the fox yet.
private struct YouAvatar: View {
    var size: CGFloat = 30
    var body: some View {
        Image("feed_empty_profile")
            .resizable().interpolation(.high).scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
    }
}

/// Instagram carousel pagination (from the kit's "Pagination"): a sliding window of
/// dots — active dot blue, the rest chip-grey, and the outermost dots shrink when
/// there are more slides beyond the window.
private struct CarouselDots: View {
    let active: Int
    let total: Int
    private let window = 5

    var body: some View {
        let half = (window - 1) / 2
        var start = active - half
        var end = active + half
        if start < 0 { end -= start; start = 0 }
        if end > total - 1 { start -= (end - (total - 1)); end = total - 1 }
        start = max(0, start)
        return HStack(spacing: 4) {
            ForEach(start...end, id: \.self) { i in
                Circle()
                    .fill(i == active ? Color(hex: "4A5DF9") : Color(hex: "25292E"))
                    .frame(width: dotSize(i, start: start, end: end),
                           height: dotSize(i, start: start, end: end))
            }
        }
    }

    private func dotSize(_ i: Int, start: Int, end: Int) -> CGFloat {
        if (i == start && start > 0) || (i == end && end < total - 1) { return 2.5 }
        if (i == start + 1 && start > 0) || (i == end - 1 && end < total - 1) { return 3.5 }
        return 4.5
    }
}

// MARK: - Feed content (the brainrot the ICP resents: AI slop, looksmaxxing, fake
// hustle, an OnlyFans-parody street interview, gambling. Captions are the accounts'
// own voice, not Aura's — aura is deliberately absent from this feed.)

private struct FeedPost: Identifiable {
    let id = UUID()
    let name: String
    let avatarImage: String
    let image: String
    let caption: String
    let time: String
    let verified: Bool
    let likes: String
    let comments: String
    let reposts: String
    let shares: String
    /// Carousel page dots: 0 = single image (no dots). `carouselActive` is the
    /// zero-based index of the highlighted (blue) dot.
    var carouselCount: Int = 0
    var carouselActive: Int = 0
}

private let feedPosts: [FeedPost] = [
    .init(name: "dailyaislop", avatarImage: "avatar_aislop", image: "feed_aislop",
          caption: "Follow for more slop 🤪", time: "2 hours ago", verified: true,
          likes: "1.2M", comments: "48.5k", reposts: "112k", shares: "203k"),
    .init(name: "mandibular", avatarImage: "avatar_chad", image: "feed_chad",
          caption: "just bonesmashed! do I mog?? 🤔", time: "3 hours ago", verified: true,
          likes: "892k", comments: "21.3k", reposts: "45.2k", shares: "88.1k",
          carouselCount: 6, carouselActive: 0),
    .init(name: "samscales", avatarImage: "avatar_hustle", image: "feed_hustle",
          caption: "your 9-5 is keeping you a brokie 💰 link in bio", time: "5 hours ago", verified: true,
          likes: "1.5M", comments: "63.7k", reposts: "98.4k", shares: "312k",
          carouselCount: 9, carouselActive: 0),
    .init(name: "sophiestorm", avatarImage: "avatar_onlystans", image: "feed_onlystans",
          caption: "He said WHAT to her 💀 full vid on my page 🔗", time: "6 hours ago", verified: true,
          likes: "2.3M", comments: "104k", reposts: "156k", shares: "421k"),
    .init(name: "johnjustdidit", avatarImage: "avatar_johnjustdidit", image: "feed_gamble",
          caption: "THIS WAS INSANE!!! free $$ with my CloudGamble code johnjustdidit 🎰", time: "7 hours ago", verified: true,
          likes: "978k", comments: "33.2k", reposts: "51.9k", shares: "144k"),
]

// MARK: - The phone + live feed (Instagram-style layout)

/// Reports the feed's full (unclipped) content height up so the scroll can run all
/// the way to the bottom instead of stopping at a guessed distance.
private struct FeedHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct LoopPhone: View {
    let scroll: CGFloat
    var reminder: ScreenTimeReminder? = nil
    /// Darken the screen with the swipe prompt until the first flick.
    var dimmed: Bool = false
    var onContentHeight: (CGFloat) -> Void = { _ in }
    /// The phone's own status-bar clock — same burning time as the big clock above.
    var statusTime: String = ""

    private let bezel = Color(hex: "111114")
    // The five unique accounts, in order — no repeat (a doubled list was showing
    // dailyaislop first AND last).
    private let posts: [FeedPost] = feedPosts
    /// The phone's screen width: the 230 frame minus the 7pt bezel each side.
    private let screenW: CGFloat = 216

    /// The whole scrolling feed as ONE column (island gap, top bar, stories, posts),
    /// offset up and clipped — reused for the sharp render and the blurred top copy.
    private var feedColumn: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 47)     // island gap (scrolls too)

            // App top bar: create + on the left, the brainrot wordmark centred,
            // activity heart on the right.
            HStack(spacing: 0) {
                coolIcon("ig_plus", 17)
                    .foregroundStyle(feedText)
                    .frame(width: 29, height: 29)
                    .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color(hex: "25292E")))
                Spacer(minLength: 0)
                BrainrotLogo()
                Spacer(minLength: 0)
                coolIcon("ig_like", 17)
                    .foregroundStyle(feedText)
                    .overlay(alignment: .topTrailing) {
                        // Same 4pt solid red as the nav dots, overlapping the heart more.
                        Circle().fill(Color(hex: "ff0034"))
                            .frame(width: 4, height: 4)
                            .offset(x: -1, y: 1.5)
                    }
                    .frame(width: 29, height: 29)
                    .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color(hex: "25292E")))
            }
            .padding(.horizontal, feedInset)
            .padding(.bottom, Theme.Spacing.xs + 2)

            // Stories: gradient-ringed avatars, running off the right.
            StoriesStrip()
                .frame(width: screenW, alignment: .leading)
                .clipped()

            // Posts, full-bleed like Instagram; a "Suggested for you" carousel drops in
            // after the second post like the real feed.
            VStack(spacing: 0) {
                ForEach(Array(posts.enumerated()), id: \.element.id) { idx, post in
                    LoopFeedPost(post: post, width: screenW)
                    if idx == 1 { SuggestedSection() }
                }
            }
        }
        .frame(width: screenW, alignment: .top)
        .background(
            GeometryReader { p in
                Color.clear.preference(key: FeedHeightKey.self, value: p.size.height)
            }
        )
        .offset(y: -scroll)
        .frame(width: screenW, height: 444, alignment: .top)
        .clipped()
    }

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height
            // The mockup's blue screen glass, measured off PhoneMockupDark
            // (1532×3140): insets L 3.92% · R 4.05% · T 1.53% · B 1.59% of the
            // frame. The feed is a plain rectangle placed over this rect; it carries
            // NO corners of its own — a mask cut from the real screen (LoopScreenMask)
            // clips it to the device's exact screen shape, so it can never poke past
            // the phone's rounded corners nor leave a gap to the wallpaper.
            let gX = W * 0.0392
            let gY = H * 0.0153
            let gW = W * 0.9204
            let gH = H * 0.9688

            ZStack {
                // Real device (opaque) — drawn only for its correct drop shadow and
                // base bezel. Its baked blue screen is fully covered by the feed.
                // Shadow on this single image alone — never on the feed (that
                // pixelates the icons).
                Image("PhoneMockupDark")
                    .resizable().interpolation(.high)
                    .frame(width: W, height: H)
                    .shadow(color: .black.opacity(0.20), radius: 24, y: 14)

                Rectangle()
                    .fill(feedBG)
                    .overlay {
                        ZStack(alignment: .top) {
                            feedColumn
                            // A true gaussian blur of the feed at the very top — crystal
                            // clear frosted glass (a blurred copy of the real content), not
                            // a washed-out material. Only while scrolling; at rest the black
                            // top bar stays pure black.
                            feedColumn
                                .blur(radius: 3)
                                .mask(
                                    LinearGradient(colors: [.black, .black, .clear],
                                                   startPoint: .top, endPoint: .bottom)
                                        .frame(height: 64)
                                        .frame(maxHeight: .infinity, alignment: .top)
                                )
                                .opacity(scroll > 0 ? 1 : 0)
                                .animation(.easeOut(duration: 0.2), value: scroll > 0)
                                .allowsHitTesting(false)
                        }
                        .frame(maxHeight: .infinity, alignment: .top)
                    }
                    .overlay(alignment: .bottom) {
                        // The floating nav shrinks once the feed starts scrolling, like
                        // Instagram's (and Aura's own) nav bar.
                        LoopNavBar()
                            .scaleEffect(scroll > 0 ? 0.8 : 1, anchor: .bottom)
                            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: scroll > 0)
                            .padding(.bottom, 10)
                    }
                    .overlay(alignment: .top) {
                        // The Aura nudge slides down from under the island, like a real iOS
                        // banner, then auto-dismisses — the user scrolls right past it.
                        if let reminder {
                            NotificationBanner(reminder: reminder)
                                .padding(.horizontal, 8)
                                .padding(.top, 40)
                                .transition(.move(edge: .top).combined(with: .opacity))
                                .id(reminder)   // distinct identity → real out/in, never a text swap
                        }
                    }
                    .overlay {
                        // Dim the whole screen with the swipe prompt centred, until the
                        // first flick — makes the one gesture unmissable. Non-blocking so
                        // the swipe underneath still registers.
                        ZStack {
                            Color.black.opacity(0.62)
                            SwipeUpHint()
                        }
                        .opacity(dimmed ? 1 : 0)
                        .animation(.easeOut(duration: 0.35), value: dimmed)
                        .allowsHitTesting(false)
                    }
                    // A hair larger than the screen so the mask has full coverage to
                    // its edges.
                    .frame(width: gW + 6, height: gH + 6)
                    .clipped()
                    .position(x: gX + gW / 2, y: gY + gH / 2)
                    // Mask the feed to the device's EXACT screen shape (a white
                    // screen-region image cut from the mockup, LoopScreenMask). The
                    // MASK — not a clip radius — defines the corners, so the feed can
                    // never poke past the phone's rounded outer corners. The opaque
                    // PhoneMockupDark underneath shows the bezel around it.
                    .mask(
                        Image("LoopScreenMask")
                            .resizable().interpolation(.high)
                            .frame(width: W, height: H)
                    )

                // iOS status bar, flanking the island: burning clock on the left, the
                // usual radios on the right.
                HStack(spacing: 0) {
                    // Left "ear": the time centred between the screen edge and the island.
                    // Digits have no descenders, so line-box centring rides high — nudge
                    // down to optically match the icons.
                    Text(statusTime)
                        .igFont(9, .semibold)
                        .offset(y: 1.5)
                        .frame(maxWidth: .infinity)
                    // The island gap (matches the pill width), so each ear abuts it.
                    Color.clear.frame(width: 68)
                    // Right "ear": the radios centred in the mirror space.
                    HStack(spacing: 3.5) {
                        Image(systemName: "cellularbars")
                        Image(systemName: "wifi")
                        Image(systemName: "battery.75")
                    }
                    .igFont(8, .semibold)
                    .offset(x: -3)   // nudge the radios slightly left of the ear centre
                    .frame(maxWidth: .infinity)
                }
                .foregroundStyle(feedText)
                .padding(.horizontal, 8)
                // Occupy the island's exact vertical band (top 14, height 21) with the
                // content centred, so the text lines up vertically with the island.
                .frame(height: 21)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 14)

                // Dynamic-island pill sized/placed to the device's real island (measured
                // off the mockup: 28.7% wide, 3.9% tall, centre at 5% down) so it reads as
                // the phone's own island.
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.black)
                    .frame(width: 66, height: 18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 14)
            }
            .frame(width: W, height: H)
        }
        .onPreferenceChange(FeedHeightKey.self) { onContentHeight($0) }
    }
}

/// A pixel-mini iOS notification banner from Aura, styled like a real lock/home
/// banner. Its copy is pulled straight from `ScreenTimeReminder` — the exact same
/// nudges the app sends once it's watching your usage — so the demo is a true
/// preview of the feature, not invented text.
private struct NotificationBanner: View {
    let reminder: ScreenTimeReminder
    private let barBG = Color(hex: "121214")

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image("AuraAppIcon")
                .resizable().interpolation(.high).scaledToFill()
                .frame(width: 18, height: 18)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                // Title + timestamp share one line, iOS-banner style.
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(reminder.title)
                        .igFont(7, .semibold)
                        .foregroundStyle(.white)
                    Spacer(minLength: 4)
                    Text("now")
                        .igFont(5.5, .regular)
                        .foregroundStyle(Color.white.opacity(0.4))
                }
                Text(reminder.body)
                    .igFont(6.5, .regular)
                    .foregroundStyle(Color.white.opacity(0.8))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        // Same dark fill as the fake nav bar; hairline a touch darker than the nav's.
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(barBG.opacity(0.92))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.55), lineWidth: 0.5))
        )
        .environment(\.colorScheme, .dark)
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }
}

/// A looping swipe-up hand that shows the one gesture the loop needs. Built in
/// SwiftUI (no Lottie/asset): a hand that rises and fades on repeat, over a caption.
private struct SwipeUpHint: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            PhaseAnimator([false, true]) { up in
                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(18))
                    .offset(y: up ? -24 : 10)
                    .opacity(up ? 0 : 1)
            } animation: { up in
                up ? .easeOut(duration: 0.85) : .easeIn(duration: 0.45)
            }
            .frame(height: 42)

            Text("Swipe up")
                .auraFont(.body, SheetType.cardBlurb, .bold)
                .foregroundStyle(.white)
        }
        // Sits ON the feed image, so cast a soft shadow to stay legible over anything.
        .shadow(color: .black.opacity(0.55), radius: 6, y: 1)
    }
}

/// Instagram-style floating bottom nav bar for the fake feed.
private struct LoopNavBar: View {
    private let barBG = Color(hex: "121214")
    var body: some View {
        // Five equal slots so the ICONS are evenly spaced. The home highlight pill
        // is a background CENTRED on the home icon, so it decorates the icon without
        // shifting the spacing.
        HStack(spacing: 0) {
            // Home glyph is a wide house; size it by HEIGHT so it matches the other
            // icons' visual size (a square frame would render it small). It's a raster
            // (white on transparent), so render .original — template masking a raster
            // hard-edges it (pixelated); .original keeps the smooth anti-aliased edges.
            Image("ig_home")
                .renderingMode(.original)
                .resizable().interpolation(.high).scaledToFit()
                .frame(width: 19, height: 14)
                .frame(maxWidth: .infinity)
                .frame(height: 26)
                .background(Capsule().fill(Color.white.opacity(0.14)).frame(width: 40, height: 26))
            coolIcon("ig_reels", 16).foregroundStyle(feedText).frame(maxWidth: .infinity)
            coolIcon("ig_share", 16).foregroundStyle(feedText)
                .overlay(alignment: .bottomTrailing) {
                    // Notification dot on the DM/share icon, same gap as the profile.
                    Circle().fill(Color(hex: "ff0034"))
                        .frame(width: 4, height: 4)
                        .offset(x: -1, y: 0)
                }
                .frame(maxWidth: .infinity)
            coolIcon("ig_search", 16).foregroundStyle(feedText).frame(maxWidth: .infinity)
            // Neutral "you" profile avatar (no aura in the brainrot app).
            YouAvatar(size: 13)
                .overlay(alignment: .bottomTrailing) {
                    // Kit's notification "Dot" red; sits just outside the avatar's
                    // bottom-right, no border. Same size + gap as the share icon's dot.
                    Circle().fill(Color(hex: "ff0034"))
                        .frame(width: 4, height: 4)
                        .offset(x: 2.5, y: 2.5)
                }
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .frame(width: 198)
        .background(
            Capsule().fill(barBG.opacity(0.92))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.9), lineWidth: 0.5))
        )
    }
}

/// The brainrot logo (brain-in-speech-bubble mascot + wordmark).
private struct BrainrotLogo: View {
    var body: some View {
        Image("BrainrotLogo")
            .resizable().interpolation(.high).scaledToFit()
            .frame(height: 28)
    }
}

// MARK: - "Suggested for you" section (kit "Discover Users")

private struct SuggestedUser: Identifiable {
    let id = UUID()
    let image: String
    let name: String
    let verified: Bool
}

private let suggestedUsers: [SuggestedUser] = [
    .init(image: "avatar_andrewskate", name: "Andrew Skate", verified: true),
    .init(image: "avatar_kylietenner", name: "Kylie Tenner", verified: true),
]

/// The kit's "Discover Users" card (scaled to the mockup): dark rounded card, a close
/// X, a circular photo, name + verified badge, a "Suggested for you" subtitle, and a
/// filled Follow button.
private struct DiscoverUserCard: View {
    let user: SuggestedUser
    var body: some View {
        VStack(spacing: 5) {
            Image(user.image)
                .resizable().interpolation(.high).scaledToFill()
                .frame(width: 54, height: 54)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Color(hex: "25292E"), lineWidth: 0.5))
            VStack(spacing: 1) {
                HStack(spacing: 2) {
                    Text(user.name)
                        .igFont(9.5, .semibold)
                        .foregroundStyle(feedText)
                        .lineLimit(1)
                    if user.verified {
                        Image("VerifiedBadgeSmall")
                            .renderingMode(.template).resizable().interpolation(.high).scaledToFit()
                            .foregroundStyle(Color(hex: "0095F6"))
                            .frame(width: 9, height: 9)
                    }
                }
                Text("Suggested for you")
                    .igFont(6.5, .regular)
                    .foregroundStyle(Color(hex: "6F7680"))
                    .lineLimit(1)
            }
            Text("Follow")
                .igFont(9.5, .semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 19)
                .background(RoundedRectangle(cornerRadius: 4.5, style: .continuous).fill(Color(hex: "4A5DF9")))
        }
        .padding(.horizontal, 7)
        .padding(.top, 10)
        .padding(.bottom, 7)
        .frame(width: 114)
        .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color(hex: "25292E")))
        .overlay(alignment: .topTrailing) {
            Image("ig_close")
                .renderingMode(.template).resizable().interpolation(.high).scaledToFit()
                .foregroundStyle(Color(hex: "6F7680"))
                .frame(width: 9, height: 9)
                .padding(5)
        }
    }
}

/// The "Suggested for you" section: a header (title, See all, more) + a horizontal
/// row of Discover Users cards, framed by hairline dividers like Instagram.
private struct SuggestedSection: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("Suggested for you")
                    .igFont(10, .semibold)
                    .foregroundStyle(feedText)
                Spacer(minLength: 0)
                Text("See all")
                    .igFont(9, .semibold)
                    .foregroundStyle(Color(hex: "4A5DF9"))
                    .underline()
                coolIcon("ig_options", 14).foregroundStyle(feedText).padding(.leading, 7)
            }
            .padding(.horizontal, feedInset + 3)
            .padding(.vertical, Theme.Spacing.s)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(suggestedUsers) { DiscoverUserCard(user: $0) }
                }
                .padding(.horizontal, feedInset + 3)
                .padding(.bottom, Theme.Spacing.m)
            }
        }
    }
}

/// The pinned stories row: gradient-ringed avatars with names under them.
private struct StoriesStrip: View {
    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.s) {
            // Your story, far left — a neutral "you" avatar (no aura), + badge.
            VStack(spacing: 3) {
                ZStack(alignment: .bottomTrailing) {
                    YouAvatar(size: storyInner(storyRingSize))
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
                    coolIcon("ig_add", 6)
                        .foregroundStyle(.black)
                        .frame(width: 13, height: 13)
                        .background(Circle().fill(.white))
                        .overlay(Circle().strokeBorder(feedBG, lineWidth: 1.5))
                }
                .frame(width: storyRingSize, height: storyRingSize)
                Text("Your story")
                    .igFont(8, .semibold)
                    .foregroundStyle(feedText)
                    .lineLimit(1)
            }
            .frame(width: 52)

            // Live accounts move to the front of the stories row, like Instagram.
            ForEach(feedPosts.filter { $0.name == "mandibular" } + feedPosts.filter { $0.name != "mandibular" }) { post in
                VStack(spacing: 3) {
                    AccountAvatar(image: post.avatarImage, size: storyRingSize, live: post.name == "mandibular")
                        .overlay(alignment: .bottom) {
                            // "LIVE" badge from the kit's Story Bar live state: a Live/Pink
                            // 100 rounded rect with a border, straddling the ring bottom.
                            if post.name == "mandibular" {
                                // Bigger badge; its TOP touches the bottom of the inner
                                // (50/78) picture, so it straddles picture and ring.
                                Text("LIVE")
                                    .font(.system(size: 6.5, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .tracking(0.2)
                                    .frame(width: 22, height: 12)
                                    .background(RoundedRectangle(cornerRadius: 2.5, style: .continuous).fill(Color(hex: "FF0069")))
                                    .overlay(RoundedRectangle(cornerRadius: 2.5, style: .continuous).strokeBorder(Color(hex: "0C1014"), lineWidth: 1))
                                    .offset(y: 1.4)
                            }
                        }
                    Text(post.name)
                        .igFont(8, .semibold)
                        .foregroundStyle(feedText)
                        .lineLimit(1)
                }
                .frame(width: 48)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, feedInset)
        .padding(.vertical, Theme.Spacing.xs + 1)
    }
}

/// One Instagram-style feed post: header (ringed avatar + app name + more), a
/// full-bleed emoji-subject media pane (some video), an icon-only action row, the
/// likes count, the username-prefixed caption, then the timestamp.
private struct LoopFeedPost: View {
    let post: FeedPost
    let width: CGFloat

    private let glyph = feedText

    private var isReel: Bool { post.carouselCount == 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Carousel posts get a "Suggested for you" header above the media; reels
            // move the header inside the media instead.
            if !isReel { postHeader }

            media

            // Carousel page dots (multi-image posts only), centred under the media.
            if post.carouselCount > 0 {
                CarouselDots(active: post.carouselActive, total: post.carouselCount)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Theme.Spacing.m)
            }

            // Action row (inset): like, comment, repost (loop arrows), share,
            // then save on the right.
            HStack(spacing: Theme.Spacing.xs) {
                action("ig_like", post.likes)
                action("ig_comment", post.comments)
                action("ig_repost", post.reposts)
                action("ig_share", post.shares)
                Spacer(minLength: Theme.Spacing.xs)
                coolIcon("ig_save", 15)
            }
            .foregroundStyle(glyph)
            .padding(.horizontal, feedInset)
            .padding(.top, 6)
            .padding(.bottom, 6)

            // Username-prefixed caption (inset): caption is slightly smaller than the
            // username, separated by weight. Truncates with a grey "more".
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 4) {
                    Text(post.name).igFont(10, .bold).foregroundStyle(feedText)
                    Text(post.caption).igFont(9, .regular).foregroundStyle(feedText)
                }
                .fixedSize(horizontal: true, vertical: false)

                HStack(spacing: 4) {
                    Text(post.name).igFont(10, .bold).foregroundStyle(feedText).fixedSize()
                    Text(post.caption).igFont(9, .regular).foregroundStyle(feedText)
                        .lineLimit(1).truncationMode(.tail)
                    Text("more").igFont(9, .regular).foregroundStyle(Color(hex: "6F7680")).fixedSize()
                }
            }
            .padding(.horizontal, feedInset)

            // Timestamp (inset): lowercase, muted grey, small.
            Text(post.time)
                .igFont(8, .regular)
                .foregroundStyle(Color(hex: "6F7680"))
                .padding(.horizontal, feedInset)
                .padding(.top, 6)
                .padding(.bottom, Theme.Spacing.m + 2)
        }
    }

    // MARK: - Header + media variants

    /// Suggested-post header: ringed avatar, username + "Suggested for you" (centred),
    /// a filled Follow button, then the more menu.
    private var postHeader: some View {
        HStack(spacing: Theme.Spacing.s - 2) {
            AccountAvatar(image: post.avatarImage, size: 24, header: true)
            VStack(alignment: .leading, spacing: 1) {
                nameRow(verifiedColor: Color(hex: "0095F6"))
                Text("Suggested for you")
                    .igFont(7, .regular)
                    .foregroundStyle(feedText)
            }
            Spacer(minLength: 0)
            FollowButton(kind: .filled)
            coolIcon("ig_options", 16).foregroundStyle(glyph)
        }
        .padding(.horizontal, feedInset)
        .padding(.vertical, Theme.Spacing.xs + 1)
    }

    private var media: some View {
        Image(post.image)
            .resizable().interpolation(.high)
            .aspectRatio(contentMode: .fill)
            .frame(width: width, height: isReel ? width * 16 / 9 : width * 5 / 4)
            .clipped()
            .overlay(alignment: .topTrailing) {
                // Carousel "Slides" counter pill, e.g. 1/6.
                if post.carouselCount > 0 {
                    Text("\(post.carouselActive + 1)/\(post.carouselCount)")
                        .igFont(8, .semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(feedPillBG))
                        .padding(8)
                }
            }
            .overlay(alignment: .bottomLeading) {
                // Carousel "tagged people" button, bottom-left (matches the sound button).
                if post.carouselCount > 0 {
                    circleIconButton("ig_tagged").padding(8)
                }
            }
            .overlay { if isReel { reelOverlay } }
    }

    /// Small translucent circular icon button (sound on reels, tagged on carousels).
    private func circleIconButton(_ name: String) -> some View {
        Image(name)
            .renderingMode(.template)
            .resizable().interpolation(.high).scaledToFit()
            .foregroundStyle(.white)
            .frame(width: 8, height: 8)
            .frame(width: 16, height: 16)
            .background(Circle().fill(feedPillBG))
    }

    /// Reel overlay: a top scrim for legibility + the header (avatar, username with a
    /// WHITE badge, music row, outline Follow, more) and a bottom-right sound button.
    private var reelOverlay: some View {
        ZStack {
            LinearGradient(colors: [.black.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 74)
                .frame(maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                HStack(spacing: Theme.Spacing.s - 2) {
                    AccountAvatar(image: post.avatarImage, size: 24, header: true)
                    VStack(alignment: .leading, spacing: 1) {
                        nameRow(verifiedColor: .white)
                        HStack(spacing: 3) {
                            Image("ig_musicnote")
                                .renderingMode(.template)
                                .resizable().interpolation(.high).scaledToFit()
                                .foregroundStyle(.white)
                                .frame(width: 6, height: 6)
                            Text("\(post.name) · Original audio")
                                .igFont(7, .regular)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                    FollowButton(kind: .outline)
                    coolIcon("ig_options", 16).foregroundStyle(.white)
                }
                .padding(.horizontal, feedInset + 2)
                .padding(.top, Theme.Spacing.s)

                Spacer(minLength: 0)

                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    circleIconButton("ig_soundon")
                }
                .padding(.horizontal, feedInset + 2)
                .padding(.bottom, Theme.Spacing.s)
            }
        }
    }

    /// Username + verified badge (badge colour differs: blue on posts, white on reels).
    private func nameRow(verifiedColor: Color) -> some View {
        HStack(spacing: 3) {
            Text(post.name)
                .igFont(9, .bold)
                .underline()
                .foregroundStyle(feedText)
                .lineLimit(1)
            if post.verified {
                Image("VerifiedBadgeSmall")
                    .renderingMode(.template)
                    .resizable().interpolation(.high).scaledToFit()
                    .foregroundStyle(verifiedColor)
                    .frame(width: 8, height: 8)
            }
        }
    }

    private func action(_ icon: String, _ count: String, flipX: Bool = false) -> some View {
        HStack(spacing: 3) {
            coolIcon(icon, 15, flipX: flipX)
            Text(count)
                .igFont(9, .bold)
                .underline()
                .fixedSize()
        }
    }
}
