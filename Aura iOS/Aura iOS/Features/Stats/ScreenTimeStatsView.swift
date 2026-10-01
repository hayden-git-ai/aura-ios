//
//  ScreenTimeStatsView.swift
//  Aura iOS
//

import FamilyControls
import SwiftUI

/// Both summaries' colours, in one place.
///
/// They were drawn for the white top card and now run straight on the blue
/// field, so every value has two readings. Kept as a type rather than a pile of
/// ternaries at the call sites — the two summaries are the same construction
/// twice over, and a palette that lives in one of them would drift.
struct SummaryPalette {
    let onBlue: Bool

    var headline: Color { onBlue ? .white : LightSheet.title }
    /// Solid on blue: at 0.7 this was 2.22:1, and the panel can't carry
    /// translucent small text at all. It's still secondary — it's 14pt under a
    /// 34pt figure, which is where the hierarchy was coming from anyway.
    var caption: Color { onBlue ? .white : LightSheet.controlIdle }

    var dayLetter: Color { onBlue ? .white : LightSheet.title }
    /// Future days are a disabled control, which WCAG exempts from contrast —
    /// the one place on this card translucent white survives the audit.
    var dayFuture: Color { onBlue ? .white.opacity(0.35) : LightSheet.subtitle }
    var dateIdle: Color { onBlue ? .white : LightSheet.controlIdle }
    /// Inverted on blue: a blue disc would vanish into the field, so the
    /// selected day goes white and its number takes the field's colour.
    var dateSelected: Color { onBlue ? LightSheet.blue : .white }
    var dateSelectedFill: Color { onBlue ? .white : LightSheet.blue }
    var dateTrack: Color { onBlue ? .white.opacity(0.14) : LightSheet.track }

    var barFill: Color { onBlue ? .white : LightSheet.blue }
    /// 0.55, up from 0.3 — an unselected bar is a control's track, which needs
    /// 3:1 against the panel, and 0.3 measured 1.42.
    var barTrack: Color { onBlue ? .white.opacity(0.55) : LightSheet.track }
    var barLabel: Color { onBlue ? .white : LightSheet.title }
    /// Solid, like every other label here. On this panel white text tops out at
    /// 4.80:1, so the usable band above 4.5 is only the last few percent of
    /// alpha — any translucency at all fails. Selection is carried by the solid
    /// bar and the white date disc, which it always was; the alpha was
    /// decoration on top of a cue that already worked.
    var barLabelIdle: Color { onBlue ? .white : LightSheet.subtitle }
    var averageLine: Color { onBlue ? .white.opacity(0.7) : LightSheet.subtitle.opacity(0.35) }

    /// The chart's floor. Translucent, not solid — a white slab here would
    /// rebuild the card this screen just lost and fight the dome below it.
    ///
    /// Dark, not light. At `white 12%` the card sat *lighter* than the field
    /// it's on (#3F94FF), which capped white text at 3.03:1 — the ceiling for
    /// anything drawn on it, since white is as light as it gets. Tinting down
    /// instead puts it at #1F70D6: white clears AA at 4.80:1, and the card
    /// reads more like a card, not less (1.36:1 against the field, up from
    /// 1.17) — a recess in the colour rather than a lighter smudge on it.
    var panelFill: Color { onBlue ? LightSheet.panelOnColour : .white }
    /// Behind the trend line, which reads as a chip rather than a caption.
    /// Tinted down for the same reason as the panel: lightening it dropped the
    /// white text on it to 2.58:1, darkening lifts it to 6.10.
    var pillFill: Color { onBlue ? LightSheet.surfaceOnColour : .black.opacity(0.05) }
    /// The stat row's tracked caps. Quiet — the figure under it carries the row
    /// — but quiet by size and tracking now, not by alpha.
    var statLabel: Color { onBlue ? .white : LightSheet.subtitle }
}

/// The three ranked lists on Stats — Your favorite quests, Most used, Pickups
/// by app — are one row shape in three places, so the numbers live here.
enum StatsRow {
    /// Between cards. Does the job the dividers used to.
    ///
    /// Was `s + 2`, which is 10 — a step invented to sit between two tokens,
    /// and off the four-grid. It's the token now.
    static let gap = Theme.Spacing.m
}

extension View {
    func statsRowCard() -> some View {
        padding(Theme.Spacing.m)
            .bottomDropCard(radius: Theme.Radius.card)
    }
}

/// One labelled figure in the stat row: small tracked caps over a value.
/// Shared so the two modes' rows line up column for column.
struct SummaryStat<Content: View>: View {
    let label: String
    let palette: SummaryPalette
    @ViewBuilder var content: Content

    var body: some View {
        // Centred in an equal share of the row, so three columns of different
        // content widths still read as evenly spaced.
        VStack(spacing: RowType.labelGap) {
            // Sentence case: tracked caps aren't in the app's vocabulary
            // anywhere else, and size and colour already do the receding.
            Text(label)
                .auraFont(.body, RowType.subLabel, .medium)
                .foregroundStyle(palette.statLabel)
                .lineLimit(1)
            content
        }
        .frame(maxWidth: .infinity)
    }
}

/// The numeric case, which is two of the three columns in both modes.
struct SummaryStatValue: View {
    let value: Int
    let palette: SummaryPalette

    var body: some View {
        Text("\(value)")
            .auraFont(.body, SheetType.cardTitle, .bold)
            .foregroundStyle(palette.headline)
            .monospacedDigit()
            .contentTransition(.numericText())
    }
}

/// The week chart's proportions, shared so the two summaries can't drift.
enum SummaryChart {
    static let barMax: CGFloat = 84
    static let barWidth: CGFloat = 14
    /// A capsule shorter than it is wide reads as a squashed blob, so an empty
    /// day bottoms out at a dot instead.
    static let barMin: CGFloat = 14
    static let barGap: CGFloat = 8
    /// Weekday letter over the date disc. The chart's labels *are* the calendar
    /// now — the separate strip of circles said the same week twice.
    static let labelBlock: CGFloat = 44
    static let panelRadius: CGFloat = 28
    /// An app icon's artwork. `appIconChrome` grows its keyline outward from
    /// here, so what lands on screen is `statIconTotal`.
    static let statIcon: CGFloat = 15
    /// What an app icon actually measures once its chrome is on: the keyline
    /// adds 0.1 of the side to each edge. Habit stickers carry no chrome, so
    /// they're framed at this instead — framing both at `statIcon` is what made
    /// the app icons come out a fifth bigger than the habits.
    static let statIconTotal: CGFloat = statIcon * 1.2
    /// Habit stickers are drawn with transparent margin baked into the PNG —
    /// the art fills 65–88% of its canvas depending on the sticker, where an
    /// app icon fills 100%. At an equal frame the sticker reads a third
    /// smaller, so it gets scaled up to roughly match. Rough, because the trim
    /// varies per asset: the exact fix is cropping the canvases.
    static let statStickerScale: CGFloat = 1.3
    /// The value's line box. The icon columns match it so all three columns
    /// come to the same height.
    static let statValueHeight: CGFloat = 22
    /// The day's headline figure. One role, drawn in both summaries — the two
    /// modes carried it as a literal each.
    static let figure: CGFloat = 34
    /// The average rule, wherever it's drawn: the week chart's horizontal line
    /// and the cumulative chart's typical day. It was a literal in two places
    /// and about to become a third.
    static let averageWidth: CGFloat = 1.5
    static let averageDash: [CGFloat] = [5, 4]
    static let panelPadding = Theme.Spacing.l + 4
    /// Readout block to chart, inside the card.
    static let readoutToChart = Theme.Spacing.xl

    static var height: CGFloat { barMax + barGap + labelBlock }
}

/// The Screen Time half of Stats: how the phone actually got used. Day strip,
/// the day's total, the week beside it, an hourly shape, then the apps behind
/// it — ranked by time, then by pickups, since those tell different stories.
/// The part that lives inside the top card: day strip, the day's total, the
/// week, and the trend. Split from the detail below so the mode switch can
/// slide the two halves independently while the header stays put.
struct ScreenTimeSummary: View {
    /// Passed in, not fetched. A view that builds its own data can never be
    /// handed the report extension's — and the extension is the only place
    /// Apple's numbers exist.
    let week: [ScreenTimeDay]
    @Binding var selected: Int
    /// Painted for the blue field rather than the white card it used to sit in.
    var onBlue: Bool = false
    /// Drops the card's own background so the content sits flush on a surface the
    /// caller provides — the full-bleed white top slab on Stats.
    var plain: Bool = false

    private var c: SummaryPalette { .init(onBlue: onBlue) }
    private var day: ScreenTimeDay { week[min(selected, week.count - 1)] }

    var body: some View {
        // One card holding the lot. Sizes itself — both modes are the same
        // construction with the same-height readout, so they already come to
        // the same height without a fixed frame forcing it.
        VStack(spacing: SummaryChart.readoutToChart) {
            totalReadout
            statRow
            weekChart
        }
        .padding(SummaryChart.panelPadding)
        .frame(maxWidth: .infinity)
        .background {
            if !plain {
                RoundedRectangle(cornerRadius: SummaryChart.panelRadius, style: .continuous)
                    .fill(c.panelFill)
            }
        }
    }

    private func section(_ title: String) -> some View {
        Text(title)
            .auraFont(.display, 17, .bold)
            .foregroundStyle(LightSheet.title)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, -Theme.Spacing.s)
    }

    // MARK: - Total + week

    /// Mean across days that have actually happened — including the empty
    /// future ones would drag it down and make every past day look heavy.
    private var average: Int {
        let logged = week.map(\.totalMinutes).filter { $0 > 0 }
        guard !logged.isEmpty else { return 0 }
        return logged.reduce(0, +) / logged.count
    }

    private var statRow: some View {
        let ranked = day.apps.sorted { $0.minutes > $1.minutes }

        return HStack(alignment: .top, spacing: Theme.Spacing.s) {
            SummaryStat(label: "Most used", palette: c) {
                HStack(spacing: RowType.labelGap) {
                    ForEach(Array(ranked.prefix(3).enumerated()), id: \.offset) { _, app in
                        UsageIcon(app: app, side: SummaryChart.statIcon)
                            .appIconChrome(side: SummaryChart.statIcon)
                    }
                }
                // Matches the numeric columns' cap height, so the three
                // baselines agree.
                .frame(height: SummaryChart.statValueHeight)
            }
            SummaryStat(label: "Apps", palette: c) {
                SummaryStatValue(value: day.apps.count, palette: c)
            }
            SummaryStat(label: "Pickups", palette: c) {
                SummaryStatValue(value: day.apps.reduce(0) { $0 + $1.pickups }, palette: c)
            }
        }
    }

    private var weekTotal: Int { week.reduce(0) { $0 + $1.totalMinutes } }
    private var previousWeek: Int { ScreenTimeSample.previousWeekTotal(week) }

    private var weekChart: some View {
        let peak = max(1, week.map(\.totalMinutes).max() ?? 1)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        return ZStack(alignment: .bottom) {
            HStack(alignment: .bottom, spacing: Theme.Spacing.s) {
                ForEach(Array(week.enumerated()), id: \.offset) { index, entry in
                    let isFuture = entry.date > today
                    let isSelected = index == selected

                    // The bar is the day picker now, so the tap target is the
                    // whole column rather than a 38pt circle above it.
                    Button {
                        guard !isFuture else { return }
                        Haptics.selection()
                        withAnimation(.snappy(duration: 0.2)) { selected = index }
                    } label: {
                        VStack(spacing: SummaryChart.barGap) {
                            Capsule()
                            .fill(isSelected ? c.barFill : c.barTrack)
                            .frame(width: SummaryChart.barWidth)
                            .frame(height: max(SummaryChart.barMin, SummaryChart.barMax * CGFloat(entry.totalMinutes) / CGFloat(peak)))
                            .frame(maxHeight: SummaryChart.barMax, alignment: .bottom)

                            VStack(spacing: RowType.labelGap) {
                                Text(calendar.shortWeekdaySymbols[index])
                                    .auraFont(.body, RowType.subLabel, .bold)
                                    .foregroundStyle(isFuture ? c.dayFuture
                                                     : isSelected ? c.dayLetter : c.barLabelIdle)
                                Text("\(calendar.component(.day, from: entry.date))")
                                    .auraFont(.body, RowType.label, .semibold)
                                    .foregroundStyle(isSelected ? c.dateSelected
                                                     : isFuture ? c.dayFuture : c.dateIdle)
                                    .frame(width: 26, height: 26)
                                    .background(Circle().fill(isSelected ? c.dateSelectedFill : .clear))
                            }
                            .frame(height: SummaryChart.labelBlock, alignment: .top)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .disabled(isFuture)
                }
            }

            // Daily average, so a day reads as above or below normal rather
            // than just tall or short.
            if average > 0 {
                DashedLine()
                    .stroke(style: StrokeStyle(lineWidth: SummaryChart.averageWidth,
                                               dash: SummaryChart.averageDash))
                    .foregroundStyle(c.averageLine)
                    .frame(height: 1)
                    .padding(.bottom, SummaryChart.labelBlock + SummaryChart.barGap
                             + SummaryChart.barMax * CGFloat(average) / CGFloat(peak))
            }
        }
        .frame(height: SummaryChart.height, alignment: .bottom)
    }

    private var totalReadout: some View {
        VStack(spacing: 4) {
            Group {
                Text(ScreenTimeSample.durationLabel(day.totalMinutes))
                    .auraFont(.body, SummaryChart.figure, .bold)
                    .foregroundStyle(c.headline)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(dateLabel)
                    .auraFont(.body, SheetType.subtitle, .medium)
                    .foregroundStyle(c.caption)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        let full = formatter.string(from: day.date)
        guard Calendar.current.isDateInToday(day.date) else { return full }
        return "Today, " + (full.split(separator: ", ").last.map(String.init) ?? full)
    }

}

/// The Daily Habits summary: identical construction to `ScreenTimeSummary` so
/// the toggle reads as two views of one thing, but counting coins earned. Up is
/// the win here, which is the one behavioural difference.
struct ScreenTimeDetail: View {
    let week: [ScreenTimeDay]
    let selected: Int
    /// The user's own App Lists, resolved by the caller. Passed as plain icon
    /// names rather than reached for through `HabitStore`: these views have to
    /// compile inside the report extension, which has no store in it.
    let brainrotIcons: Set<String>

    private var day: ScreenTimeDay { week[min(selected, week.count - 1)] }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            section("Hourly Breakdown")
            hourlyBreakdownCard
            section("Compared to a typical day")
            cumulativeCard
            section("Most used")
            appList(week: day.apps.sorted { $0.minutes > $1.minutes },
                    value: { ScreenTimeSample.durationLabel($0.minutes) })
            section("Pickups by app")
            appList(week: day.apps.sorted { $0.pickups > $1.pickups },
                    value: { "\($0.pickups)" })
        }
    }

    /// Dark: these sit on the light surface below the blue band.
    private func section(_ title: String) -> some View {
        Text(title)
            .auraFont(.display, 17, .bold)
            .foregroundStyle(LightSheet.title)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, -Theme.Spacing.s)
    }

    // The three bands, in the reference's colours.
    private static let otherColor = Color(hex: "2586FF")
    private static let socialColor = Color(hex: "7DB8FF")
    private static let gamesColor = Color(hex: "FF6B03")

    /// 24 stacked bars — one per hour, split social / games / other — with a
    /// dot where an hour has no usage, then the three category totals.
    private var hourlyBreakdownCard: some View {
        let bands = day.hourlyBands
        let peak = max(1, bands.map(\.total).max() ?? 1)

        return VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            GeometryReader { proxy in
                let h = proxy.size.height
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(0..<24, id: \.self) { hour in
                        let b = bands[hour]
                        Group {
                            if b.total == 0 {
                                Circle()
                                    .fill(LightSheet.track)
                                    .frame(width: 5, height: 5)
                            } else {
                                VStack(spacing: 0) {
                                    Rectangle().fill(Self.gamesColor)
                                        .frame(height: h * CGFloat(b.games) / CGFloat(peak))
                                    Rectangle().fill(Self.socialColor)
                                        .frame(height: h * CGFloat(b.social) / CGFloat(peak))
                                    Rectangle().fill(Self.otherColor)
                                        .frame(height: h * CGFloat(b.other) / CGFloat(peak))
                                }
                                .frame(width: 8)
                                .clipShape(Capsule())
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .frame(height: 150)

            // Just the quarter marks.
            HStack(spacing: 0) {
                ForEach(Array(["12 AM", "6 AM", "12 PM", "6 PM"].enumerated()), id: \.offset) { i, label in
                    if i > 0 { Spacer(minLength: 0) }
                    Text(label)
                        .auraFont(.body, 11, .medium)
                        .foregroundStyle(RowType.subLabelColor)
                }
            }

            // The day's category totals, in the same colours as the bars.
            HStack(alignment: .top, spacing: Theme.Spacing.xl) {
                breakdownKey("Other", day.otherMinutes, Self.otherColor)
                breakdownKey("Social Media", day.socialMinutes, Self.socialColor)
                breakdownKey("Games", day.gamesMinutes, Self.gamesColor)
                Spacer(minLength: 0)
            }
        }
        .padding(Theme.Spacing.l)
        .bottomDropCard(radius: Theme.Radius.card)
    }

    private func breakdownKey(_ title: String, _ minutes: Int, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: RowType.labelGap) {
            Text(title)
                .auraFont(.body, RowType.subLabel, .semibold)
                .foregroundStyle(color)
            Text(ScreenTimeSample.durationLabel(minutes))
                .auraFont(.body, RowType.label, .medium)
                .foregroundStyle(RowType.subLabelColor)
        }
    }

    /// The two keys above the cumulative chart — smaller label, big bold value.
    private func comparedKey(_ title: String, _ minutes: Int,
                             dot: Color, valueColor: Color) -> some View {
        VStack(alignment: .leading, spacing: RowType.labelGap) {
            HStack(spacing: RowType.labelGap) {
                Circle().fill(dot).frame(width: 8, height: 8)
                Text(title)
                    .auraFont(.body, 11, .medium)
                    .foregroundStyle(RowType.subLabelColor)
            }
            Text(ScreenTimeSample.durationLabel(minutes))
                .auraFont(.display, SheetType.title, .heavy)
                .foregroundStyle(valueColor)
        }
    }

    // MARK: - Cumulative

    /// This day's running total against a typical day's, midnight to midnight.
    ///
    /// Replaced a row of 24 per-hour bars. Those were 5pt wide with no baseline
    /// to read against — you couldn't tell a 40-minute hour from a 55-minute
    /// one, and nothing on the card said whether any of it was unusual. A pair
    /// of running totals answers the question the card is actually for: how much
    /// so far, versus normal. It's also the only thing on this screen that moves
    /// during the day, which is the only reason to open Stats before bedtime.
    private var cumulativeCard: some View {
        let dayRun = Self.running(day.hourly)
        let typicalRun = Self.running(Self.typicalHourly(week))
        // A tenth of headroom. Scaled to the bare maximum, the winning line ran
        // into the top edge and read as clipped rather than as the top of a
        // climb.
        let peak = max(1, Int(Double(max(dayRun.last ?? 0, typicalRun.last ?? 0)) * 1.1))
        // Only draw this day's line as far as it has actually happened. A
        // finished day runs the full width; today stops at the current hour, so
        // the line ends where you are rather than flattening to the right edge.
        let cutoff = isSelectionToday ? min(24, Calendar.current.component(.hour, from: .now) + 1) : 24

        return VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            // `cardBlurb`, not `cardTitle`. `cardTitle` is 15 and so is
            // `sectionHeader`, so filing this as a card title put two 15s in
            // the same colour directly on top of each other and the header and
            // the sentence read as one block. The separation comes from
            // dropping a rung, not from adding one — the 21 the banners use is
            // for a statement sitting on the field, and nothing inside a card
            // in this app goes above 15.
            Text(Self.verdict(day: dayRun[cutoff], typical: typicalRun[cutoff],
                              isToday: isSelectionToday))
                .auraFont(.body, 16, .semibold)
                .foregroundStyle(SheetType.titleColor)
                .fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(LightSheet.divider)
                .frame(height: 1)

            // Both read at the same hour. An average measured to midnight
            // against a day measured to 8pm isn't a comparison, it's a
            // head start.
            HStack(alignment: .top, spacing: Theme.Spacing.xl) {
                comparedKey(isSelectionToday ? "Today" : Self.weekdayName(day.date),
                            dayRun[cutoff], dot: LightSheet.blue, valueColor: LightSheet.blue)
                comparedKey("Average", typicalRun[cutoff],
                            dot: LightSheet.badge, valueColor: LightSheet.title)
                Spacer(minLength: 0)
            }

            GeometryReader { proxy in
                let w = proxy.size.width
                let h = proxy.size.height

                let size = CGSize(width: w, height: h)

                ZStack {
                    // The typical day sits under this one and reads as the
                    // ground the other line is measured against — thinner, not
                    // paler. A lighter grey would have dropped under 3:1 on the
                    // card, and weight separates them just as well.
                    // A solid, lighter line — the ground the day is measured
                    // against, quieter than the day's own line.
                    Self.line(typicalRun, upTo: 24, in: size, peak: peak)
                        .stroke(LightSheet.badge,
                                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    Self.line(dayRun, upTo: cutoff, in: size, peak: peak)
                        .stroke(LightSheet.blue,
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                    // Where you are right now.
                    Image("StatsTypicalDay")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 26, height: 26)
                        .position(Self.point(dayRun, at: cutoff, in: size, peak: peak))
                }
            }
            .frame(height: 168)

            // Just the ends. Interior ticks were labelling a bar chart's
            // buckets; a line only needs to say where the day starts and stops.
            HStack(spacing: 0) {
                Text("12 AM")
                Spacer(minLength: 0)
                Text("11 PM")
            }
            .auraFont(.body, 11, .medium)
            .foregroundStyle(RowType.subLabelColor)
        }
        .padding(Theme.Spacing.l)
        .bottomDropCard(radius: Theme.Radius.card)
    }

    private var isSelectionToday: Bool {
        Calendar.current.isDateInToday(day.date)
    }

    /// The card's headline — the reading, not the data. "More or less than
    /// usual" is the only thing a running total is for; leaving the user to
    /// infer it from two lines is making them do the card's job.
    ///
    /// The verdict word is picked out the way the Stats banners pick out their
    /// figure, and in this screen's own colours: blue is productive, `danger` is
    /// distracted, on the peak keys and the split bar alike. A whole sentence at
    /// one weight makes you read all of it to learn one bit.
    ///
    /// `AttributedString` rather than `Text + Text`: concatenation only works on
    /// `Text`, which rules out the font modifier, and the `+` operator is
    /// deprecated in iOS 26 — the banners still carry those warnings.
    private static func verdict(day: Int, typical: Int, isToday: Bool) -> AttributedString {
        // A finished day is a whole day, so "by this point" would be nonsense
        // on anything but today.
        let tail = isToday ? " by this point" : ""
        let word = day > typical ? "more" : (day < typical ? "less" : "about as much")
        // "more/less than", but "about as much as".
        let connector = day == typical ? "as" : "than"
        var sentence = AttributedString("You're using your phone \(word) \(connector) you usually do\(tail).")

        // The equal case is a non-event; nothing to call out in it.
        guard day != typical, let range = sentence.range(of: word) else { return sentence }
        sentence[range].foregroundColor = day > typical ? LightSheet.danger : LightSheet.blue
        sentence[range].font = Typography.body(size: SheetType.cardBlurb, weight: .bold)
        return sentence
    }

    private static func weekdayName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    /// Minutes accumulated by the end of each hour — 25 points, starting at
    /// midnight's zero so the line begins on the axis rather than above it.
    private static func running(_ hourly: [Int]) -> [Int] {
        var out = [0]
        var total = 0
        for minutes in hourly {
            total += minutes
            out.append(total)
        }
        return out
    }

    /// A typical day's shape: the mean minutes in each hour across the days that
    /// have actually happened.
    ///
    /// Future days are all-zero in the sample, and averaging those in would drag
    /// a typical day down by however far through the week you are — on a Monday
    /// it would read as a seventh of the truth.
    private static func typicalHourly(_ week: [ScreenTimeDay]) -> [Int] {
        let today = Calendar.current.startOfDay(for: .now)
        let elapsed = week.filter { $0.date <= today }
        guard !elapsed.isEmpty else { return Array(repeating: 0, count: 24) }
        return (0..<24).map { hour in
            elapsed.reduce(0) { $0 + $1.hourly[hour] } / elapsed.count
        }
    }

    private static func point(_ values: [Int], at index: Int,
                              in size: CGSize, peak: Int) -> CGPoint {
        CGPoint(
            x: size.width * CGFloat(index) / 24,
            y: size.height - size.height * CGFloat(values[index]) / CGFloat(peak)
        )
    }

    private static func line(_ values: [Int], upTo cutoff: Int,
                             in size: CGSize, peak: Int) -> Path {
        curve(through: (0...cutoff).map { point(values, at: $0, in: size, peak: peak) })
    }

    /// A quadratic through the midpoints of each pair — the mild smoothing a
    /// chart like this expects.
    ///
    /// Straight segments between 24 hourly readings visibly kink in the evening,
    /// where usage climbs fastest. Quadratics through midpoints round that off
    /// without inventing shape: the curve is bounded by the points it sits
    /// between, so it can't overshoot into a peak that never happened the way a
    /// Catmull-Rom spline can.
    private static func curve(through points: [CGPoint]) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            guard points.count > 2 else {
                points.dropFirst().forEach { path.addLine(to: $0) }
                return
            }
            for index in 1..<(points.count - 1) {
                let next = points[index + 1]
                let middle = CGPoint(x: (points[index].x + next.x) / 2,
                                     y: (points[index].y + next.y) / 2)
                path.addQuadCurve(to: middle, control: points[index])
            }
            path.addQuadCurve(to: points[points.count - 1],
                              control: points[points.count - 2])
        }
    }

    // MARK: - App lists

    /// A card per row rather than one card of rows. The gap between cards does
    /// what the dividers were doing, so they're gone.
    private func appList(week apps: [AppUsage], value: @escaping (AppUsage) -> String) -> some View {
        VStack(spacing: StatsRow.gap) {
            ForEach(apps) { app in
                HStack(spacing: Theme.Spacing.m) {
                    UsageIcon(app: app, side: 24)
                        // Defaults rather than a fixed 3: the keyline and edge
                        // scale with the icon instead of getting heavier as it
                        // shrinks.
                        .appIconChrome(side: 24)

                    VStack(alignment: .leading, spacing: RowType.labelGap) {
                        Text(app.name)
                            .auraFont(.body, RowType.label, .semibold)
                            .foregroundStyle(RowType.labelColor)
                        Text(app.category)
                            .auraFont(.body, RowType.subLabel, .medium)
                            .foregroundStyle(LightSheet.subtitle)
                    }

                    Spacer(minLength: Theme.Spacing.s)

                    Text(value(app))
                        .auraFont(.body, RowType.value, .medium)
                        .foregroundStyle(RowType.valueColor)
                }
                .statsRowCard()
            }
        }
    }
}

/// A single horizontal rule, for stroking with a dash pattern.
/// Shared by both summary charts, which now live in separate files.
struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

/// An app's icon in the usage charts.
///
/// Real results carry a token and no artwork of our own — the system draws
/// those. The sample data carries an asset name and no token. One view so the
/// charts don't have to know which world they're in.
struct UsageIcon: View {
    let app: AppUsage
    let side: CGFloat

    var body: some View {
        if let token = app.token {
            UsageAppStoreArtworkView(bundleIdentifier: app.icon, side: side) {
                Label(token)
                    .labelStyle(.iconOnly)
                    .frame(width: 20, height: 20)
                    .scaleEffect(side / 20)
                    .frame(width: side, height: side)
                    .clipped()
            }
        } else {
            Image(app.icon)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: side, height: side)
        }
    }
}

private struct UsageAppStoreArtworkView<Fallback: View>: View {
    let bundleIdentifier: String
    let side: CGFloat
    @ViewBuilder let fallback: () -> Fallback

    @State private var artworkURL: URL?

    var body: some View {
        Group {
            if let artworkURL {
                AsyncImage(url: artworkURL, transaction: Transaction(animation: nil)) { phase in
                    if case .success(let image) = phase {
                        image.resizable().interpolation(.high).scaledToFit()
                    } else {
                        fallback()
                    }
                }
            } else {
                fallback()
            }
        }
        .frame(width: side, height: side)
        .task(id: bundleIdentifier) {
            artworkURL = await UsageAppStoreArtworkResolver.shared.artworkURL(for: bundleIdentifier)
        }
    }
}

private actor UsageAppStoreArtworkResolver {
    static let shared = UsageAppStoreArtworkResolver()
    private var cache: [String: URL] = [:]

    func artworkURL(for bundleIdentifier: String) async -> URL? {
        if let cached = cache[bundleIdentifier] { return cached }
        var components = URLComponents(string: "https://itunes.apple.com/lookup")
        components?.queryItems = [
            URLQueryItem(name: "bundleId", value: bundleIdentifier),
            URLQueryItem(name: "country", value: Locale.current.region?.identifier ?? "US"),
            URLQueryItem(name: "limit", value: "1")
        ]
        guard let url = components?.url,
              let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let result = try? JSONDecoder().decode(UsageAppStoreLookupResponse.self, from: data),
              let artworkURL = result.results.first?.artworkURL else {
            return nil
        }
        cache[bundleIdentifier] = artworkURL
        return artworkURL
    }
}

private struct UsageAppStoreLookupResponse: Decodable {
    struct Result: Decodable {
        let artworkUrl512: URL?
        let artworkUrl100: URL?

        var artworkURL: URL? {
            artworkUrl512 ?? artworkUrl100.flatMap { url in
                URL(string: url.absoluteString.replacingOccurrences(of: "100x100", with: "512x512"))
            }
        }
    }

    let results: [Result]
}
