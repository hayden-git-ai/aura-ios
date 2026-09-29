//
//  OnboardingQuestions.swift
//  Aura iOS
//
//  Phase 4: the tapped-question stretch. Every question shares ONE fixed header
//  (the fox stacked over the question text, centred, in the same position on
//  every screen) on the brand-blue ground, with full-width option rows below and
//  Continue at the bottom. After the user answers and taps Continue, the question
//  text swaps in place to the fox's reaction to their answer, then Continue
//  advances. The fox and the header never move screen to screen.
//

import SwiftUI
import AudioToolbox

// MARK: - Fox + question header (fixed position on every question screen)

/// The fox stacked over the current line (question or reaction), centred. Fox
/// size and vertical position are identical on every question screen. The line
/// types on: the full text is always laid out (so it never reflows), and the
/// characters past `shown` are drawn clear, revealing left to right.
struct OnbQuestionHeader: View {
    let text: String
    var note: String? = nil
    /// Fired once the line finishes typing (used for the reaction auto-advance).
    var onFinishedTyping: (() -> Void)? = nil
    var foxHeight: CGFloat = 152
    /// The contact shadow is for the blue ground; drop it on the dark cost screens.
    var showShadow: Bool = true

    @State private var shown = 0

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            // Placeholder animated fox (the thinking loop) with a contact shadow,
            // until the founder makes per-question ones.
            LoopingVideoView(resource: "InterventionTalkFox")
                .frame(height: foxHeight)
                .frame(maxWidth: .infinity)
                // Same contact shadow as the intro foxes (OnbFoxStage): ratios of
                // the fox height so size and placement read the same.
                .background(alignment: .bottom) {
                    if showShadow {
                        Ellipse().fill(Color.black.opacity(0.13))
                            .frame(width: foxHeight * 0.51, height: foxHeight * 0.136)
                            .offset(y: -foxHeight * 0.05)
                    }
                }

            VStack(spacing: Theme.Spacing.xs) {
                Text(revealed(text, shown))
                    .auraFont(.display, SheetType.banner, .bold)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if let note {
                    Text(note)
                        .auraFont(.body, SheetType.subtitle, .semibold)
                        .foregroundStyle(.white.opacity(0.75))
                        .opacity(shown >= text.count ? 1 : 0)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .task(id: text) {
            shown = 0
            try? await Task.sleep(nanoseconds: 180_000_000)
            for i in 1...max(1, text.count) {
                shown = i
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
            onFinishedTyping?()
        }
    }

    private func revealed(_ s: String, _ n: Int) -> AttributedString {
        var a = AttributedString(s)
        a.foregroundColor = .white
        if n < s.count {
            let idx = a.index(a.startIndex, offsetByCharacters: n)
            a[idx...].foregroundColor = .clear
        }
        return a
    }
}

// MARK: - Answer row (translucent, white text, white border on selection)

struct OnbAnswerRow: View {
    let label: String
    let icon: String
    var selected: Bool = false
    var multi: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 24)
                Text(label)
                    .auraFont(.body, SheetType.cardTitle, .semibold)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.Spacing.l)
            .frame(height: 58)
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.16),
                        in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(selected ? Color.white : Color.clear, lineWidth: 2.5))
        }
        .buttonStyle(PressBounceStyle())
    }
}

// MARK: - Shared blue layout (fixed header + content + CTA)

struct OnbQuestionLayout<Content: View, Bottom: View>: View {
    var showBack: Bool = true
    var progress: Double? = nil
    let headerText: String
    var note: String? = nil
    var onFinishedTyping: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content
    @ViewBuilder var bottom: () -> Bottom

    var body: some View {
        ZStack {
            LightSheet.blue.ignoresSafeArea()

            VStack(spacing: 0) {
                OnbTopBar(showBack: showBack, progress: progress, onSky: true)
                    .padding(.bottom, Theme.Spacing.l)

                OnbQuestionHeader(text: headerText, note: note, onFinishedTyping: onFinishedTyping)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.bottom, Theme.Spacing.xl)

                content()
                    .padding(.horizontal, Theme.Spacing.xl)

                Spacer(minLength: Theme.Spacing.l)

                bottom()
                    .padding(.horizontal, Theme.Spacing.xl)
                Spacer().frame(height: Theme.Spacing.l)
            }
        }
    }
}

/// The white-on-blue Continue used across the question flow.
func onbContinue(enabled: Bool = true, _ action: @escaping () -> Void) -> some View {
    LightPrimaryButton(title: "Continue",
                       face: .white, textColor: LightSheet.title, shade: LightSheet.whiteShadeOnColour,
                       enabled: enabled, action: action)
}

private func questionTap() {
    Haptics.impact(.light)
    AudioServicesPlaySystemSound(1104)
}

// MARK: - Single-select question (with inline reaction)

struct OnbSingleSelectScreen: View {
    @Environment(OnboardingFlow.self) private var flow
    var showBack: Bool = true
    let progress: Double
    let question: String
    let options: [(label: String, icon: String)]
    let key: ReferenceWritableKeyPath<OnboardingFlow, String?>
    /// Fox's reaction to the chosen answer (shown in place after Continue). Nil
    /// skips the reaction beat.
    var reaction: ((String) -> String)? = nil
    /// Overrides what Continue does after the reaction (default: flow.advance()).
    var onAdvance: (() -> Void)? = nil

    @State private var reacting = false
    @State private var advanced = false

    private func finish() {
        guard !advanced else { return }
        advanced = true
        if let onAdvance { onAdvance() } else { flow.advance() }
    }

    var body: some View {
        let current = flow[keyPath: key]
        OnbQuestionLayout(showBack: showBack, progress: progress,
                          headerText: reacting ? (reaction?(current ?? "") ?? question) : question,
                          onFinishedTyping: {
                              // Once the reaction has typed out, pause briefly then advance.
                              if reacting {
                                  Task { try? await Task.sleep(nanoseconds: 1_500_000_000); finish() }
                              }
                          },
                          content: {
            VStack(spacing: Theme.Spacing.s) {
                ForEach(options, id: \.label) { opt in
                    OnbAnswerRow(label: opt.label, icon: opt.icon,
                                 selected: current == opt.label, multi: false) {
                        guard !reacting else { return }
                        questionTap()
                        flow[keyPath: key] = opt.label
                    }
                }
            }
            .opacity(reacting ? 0.55 : 1)
        }, bottom: {
            onbContinue(enabled: current != nil) {
                if reaction != nil, !reacting {
                    withAnimation(.easeInOut(duration: 0.25)) { reacting = true }
                } else {
                    finish()
                }
            }
        })
    }
}

// MARK: - Multi-select question (with inline reaction)

struct OnbMultiSelectScreen: View {
    @Environment(OnboardingFlow.self) private var flow
    let progress: Double
    let question: String
    var note: String? = nil
    let options: [(label: String, icon: String)]
    let key: ReferenceWritableKeyPath<OnboardingFlow, Set<String>>
    /// Reaction keyed off the current picks (nil skips the reaction beat).
    var reaction: ((Set<String>) -> String)? = nil

    @State private var reacting = false
    @State private var advanced = false

    private func finish() {
        guard !advanced else { return }
        advanced = true
        flow.advance()
    }

    var body: some View {
        let current = flow[keyPath: key]
        OnbQuestionLayout(progress: progress,
                          headerText: reacting ? (reaction?(current) ?? question) : question,
                          note: reacting ? nil : note,
                          onFinishedTyping: {
                              if reacting {
                                  Task { try? await Task.sleep(nanoseconds: 1_500_000_000); finish() }
                              }
                          },
                          content: {
            VStack(spacing: Theme.Spacing.s) {
                ForEach(options, id: \.label) { opt in
                    OnbAnswerRow(label: opt.label, icon: opt.icon,
                                 selected: current.contains(opt.label), multi: true) {
                        guard !reacting else { return }
                        questionTap()
                        if current.contains(opt.label) { flow[keyPath: key].remove(opt.label) }
                        else { flow[keyPath: key].insert(opt.label) }
                    }
                }
            }
            .opacity(reacting ? 0.55 : 1)
        }, bottom: {
            onbContinue(enabled: !current.isEmpty) {
                if reaction != nil, !reacting {
                    withAnimation(.easeInOut(duration: 0.25)) { reacting = true }
                } else {
                    finish()
                }
            }
        })
    }
}

// MARK: - Option data (labels + SF Symbols)

enum OnbQ {
    static let goal: [(label: String, icon: String)] = [
        ("Improve focus", "scope"),
        ("Reduce mindless scrolling", "iphone.slash"),
        ("Sleep better", "moon.stars.fill"),
        ("Be more present", "leaf.fill"),
        ("Be more productive", "bolt.fill"),
        ("Just curious", "sparkles"),
    ]
    static let feelings: [(label: String, icon: String)] = [
        ("No focus / procrastination", "questionmark.circle"),
        ("Anxiety / overstimulation", "eyes"),
        ("Bad sleep", "bed.double.fill"),
        ("Productivity loss", "gearshape.fill"),
        ("I feel mentally fried", "flame.fill"),
        ("Less time with friends / family", "heart.slash.fill"),
    ]
    static let persona: [(label: String, icon: String)] = [
        ("Student", "graduationcap.fill"),
        ("Working professional", "briefcase.fill"),
        ("Entrepreneur / Self-employed", "lightbulb.fill"),
        ("Parent / Caregiver", "figure.and.child.holdinghands"),
        ("Currently between jobs", "magnifyingglass"),
        ("Other", "ellipsis"),
    ]
    static let worstTime: [(label: String, icon: String)] = [
        ("First thing in the morning", "sunrise.fill"),
        ("During the day", "sun.max.fill"),
        ("Evenings", "sunset.fill"),
        ("Honestly, all day", "clock.fill"),
        ("Not sure", "questionmark.circle"),
    ]
    static let skip: [(label: String, icon: String)] = [
        ("Sleep", "moon.zzz.fill"),
        ("The gym", "dumbbell.fill"),
        ("Work or study", "book.fill"),
        ("Time with people", "person.2.fill"),
        ("Getting outside", "figure.walk"),
        ("Something you'd promised yourself", "star.fill"),
    ]
    static let tried: [(label: String, icon: String)] = [
        ("Yes, didn't stick", "heart.slash.fill"),
        ("Yes, briefly worked", "hand.thumbsup.fill"),
        ("No, first time", "hand.thumbsdown.fill"),
    ]

    /// "Did you know?" facts, ref-B card format (bare coloured icon + fact).
    static let didYouKnow: [(icon: String, tint: Color, text: String)] = [
        ("alarm.fill", Color(red: 1.0, green: 0.23, blue: 0.19),
         "The average person spends over 4 hours per day on their phone"),
        ("iphone", Color(red: 0.69, green: 0.32, blue: 0.87),
         "Most of us check our phone 58 times a day without realizing"),
        ("bed.double.fill", Color(red: 0.55, green: 0.35, blue: 0.90),
         "Too much screen time messes with your memory, focus and sleep"),
        ("eyes", LightSheet.blue,
         "7 out of 10 people get tired, dry eyes from staring at screens"),
    ]
}

// MARK: - Scroll estimate (thick slider, phone knob, inline reaction)

/// A slim track with the phone sticker (bigger, tilted left) as the draggable
/// knob, and "0h" / "12h+" end labels.
private struct PhoneSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...12
    var step: Double = 0.5

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            GeometryReader { geo in
                let knob: CGFloat = 58
                let usable = max(1, geo.size.width - knob)
                let frac = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.16))
                        .frame(height: 14)
                    Capsule().fill(Color.white)
                        .frame(width: knob / 2 + frac * usable, height: 14)
                    Image("ScrollCardIcon")
                        .resizable().interpolation(.high).scaledToFit()
                        .frame(width: knob, height: knob)
                        .rotationEffect(.degrees(-12))
                        .shadow(color: .black.opacity(0.22), radius: 5, y: 3)
                        .offset(x: frac * usable)
                }
                .frame(height: knob)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            let x = min(max(0, g.location.x - knob / 2), usable)
                            let raw = range.lowerBound + Double(x / usable) * (range.upperBound - range.lowerBound)
                            let stepped = (raw / step).rounded() * step
                            if stepped != value {
                                // Animate so the readout number rolls (numericText).
                                withAnimation(.snappy(duration: 0.18)) { value = stepped }
                                Haptics.impact(.light)
                                AudioServicesPlaySystemSound(1104)
                            }
                        }
                )
            }
            .frame(height: 58)

            HStack {
                Text("0h")
                Spacer()
                Text("12h+")
            }
            .auraFont(.body, SheetType.subtitle, .semibold)
            .foregroundStyle(.white.opacity(0.7))
            .padding(.horizontal, Theme.Spacing.xs)
        }
    }
}

struct OnbScrollSliderView: View {
    @Environment(OnboardingFlow.self) private var flow
    @State private var reacting = false
    @State private var advanced = false

    private var reactionLine: String {
        let h = flow.hours
        let x = flow.hoursText
        let nameComma = flow.firstName.isEmpty ? "" : ", \(flow.firstName.lowercased())"
        if h <= 2 { return "\(x) hours. look at you, basically a monk." }
        if h < 6  { return "\(x) hours. every day. your phone should put you on payroll." }
        if h < 8  { return "\(x) hours. scrolling is officially your main hobby and your part-time job." }
        if h < 10 { return "\(x) hours\(nameComma). at this point the phone should pay rent." }
        let disp = h >= 12 ? "12+" : x
        return "\(disp) hours\(nameComma). okay. no judgment, but also, a lot of judgment. let's fix it."
    }

    /// Live line under the slider, changing with the position.
    private var sliderNote: String {
        let h = flow.hours
        if h <= 2 { return "Below average. Solid." }
        if h < 6  { return "That's around the national average." }
        if h < 8  { return "Nearly a full workday, on your phone." }
        if h <= 10 { return "That's a serious amount of your day." }
        return "Most of your life is given to your phone."
    }

    private func finish() {
        guard !advanced else { return }
        advanced = true
        flow.advance()
    }

    var body: some View {
        @Bindable var flow = flow
        return OnbQuestionLayout(
            progress: 0.78,
            headerText: reacting ? reactionLine : "how much time do you spend on your phone every day? not judging.",
            onFinishedTyping: {
                if reacting {
                    Task { try? await Task.sleep(nanoseconds: 1_500_000_000); finish() }
                }
            },
            content: {
                // Sits directly below the header, same gap as the option rows.
                VStack(spacing: Theme.Spacing.xxl) {
                    // One line, number and unit the same size and weight, no "a day".
                    Text(flow.hours >= 12 ? "12+ hours" : "\(flow.hoursText) hours")
                        .auraFont(.body, 44, .heavy)
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .contentTransition(.numericText())

                    VStack(spacing: Theme.Spacing.l) {
                        PhoneSlider(value: $flow.hours)
                            .disabled(reacting)

                        // Live nudge under the slider, changes with the position.
                        Text(sliderNote)
                            .auraFont(.body, SheetType.cardTitle, .semibold)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .contentTransition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.Spacing.xxl)
            },
            bottom: {
                onbContinue {
                    if !reacting { withAnimation(.easeInOut(duration: 0.25)) { reacting = true } }
                    else { finish() }
                }
            }
        )
    }
}

// MARK: - Did you know? (blue ground, animated fox, fact cards)

struct OnbWhyFloppedView: View {
    @Environment(OnboardingFlow.self) private var flow

    var body: some View {
        ZStack {
            LightSheet.blue.ignoresSafeArea()

            VStack(spacing: 0) {
                OnbTopBar(showBack: true, progress: 0.72, onSky: true)

                Spacer(minLength: Theme.Spacing.l)

                Text("Did you know?")
                    .auraFont(.display, SheetType.heroCompact, .bold)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Spacer(minLength: Theme.Spacing.xl)

                // The same animated fox the companion screens use, grounded on a
                // soft contact shadow like the other foxes.
                LoopingVideoView(resource: "InterventionTalkFox")
                    .frame(height: 190)
                    .frame(maxWidth: .infinity)
                    .background(alignment: .bottom) {
                        Ellipse().fill(Color.black.opacity(0.12))
                            .frame(width: 190 * 0.42, height: 190 * 0.11)
                            .offset(y: -14)
                    }

                Spacer(minLength: Theme.Spacing.xl)

                VStack(spacing: Theme.Spacing.m) {
                    ForEach(Array(OnbQ.didYouKnow.enumerated()), id: \.offset) { _, r in
                        HStack(spacing: Theme.Spacing.l) {
                            Image(systemName: r.icon)
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(r.tint)
                                .frame(width: 32)
                            Text(r.text)
                                .auraFont(.body, SheetType.cardTitle, .semibold)
                                .foregroundStyle(LightSheet.title)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(Theme.Spacing.l)
                        .frame(maxWidth: .infinity)
                        .background(Color.white,
                                    in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)

                Spacer(minLength: Theme.Spacing.xl)

                onbContinue { flow.advance() }
                    .padding(.horizontal, Theme.Spacing.xl)
                Spacer().frame(height: Theme.Spacing.l)
            }
        }
    }
}
