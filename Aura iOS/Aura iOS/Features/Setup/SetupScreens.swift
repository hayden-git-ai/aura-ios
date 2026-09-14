//
//  SetupScreens.swift
//  Aura iOS
//
//  The setup-handoff steps. Deterministic layout: the sunbeam/rings centre AND
//  the hero are both centred on the background (0.5); the title sits directly
//  below the hero. The progress bar is the Home charge-bar style in blue, with a
//  STEP-MATCHING sticker covering each seam. Copy is system UI. Sign-in stubbed.
//

import AuthenticationServices
import CryptoKit
import SwiftUI

// MARK: - Sign in with Apple

/// Drives a real Sign in with Apple request and reports the result. Retains
/// itself for the duration of the async request (the controller holds only weak
/// references), then releases.
/// The material a successful Apple sign-in hands back. `idToken` + `nonce` are
/// what Supabase needs to open a session; name/email arrive only on the first
/// authorization and fill the profile.
struct AppleCredential {
    let idToken: String
    let nonce: String
    let fullName: String?
    let email: String?
}

final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate,
                                    ASAuthorizationControllerPresentationContextProviding {
    private var onResult: ((AppleCredential?) -> Void)?
    private var retain: AppleSignInCoordinator?
    /// The raw nonce for this attempt. Apple gets its SHA256; Supabase gets this.
    private var currentNonce: String?

    func start(_ onResult: @escaping (AppleCredential?) -> Void) {
        self.onResult = onResult
        self.retain = self
        let nonce = Self.randomNonce()
        currentNonce = nonce
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard
            let cred = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = cred.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8),
            let nonce = currentNonce
        else {
            // No identity token means we can't open a Supabase session.
            onResult?(nil)
            finish()
            return
        }

        var name: String?
        if let components = cred.fullName {
            let formatted = PersonNameComponentsFormatter().string(from: components)
                .trimmingCharacters(in: .whitespaces)
            name = formatted.isEmpty ? nil : formatted
        }

        onResult?(AppleCredential(idToken: idToken, nonce: nonce,
                                  fullName: name, email: cred.email))
        finish()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        // Cancelled or failed: don't sign in, just stay on the screen.
        onResult?(nil)
        finish()
    }

    // MARK: - Nonce

    /// A random URL-safe nonce. Apple embeds its SHA256 in the identity token so
    /// the token can't be replayed; Supabase checks the raw value against it.
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

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        // The system only requests an anchor while the auth sheet is being
        // presented, so a window scene is always on screen here.
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first!
        return scene.keyWindow ?? UIWindow(windowScene: scene)
    }

    private func finish() { onResult = nil; retain = nil }
}

// MARK: - Content height (hoisted geometry)

// The safe-area content height, measured ONCE by the flow container and pushed
// down through the environment. Each screen reads it instead of wrapping itself
// in a GeometryReader: a root GeometryReader collapses to zero height the moment
// its screen leaves the hierarchy during a slide, which would drop the screen's
// full-bleed ray background and flash the white app ground behind the slide.
private struct SetupContentHeightKey: EnvironmentKey { static let defaultValue: CGFloat = 781 }
extension EnvironmentValues {
    var setupContentHeight: CGFloat {
        get { self[SetupContentHeightKey.self] }
        set { self[SetupContentHeightKey.self] = newValue }
    }
}

// MARK: - Palette

private enum SetupPalette {
    // Two app colours, alternating. Every value is lifted straight from the app —
    // no derived tints.
    //
    // PURPLE = the Deep Focus / Lock In world. Rays are FocusSuccessView's exact
    // sunburst; the accent is HabitCategory.focus.accent (the Lock In button).
    static let purpleL     = Color(hex: "EAE3FB"); static let purpleD     = Color(hex: "D5C9F5")
    static let purpleAccent = Color(hex: "5B4BE0"); static let purpleShade = Color(hex: "4436B8")
    // ORANGE = the app's orange. Rays are ExerciseSuccessView's exact sunburst;
    // the accent is LightSheet.orange (the app's orange button).
    static let orangeL     = Color(hex: "FFE7C8"); static let orangeD     = Color(hex: "FFD29B")
    static let orangeAccent = LightSheet.orange;    static let orangeShade = LightSheet.orangeShade
}

// MARK: - Progress bar (one continuous blue bar)

private struct SetupProgressBar: View {
    /// Overall progress through the flow, 0...1.
    let progress: CGFloat
    let step: Int
    let totalSteps: Int
    /// The screen's accent — the fill matches the screen's button.
    var accent: Color = LightSheet.blue
    private let barHeight: CGFloat = 12
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.12))
                Capsule()
                    .fill(LinearGradient(
                        colors: [accent.lightened(by: 0.16), accent, accent.darkened(by: 0.08)],
                        startPoint: .top, endPoint: .bottom))
                    .frame(width: max(barHeight, proxy.size.width * min(max(progress, 0), 1)))
            }
            .frame(height: barHeight)
            .overlay(Capsule().strokeBorder(.white, lineWidth: 2.5))
            .frame(maxHeight: .infinity)   // centre the bar in the row
        }
        .frame(height: 40)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: progress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Setup progress")
        .accessibilityValue("Step \(step) of \(totalSteps)")
    }
}

private struct SetupTopBar: View {
    @Environment(SetupFlow.self) private var flow
    var showBack: Bool = true
    var accent: Color = LightSheet.blue
    var body: some View {
        // Back button and progress bar share ONE row — the back button on the left,
        // the bar filling the rest. The back slot is dropped when there's nowhere
        // to go back, so the bar takes the full width on Welcome / All set.
        HStack(spacing: Theme.Spacing.m) {
            if showBack {
                CircleIconButton(symbol: "chevron.left") { flow.back() }
            }

            SetupProgressBar(
                progress: Self.progress(for: flow.step),
                step: flow.step.rawValue + 1,
                totalSteps: SetupFlow.Step.allCases.count,
                accent: accent
            )
        }
        .frame(height: 40)
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, Theme.Spacing.xs)
    }

    /// Even progress across the six screens — every step advances the bar, filling
    /// it on the last one.
    private static func progress(for step: SetupFlow.Step) -> CGFloat {
        CGFloat(step.rawValue + 1) / CGFloat(SetupFlow.Step.allCases.count)
    }
}

// MARK: - Red rings background

private struct SetupRingsBackground: View {
    var centre: CGFloat = 0.5
    private static let ringColors: [Color] = [
        LightSheet.rippleRed, Color(hex: "FF564C"), Color(hex: "FF6E66"),
        Color(hex: "FF857E"), Color(hex: "FF9C96"), Color(hex: "FFB1AC"),
        Color(hex: "FFC3BF"), Color(hex: "FFD1CE"), Color(hex: "FFDCDA"),
    ]
    private static let stops: [Gradient.Stop] = {
        let n = ringColors.count
        var s: [Gradient.Stop] = []
        for (i, c) in ringColors.enumerated() {
            s.append(.init(color: c, location: Double(i) / Double(n)))
            s.append(.init(color: c, location: Double(i + 1) / Double(n)))
        }
        return s
    }()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false
    var body: some View {
        // No GeometryReader: the UnitPoint is relative to the drawn frame, which
        // (with .ignoresSafeArea in the container) is the FULL screen — so 0.5 is
        // the true screen centre, not the safe-area centre.
        RadialGradient(gradient: Gradient(stops: Self.stops),
                       center: UnitPoint(x: 0.5, y: centre), startRadius: 0, endRadius: 1000)
            .scaleEffect(breathing ? 1.05 : 1.0, anchor: UnitPoint(x: 0.5, y: centre))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { breathing = true }
            }
    }
}

// MARK: - Container (hero + bg centred on the background, title below)

private enum SetupBG { case home; case white; case sun(Color, Color); case rings }

private struct SetupScreen<Hero: View, Bottom: View>: View {
    var showBack: Bool = true
    var onDark: Bool = false
    /// When true, the title + subtitle type in line by line in the intro's white
    /// style (used on the two fox screens on the Home background).
    var typing: Bool = false
    /// The screen's accent — drives the progress bar (and matches the button the
    /// screen sets on its own primary CTA).
    var accent: Color = LightSheet.blue
    /// Nudge (points) applied to the measured hero centre before the glow is
    /// placed behind it — positive = down. Only needed where a hero's visible art
    /// sits off the centre of its own view box (the celebration / streak fox).
    var glowBias: CGFloat = 0
    /// Lifts the whole centred block (hero + title) by this many points — for
    /// heroes whose visible art sits low in its view box (the fox clips carry
    /// whitespace above the animal), so the VISIBLE block lands dead-centre.
    var blockLift: CGFloat = 0
    /// The gap between the hero's visible bottom and the title — one locked
    /// spacing token, identical on every screen. `heroBottomInset` first trims
    /// each hero's box down to its visible bottom, so this single value gives a
    /// pixel-identical art→text gap regardless of the art.
    var titleGap: CGFloat = Theme.Spacing.xxxl
    /// Distance (points) from the hero's visible bottom (fox shadow / sticker /
    /// icon / cube body) to the BOTTOM of its layout box. Applied as negative
    /// bottom padding so the title sits `titleGap` below the visible bottom, not
    /// below the empty box. 0 for heroes already tight to their visible bottom.
    var heroBottomInset: CGFloat = 0
    /// FOX SCREENS ONLY (1, 2, 6). When set, the hero is pinned so its box BOTTOM
    /// (the fox's feet/shadow line) sits at this many points below the content top,
    /// with the title a fixed `titleGap` under it — a shared, fixed placement so
    /// all three fox screens line up identically regardless of their buttons.
    var foxFeetY: CGFloat? = nil
    /// The fox hero's box height (celebration = 248, streak = 273). Both bottom-
    /// align to `foxFeetY`, so their shadows land on the same line.
    var heroBox: CGFloat = 248
    let bg: SetupBG
    @ViewBuilder let hero: () -> Hero
    let title: String
    let subtitle: String
    @ViewBuilder let bottom: () -> Bottom

    /// Reserved space above the centred block: the progress bar's visible bottom
    /// edge (its top padding + half the 40pt row + half the 16pt bar). Everything
    /// between here and the CTA/card below is then centred by the two Spacers, so
    /// the hero + title always sit dead-centre in that gap — on every screen, with
    /// nothing to hand-tune.
    private let barBottom: CGFloat = Theme.Spacing.xs + 20 + 8

    // The glow follows the hero: measure the hero's centre and the full-screen
    // height, and derive the ray-centre fraction from them each layout pass. No
    // per-screen glow fraction to keep in sync with the art.
    @State private var heroMidY: CGFloat = 340
    @State private var glowAnchorMidY: CGFloat? = nil
    @State private var screenH: CGFloat = 874

    var body: some View {
        // Prefer an explicit glow anchor (a focal element inside the hero); fall
        // back to the centre of the whole hero frame.
        let mid = glowAnchorMidY ?? heroMidY
        let glowCentre = max(0, min(1, (mid + glowBias) / max(1, screenH)))
        return ZStack(alignment: .top) {
            background(centre: glowCentre)
                .ignoresSafeArea()
                .background {
                    // Measure the FULL-screen height the sunburst actually spans
                    // (it ignores the safe area, so its own GeometryReader is 874,
                    // not the 840 safe-area height). The measuring reader must
                    // ignore the safe area too, or the glow fraction divides by the
                    // wrong height and the convergence lands low.
                    GeometryReader { g in
                        Color.clear.onChange(of: g.size.height, initial: true) { _, nh in screenH = nh }
                    }
                    .ignoresSafeArea()
                }

            if let foxFeetY {
                // FIXED placement (ALL screens): the hero's box is rendered with its
                // bottom at foxFeetY, then `heroBottomInset` trims the empty slack so
                // the layout bottom lands on the hero's VISIBLE bottom (the fox's
                // shadow, or the sticker/icon body). The title then sits one shared
                // `titleGap` below that visible bottom on every screen, so the
                // art→text gap is identical everywhere. The glow anchor stays on the
                // rendered box bottom (unaffected by the layout trim).
                VStack(spacing: 0) {
                    Color.clear.frame(height: max(0, foxFeetY - heroBox))
                    hero()
                        .frame(height: heroBox, alignment: .bottom)
                        .overlay(alignment: .bottom) { Color.clear.frame(height: 1).glowAnchor() }
                        .padding(.bottom, -heroBottomInset)
                    titleBlock
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, Theme.Spacing.xl)
                        .padding(.top, titleGap)
                    Spacer(minLength: 0)
                    bottom()
                    Color.clear.frame(height: Theme.Spacing.l)
                }
            } else {
                VStack(spacing: 0) {
                    Color.clear.frame(height: barBottom)
                    Spacer(minLength: 0)
                    VStack(spacing: titleGap) {
                        hero()
                            .background {
                                GeometryReader { g in
                                    Color.clear.onChange(of: g.frame(in: .global).midY, initial: true) { _, mid in heroMidY = mid }
                                }
                            }
                            // Pull the box down onto the hero's visible bottom, so the
                            // fixed titleGap below is measured from the art, not the box.
                            .padding(.bottom, -heroBottomInset)
                        titleBlock
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, Theme.Spacing.xl)
                    }
                    .offset(y: -blockLift)
                    Spacer(minLength: 0)
                    bottom()
                    Color.clear.frame(height: Theme.Spacing.l)
                }
            }

            // Overlaid, not stacked, so the progress bar sits at the exact same
            // Y on every screen regardless of how tall the hero below it is.
            SetupTopBar(showBack: showBack, accent: accent)
        }
        // Always fill the screen so the ray background covers it edge to edge,
        // including while the screen is sliding in or out.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onPreferenceChange(GlowAnchorKey.self) { glowAnchorMidY = $0 }
    }

    /// The title/subtitle: dark on white by default, or the intro's white typing
    /// style when `typing` is set (the two fox screens).
    @ViewBuilder private var titleBlock: some View {
        if typing {
            TypewriterLines(lines: Self.typingLines(title, subtitle), maxWidth: 500)
                .auraFont(.display, SheetType.heroCompact, .bold)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.55), radius: 4, y: 1)
                .shadow(color: .black.opacity(0.5), radius: 16, y: 3)
                .multilineTextAlignment(.center)
        } else {
            setupTitle(title, subtitle, onDark: onDark)
        }
    }

    /// The title as the first typed line, then each subtitle sentence on its own.
    private static func typingLines(_ title: String, _ subtitle: String) -> [String] {
        var lines = [title]
        let parts = subtitle.components(separatedBy: ". ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        for (i, p) in parts.enumerated() {
            let last = i == parts.count - 1
            let ends = p.hasSuffix(".") || p.hasSuffix("!") || p.hasSuffix("?")
            lines.append(last || ends ? p : p + ".")
        }
        return lines
    }

    @ViewBuilder private func background(centre: CGFloat) -> some View {
        switch bg {
        case .home: HomeBackground()
        case .white: LightSheet.bg
        case .sun(let l, let d): SunburstBackground(lighter: l, darker: d, centre: centre)
        case .rings: SetupRingsBackground(centre: centre)
        }
    }
}

// MARK: - Shared bits

@ViewBuilder
private func setupTitle(_ title: String, _ subtitle: String, onDark: Bool) -> some View {
    VStack(spacing: Theme.Spacing.xs) {
        Text(title)
            .auraFont(.display, SheetType.title, .bold)
            .foregroundStyle(onDark ? Color.white : SheetType.titleColor)
            .multilineTextAlignment(.center)
        Text(subtitle)
            .auraFont(.body, SheetType.cardTitle, .regular)
            .foregroundStyle(onDark ? Color.white.opacity(0.92) : SheetType.subtitleColor)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private func setupTextButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
    Button(title, action: action)
        .auraFont(.body, SheetType.cardTitle, .semibold)
        .foregroundStyle(color)
        .buttonStyle(.plain)
}

/// Lets a hero mark the exact element the glow should sit behind (its global
/// vertical centre), overriding the default "centre of the whole hero frame".
/// Needed where the hero frame is taller than its focal art — e.g. the frozen
/// tile, whose icicles extend the frame below the icon row.
private struct GlowAnchorKey: PreferenceKey {
    static let defaultValue: CGFloat? = nil
    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        value = value ?? nextValue()
    }
}
extension View {
    func glowAnchor() -> some View {
        background(GeometryReader { g in
            Color.clear.preference(key: GlowAnchorKey.self, value: g.frame(in: .global).midY)
        })
    }
}

/// A square PNG hero cropped to its visible (non-transparent) art, so the view's
/// frame hugs the artwork. Padded assets (e.g. the bell) otherwise leave a fat
/// margin below the art, which throws off both the gap to the title and the glow
/// centred on the hero. Pass the alpha bounding box as fractions of the source.
private struct TightHeroImage: View {
    let name: String
    /// Target on-screen height of the VISIBLE art.
    let visibleHeight: CGFloat
    /// Alpha bounding box in the source image, as 0...1 fractions.
    let top: CGFloat, bottom: CGFloat, left: CGFloat, right: CGFloat

    var body: some View {
        let visFracH = bottom - top
        let visFracW = right - left
        let fullH = visibleHeight / visFracH          // full image height so the art = visibleHeight
        let fullW = fullH                             // square source
        let visW = fullW * visFracW
        let cx = (left + right) / 2, cy = (top + bottom) / 2
        Image(name)
            .resizable().interpolation(.high)
            .frame(width: fullW, height: fullH)
            .offset(x: fullW * (0.5 - cx), y: fullH * (0.5 - cy))
            // Frame hugs the art for layout, but DON'T clip — the sticker's soft
            // shadow sits just outside the alpha box and would be sheared off.
            .frame(width: visW, height: visibleHeight)
    }
}

// MARK: - Home-exact fox (setup fox screens)

/// The setup fox screens' hero: the ORIGINAL celebration animation, but sized and
/// grounded to match the Home screen's fox exactly — the Home fox's 260 frame and
/// its contact shadow (same size AND position), so the fox and shadow read
/// identically to Home.
private struct SetupHomeFox: View {
    private static let size: CGFloat = 260
    /// The bushy tail pulls the body left of centre; nudge it back (same ratio
    /// SuccessCelebrationArt uses).
    private static let bodyCentreNudge: CGFloat = size * (0.5 - 0.477)

    var body: some View {
        ZStack(alignment: .bottom) {
            // Home's contact shadow: same size (260 ratios) and position (-13).
            Ellipse()
                .fill(Color.black.opacity(HomeDaylight.isDay() ? 0.12 : 0.30))
                .frame(width: 260 * 0.51, height: 260 * 0.136)
                .offset(y: -13)

            // The celebration clip, at Home's 260 size, stood on the shadow.
            LoopingVideoView(resource: "SuccessCelebration")
                .frame(width: Self.size, height: Self.size)
                .offset(x: Self.bodyCentreNudge, y: -12)
        }
        .frame(width: Self.size, height: Self.size)
    }
}

// MARK: - 1 · Welcome

struct SetupWelcomeView: View {
    @Environment(SetupFlow.self) private var flow
    var body: some View {
        SetupScreen(
            showBack: false, typing: true, accent: LightSheet.blue, heroBottomInset: 13, foxFeetY: 442, heroBox: 260,
            bg: .home,
            hero: { SetupHomeFox() },
            title: "You're in!", subtitle: "Let's get Aura set up for you. It'll take less than 60 seconds!",
            bottom: { LightPrimaryButton(title: "Let's go!") { flow.advance() }.padding(.horizontal, Theme.Spacing.xl) }
        )
    }
}

/// The sign-in fox. The streak clip (fire tail) draws the fox ~5% smaller than the
/// celebration clip at the same frame size, so its video frame is enlarged to 273
/// to match the celebration fox's body — while the contact shadow stays the
/// celebration fox's exact ellipse, so both screens ground the fox identically.
private struct SetupStreakHero: View {
    var body: some View {
        // Frame == video (273) so the ZStack isn't over-constrained (a smaller
        // frame would centre the taller video and shove it downward). The shadow
        // is the celebration fox's exact ellipse, offset the celebration amount
        // (-248*0.05-2) so it lands at the identical screen position.
        ZStack(alignment: .bottom) {
            Ellipse()
                .fill(Color.black.opacity(0.12))
                .frame(width: 260 * 0.51, height: 260 * 0.136)
                // Same offset as the celebration fox (SuccessCelebrationArt) so the
                // shadow sits at the identical spot relative to the hero's bottom —
                // and therefore the same distance below the fox and above the title
                // as Screen 1.
                .offset(y: -14.4)
            LoopingVideoView(resource: "StreakFox")
                .frame(width: 273, height: 273)
                // Body already centred horizontally (no x-nudge). y: drop the fox so
                // its feet sit in the MIDDLE of the shadow (this clip frames the fox
                // higher than the celebration clip, so it needs less lift).
                .offset(y: 5)
        }
        .frame(width: 273, height: 273)
    }
}

// MARK: - 2 · Sign in

struct SetupSignInView: View {
    @Environment(SetupFlow.self) private var flow
    @Environment(HabitStore.self) private var store
    @State private var appleSignIn = AppleSignInCoordinator()
    @State private var showEmailSignIn = false
    var body: some View {
        ZStack(alignment: .top) {
            LightSheet.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                SetupTopBar(showBack: true, accent: LightSheet.blue)

                // Title sits top-left under the bar (reference layout).
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Save your progress")
                        .auraFont(.display, SheetType.hero, .bold)
                        .foregroundStyle(SheetType.titleColor)
                    Text("Sign in so your streak and coins follow you everywhere.")
                        .auraFont(.body, SheetType.cardTitle, .regular)
                        .foregroundStyle(SheetType.subtitleColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.l)

                Spacer(minLength: 0)

                VStack(spacing: Theme.Spacing.m) {
                    authButton("Sign in with Apple", icon: .symbol("applelogo"), light: false) {
                        appleSignIn.start { credential in
                            guard let credential else { return }   // cancelled/failed: stay put
                            Task {
                                do {
                                    try await SupabaseManager.shared.signInWithApple(
                                        idToken: credential.idToken, nonce: credential.nonce)
                                    store.applySignIn(fullName: credential.fullName, email: credential.email)
                                    try? await SupabaseManager.shared.upsertProfile(
                                        displayName: credential.fullName, email: credential.email)
                                    await MainActor.run { flow.advance() }
                                } catch {
                                    // Session couldn't be opened: stay on the screen.
                                    // A visible error surface comes with the email path.
                                }
                            }
                        }
                    }
                    authButton("Sign in with Google", icon: .asset("AppIconGoogle"), light: true) {
                        Task {
                            do {
                                let result = try await GoogleSignInService.signIn()
                                try await SupabaseManager.shared.signInWithGoogle(
                                    idToken: result.idToken, accessToken: result.accessToken,
                                    nonce: result.nonce)
                                await MainActor.run {
                                    store.applySignIn(fullName: result.name, email: result.email)
                                }
                                try? await SupabaseManager.shared.upsertProfile(
                                    displayName: result.name, email: result.email)
                                await MainActor.run { flow.advance() }
                            } catch {
                                // Cancelled or failed: stay on the screen.
                            }
                        }
                    }
                    // Email + password: the path for users who joined on the web
                    // funnel, where the account was made with an email and password.
                    authButton("Sign in with email", icon: .symbol("envelope.fill"), light: true) {
                        showEmailSignIn = true
                    }
                    HStack(spacing: 4) {
                        Text("Would you like to sign in later?")
                            .auraFont(.body, SheetType.cardTitle, .medium).foregroundStyle(SheetType.subtitleColor)
                        Button("Skip") { flow.advance() }
                            .auraFont(.body, SheetType.cardTitle, .bold).foregroundStyle(SheetType.titleColor)
                            .underline().buttonStyle(.plain)
                    }
                    .padding(.top, Theme.Spacing.xs)
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.xxl)
            }
        }
        .fullScreenCover(isPresented: $showEmailSignIn) {
            SetupEmailSignInView(onSignedIn: {
                showEmailSignIn = false
                flow.advance()
            })
        }
    }
    private enum AuthIcon { case symbol(String), asset(String) }
    private func authButton(_ title: String, icon: AuthIcon, light: Bool, action: @escaping () -> Void) -> some View {
        // Bottom-only drop edge, same as the blue CTAs in this flow
        // (PillPressButtonStyle): a face over a darker edge underneath. Apple = a
        // near-black face over a fully black edge; Google = white over a light grey.
        let face: Color = light ? .white : Color(white: 0.13)
        // Match the app's white-pill drop edge on a coloured surface, not a
        // one-off grey.
        let shade: Color = light ? LightSheet.whiteShadeOnColour : .black
        return Button(action: action) {
            HStack(spacing: Theme.Spacing.s) {
                switch icon {
                case .symbol(let s): Image(systemName: s).font(.system(size: 19, weight: .medium))
                case .asset(let a): Image(a).resizable().scaledToFit().frame(width: 22, height: 22)
                }
                Text(title).auraFont(.body, SheetType.cardTitle, .semibold)
            }
            .foregroundStyle(light ? LightSheet.title : .white)
        }
        .buttonStyle(PillPressButtonStyle(face: face, shade: shade))
    }
}

// MARK: - 2b · Email sign-in (web-funnel users)

/// Email + password sign-in, for people who joined through the web funnel, where
/// the account was created with an email and password. Presented full-screen over
/// the sign-in screen, in the same purple world. On success it dismisses and the
/// flow advances, exactly like Apple.
struct SetupEmailSignInView: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var onSignedIn: () -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var isSubmitting = false
    @State private var errorText: String?
    @State private var noticeText: String?
    @FocusState private var focused: Field?
    private enum Field { case email, password }
    private let fieldHeight: CGFloat = 56

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty
            && !password.isEmpty && !isSubmitting
    }

    var body: some View {
        ZStack(alignment: .top) {
            LightSheet.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Theme.Spacing.l) {
                        setupTitle("Welcome back",
                                   "Sign in with the email and password you used to join.",
                                   onDark: false)
                            .padding(.top, Theme.Spacing.l)
                            .padding(.bottom, Theme.Spacing.s)

                        field(label: "Email", text: $email, secure: false,
                              content: .emailAddress, keyboard: .emailAddress, tag: .email)
                        field(label: "Password", text: $password, secure: true,
                              content: .password, keyboard: .default, tag: .password)

                        if let errorText {
                            message(errorText, color: LightSheet.drainRed)
                        } else if let noticeText {
                            message(noticeText, color: LightSheet.blue)
                        }

                        setupTextButton("Forgot password?", color: LightSheet.blue) { sendReset() }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)  // 44pt hit area (DESIGN §8)
                            .contentShape(Rectangle())
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.s)
                }

                LightPrimaryButton(title: "Sign in", enabled: canSubmit) { submit() }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.bottom, Theme.Spacing.l)
            }
        }
    }

    private var header: some View {
        HStack {
            CircleIconButton(symbol: "chevron.left") { dismiss() }
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.top, Theme.Spacing.s)
    }

    private func message(_ text: String, color: Color) -> some View {
        Text(text)
            .auraFont(.body, SheetType.cardTitle, .medium)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func field(label: String, text: Binding<String>, secure: Bool,
                       content: UITextContentType, keyboard: UIKeyboardType, tag: Field) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(label)
                .auraFont(.display, SheetType.sectionHeader, .bold)
                .foregroundStyle(SheetType.titleColor)

            HStack(spacing: Theme.Spacing.s) {
                Group {
                    if secure && !showPassword {
                        SecureField("", text: text)
                    } else {
                        TextField("", text: text)
                    }
                }
                .auraFont(.body, SheetType.input, .medium)
                .foregroundStyle(LightSheet.title)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(content)
                .keyboardType(keyboard)
                .focused($focused, equals: tag)
                .submitLabel(secure ? .go : .next)
                .onSubmit { if secure { submit() } else { focused = .password } }

                if secure {
                    Button { showPassword.toggle() } label: {
                        Image(systemName: showPassword ? "eye.fill" : "eye.slash.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(LightSheet.controlIdle)
                            .frame(width: 44, height: 44)   // 44pt hit area (DESIGN §8)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, Theme.Spacing.l)
            // Less trailing inset on a secure field: the eye's 44pt box carries
            // its own edge padding, so the same visual gap without double-padding.
            .padding(.trailing, secure ? Theme.Spacing.xs : Theme.Spacing.l)
            .frame(height: fieldHeight)
            .background(LightSheet.field, in: RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous)
                .strokeBorder(LightSheet.fieldStroke, lineWidth: 1))
        }
    }

    private func submit() {
        guard canSubmit else { return }
        focused = nil
        isSubmitting = true
        errorText = nil
        noticeText = nil
        let cleanEmail = email.trimmingCharacters(in: .whitespaces)
        Task {
            do {
                try await SupabaseManager.shared.signInWithEmail(cleanEmail, password: password)
                let profile = try? await SupabaseManager.shared.fetchProfile()
                store.applySignIn(fullName: profile?.displayName, email: profile?.email ?? cleanEmail)
                isSubmitting = false
                onSignedIn()
            } catch {
                isSubmitting = false
                errorText = "That email and password didn't match. Give it another go."
            }
        }
    }

    private func sendReset() {
        let cleanEmail = email.trimmingCharacters(in: .whitespaces)
        guard !cleanEmail.isEmpty else {
            errorText = "Enter your email first, then tap forgot password."
            return
        }
        errorText = nil
        Task {
            try? await SupabaseManager.shared.sendPasswordReset(to: cleanEmail)
            noticeText = "Check your email for a link to reset your password."
        }
    }
}

// MARK: - 3 · Notifications

struct SetupNotificationsView: View {
    @Environment(SetupFlow.self) private var flow
    @Environment(HabitStore.self) private var store
    var body: some View {
        SetupScreen(
            accent: LightSheet.blue, glowBias: -79, foxFeetY: 386, heroBox: 158,
            bg: .white,
            hero: { TightHeroImage(name: "AppSetUp_Reminders", visibleHeight: 158,
                                   top: 0.047, bottom: 0.812, left: 0.166, right: 0.832) },
            title: "Stay on track", subtitle: "Aura reminds you to watch your screen time and complete healthy habits.",
            bottom: {
                VStack(spacing: Theme.Spacing.s) {
                    LightPrimaryButton(title: "Allow notifications") {
                        Task {
                            await flow.requestNotifications()
                            // Turn the reminder toggles on when granted (and leave
                            // them off if the user declines) so Settings → Reminders
                            // reflects the choice made here.
                            let granted = flow.notifStatus == .authorized
                            store.remindersEnabled = granted
                            store.screenTimeRemindersEnabled = granted
                        }
                    }
                    setupTextButton("Not now", color: LightSheet.title) {
                        store.remindersEnabled = false
                        store.screenTimeRemindersEnabled = false
                        flow.advance()
                    }
                    .padding(.top, Theme.Spacing.xs)
                }
                .padding(.horizontal, Theme.Spacing.xl)
            }
        )
    }
}

// MARK: - 4 · Screen Time

struct SetupScreenTimeView: View {
    @Environment(SetupFlow.self) private var flow
    var body: some View {
        SetupScreen(
            accent: LightSheet.blue, glowBias: -48, foxFeetY: 386, heroBox: 96,
            bg: .white,
            hero: { iconPair },
            title: "Connect Aura to Screen Time", subtitle: "Screen time access is what lets Aura block your apps.",
            bottom: {
                VStack(spacing: Theme.Spacing.m) {
                    privacyCard
                    LightPrimaryButton(title: "Connect to Screen Time") { Task { await flow.requestScreenTime() } }
                }
                .padding(.horizontal, Theme.Spacing.xl)
            }
        )
    }
    private var iconPair: some View {
        HStack(spacing: -20) {
            appIcon("AppSetUp_ScreenTimeIcon").zIndex(0)
            appIcon("AuraAppIcon").zIndex(1)
        }
    }
    private func appIcon(_ name: String) -> some View {
        Image(name).resizable().interpolation(.high).scaledToFill()
            .frame(width: 96, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
            .shadow(color: .black.opacity(0.14), radius: 8, y: 4)
    }
    private var privacyCard: some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: "applelogo").font(.system(size: 26, weight: .medium)).foregroundStyle(LightSheet.title)
            VStack(alignment: .leading, spacing: 2) {
                Text("We can't see your data").auraFont(.body, SheetType.cardTitle, .bold).foregroundStyle(LightSheet.title)
                Text("Protected by Apple's Privacy Rules").auraFont(.body, SheetType.subtitle, .regular).foregroundStyle(SheetType.subtitleColor)
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.l)
        .background(.white, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        // A defined border so the white card reads on the white background.
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
            .strokeBorder(Color.black.opacity(0.12), lineWidth: 1))
    }
}

// MARK: - 5 · App picker (red rings + 2×2 grid, both centred on 0.5)

struct SetupAppPickerView: View {
    @Environment(SetupFlow.self) private var flow
    var body: some View {
        SetupScreen(
            accent: LightSheet.blue, glowBias: -48, foxFeetY: 386, heroBox: 96,
            bg: .white,
            hero: { iconPair },
            title: "Pick what apps to freeze", subtitle: subtitle,
            bottom: {
                VStack(spacing: Theme.Spacing.s) {
                    LightPrimaryButton(title: flow.selection.isEmpty ? "Choose apps" : "Continue") {
                        if flow.selection.isEmpty { Task { await flow.pickApps() } } else { flow.advance() }
                    }
                    if !flow.selection.isEmpty {
                        setupTextButton("Add more apps", color: LightSheet.title) { Task { await flow.pickApps() } }.padding(.top, Theme.Spacing.xs)
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
            }
        )
    }
    /// Aura icon + a TikTok in the hand-drawn ice frame, overlapping like the
    /// Screen Time pair. The Aura icon matches the Screen Time icon size (96);
    /// the frozen tile carries its ice border + drips and sits in front so the
    /// frame reads clearly.
    private var iconPair: some View {
        // Same order as the Screen Time pair: the other app behind-left, Aura in
        // front-right. The frozen tile (frame included) is sized to the same 96
        // footprint as the Aura icon.
        // Both icons occupy an identical 96×96 layout box and overlap like the
        // Screen Time pair. The ice CUBE (0.838 of the tile) fills its box; the
        // icicles overflow BELOW it (like a shadow) without changing the layout,
        // so the cube body lines up with the Aura icon and the gap to the title
        // matches the other screens.
        HStack(spacing: -20) {
            Color.clear.frame(width: 96, height: 96)
                .overlay(alignment: .top) {
                    FrozenAppTile(icon: .asset("AppIconTikTok"), side: 72)
                        .offset(y: -4)
                        .shadow(color: .black.opacity(0.14), radius: 8, y: 4)
                }
                .zIndex(0)
            Image("AuraAppIcon").resizable().interpolation(.high).scaledToFill()
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
                .shadow(color: .black.opacity(0.14), radius: 8, y: 4)
                .zIndex(1)
        }
    }
    private var subtitle: String {
        if flow.selection.isEmpty { return "The apps that distract you most. Instagram, TikTok, whatever yours are." }
        let n = flow.selection.appCount + flow.selection.categoryCount
        if n == 1 {
            return "1 app selected. This app gets frozen until you earn it back by completing quests."
        }
        return "\(n) apps selected. These apps get frozen until you earn them back by completing quests."
    }
}

// MARK: - 6 · All set

struct SetupAllSetView: View {
    @Environment(SetupFlow.self) private var flow
    var body: some View {
        SetupScreen(
            showBack: false, typing: true, accent: LightSheet.blue, heroBottomInset: 13, foxFeetY: 442, heroBox: 260,
            bg: .home,
            hero: { SetupHomeFox() },
            title: "You're all set!", subtitle: "Now let me show you around the app.",
            bottom: { LightPrimaryButton(title: "Let's go!") { flow.advance() }.padding(.horizontal, Theme.Spacing.xl) }
        )
    }
}

// MARK: - Standalone sign-in (outside onboarding)

/// Sign-in presented on its own, not as a step in the setup funnel: from Settings
/// when the account is signed out, and from the support chat (you must be signed
/// in to message the founders). Same three methods as `SetupSignInView`, but on
/// success it calls `onSignedIn` and dismisses instead of advancing a flow, and
/// there is no "skip" (the caller opened this because a sign-in is needed).
struct AccountSignInSheet: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var appleSignIn = AppleSignInCoordinator()
    @State private var showEmailSignIn = false
    var onSignedIn: () -> Void = {}

    var body: some View {
        ZStack(alignment: .top) {
            SunburstBackground(lighter: SetupPalette.purpleL, darker: SetupPalette.purpleD, centre: 0.24)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer(minLength: 0)
                SetupStreakHero()
                setupTitle("Save your progress",
                           "Sign in so your streak and coins follow you everywhere, and so you can message the founders.",
                           onDark: false)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.m)
                    .padding(.bottom, Theme.Spacing.l)
                buttons
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.bottom, Theme.Spacing.xxl)
            }
        }
        .fullScreenCover(isPresented: $showEmailSignIn) {
            SetupEmailSignInView(onSignedIn: {
                showEmailSignIn = false
                finish()
            })
        }
    }

    private var header: some View {
        HStack {
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(LightSheet.title)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.white.opacity(0.65)))
            }
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.top, Theme.Spacing.l)
    }

    private var buttons: some View {
        VStack(spacing: Theme.Spacing.m) {
            authButton("Sign in with Apple", icon: .symbol("applelogo"), light: false) {
                appleSignIn.start { credential in
                    guard let credential else { return }
                    Task {
                        do {
                            try await SupabaseManager.shared.signInWithApple(
                                idToken: credential.idToken, nonce: credential.nonce)
                            await MainActor.run {
                                store.applySignIn(fullName: credential.fullName, email: credential.email)
                            }
                            try? await SupabaseManager.shared.upsertProfile(
                                displayName: credential.fullName, email: credential.email)
                            await MainActor.run { finish() }
                        } catch {
                            // Stay put on failure; the caller can retry.
                        }
                    }
                }
            }
            authButton("Sign in with Google", icon: .asset("AppIconGoogle"), light: true) {
                Task {
                    do {
                        let result = try await GoogleSignInService.signIn()
                        try await SupabaseManager.shared.signInWithGoogle(
                            idToken: result.idToken, accessToken: result.accessToken,
                            nonce: result.nonce)
                        await MainActor.run {
                            store.applySignIn(fullName: result.name, email: result.email)
                        }
                        try? await SupabaseManager.shared.upsertProfile(
                            displayName: result.name, email: result.email)
                        await MainActor.run { finish() }
                    } catch {
                        // Stay put on failure; the caller can retry.
                    }
                }
            }
            authButton("Sign in with email", icon: .symbol("envelope.fill"), light: true) {
                showEmailSignIn = true
            }
        }
    }

    private func finish() {
        onSignedIn()
        dismiss()
    }

    private enum AuthIcon { case symbol(String), asset(String) }
    private func authButton(_ title: String, icon: AuthIcon, light: Bool, action: @escaping () -> Void) -> some View {
        let face: Color = light ? .white : Color(white: 0.13)
        let shade: Color = light ? LightSheet.whiteShadeOnColour : .black
        return Button(action: action) {
            HStack(spacing: Theme.Spacing.s) {
                switch icon {
                case .symbol(let s): Image(systemName: s).font(.system(size: 19, weight: .medium))
                case .asset(let a): Image(a).resizable().scaledToFit().frame(width: 22, height: 22)
                }
                Text(title).auraFont(.body, SheetType.cardTitle, .semibold)
            }
            .foregroundStyle(light ? LightSheet.title : .white)
        }
        .buttonStyle(PillPressButtonStyle(face: face, shade: shade))
    }
}
