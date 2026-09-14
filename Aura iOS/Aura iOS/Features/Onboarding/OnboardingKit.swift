//
//  OnboardingKit.swift
//  Aura iOS
//
//  Shared building blocks for the onboarding funnel, cloning Brainrot's light
//  design: a brand-blue sky over a tall rounded white hill, the app's real logo
//  and controls, clean option cards, and the animated promise tagline.
//

import SwiftUI

// MARK: - Background (brand-blue sky + tall rounded white hill)

/// A white hill filling the lower portion of the screen, curving up in the
/// middle like a soft dome. `topRatio` is where the hill's side edges sit (a
/// fraction of height); `curveDepth` is how far the centre bulges above them
/// (also a fraction of height), so a small value reads as a nearly flat hill.
/// The visible peak lands at `topRatio - curveDepth/2`.
struct HillShape: Shape {
    var topRatio: CGFloat = 0.46
    var curveDepth: CGFloat = 0.11
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let top = rect.height * topRatio
        p.move(to: CGPoint(x: 0, y: top))
        p.addQuadCurve(to: CGPoint(x: rect.width, y: top),
                       control: CGPoint(x: rect.width / 2, y: top - rect.height * curveDepth))
        p.addLine(to: CGPoint(x: rect.width, y: rect.height))
        p.addLine(to: CGPoint(x: 0, y: rect.height))
        p.closeSubpath()
        return p
    }
}

/// The onboarding background: the brand blue (same as the CTA) over a white
/// hill. Welcome uses a tall, round dome; the intro beats use a flatter hill
/// whose peak sits at the exact vertical centre (see `OnbStatementScreen`).
struct OnbSkyBackground: View {
    var hillTop: CGFloat = 0.46
    var curveDepth: CGFloat = 0.11
    var body: some View {
        ZStack {
            LightSheet.blue
            HillShape(topRatio: hillTop, curveDepth: curveDepth).fill(Color.white)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Chrome

/// Top bar: a back chevron on a light disc, plus an optional thin progress bar.
struct OnbTopBar: View {
    @Environment(OnboardingFlow.self) private var flow
    var showBack: Bool = true
    /// 0...1, or nil to hide the progress bar.
    var progress: Double? = nil
    /// On the blue sky the chevron disc needs to read; on white it is subtle.
    var onSky: Bool = false

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            // Omit the back button entirely when hidden, so the progress bar can
            // run full width on screens that don't allow going back.
            if showBack {
                Button { flow.back() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(onSky ? Color.white : LightSheet.title)
                        .frame(width: 40, height: 40)
                        .background(onSky ? Color.black.opacity(0.16) : Color.black.opacity(0.06), in: Circle())
                        // Visual disc stays 40pt; the hit area is padded out to
                        // Apple's 44pt minimum.
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressBounceStyle())
            }

            if let progress {
                // Track = the back-button circle's material; pure white fill and
                // white outline (#FFFFFF).
                Capsule().fill(onSky ? Color.black.opacity(0.16) : LightSheet.track)
                    .frame(height: 12)
                    .overlay(alignment: .leading) {
                        GeometryReader { g in
                            Capsule().fill(onSky ? Color.white : LightSheet.blue)
                                .frame(width: max(0, g.size.width * max(0, min(1, progress))))
                        }
                    }
            } else {
                Spacer(minLength: 0)
            }
        }
        .frame(height: 40)
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, Theme.Spacing.xs)
    }
}

// MARK: - Fox stage (all three intro foxes, one size + one contact shadow)

/// Grounds any fox on a single, shared platform so the streak / blocked / tired
/// foxes read at the exact same size with the exact same contact shadow — the
/// same 260 frame and 0.51×0.136 shadow ellipse Home uses.
struct OnbFoxStage<Fox: View>: View {
    @ViewBuilder var fox: () -> Fox
    var body: some View {
        fox()
            .frame(height: 260)
            .frame(maxWidth: .infinity)
            .background(alignment: .bottom) {
                Ellipse()
                    .fill(Color.black.opacity(0.13))
                    .frame(width: 260 * 0.51, height: 260 * 0.136)
                    .offset(y: -13)
            }
    }
}

// MARK: - Statement screen (the intro / meet-the-fox beats)

struct OnbStatementScreen<Fox: View>: View {
    var showBack: Bool = true
    var progress: Double? = nil
    @ViewBuilder var fox: () -> Fox
    let title: String
    var subtitle: String? = nil
    let cta: String
    let onCTA: () -> Void

    var body: some View {
        ZStack {
            // Full-bleed sky + hill + fox + copy, positioned to the TRUE screen
            // centre. The hill's peak sits at the exact vertical centre; the fox
            // stands just above it (feet in the blue), the copy just below it
            // (on the white).
            GeometryReader { geo in
                let h = geo.size.height
                ZStack {
                    OnbSkyBackground(hillTop: 0.52, curveDepth: 0.045)

                    OnbFoxStage { fox() }
                        .position(x: geo.size.width / 2, y: h * 0.5 - 122)

                    VStack(spacing: Theme.Spacing.s) {
                        Text(title)
                            .auraFont(.display, SheetType.hero, .bold)
                            .foregroundStyle(LightSheet.title)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        if let subtitle {
                            Text(subtitle)
                                .auraFont(.body, SheetType.cardTitle, .medium)
                                .foregroundStyle(LightSheet.subtitleDark)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .frame(width: geo.size.width, alignment: .center)
                    .position(x: geo.size.width / 2, y: h * 0.64)
                }
            }
            .ignoresSafeArea()

            // Chrome respects the safe area: top bar under the notch, CTA above
            // the home indicator.
            VStack(spacing: 0) {
                OnbTopBar(showBack: showBack, progress: progress, onSky: true)
                Spacer()
                LightPrimaryButton(title: cta) { onCTA() }
                    .padding(.horizontal, Theme.Spacing.xl)
                Spacer().frame(height: Theme.Spacing.l)
            }
        }
    }
}

// MARK: - Question layout (the shared companion scaffold: fox + line below + content + CTA)

struct OnbQuestionScreen<Content: View, Bottom: View>: View {
    var showBack: Bool = true
    var progress: Double? = nil
    /// The fox's question, in his voice — types out below him.
    let title: String
    var note: String? = nil
    @ViewBuilder var content: () -> Content
    @ViewBuilder var bottom: () -> Bottom

    var body: some View {
        CompanionScaffold(showBack: showBack, progress: progress, lines: [title],
                          content: content, bottom: bottom)
    }
}
