import SwiftUI

struct OnbLaunchCustomPlan: View {
    @Environment(OnboardingFlow.self) private var flow
    private static let buttonClearance: CGFloat = 92

    var body: some View {
        ZStack {
            LightSheet.blue.ignoresSafeArea()
            ScrollView {
                LazyVStack(spacing: 0) {
                    heroBand
                    arcBand
                    Spacer().frame(height: Self.buttonClearance)
                }
            }
            .ignoresSafeArea(edges: .top)

            VStack(spacing: 0) {
                Spacer()
                LightPrimaryButton(
                    title: "Let's get started!",
                    face: .white,
                    textColor: LightSheet.title,
                    shade: LightSheet.whiteShadeOnColour
                ) { flow.advance() }
                .padding(Theme.Spacing.s)
                .background(Capsule().fill(.black.opacity(0.12)))
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.l)
            }
        }
    }

    private var heroBand: some View {
        let foxHeight: CGFloat = 192
        let successArtNativeSize: CGFloat = 248
        let topSpace: CGFloat = 96
        let crestY = topSpace + foxHeight / 2

        return VStack(spacing: 0) {
            Spacer().frame(height: topSpace)
            SuccessCelebrationArt()
                .scaleEffect(foxHeight / successArtNativeSize)
                .frame(width: foxHeight, height: foxHeight)
                .frame(maxWidth: .infinity)
            Spacer().frame(height: Theme.Spacing.l)
            Text(heroHeadline)
                .auraFont(.display, SheetType.heroCompact, .heavy)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Theme.Spacing.xl)
            Spacer().frame(height: Theme.Spacing.xxxl)
            Image("StatsHabitsCompleted")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 72, height: 72)
                .padding(.bottom, Theme.Spacing.xl)
            Text("Your personalized plan is ready")
                .auraFont(.body, SheetType.banner, .bold)
                .foregroundStyle(.white)
            Text("Follow your plan through")
                .auraFont(.body, SheetType.banner, .bold)
                .foregroundStyle(.white)
                .padding(.top, 2)
            Text(planDate)
                .auraFont(.body, SheetType.cta, .heavy)
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
            ? "Your next 4 weeks start here."
            : "Your next 4 weeks start here, \(flow.firstName)."
    }

    private var arcBand: some View {
        VStack(spacing: Theme.Spacing.m) {
            OnbWeekCard(week: 1, title: "The reset", emoji: "🌱",
                        lines: ["Cut the easiest scroll triggers", "Set a calmer bedtime", "Stack a few small wins"])
            OnbWeekCard(week: 2, title: "The spark", emoji: "⚡️",
                        lines: ["Practice longer focus blocks", "Start before motivation arrives", "Make room for what matters"])
            OnbWeekCard(week: 3, title: "The lock in", emoji: "🔒",
                        lines: ["Protect time for hard things", "Repeat the habits you chose", "Keep your phone out of the way"])
            OnbWeekCard(week: 4, title: "The comeback", emoji: "🏆",
                        lines: ["Review what worked", "Keep the routines that helped", "Choose what comes next"])
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.xxl)
        .frame(maxWidth: .infinity)
        .background(LightSheet.blue)
    }

    private var planDate: String {
        let target = Calendar.current.date(byAdding: .day, value: 28, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: target)
    }
}

private struct LaunchHeroHillBackground: View {
    private let sky = Color(hex: "FFC531")
    private let rayLight = Color(hex: "FFDE5E")
    private let hill = LightSheet.blue
    let crestY: CGFloat

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                sky
                TimelineView(.animation) { timeline in
                    LaunchSunburstRays(
                        base: sky,
                        ray: rayLight,
                        center: CGPoint(x: geometry.size.width / 2, y: crestY),
                        rotation: timeline.date.timeIntervalSinceReferenceDate * 0.08
                    )
                }
                Ellipse()
                    .fill(hill)
                    .frame(width: geometry.size.width * 3.8, height: geometry.size.height * 2.6)
                    .position(x: geometry.size.width / 2, y: crestY + geometry.size.height * 1.3)
            }
        }
    }
}

private struct LaunchSunburstRays: View {
    let base: Color
    let ray: Color
    let center: CGPoint
    var count = 22
    var rotation = 0.0

    var body: some View {
        Canvas { context, size in
            let radius = hypot(size.width, size.height) * 1.6
            let step = 2 * Double.pi / Double(count)
            for index in 0..<count {
                let start = Double(index) * step - Double.pi / 2 + rotation
                let end = start + step
                var path = Path()
                path.move(to: center)
                path.addLine(to: CGPoint(x: center.x + cos(start) * radius, y: center.y + sin(start) * radius))
                path.addLine(to: CGPoint(x: center.x + cos(end) * radius, y: center.y + sin(end) * radius))
                path.closeSubpath()
                context.fill(path, with: .color(index.isMultiple(of: 2) ? ray : base))
            }
        }
        .allowsHitTesting(false)
    }
}

private struct OnbWeekCard: View {
    let week: Int
    let title: String
    let emoji: String
    let lines: [String]

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.m) {
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
                    Text(line.prefix(1).uppercased() + line.dropFirst())
                        .auraFont(.body, SheetType.cardBlurb, .medium)
                        .foregroundStyle(LightSheet.subtitleDark)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous))
    }
}
