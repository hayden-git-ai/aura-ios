//
//  OnbLaunchSlider.swift
//  Aura iOS
//
//  Launch-flow copy of OnbScrollSliderView (screen 5). Reuses the shared
//  OnbQuestionLayout + PhoneSlider; progress off the active sequence (flow.progress).
//

import SwiftUI
import AudioToolbox

struct OnbLaunchSlider: View {
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
        return OnbLaunchQuestionLayout(
            progress: flow.progress,
            headerText: reacting ? reactionLine : "how much time do you spend on your phone every day? not judging.",
            onFinishedTyping: {
                if reacting {
                    Task { try? await Task.sleep(nanoseconds: 1_500_000_000); finish() }
                }
            },
            content: {
                VStack(spacing: Theme.Spacing.xxl) {
                    Text(flow.hours >= 12 ? "12+ hours" : "\(flow.hoursText) hours")
                        .auraFont(.display, 44, .heavy)
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .contentTransition(.numericText())

                    VStack(spacing: Theme.Spacing.l) {
                        LaunchPhoneSlider(value: $flow.hours)
                            .disabled(reacting)

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

/// Launch-flow copy of the private PhoneSlider (the app's onboarding time slider).
private struct LaunchPhoneSlider: View {
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
