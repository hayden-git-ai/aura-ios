//
//  StatsView.swift
//  Aura iOS
//

import DeviceActivity
import SwiftUI

/// Stats — one scroll of achievements: the screen-time overview up top, then
/// the all-time achievement cards, the 90-day journey, and the Wall of Wins.
struct StatsView: View {
    @Environment(HabitStore.self) private var store
    @Environment(NavChrome.self) private var navChrome

    @State private var selectedDay = Calendar.current.component(.weekday, from: .now) - 1
    @State private var showWall = false

    /// The two data seams, resolved once here and handed down.
    ///
    /// Swapping either to real data is a change to these two lines — the views
    /// below take what they're given. Screen Time's real provider will live in
    /// the report extension, since that's the only place Apple's numbers exist.
    private let screenTimeProvider: ScreenTimeProviding = SampleScreenTimeProvider()

    private var screenTimeWeek: [ScreenTimeDay] { screenTimeProvider.week() }
    private var hasScreenTimeData: Bool { !screenTimeWeek.isEmpty }




    // The screen's spacing scale. Five steps, so each boundary reads as more
    // separate than the one above it: 4 tight, 10 paired, 24 grouped (inside
    // the card), 40 section, 64 zone. Everything sitting at 16/24 was why
    // nothing looked more separate than anything else.





    private let headerTopInset: CGFloat = 64

    /// One scroll, four blocks: the week card (A), the 90-day journey (B, kept
    /// as it was), the Wall of Wins (C), and a single screen-time overview (D).
    /// The old two-tab toggle, the blue dome, the week coin-bar, peak hours,
    /// favorite quests, and the deep screen-time analytics are gone.
    var body: some View {
        ZStack(alignment: .top) {
            LightSheet.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // The title + screen-time card share one full-bleed white
                    // slab; everything else sits on the light ground below it.
                    topSlab

                    VStack(alignment: .leading, spacing: Self.sectionGap) {
                        achievementsSection
                        journeySection
                        wallOfWins
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Self.sectionGap)
                    .padding(.bottom, Theme.Layout.scrollBottomClearance)
                }
            }
            .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, y in
                navChrome.track(y)
            }
            .ignoresSafeArea(edges: .top)
        }
        .sheet(isPresented: $showWall) {
            WallOfWinsSheet()
        }
        // Once the account is a week old, snapshot this week's screen-time total
        // as the baseline the Profile time-saved statistic measures against. No-op after the
        // first capture. (Fed from here because the store has no screen-time
        // source of its own.)
        .onAppear {
            guard hasScreenTimeData else { return }
            store.captureScreenTimeBaselineIfNeeded(
                currentWeeklyMinutes: screenTimeWeek.reduce(0) { $0 + $1.totalMinutes })
        }
        // Capped at accessibility1 — the grid and bars are geometry, so type
        // grows within a frame rather than pushing it.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    /// The gap between the four major blocks.
    private static let sectionGap: CGFloat = 32



    // MARK: - Header



    /// Dark: everything from here down sits on the light surface, not the blue.
    /// 20pt — the same rung as the Apps screen's section headers. The enclosing
    /// section VStacks run at `l` spacing, so the header sits `l` (16) above its
    /// content — matching the Apps screen's header-to-content gap.
    private func section(_ title: String) -> some View {
        Text(title)
            .auraFont(.display, SheetType.banner, .bold)
            .foregroundStyle(LightSheet.title)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Habits summary (inside the top card)






    // MARK: - Achievements (horizontal scroll)

    /// The illustration and metric have separate areas so neither obscures the other.
    private struct AchievementItem {
        let value: String
        let label: String
        let color: LightSheet.Achievement.Palette
        let sticker: String?
        var backgroundImage: String? = nil
    }

    private enum AchievementLayout {
        static let width: CGFloat = 200
        static let height: CGFloat = 236
        static let artworkSize: CGFloat = 152
        static let artworkBleed: CGFloat = 12
        static let numeralSize: CGFloat = 44
        static let discSize: CGFloat = 210
        static let discBleed: CGFloat = 50

    }

    private var achievements: [AchievementItem] {
        [
            AchievementItem(value: "\(store.streak.longestStreak)", label: "Best Streak",
                            color: LightSheet.Achievement.streak, sticker: "AchievementFoxStreak", backgroundImage: "AchievementBackgroundStreak"),
            AchievementItem(value: "\(store.lifetimeHealthyHabits)", label: "Healthy Habits",
                            color: LightSheet.Achievement.habits, sticker: "AchievementFoxHabits", backgroundImage: "AchievementBackgroundHabits"),
            AchievementItem(value: "\(store.lifetimeReps)", label: "Reps Completed",
                            color: LightSheet.Achievement.reps, sticker: "AchievementFoxReps", backgroundImage: "AchievementBackgroundReps"),
            AchievementItem(value: focusValueLabel, label: "Time Focused",
                            color: LightSheet.Achievement.focus, sticker: "AchievementFoxFocus", backgroundImage: "AchievementBackgroundFocus"),
            AchievementItem(value: "\(store.lifetimeEarnedMinutes)", label: "Coins Earned",
                            color: LightSheet.Achievement.coins, sticker: "AchievementFoxCoins", backgroundImage: "AchievementBackgroundCoins"),
        ]
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            section("Achievements")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.m) {
                    ForEach(Array(achievements.enumerated()), id: \.offset) { _, item in
                        achievementCard(item)
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
            }
            // Let the cards' drop shadow render OUTSIDE the scroll's bounds rather
            // than being clipped into a hard line at the card edges.
            .scrollClipDisabled()
            // Bleed the scroll to the screen edges; the inner padding re-aligns
            // the first card with the page margin.
            .padding(.horizontal, -Theme.Spacing.xl)
        }
    }

    /// Time focused as a single number: hours once it passes an hour, minutes
    /// below that.
    private var focusValueLabel: String {
        let m = store.lifetimeFocusMinutes
        return m >= 60 ? "\(m / 60)h" : "\(m)m"
    }

    private func achievementNumberFont(_ value: String) -> UIFont {
        let font = Typography.displayUIFont(size: AchievementLayout.numeralSize, weight: .black, tabular: true)
        let measuredWidth = (value as NSString).size(withAttributes: [.font: font]).width
        let availableWidth = AchievementLayout.width - Theme.Spacing.m * 2
        let outlinedWidth = measuredWidth + font.pointSize * StrokedNumeral.outlineRatio * 2
        return font.withSize(font.pointSize * min(1, availableWidth / max(outlinedWidth, 1)))
    }

    private func achievementCard(_ a: AchievementItem) -> some View {
        ZStack(alignment: .bottom) {
            if let backgroundImage = a.backgroundImage {
                Image(backgroundImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(width: AchievementLayout.width, height: AchievementLayout.height)
                    .clipped()
                    .accessibilityHidden(true)
            } else {
                LinearGradient(colors: [a.color.top, a.color.bottom],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle()
                    .fill(a.color.bottom.opacity(0.45))
                    .frame(width: AchievementLayout.discSize, height: AchievementLayout.discSize)
                    .offset(y: AchievementLayout.discBleed)
            }

            if let sticker = a.sticker {
                Image(sticker)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: AchievementLayout.artworkSize,
                           height: AchievementLayout.artworkSize)
                    // Extend the original PNG's straight body edge below the mask.
                    .offset(y: AchievementLayout.artworkBleed)
                    .accessibilityHidden(true)
            }

            VStack(spacing: 0) {
                StrokedNumber(text: a.value, font: achievementNumberFont(a.value),
                              fill: .black, stroke: .white,
                              outlineWidth: achievementNumberFont(a.value).pointSize * StrokedNumeral.outlineRatio)
                    .fixedSize()
                    .shadow(color: .black.opacity(LightSheet.Achievement.numeralShadowOpacity),
                            radius: LightSheet.Achievement.numeralShadowRadius,
                            y: LightSheet.Achievement.numeralShadowDrop)
                Text(a.label)
                    .auraFont(.body, SheetType.cardTitle, .bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .shadow(color: .white, radius: 0, x: LightSheet.Achievement.labelEdgeWidth)
                    .shadow(color: .white, radius: 0, x: -LightSheet.Achievement.labelEdgeWidth)
                    .shadow(color: .white, radius: 0, y: LightSheet.Achievement.labelEdgeWidth)
                    .shadow(color: .white, radius: 0, y: -LightSheet.Achievement.labelEdgeWidth)
                    .padding(.top, -Theme.Spacing.xs)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.black)
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.top, Theme.Spacing.m)
        }
        .frame(width: AchievementLayout.width, height: AchievementLayout.height)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous)
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.6), .white.opacity(0.05)],
                                             startPoint: .top, endPoint: .bottom), lineWidth: 1)
        }
        .illustratedCardShadow()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(a.label), \(a.value), all time")
    }

    // MARK: - This week (Reference A, repackaged)



    // MARK: - Sections (single-screen wire-up)

    /// Reference B, kept exactly as it was — the 90-day flame grid in its own
    /// section.
    private var journeySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            section("Your past 90 days")
            consistencyCard
        }
    }

    /// The screen-time block, at the top: the real summary that was built for
    /// the old Screen Time tab — a selectable week, the day's total + date, the
    /// Most used / Apps / Pickups row, and the 7-day bars read against a daily
    /// average. On a light card now (no blue field, no fox). Matches the two
    /// competitor references: reference B's layout with reference A's stat row.
    /// The full-bleed white slab at the top: the "Stats" title and the screen-
    /// time summary sitting flush on one white surface, only its bottom corners
    /// rounded, running under the status bar — the same top-slab treatment the
    /// app uses elsewhere, so the two read as one cohesive white unit.
    private var topSlab: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Sticker title, aligned to the chart's own left inset.
            StrokedNumber(text: "Stats",
                          font: Typography.displayUIFont(size: SheetType.hero, weight: .black),
                          fill: .black,
                          stroke: .white,
                          outlineWidth: 3)
                .fixedSize()
                .shadow(color: .black.opacity(0.22), radius: 5, y: 2)
                .padding(.horizontal, SummaryChart.panelPadding)

            // Debug previews use their deliberately labelled fixture. In a
            // release build, Apple renders real Device Activity data inside
            // the report extension; this host never receives its numbers.
#if DEBUG
            if screenTimeWeek.isEmpty {
                StatsLoadingState()
            } else {
                ScreenTimeSummary(week: screenTimeWeek, selected: $selectedDay, plain: true)
            }
#else
            ZStack {
                StatsLoadingState()
                DeviceActivityReport(
                    .screenTimeWeek,
                    filter: DeviceActivityFilter(
                        segment: .hourly(during: ScreenTimeReportWindow.currentWeek()),
                        users: .all,
                        devices: .all
                    )
                )
                // A report view is hosted in a separate extension process and has
                // no useful height for this outer ScrollView to infer.
                .frame(height: 320)
            }
            .frame(height: 320)
#endif
        }
        .padding(.top, headerTopInset)
        .padding(.bottom, Theme.Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(
            UnevenRoundedRectangle(bottomLeadingRadius: Theme.Radius.sheet,
                                   bottomTrailingRadius: Theme.Radius.sheet,
                                   style: .continuous)
        )
        // A soft shadow along the bottom edge lifts the slab off the ground.
        // The sides run off-screen, so only the bottom sweep reads.
        .shadow(color: .black.opacity(0.07), radius: 10, y: 5)
    }

    // MARK: - Habits detail







    /// The long arc. Everything else on this screen is one week; this is the
    /// only thing that shows a habit as a habit.
    private var consistencyCard: some View {
        let days = store.journeyDays

        return VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            // 10 x 9 lands on exactly 90, so there's no ragged final row.
            VStack(spacing: Self.gridGap) {
                ForEach(0..<Self.gridRows, id: \.self) { row in
                    HStack(spacing: Self.gridGap) {
                        ForEach(0..<Self.gridColumns, id: \.self) { column in
                            dayDot(index: row * Self.gridColumns + column, days: days)
                        }
                    }
                }
            }

            HStack(spacing: 0) {
                journeyStat("Past90DaysCalendar", "Day \(store.detoxDay) of \(Journey.board)")
                Spacer(minLength: Theme.Spacing.s)
                journeyStat("Past90DaysVerified",
                            "\(store.boardHabitsCompleted) habit\(store.boardHabitsCompleted == 1 ? "" : "s") completed")
            }
        }
        .padding(Theme.Spacing.l)
        // Artwork behind the grid: a subtle overall darken for depth, and a
        // stronger scrim at the foot so the white stats read over the clouds.
        .background {
            ZStack {
                Image("NinetyDayCardBackground")
                    .resizable()
                    .scaledToFill()
                Color.black.opacity(0.12)
                LinearGradient(colors: [.clear, .black.opacity(0.5)],
                               startPoint: .center, endPoint: .bottom)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        // The Apps lane-card depth: soft ambient shadow plus a tighter contact
        // shadow, so the card lifts off the ground and reads as a chunky piece.
        .shadow(color: .black.opacity(0.16), radius: 20, y: 11)
        .shadow(color: .black.opacity(0.10), radius: 4, y: 2)
    }

    /// Kept, missed, or today. Missed days stay neutral rather than going red:
    /// the kept ones carry the story, and red already means scrolling on the
    /// card above this one. No glyph inside — at the size 15 columns leaves, a
    /// checkmark read as speckle.
    @ViewBuilder
    private func dayDot(index: Int, days: [Bool]) -> some View {
        let kept = index < days.count && days[index]

        // Two fills, no third state. Today was marked first with a ring and
        // then with its own colour, and both fought the grid: at 17pt a cell is
        // too small to carry a mark as well as a value, so either treatment
        // reads as one dot that went wrong rather than the one that's now.
        //
        // Nothing marks it, because nothing needs to. Today is the last filled
        // cell of a left-to-right grid, and "Day 79 of 90" sits directly under
        // it — the position and the caption both already say where you are.
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                Image("StreakFlame")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    // Missed / not-yet days keep the flame, desaturated to a
                    // light gray, so the grid reads as a streak that lit or not.
                    .grayscale(kept ? 0 : 1)
                    .opacity(kept ? 1 : 0.4)
            )
    }

    private func journeyStat(_ sticker: String, _ label: String) -> some View {
        HStack(spacing: 6) {
            Image(sticker)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 20, height: 20)
            Text(label)
                .auraFont(.body, RowType.subLabel, .medium)
                .foregroundStyle(.white)
        }
    }

    private static let gridColumns = 10
    private static let gridRows = 9
    private static let gridGap: CGFloat = 4

    /// The six most recent proofs, with the rest behind See all. A strip rather
    /// than a grid: it's a glance at what you've done, not an archive.
    private var wallOfWins: some View {
        // `l` header-to-strip gap, matching the other sections and the Apps screen.
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: RowType.labelGap) {
                    Text("Wall of wins")
                        .auraFont(.display, SheetType.banner, .bold)
                        .foregroundStyle(LightSheet.title)
                    // The empty state below carries the "no wins" message, so the
                    // count and See all only show once there's something to count.
                    if !store.wins.isEmpty {
                        Text("\(store.wins.count) win\(store.wins.count == 1 ? "" : "s") captured")
                            .auraFont(.body, RowType.subLabel, .medium)
                            .foregroundStyle(RowType.subLabelColor)
                    }
                }

                Spacer(minLength: Theme.Spacing.s)

                if !store.wins.isEmpty {
                    Button {
                        Haptics.impact(.light)
                        showWall = true
                    } label: {
                        // `controlIdle` and bold, the same as an unselected segment
                        // in `LightSegmentedPill` — this is the same thing, an idle
                        // label on a pill. It was `title` at 14:1, which is the
                        // colour of the section heading above it, so a secondary
                        // control was shouting as loudly as the thing it sits under.
                        HStack(spacing: RowType.labelGap) {
                            Text("See all")
                                .auraFont(.body, SheetType.cardBlurb, .bold)
                            Image(systemName: "chevron.right")
                                .font(.system(size: RowType.subLabel, weight: .bold))
                        }
                        .foregroundStyle(LightSheet.controlIdle)
                        .padding(.horizontal, Theme.Spacing.m)
                        .frame(height: Theme.Spacing.xxl)
                        .background(Capsule().fill(LightSheet.chromeOnLight))
                    }
                    .buttonStyle(PressBounceStyle())
                }
            }

            if store.wins.isEmpty {
                // The same crying fox as the full sheet, so an empty wall reads
                // the same whether you glance at the strip or open it.
                WinsEmptyState()
                    .padding(.vertical, Theme.Spacing.l)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.s) {
                        ForEach(store.wins.prefix(6)) { win in
                            WinTile(win: win)
                                // 2.5 across: 369 of visible width from the first
                                // tile's edge, less two 8pt gaps.
                                .frame(width: 152)
                        }
                    }
                    // Negated, then re-applied inside, so the strip scrolls to the
                    // screen's edges while staying aligned with the cards above.
                    .padding(.horizontal, Theme.Spacing.xl)
                }
                // Let the tiles' drop shadow render outside the scroll's bounds
                // rather than being clipped into a hard line at the tile edges.
                .scrollClipDisabled()
                .padding(.horizontal, -Theme.Spacing.xl)
            }
        }
    }



    // MARK: - Derived
    //
    // TODO: the store keeps running totals, not a per-day log, so the daily
    // figures below are shaped from today's earnings. The views already want
    // what a real log would give them — only the source changes.






}

private struct StatsLoadingState: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            ProgressView()
                .controlSize(.regular)
                .tint(LightSheet.blue)
            Text("Loading Screen Time…")
                .auraFont(.body, RowType.label, .semibold)
                .foregroundStyle(LightSheet.subtitleDark)
        }
        .frame(maxWidth: .infinity, minHeight: 320)
        .accessibilityLabel("Loading screen-time stats")
    }
}

#Preview {
    StatsView()
        .environment(HabitStore())
}
