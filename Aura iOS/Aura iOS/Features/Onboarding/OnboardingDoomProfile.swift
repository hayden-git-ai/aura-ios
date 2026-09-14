//
//  OnboardingDoomProfile.swift
//  Aura iOS
//
//  Screen 18 (locked flow): the doomscroll profile beat. Extracted from the custom
//  plan / Wrapped and moved into the question stretch, right after `qWorstTime`, so
//  it reacts to feelings + persona + worst-time. Yellow-sunbeam hero, fox, an honest
//  archetype + real-data bars derived from the user's own answers — no fake data.
//

import SwiftUI

struct OnbDoomProfileView: View {
    @Environment(OnboardingFlow.self) private var flow

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // The custom plan's yellow sunbeam hero: rotating sunburst behind the
                // fox, blue hill below, crest at the fox's vertical center.
                HeroHillBackground(crestY: geo.safeAreaInsets.top + Theme.Spacing.xl + 100)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // No back button or progress bar on this beat; a small top
                    // clearance instead, so the fox and cluster ride higher.
                    Spacer().frame(height: Theme.Spacing.xl)

                    // Same fox size as the custom plan hero (200).
                    LoopingVideoView(resource: "InterventionTalkFox")
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                        .background(alignment: .bottom) {
                            Ellipse().fill(Color.black.opacity(0.13))
                                .frame(width: 200 * 0.51, height: 200 * 0.136)
                                .offset(y: -200 * 0.05)
                        }

                    Text("Your doomscroll profile is")
                        .auraFont(.body, SheetType.cardBlurb, .bold)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.top, Theme.Spacing.l)

                    Text(archetype.name)
                        .auraFont(.display, SheetType.heroCompact, .heavy)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Theme.Spacing.xs)

                    Text(archetype.desc)
                        .auraFont(.body, SheetType.cardTitle, .medium)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Theme.Spacing.s)

                    Spacer(minLength: Theme.Spacing.l)

                    VStack(spacing: Theme.Spacing.l) {
                        OnbProfileBar(label: "Daily screen time",
                                      fill: min(1, flow.hours / 12),
                                      leftLabel: "Low", rightLabel: "High")
                        OnbProfileBar(label: "Daytime vulnerability",
                                      value: flow.worstTime == "Honestly, all day" ? "All day" : nil,
                                      fill: exposureFill,
                                      leftLabel: "Mornings", rightLabel: "Evenings")
                        OnbProfileBar(label: "Mental drain",
                                      fill: drainFill,
                                      leftLabel: "Low", rightLabel: "High")
                    }

                    Spacer(minLength: Theme.Spacing.l)

                    onbContinue { flow.advance() }
                    Spacer().frame(height: Theme.Spacing.l)
                }
                .padding(.horizontal, Theme.Spacing.xl)
            }
        }
    }

    // MARK: - Archetype + bar fills (from the user's real answers, no fake data)

    /// A short, honest archetype picked from their real answers (no fabricated data).
    private var archetype: (name: String, desc: String) {
        let f = flow.feelings
        if flow.worstTime == "Honestly, all day" {
            return ("The All-Day Scroller", "Your phone's in your hand from morning to night.")
        }
        if f.contains("Bad sleep") || flow.worstTime == "Evenings" {
            return ("The Night Scroller", "You stay up on your phone, and mornings are rough.")
        }
        if flow.worstTime == "First thing in the morning" {
            return ("The Morning Scroller", "Your day starts in bed, on your phone, before you're even up.")
        }
        if f.contains("Anxiety / overstimulation") {
            return ("The Anxious Refresher", "You refresh the same apps on repeat.")
        }
        if f.contains("No focus / procrastination") || f.contains("Productivity loss") {
            return ("The Great Avoider", "You reach for your phone whenever there's something you'd rather not do.")
        }
        if f.contains("I feel mentally fried") {
            return ("The Overloaded Scroller", "Your attention gets pulled ten ways at once.")
        }
        return ("The Heavy Scroller", "Your phone takes more of your day than you'd think.")
    }

    private var exposureFill: Double {
        switch flow.worstTime {
        case "First thing in the morning": return 0.08
        case "During the day":             return 0.42
        case "Evenings":                   return 0.92
        case "Honestly, all day":          return 1.0
        default:                           return 0.5
        }
    }

    private var drainFill: Double { min(1, Double(flow.feelings.count) / 6 * 0.6 + flow.hours / 12 * 0.4) }
}

// MARK: - Profile bar (real-data slider with a sticker at the fill)

private struct OnbProfileBar: View {
    let label: String
    var value: String?
    let fill: Double
    var caption: String? = nil
    var leftLabel: String? = nil
    var rightLabel: String? = nil

    private let barHeight: CGFloat = 20

    private let fillGradient = LinearGradient(
        colors: [Color(hex: "FFD84D"), Color(hex: "FF8A1E")],
        startPoint: .leading, endPoint: .trailing)

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                Text(label)
                    .auraFont(.body, SheetType.cta, .heavy)
                    .foregroundStyle(.white)
                Spacer()
                if let value, !value.isEmpty {
                    Text(value)
                        .auraFont(.body, SheetType.cardTitle, .heavy)
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.18))
                        .frame(height: barHeight)
                    Capsule().fill(fillGradient)
                        .frame(width: max(barHeight, g.size.width * fill), height: barHeight)
                }
                .frame(height: barHeight, alignment: .leading)
            }
            .frame(height: barHeight)
            if let leftLabel, let rightLabel {
                HStack { Text(leftLabel); Spacer(); Text(rightLabel) }
                    .auraFont(.body, SheetType.subtitle, .medium)
                    .foregroundStyle(.white.opacity(0.65))
            }
            if let caption {
                Text(caption)
                    .auraFont(.body, SheetType.subtitle, .medium)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}
