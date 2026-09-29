//
//  ProofFailureView.swift
//  Aura iOS
//

import SwiftUI

/// The photo didn't verify.
///
/// Built as `ProofSuccessView`'s sibling: same white field, same art position,
/// same type, so the two outcomes read as one screen with a different answer on
/// it rather than as two unrelated places the flow can land.
///
/// Drawn over the still-mounted camera rather than pushed as its own stage.
/// Retaking is then a state change and the viewfinder is back instantly, which
/// matters more here than anywhere: the person is standing there holding their
/// phone up at a book, and every screen transition between them and a second
/// attempt is a chance to give up.
struct ProofFailureView: View {
    let habit: Habit
    let verdict: ProofVerdict
    var onRetake: () -> Void
    var onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var script = ProofFailureScript.random

    /// The fox's measured centre in window coordinates — the rings' bullseye is
    /// pinned here, so the tip card and the line come out the same distance from
    /// the middle circle.
    @State private var foxCentreGlobalY: CGFloat? = nil

    /// The height of the "Not now" line under the Retake button.
    private static let notNowHeight: CGFloat = 44

    /// The fox's frame. 248 lands his visible size on the streak/home fox's.
    private static let foxSize: CGFloat = 248

    var body: some View {
        GeometryReader { geo in
            // How far the Retake button sits off the physical bottom: the safe
            // inset, the bottom padding, and the "Not now" line above it. The tip
            // card is pinned the same distance off the top, to mirror it.
            let mirrorGap = geo.safeAreaInsets.bottom + Theme.Spacing.xl
                + Self.notNowHeight + Theme.Spacing.s

            ZStack {
                // Concentric red rings, not a sunburst — a different shape
                // entirely, so a miss never looks like one of the celebrations.
                RippleBackground(centreGlobalY: foxCentreGlobalY)
                    .ignoresSafeArea()

                // The tip card, pinned to the top and mirroring the Retake
                // button's gap from the bottom.
                VStack(spacing: 0) {
                    FailureTipCard(text: fix)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, mirrorGap)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .opacity(appeared ? 1 : 0)

                // The fox and its line, centred on the full screen so the rings —
                // pinned to the measured fox — sit dead centre.
                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    art
                        .scaleEffect(appeared ? 1 : 0.8)
                        .opacity(appeared ? 1 : 0)
                        // Measure the fox's centre in window space so the rings
                        // pin dead on it.
                        .onGeometryChange(for: CGFloat.self) { proxy in
                            proxy.frame(in: .global).midY
                        } action: { foxCentreGlobalY = $0 }
                        // The line hangs 40px under the fox as an overlay, so it
                        // can't pull the fox off centre — the rings stay put and
                        // the pale ring shows evenly top and bottom.
                        .overlay(alignment: .top) {
                            Text(headline)
                                .auraFont(.display, 26, .bold)
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.28), radius: 8, y: 2)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(width: geo.size.width - 2 * Theme.Spacing.xl)
                                .offset(y: Self.foxSize + Theme.Spacing.xl + Theme.Spacing.l)
                        }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Centre on the FULL screen (not the safe area) so the fox — and
                // the rings pinned to it — sit at the true middle: even pink top
                // and bottom. This is the line that keeps getting missed.
                .ignoresSafeArea()
                .opacity(appeared ? 1 : 0)

                // The buttons, pinned to the bottom of the safe area.
                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    // White, so it sits on the red rather than competing with it.
                    LightPrimaryButton(title: "Retake Photo",
                                       face: .white,
                                       textColor: LightSheet.title,
                                       shade: LightSheet.whiteShadeOnColour,
                                       action: onRetake)

                    // Leaving is a line of text under it, not an equal button.
                    Button(action: onClose) {
                        Text("Not now")
                            .auraFont(.body, SheetType.cardTitle, .semibold)
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .frame(height: Self.notNowHeight)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, Theme.Spacing.s)
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.xl)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            Haptics.notify(.error)
            guard !reduceMotion else { appeared = true; return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.62)) { appeared = true }
        }
    }


    private var art: some View {
        // The pay-up intervention fox, this screen's own clip (`ProofFailureFox`).
        // 248, not 260: measured, this clip fills more of its frame than the
        // streak clip does, so a slightly smaller frame lands his VISIBLE size on
        // the streak/home fox's (~197pt tall). The shadow is the streak fox's
        // exact shadow (sized off 260) so it matches too.
        LoopingVideoView(resource: "ProofFailureFox")
            .frame(width: Self.foxSize, height: Self.foxSize)
            .background(alignment: .bottom) {
                Ellipse()
                    .fill(Color.black.opacity(0.12))
                    .frame(width: 260 * 0.51, height: 260 * 0.136)
                    .offset(y: -Self.foxSize * 0.05 - 2)
            }
    }

    /// The fox, unless the model refused the photo.
    ///
    /// A blocked photo gets fixed, neutral copy and no joke at all. Humour is
    /// wrong in both directions here: if it was an accident, being quipped at
    /// about it is unsettling, and if it was deliberate, a funny reaction is
    /// exactly the response somebody was fishing for. Rotation comes off too,
    /// because variety reads as personality and personality is the thing to
    /// withhold.
    /// The headline: the fox's read on the photo. The model's line where there
    /// is one (it's written about this exact photo), the script's stock reaction
    /// where there isn't, and a neutral line when the photo was refused.
    private var headline: String {
        if verdict.isBlocked { return "i can't use that one." }
        if let reason = verdict.reason, !reason.isEmpty { return reason }
        return script.title
    }

    /// What to point the camera at next time.
    ///
    /// The model's own instruction where there is one, since it's written about
    /// the photo that just failed. Where there isn't (a fallback verdict, or an
    /// older deploy), the habit's own hint does the job: it's less specific but
    /// it's still true, which is more than a generic line about lighting would
    /// be.
    ///
    /// A blocked photo skips all of that. It never says what it saw, never
    /// names a category, and never mentions accounts or consequences. Naming it
    /// confirms to a deliberate user that the app looked, and threatens an
    /// innocent one over a false positive.
    private var fix: String {
        if verdict.isBlocked { return "take a photo of your habit and try again." }
        if let fix = verdict.fix, !fix.isEmpty { return fix }
        if !habit.proofHint.isEmpty { return habit.proofHint }
        return script.fallbackFix
    }
}

/// Concentric red rings radiating from a point — the failure screen's answer to
/// the success sunburst. Same idea (a stepped gradient), a different shape
/// (radial rings, not angular rays), so a pass and a miss never look alike. Deep
/// red at the centre behind the fox, fading to a pale pink at the edges.
private struct RippleBackground: View {
    /// The rings' centre in GLOBAL (window) coordinates — so it can be pinned to
    /// a measured view rather than guessed as a fraction. This view ignores the
    /// safe area, so its global origin is the top of the window; a fraction
    /// computed against a safe-area-laid-out fox would drift. Nil until measured.
    var centreGlobalY: CGFloat? = nil
    /// Used until the fox has been measured.
    var fallbackCentre: CGFloat = 0.44

    /// Centre to edge: a strong red stepping down to a pale pink.
    private static let ringColors: [Color] = [
        LightSheet.rippleRed,
        Color(hex: "FF564C"),
        Color(hex: "FF6E66"),
        Color(hex: "FF857E"),
        Color(hex: "FF9C96"),
        Color(hex: "FFB1AC"),
        Color(hex: "FFC3BF"),
        Color(hex: "FFD1CE"),
        Color(hex: "FFDCDA"),
    ]

    /// Each colour held across its own band, so the rings step rather than blend.
    private static let stops: [Gradient.Stop] = {
        let n = ringColors.count
        var stops: [Gradient.Stop] = []
        for (i, colour) in ringColors.enumerated() {
            stops.append(.init(color: colour, location: Double(i) / Double(n)))
            stops.append(.init(color: colour, location: Double(i + 1) / Double(n)))
        }
        return stops
    }()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    var body: some View {
        GeometryReader { geo in
            // Origin ≈ top of the window (this view ignores the safe area), so
            // a global Y converts straight to a local fraction.
            let originY = geo.frame(in: .global).minY
            let fraction: CGFloat = {
                guard geo.size.height > 0 else { return fallbackCentre }
                if let y = centreGlobalY { return (y - originY) / geo.size.height }
                return fallbackCentre
            }()
            // 1.45 spreads the 9 bands wider, so every ring reads a little bigger.
            let radius = max(geo.size.width, geo.size.height) * 1.45
            RadialGradient(gradient: Gradient(stops: Self.stops),
                           center: UnitPoint(x: 0.5, y: fraction),
                           startRadius: 0,
                           endRadius: radius)
                // A slow breath so the rings feel alive — scaled about the
                // bullseye so its centre stays pinned to the fox.
                .scaleEffect(breathing ? 1.09 : 1.0,
                             anchor: UnitPoint(x: 0.5, y: fraction))
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
    }
}

/// The "here's how to nail it" card above the fox. Wears the success cards'
/// frosted material (`black.opacity(0.24)`) and a question-mark sticker, so a
/// miss still feels like it's part of the same set of screens.
private struct FailureTipCard: View {
    let text: String

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            Image("FoxSettingsHelp")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 44, height: 44)

            Text(text)
                .auraFont(.body, 15, .medium)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Color.black.opacity(0.24))
        )
    }
}

/// What the fox says when a photo doesn't pass.
///
/// Every one of these puts the miss on the fox's own eyes rather than on the
/// person's effort. They did the habit, most likely; the camera was pointed
/// wrong. "You did not pass" is a grade, and being graded by an app you
/// downloaded to help you is a bad feeling at exactly the wrong moment.
///
/// Short, too. The two useful sentences on this screen come from the model and
/// are about this photo. The title only has to sound like a person taking it
/// well, then get out of the way.
struct ProofFailureScript {
    let title: String
    /// Only reached when there's no model instruction and the habit has no
    /// hint either, which is a custom habit somebody left blank.
    let fallbackFix: String

    static let all: [ProofFailureScript] = [
        ProofFailureScript(title: "hmm, that's not it.",
                           fallbackFix: "get the whole thing in the frame and try that again."),
        ProofFailureScript(title: "yeah, i can't tell.",
                           fallbackFix: "throw a bit more light on it and take another."),
        ProofFailureScript(title: "you've lost me.",
                           fallbackFix: "get a little closer and give it another go."),
    ]

    static var random: ProofFailureScript { all.randomElement() ?? all[0] }
}
