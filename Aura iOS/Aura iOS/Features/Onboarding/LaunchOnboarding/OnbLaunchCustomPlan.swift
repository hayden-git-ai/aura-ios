//
//  OnbLaunchCustomPlan.swift
//  Aura iOS
//
//  Launch-flow copy of OnboardingCustomPlan (screen 11, the Wrapped payoff).
//  Independent of the v2 original; top-level types are Launch-prefixed to avoid
//  collisions, and all private helpers come along unchanged.
//
//  The payoff reveal right after the loader (spec: docs/onboarding/CUSTOM_PLAN_SPEC.md).
//  Styled chapter-by-chapter after Unrot/Brainrot: each section is its own full-bleed
//  band with its own ground, colorful pastel timeline cards, a red/blue two-paths toggle,
//  white review cards. Reskinned to the Aura fox + our blue. Deeply personalized from the
//  onboarding answers. No fake stats, no laurels.
//

import SwiftUI

struct OnbLaunchCustomPlan: View {
    @Environment(OnboardingFlow.self) private var flow
    @Environment(HabitStore.self) private var store

    /// Bottom scroll clearance so the last card clears the floating CTA.
    private static let buttonClearance: CGFloat = 92

    var body: some View {
        ZStack {
            // The final band is blue, so the base behind the pinned button is blue
            // too: the button floats on a transparent pill, no white footer bar.
            LightSheet.blue.ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 0) {
                    heroBand
                    arcBand
                    twoPathsBand
                    #if DEBUG
                    reviewsBand
                    #endif
                    faqBand
                    // Clearance so the last card scrolls clear of the floating button.
                    Spacer().frame(height: Self.buttonClearance)
                }
            }
            .ignoresSafeArea(edges: .top)

            // The button floats over the content, with a translucent pill behind it
            // (same shape, a little bigger) to separate it from the background — the
            // same treatment as the create-your-own button on the habit detail screen.
            VStack(spacing: 0) {
                Spacer()
                LightPrimaryButton(title: "Let's get started!",
                                   face: .white, textColor: LightSheet.title, shade: LightSheet.whiteShadeOnColour) {
                    flow.advance()
                }
                .padding(Theme.Spacing.s)
                .background(Capsule().fill(.black.opacity(0.12)))
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.l)
            }
        }
    }

    // MARK: - A. Hero

    private var heroBand: some View {
        let foxH: CGFloat = 200
        let topSpace: CGFloat = 96          // clears the status bar / Dynamic Island
        let crestY = topSpace + foxH / 2    // hill line + beam origin at the fox's center

        // Content-sized section: headline stays tight under the fox and the pill lands
        // near the bottom, with no flexible air shoving the cluster around.
        return VStack(spacing: 0) {
            Spacer().frame(height: topSpace)

            LoopingVideoView(resource: "InterventionTalkFox")
                .frame(height: foxH)
                .frame(maxWidth: .infinity)
                .background(alignment: .bottom) {
                    Ellipse().fill(Color.black.opacity(0.13))
                        .frame(width: foxH * 0.51, height: foxH * 0.136)
                        .offset(y: -foxH * 0.05)
                }

            Spacer().frame(height: Theme.Spacing.l)

            Text(heroHeadline)
                .auraFont(.display, SheetType.heroCompact, .heavy)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Theme.Spacing.xl)

            Spacer().frame(height: Theme.Spacing.xxxl)

            Image("StatsHabitsCompleted")
                .resizable().interpolation(.high).scaledToFit()
                .frame(width: 72, height: 72)
                .padding(.bottom, Theme.Spacing.xl)

            Text("Your personalized plan is ready")
                .auraFont(.body, SheetType.banner, .bold)
                .foregroundStyle(.white)
            Text("You will feel like yourself again by")
                .auraFont(.body, SheetType.banner, .bold)
                .foregroundStyle(.white)
                .padding(.top, 2)

            Text(planDate)
                .auraFont(.display, SheetType.cta, .heavy)
                .foregroundStyle(LightSheet.blue)
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.vertical, Theme.Spacing.s)
                .background(Color.white, in: Capsule())
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                .padding(.top, Theme.Spacing.xl)

            Spacer().frame(height: Theme.Spacing.xxl)
        }
        .frame(maxWidth: .infinity)
        .background(LaunchHeroHillBackground(crestY: crestY))
    }

    private var heroHeadline: String {
        flow.firstName.isEmpty
            ? "In 4 weeks you won't recognize yourself."
            : "In 4 weeks you won't recognize yourself, \(flow.firstName)."
    }

    // MARK: - C. The 4-week arc (pastel cards)

    private var arcBand: some View {
        VStack(spacing: Theme.Spacing.m) {
            OnbWeekCard(week: 1, title: "The reset", ground: .white, emoji: "🌱",
                        lines: ["You scroll less without trying",
                                "You fall asleep faster",
                                "The small wins feel huge"])
            OnbWeekCard(week: 2, title: "The spark", ground: .white, emoji: "⚡️",
                        lines: ["Focus lasts longer",
                                "You stop putting things off",
                                "Your mind feels less cluttered"])
            OnbWeekCard(week: 3, title: "The lock in", ground: .white, emoji: "🔒",
                        lines: ["Hard things stop feeling hard",
                                "The good habits stick",
                                "You get more done"])
            OnbWeekCard(week: 4, title: "The comeback", ground: .white, emoji: "🏆",
                        lines: ["Calm mornings, sharp focus",
                                "Your phone stops running your life",
                                "Life feels good again"])
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.xxl)
        .frame(maxWidth: .infinity)
        .background(LightSheet.blue)
    }

    // MARK: - D. Two paths (full-bleed toggle)

    private var twoPathsBand: some View {
        OnbTwoPaths()
    }

    // MARK: - E. Reviews (fox / title / cards, blue)

    private var reviewsBand: some View {
        VStack(spacing: 0) {
            sectionFox()
            Spacer().frame(height: Theme.Spacing.xxl)
            sectionTitle("people who stopped scrolling")
            Spacer().frame(height: Theme.Spacing.xl)
            VStack(spacing: Theme.Spacing.l) {
                OnbReviewCard(name: "placeholder", quote: "got my mornings back. i make breakfast now.")
                OnbReviewCard(name: "placeholder", quote: "earning my screen time is the only thing that ever worked for me.")
                OnbReviewCard(name: "placeholder", quote: "down from 7 hours to under 2. didn't think it was possible.")
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.xxl)
        .frame(maxWidth: .infinity)
        .background(LightSheet.blue)
    }

    // MARK: - F. FAQ (fox / title / cards, blue)

    private var faqBand: some View {
        VStack(spacing: 0) {
            sectionFox()
            Spacer().frame(height: Theme.Spacing.xxl)
            sectionTitle("you might ask...")
            Spacer().frame(height: Theme.Spacing.xl)
            VStack(spacing: Theme.Spacing.l) {
                OnbFaqCard(question: "is this just another screen-time app?",
                           answer: "no. a blocker you can switch off in a tap does nothing. Aura makes you earn screen time by doing the things you keep meaning to do. the friction is the point.")
                OnbFaqCard(question: "what if i slip?",
                           answer: "you will, everyone does. the plan runs on momentum, not a perfect streak. one bad day doesn't reset you.")
                OnbFaqCard(question: "is it worth it?",
                           answer: "it costs less than a coffee a month. you're trying to win back \(flow.hoursText) hours a day of your own life. you decide.")
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.xxl)
        .frame(maxWidth: .infinity)
        .background(LightSheet.blue)
    }

    // The section header the reviews + FAQ bands share, matching the two-paths
    // beat: the animated fox, then a centered white title.
    private func sectionFox() -> some View {
        LoopingVideoView(resource: "InterventionTalkFox")
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .background(alignment: .bottom) {
                Ellipse().fill(Color.black.opacity(0.13))
                    .frame(width: 200 * 0.51, height: 200 * 0.136)
                    .offset(y: -200 * 0.05)
            }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .auraFont(.display, SheetType.heroCompact, .heavy)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Shared


    private var planDate: String {
        let target = Calendar.current.date(byAdding: .day, value: 28, to: Date()) ?? Date()
        let f = DateFormatter(); f.dateFormat = "MMMM d, yyyy"
        return f.string(from: target)
    }
}

// MARK: - Hero sunburst hill background

struct LaunchHeroHillBackground: View {
    private let sky = Color(hex: "FFC531")
    private let rayLight = Color(hex: "FFDE5E")
    private let hill = LightSheet.blue
    var crestY: CGFloat

    var body: some View {
        GeometryReader { g in
            ZStack {
                sky
                // Beam origin is centered on the crest, which is the fox's vertical center,
                // so the rays radiate from directly behind the fox's body. Slow rotation.
                TimelineView(.animation) { tl in
                    LaunchSunburstRays(base: sky, ray: rayLight,
                                 center: CGPoint(x: g.size.width / 2, y: crestY),
                                 rotation: tl.date.timeIntervalSinceReferenceDate * 0.08)
                }
                // Wide, shallow ellipse so the hill crest reads flatter, not a round dome.
                Ellipse()
                    .fill(hill)
                    .frame(width: g.size.width * 3.8, height: g.size.height * 2.6)
                    .position(x: g.size.width / 2, y: crestY + g.size.height * 1.3)
            }
        }
    }
}

struct LaunchSunburstRays: View {
    var base: Color
    var ray: Color
    var center: CGPoint
    var count: Int = 22
    var rotation: Double = 0

    var body: some View {
        Canvas { ctx, size in
            let R = hypot(size.width, size.height) * 1.6
            let step = (2 * Double.pi) / Double(count)
            for i in 0..<count {
                let a0 = Double(i) * step - Double.pi / 2 + rotation
                let a1 = a0 + step
                var p = Path()
                p.move(to: center)
                p.addLine(to: CGPoint(x: center.x + cos(a0) * R, y: center.y + sin(a0) * R))
                p.addLine(to: CGPoint(x: center.x + cos(a1) * R, y: center.y + sin(a1) * R))
                p.closeSubpath()
                ctx.fill(p, with: .color(i % 2 == 0 ? ray : base))
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Soft shadow helper

private extension View {
}

// MARK: - Week card (pastel)

private struct OnbWeekCard: View {
    let week: Int
    let title: String
    let ground: Color
    let emoji: String
    let lines: [String]

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.m) {
            // A per-week emoji over "Week N".
            VStack(spacing: Theme.Spacing.xs) {
                Text(emoji)
                    .font(.system(size: 40))
                    .frame(width: 60, height: 60)
                Text("Week \(week)")
                    .auraFont(.body, SheetType.cardBlurb, .bold)
                    .foregroundStyle(LightSheet.title)
            }
            .frame(width: 64)

            VStack(alignment: .leading, spacing: RowType.labelGap) {
                Text(title)
                    .auraFont(.body, SheetType.cta, .bold)
                    .foregroundStyle(LightSheet.title)
                    .padding(.bottom, Theme.Spacing.xs)
                ForEach(lines, id: \.self) { line in
                    Text(capFirst(line))
                        .auraFont(.body, SheetType.cardBlurb, .medium)
                        .foregroundStyle(LightSheet.subtitleDark)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ground, in: RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous))
    }
}

private func capFirst(_ s: String) -> String {
    guard let f = s.first else { return s }
    return f.uppercased() + s.dropFirst()
}

// MARK: - Two paths (full-bleed drained/charged)

private struct OnbTwoPaths: View {
    @State private var charged = false   // false = Brainrot (red), true = Unrot (blue)

    private let drainedGround = LightSheet.drainRed

    // Cloned verbatim from the reference, to iterate/adapt from.
    private let brainrotRows = [
        "You waste half your day scrolling",
        "You procrastinate on important tasks, feel guilty after",
        "You wake up tired from scrolling late at night in bed",
        "You can't focus on tasks without getting distracted",
    ]
    private let unrotRows = [
        "You complete meaningful tasks instead of scrolling",
        "You set out to do what you plan to do",
        "You go to sleep without scrolling, waking up refreshed",
        "You focus on your tasks without picking up your phone",
    ]
    @Environment(HabitStore.self) private var store

    // Unrot side: the real catalogue — Healthy Habits + Daily Exercise + Passive Income.
    private var goodPills: [OnbLaunchPill] {
        var pills = store.proofHabits.map { h in
            OnbLaunchPill(name: h.name, asset: h.iconAsset, emoji: h.emoji,
                    rate: h.requiresFocusSession ? "\(Int(h.rewardRate))/hr" : "\(h.rewardMinutes)")
        }
        pills += Exercise.all.map { e in
            OnbLaunchPill(name: e.name, asset: e.iconAsset,
                    rate: "\(String(format: "%g", store.rate(for: e)))/\(e.unitNoun)")
        }
        pills += store.healthMetrics.map { m in
            OnbLaunchPill(name: m.name, asset: m.iconAsset,
                    rate: m.rateLabel.replacingOccurrences(of: " min / ", with: "/"))
        }
        return pills
    }
    // Brainrot side: the negatives, same pill shape (emoji placeholders until real art).
    private let badPills: [OnbLaunchPill] = [
        OnbLaunchPill(name: "Doomscroll", emoji: "📱", rate: "-2 hrs", isLoss: true),
        OnbLaunchPill(name: "Binge shows", emoji: "📺", rate: "-3 hrs", isLoss: true),
        OnbLaunchPill(name: "Procrastinate", emoji: "🕒", rate: "-1 hr", isLoss: true),
        OnbLaunchPill(name: "Rot in bed", emoji: "🛏️", rate: "-90 min", isLoss: true),
        OnbLaunchPill(name: "Waste hours", emoji: "⏳", rate: "-2 hrs", isLoss: true),
        OnbLaunchPill(name: "Skip the gym", emoji: "🛋️", rate: "-45 min", isLoss: true),
        OnbLaunchPill(name: "Stay up late", emoji: "🌙", rate: "-1 hr", isLoss: true),
        OnbLaunchPill(name: "Refresh apps", emoji: "🔄", rate: "-30 min", isLoss: true),
        OnbLaunchPill(name: "Numb out", emoji: "🧟", rate: "-2 hrs", isLoss: true),
        OnbLaunchPill(name: "Feel guilty", emoji: "😞", rate: "-1 hr", isLoss: true),
        OnbLaunchPill(name: "Compare yourself", emoji: "😵", rate: "-30 min", isLoss: true),
        OnbLaunchPill(name: "Ignore your goals", emoji: "🎯", rate: "-1 hr", isLoss: true),
    ]

    private func threeRows(_ pills: [OnbLaunchPill]) -> [[OnbLaunchPill]] {
        var rows: [[OnbLaunchPill]] = [[], [], []]
        for (i, p) in pills.enumerated() { rows[i % 3].append(p) }
        return rows
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.xxxl) {
            VStack(spacing: 0) {
                // Mascot: the same animated fox and size as the other sections.
                LoopingVideoView(resource: "InterventionTalkFox")
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .background(alignment: .bottom) {
                        Ellipse().fill(Color.black.opacity(0.13))
                            .frame(width: 200 * 0.51, height: 200 * 0.136)
                            .offset(y: -200 * 0.05)
                    }

                Spacer().frame(height: Theme.Spacing.xxl)

                // Header group: title + hint sit tight together.
                Text("Two paths. Which one do you choose?")
                    .auraFont(.display, SheetType.heroCompact, .heavy)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer().frame(height: Theme.Spacing.xl)
                Text("← Toggle to see changes →")
                    .auraFont(.body, SheetType.cardTitle, .medium)
                    .foregroundStyle(.white.opacity(0.85))

                Spacer().frame(height: Theme.Spacing.xl)

                HStack(spacing: 0) {
                    segment("Without Aura", "💀", on: !charged) { withAnimation(.snappy(duration: 0.25)) { charged = false } }
                    segment("With Aura", "😊", on: charged) { withAnimation(.snappy(duration: 0.25)) { charged = true } }
                }
                .padding(4)
                .background(Color.black.opacity(0.18), in: Capsule())

                Spacer().frame(height: Theme.Spacing.xxl)

                VStack(spacing: Theme.Spacing.l) {
                    ForEach(charged ? unrotRows : brainrotRows, id: \.self) { row in
                        HStack(alignment: .center, spacing: Theme.Spacing.m) {
                            Image(systemName: charged ? "checkmark" : "xmark")
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundStyle(charged ? LightSheet.blue : drainedGround)
                                .frame(width: 32, height: 32)
                                .background(Color.white, in: Circle())
                            Text(row)
                                .auraFont(.body, SheetType.cardTitle, .semibold)
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)

            // 3 auto-scrolling marquee rows, alternating direction, bleeding off the edges.
            let rows = threeRows(charged ? goodPills : badPills)
            VStack(spacing: Theme.Spacing.s) {
                ForEach(0..<3, id: \.self) { i in
                    PillMarquee(pills: rows[i], toLeft: i % 2 == 0)
                }
            }
        }
        .padding(.vertical, Theme.Spacing.xxl)
        .frame(maxWidth: .infinity)
        .background(charged ? LightSheet.blue : drainedGround)
    }

    private func segment(_ title: String, _ emoji: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.s) {
                Text(emoji).font(.system(size: 14))
                Text(title).auraFont(.body, SheetType.cardTitle, .bold)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.s)
            .background(on ? Color.white.opacity(0.22) : Color.clear, in: Capsule())
        }
        .buttonStyle(PressBounceStyle())
    }
}

// MARK: - Habit pill + auto-scrolling marquee

struct OnbLaunchPill: Identifiable {
    let id = UUID()
    let name: String
    var asset: String? = nil
    var emoji: String? = nil
    /// The line under the name (nil = name only).
    var rate: String? = nil
    /// A loss (Brainrot) shows a red time-drain rate instead of the coin rate.
    var isLoss: Bool = false
}

/// The in-app habit card (HabitPickerRow) minus the heart/tap: sticker, name over
/// its coin rate, on the white bottom-drop card.
private struct OnbLaunchPillView: View {
    let pill: OnbLaunchPill
    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            Group {
                if let asset = pill.asset {
                    Image(asset).resizable().interpolation(.high).scaledToFit()
                } else if let emoji = pill.emoji {
                    Text(emoji).font(.system(size: 30))
                }
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: RowType.labelGap) {
                Text(pill.name)
                    .auraFont(.body, RowType.label, .semibold)
                    .foregroundStyle(RowType.labelColor)
                    .lineLimit(1)
                if let rate = pill.rate {
                    HStack(spacing: 4) {
                        if pill.isLoss {
                            Image(systemName: "hourglass")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(LightSheet.drainRed)
                                .frame(width: 14, height: 14)
                            Text(rate)
                                .auraFont(.body, RowType.subLabel, .semibold)
                                .foregroundStyle(LightSheet.drainRed)
                        } else {
                            Image("AuraCoinIcon").resizable().interpolation(.high).scaledToFit()
                                .frame(width: 14, height: 14)
                            Text(rate)
                                .auraFont(.body, RowType.subLabel, .medium)
                                .foregroundStyle(LightSheet.subtitle)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
        .bottomDropCard(radius: Theme.Radius.card, shade: LightSheet.whiteShadeOnColour)
    }
}

private struct MarqueeWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// One row of pills auto-scrolling forever. Two copies laid end to end and offset
/// by (elapsed × speed) mod one copy's width make a seamless loop.
private struct PillMarquee: View {
    let pills: [OnbLaunchPill]
    let toLeft: Bool
    var speed: CGFloat = 30
    private let spacing = Theme.Spacing.s
    @State private var w: CGFloat = 0

    private var oneCopy: some View {
        HStack(spacing: spacing) { ForEach(pills) { OnbLaunchPillView(pill: $0) } }
    }

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: 66)
            .overlay(alignment: .leading) {
                TimelineView(.animation) { tl in
                    let total = w + spacing
                    let t = CGFloat(tl.date.timeIntervalSinceReferenceDate) * speed
                    let shift = total > 0 ? t.truncatingRemainder(dividingBy: total) : 0
                    HStack(spacing: spacing) {
                        oneCopy.background(GeometryReader { g in
                            Color.clear.preference(key: MarqueeWidthKey.self, value: g.size.width)
                        })
                        oneCopy
                    }
                    .fixedSize()
                    .offset(x: toLeft ? -shift : shift - total)
                }
            }
            .clipped()
            .onPreferenceChange(MarqueeWidthKey.self) { w = $0 }
    }
}

// MARK: - Review card (white)

private struct OnbReviewCard: View {
    let name: String
    let quote: String

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            Text(name)
                .auraFont(.display, SheetType.cardTitle, .bold)
                .foregroundStyle(LightSheet.title)
            Text(quote)
                .auraFont(.body, SheetType.cardTitle, .medium)
                .foregroundStyle(LightSheet.subtitleDark)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { _ in
                    Image(systemName: "star.fill").font(.system(size: 14)).foregroundStyle(LightSheet.starGold)
                }
            }
            .padding(.top, 2)
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity)
        .background(Color.white, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .cardShadow()
    }
}

// MARK: - FAQ card

private struct OnbFaqCard: View {
    let question: String
    let answer: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(question)
                .auraFont(.body, SheetType.cardTitle, .bold)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text(answer)
                .auraFont(.body, SheetType.subtitle, .medium)
                .foregroundStyle(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous)
                .fill(Color.black.opacity(0.16))
        )
    }
}
