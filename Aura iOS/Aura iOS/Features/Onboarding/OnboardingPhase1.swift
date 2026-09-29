//
//  OnboardingPhase1.swift
//  Aura iOS
//
//  Phase 1 - brand and disarm, cloning Brainrot: welcome (logo + phone mockup +
//  animated promise tagline), the intro / meet-the-fox beats, name, and age.
//

import SwiftUI

// MARK: - 1 - Welcome (promise)

struct OnbWelcomeView: View {
    @Environment(OnboardingFlow.self) private var flow
    var body: some View {
        ZStack {
            // Illustrated sky + mountains background (full bleed). Drawn via a
            // Color.clear overlay + clip so the oversized scaledToFill image
            // never widens the layout (which would stretch the CTA past the
            // app's standard width).
            Color.clear
                .overlay {
                    Image("Onboarding_Welcome Screen (1)")
                        .resizable().interpolation(.high).scaledToFill()
                        // Slight upscale so the blur never softens into the edges.
                        .scaleEffect(1.03)
                        .blur(radius: 1.5)
                }
                .clipped()
                .ignoresSafeArea()

            // Very subtle dark scrim for contrast + depth over the background.
            Color.black.opacity(0.18).ignoresSafeArea()

            VStack(spacing: 0) {
                // Top margin below the safe area (no logo on this screen).
                Spacer().frame(height: Theme.Spacing.xl)

                // Real phone mockup (video-ready screen area for later), with the
                // fox peeking over its top black bezel and a soft shadow behind
                // him. Height 480, fox 115.2, offset -69.6 and reserve 64.8 are
                // all ×1.2 off the locked 400/96/-58/54 baseline, so the paws
                // stay exactly on the black edge as the pair grows.
                Image("PhoneMockupDark")
                    .resizable().interpolation(.high).scaledToFit()
                    .frame(height: 440)
                    .shadow(color: .black.opacity(0.22), radius: 22, y: 14)
                    .overlay(alignment: .top) {
                        Image("Aura Fox_Peeking (2)")
                            .resizable().interpolation(.high).scaledToFit()
                            .frame(width: 104)
                            .foxShadow()
                            .offset(y: -63)
                    }
                    // Reserve the fox's overhang so the block measures its true
                    // visual top. Fox top stays pinned by the fixed top margin as
                    // the phone resizes (reserve + offset scale together).
                    .padding(.top, 59.4)

                // Fixed gap the founder liked — the title stays this far below the
                // phone; the title→button gap below grows as the phone shrinks.
                Spacer().frame(height: 33)

                VStack(spacing: Theme.Spacing.s) {
                    // White outer outline, matching the streak / timer numerals
                    // (StrokedNumber: dark fill stroked white, outer-only).
                    StrokedNumber(
                        text: "Live More. Scroll Less.",
                        font: Typography.displayUIFont(size: SheetType.heroCompact, weight: .heavy),
                        fill: UIColor(LightSheet.title),
                        stroke: .white,
                        outlineWidth: SheetType.heroCompact * StrokedNumeral.outlineRatio
                    )
                    .fixedSize()
                    .shadow(color: .black.opacity(0.18), radius: 3, y: 1)

                    Text("Replace doomscrolling with healthy habits.")
                        .auraFont(.body, SheetType.cardTitle, .bold)
                        .foregroundStyle(LightSheet.title)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Theme.Spacing.xl)

                Spacer(minLength: Theme.Spacing.l)

                VStack(spacing: Theme.Spacing.m) {
                    LightPrimaryButton(title: "Get started",
                                       face: .white, textColor: LightSheet.title, shade: LightSheet.whiteShadeOnColour) { flow.advance() }
                    Button { flow.onSignInRequested() } label: {
                        Text("Already have an account? \(Text("Sign in").font(Typography.body(size: 15, weight: .bold)).foregroundStyle(.white).underline())")
                            .font(Typography.body(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.22), radius: 3, y: 1)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Theme.Spacing.xl)
                // Bottom inset matches the horizontal inset (24) so the content
                // sits in a uniform frame above the home indicator.
                Spacer().frame(height: Theme.Spacing.xl)
            }
        }
    }
}

// MARK: - Name

struct OnbNameView: View {
    @Environment(OnboardingFlow.self) private var flow
    @FocusState private var focused: Bool
    /// Once they've answered, the fox reacts by name before we move on.
    @State private var reacting = false
    /// Gates the CTA until the fox has finished typing the current line.
    @State private var ready = false
    @State private var advanced = false

    private func finish() {
        guard !advanced else { return }
        advanced = true
        flow.advance()
    }

    var body: some View {
        @Bindable var flow = flow
        return CompanionScaffold(
            progress: 0.35,
            lines: reacting ? ["welcome, \(flow.firstName.lowercased()). the start of a beautiful, slightly naggy friendship."]
                            : ["what should i call you?"],
            onAllDone: {
                // The reaction auto-advances after a pause; the question just gates the CTA.
                if reacting { Task { @MainActor in try? await Task.sleep(for: .seconds(1.5)); finish() } }
                else { ready = true }
            },
            content: {
                // The field only exists while he's still asking; the reaction
                // beat is just fox + line + CTA, like the intro screens.
                if !reacting {
                    TextField("", text: $flow.name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.continue)
                        .focused($focused)
                        .onSubmit { if ProfileIdentity.isValidName(flow.name) { react() } }
                        .auraFont(.body, 17, .medium)
                        .foregroundStyle(.white)
                        .overlay(alignment: .leading) {
                            if flow.name.isEmpty {
                                Text("Your name")
                                    .auraFont(.body, 17, .medium)
                                    .foregroundStyle(.white.opacity(0.6))
                                    .allowsHitTesting(false)
                            }
                        }
                        .padding(Theme.Spacing.l)
                        .background(Color.black.opacity(0.42), in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                }
            },
            bottom: {
                LightPrimaryButton(title: "Continue",
                                   face: .white, textColor: LightSheet.title, shade: LightSheet.whiteShadeOnColour,
                                   enabled: ready && (reacting || ProfileIdentity.isValidName(flow.name))) {
                    if reacting { finish() } else { react() }
                }
            }
        )
    }

    private func react() {
        focused = false
        ready = false
        withAnimation(.easeInOut(duration: 0.25)) { reacting = true }
    }
}

// MARK: - 6 - Age

struct OnbAgeView: View {
    @Environment(OnboardingFlow.self) private var flow
    /// After they land on an age, the fox reacts to the band before moving on.
    @State private var reacting = false
    /// Gates the CTA until the fox has finished typing the current line.
    @State private var ready = false
    @State private var advanced = false

    private func finish() {
        guard !advanced else { return }
        advanced = true
        flow.advance()
    }

    /// The fox's read on their age band — dry, no problem talk yet.
    private var reaction: String {
        switch flow.age ?? 18 {
        case ..<18:   return "young, i won't pretend to know your slang"
        case 18...24: return "ah, the \"i'll get my life together monday\" era"
        case 25...34: return "welcome to the \"why does my back hurt\" era"
        case 35...49: return "you definitely remember when ringtones were a personality"
        default:      return "you remember when phones were attached to walls, respect"
        }
    }

    var body: some View {
        @Bindable var flow = flow
        return CompanionScaffold(
            progress: 0.55,
            lines: reacting ? [reaction] : ["how old are you?"],
            onAllDone: {
                if reacting { Task { @MainActor in try? await Task.sleep(for: .seconds(1.5)); finish() } }
                else { ready = true }
            },
            content: {
                // The app's own wheel picker (AuraWheel), tuned for the dark
                // scene: pill in the input-field material, big white numerals.
                // Hidden during the reaction beat.
                if !reacting {
                    ZStack {
                        AuraWheel.pill(fill: Color.black.opacity(0.42))
                        AuraWheelColumn(
                            values: Array(13...99),
                            selection: Binding(get: { flow.age ?? 18 }, set: { flow.age = $0 }),
                            fontSize: 32,
                            selectedColor: .white,
                            idleColor: .white.opacity(0.45),
                            label: { "\($0)" }
                        )
                    }
                    .frame(height: AuraWheel.height)
                }
            },
            bottom: {
                LightPrimaryButton(title: "Continue",
                                   face: .white, textColor: LightSheet.title, shade: LightSheet.whiteShadeOnColour,
                                   enabled: ready) {
                    if reacting { finish() }
                    else { ready = false; withAnimation(.easeInOut(duration: 0.25)) { reacting = true } }
                }
            }
        )
    }
}
