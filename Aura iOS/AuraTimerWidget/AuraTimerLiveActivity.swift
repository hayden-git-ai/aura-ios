//
//  AuraTimerLiveActivity.swift
//  AuraTimerWidget
//
//  Belongs to the widget extension target. `AuraTimerAttributes.swift` must be
//  a member of BOTH this target and the app.
//

import ActivityKit
import SwiftUI
import WidgetKit

struct AuraTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AuraTimerAttributes.self) { context in
            LockScreenBanner(state: context.state)
                // The card takes the timer's own colour, the way the reference
                // gives the whole banner over to its mascot's world. In
                // always-on the banner paints its own dark ground over this.
                .activityBackgroundTint(Self.accent)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Fox left, clock right, the label and its bar underneath —
                // the expanded Island is a wide, short canvas, so anything
                // stacked in the leading region gets squeezed.
                DynamicIslandExpandedRegion(.leading) {
                    Self.mascot(52, state: context.state)
                        .padding(.leading, Self.gutter)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Self.countdown(context.state)
                        .font(WidgetType.display(size: 32, weight: 700))
                        // The trailing region is only about a third of the
                        // Island and the system won't shrink a countdown to
                        // fit — it truncates it, which on a clock loses the
                        // one part that matters.
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, Self.gutter)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(context.state.title)
                            .font(WidgetType.label(size: 13, weight: 700))
                            .foregroundStyle(.white)

                        Self.bar(context.state, fill: Self.accent, track: Self.track, height: 9)
                    }
                    .padding(.horizontal, Self.gutter)
                    .padding(.top, 2)
                    .padding(.bottom, 4)
                }
            } compactLeading: {
                Self.mascot(26, state: context.state)
                    .padding(.leading, 3)
            } compactTrailing: {
                Self.countdown(context.state)
                    .font(WidgetType.display(size: 16, weight: 700))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(.white)
                    // The compact slot is narrow and a countdown is the widest
                    // thing that can sit in it; without a cap the system
                    // truncates it rather than shrinking it. h:mm:ss needs
                    // the wider cap or it gets squeezed down to nothing.
                    .frame(maxWidth: context.state.showsHours ? 74 : 54)
            } minimal: {
                Self.mascot(20, state: context.state)
            }
        }
    }

    /// How far through it is. Paused freezes at whatever fraction it stopped
    /// on, and an open-ended session has no bar at all — nothing to fill
    /// towards.
    ///
    /// Everything visible here is drawn locally; the only thing taken from the
    /// system is *where the fill ends*. That's the one part that can't be
    /// drawn, because only the built-in linear style gets a live fill — a
    /// custom `ProgressViewStyle` renders once and then sits frozen. So the
    /// native bar is tinted white, stretched to cover the whole capsule, and
    /// used purely as a mask: fill becomes opaque, its own track becomes
    /// nothing. Track colour, thickness, stroke and shape are then all ours.
    @ViewBuilder
    static func bar(_ state: AuraTimerAttributes.ContentState, fill: Color, track: Color, height: CGFloat) -> some View {
        if let endsAt = state.endsAt {
            Capsule()
                .fill(track)
                .overlay {
                    Capsule()
                        .fill(fill)
                        .mask { Self.fillExtent(state, endsAt: endsAt) }
                }
                .overlay(Capsule().strokeBorder(.white.opacity(0.9), lineWidth: 1.5))
                .frame(height: height)
        }
    }

    /// The mask: a white-tinted native bar crushed to pure black and white so
    /// `luminanceToAlpha` reads as filled or not filled with nothing in
    /// between, then stretched vertically to cover whatever height the capsule
    /// is.
    static func fillExtent(_ state: AuraTimerAttributes.ContentState, endsAt: Date) -> some View {
        Group {
            if let paused = state.pausedRemaining {
                let total = max(1, endsAt.timeIntervalSince(state.startedAt))
                ProgressView(value: max(0, total - Double(paused)), total: total)
            } else {
                // Empty labels rather than `.labelsHidden()`: the interval
                // style prints its own countdown above the bar, which would be
                // a second clock on the same card, and it's the initialiser
                // that takes it away.
                ProgressView(timerInterval: state.startedAt...endsAt, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
            }
        }
        .progressViewStyle(.linear)
        .tint(.white)
        // Opaque black behind it first: the style's own track is the tint at
        // 50% alpha, and alpha survives `luminanceToAlpha` untouched. Against
        // black it becomes a mid grey instead, which can be crushed — but 0.5
        // is exactly the contrast pivot, so it has to be darkened off the pivot
        // before the crush. Track 0.5 -> 0.35 -> 0, fill 1.0 -> 0.85 -> 1.
        .background(Color.black)
        .brightness(-0.15)
        .contrast(20)
        .luminanceToAlpha()
        .scaleEffect(y: 30, anchor: .center)
    }

    /// A live countdown the widget renders itself.
    ///
    /// `Text(timerInterval:)` ticks without the app sending anything, which is
    /// the only workable approach: ActivityKit budgets updates aggressively, and
    /// one a second would be throttled long before the timer ran out.
    ///
    /// Paused is the exception — a stopped clock can't be expressed as an
    /// interval, so it renders as a fixed figure and costs one update each way.
    @ViewBuilder
    static func countdown(_ state: AuraTimerAttributes.ContentState) -> some View {
        if let paused = state.pausedRemaining {
            Text(Self.clock(paused))
        } else if let endsAt = state.endsAt {
            Text(timerInterval: Date.now...endsAt, countsDown: true)
        } else {
            // Extreme Focus: counting up, so the range is anchored at the start
            // and runs far enough ahead that it can't be reached. Nobody sits
            // in a focus session for a day, and if they somehow do, it stops
            // there rather than misreporting.
            Text(timerInterval: state.startedAt...state.startedAt.addingTimeInterval(86_400),
                 countsDown: false)
        }
    }

    private static func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    /// Aura's app icon, cornered like one.
    ///
    /// From this target's own asset catalogue — a widget extension can't see
    /// the app's, so the imageset is duplicated into
    /// `AuraTimerWidget/Assets.xcassets`.
    ///
    /// The radius is 22.37% of the side, which is the proportion iOS uses for
    /// home-screen icons. A `.continuous` corner is the closest SwiftUI gets to
    /// the squircle the system actually draws; at these sizes the difference
    /// isn't visible, but the ratio has to be right or it reads as a rounded
    /// square sitting next to real app icons rather than as one of them.
    @ViewBuilder
    static func mascot(_ side: CGFloat, state: AuraTimerAttributes.ContentState) -> some View {
        if state.kind == .scrolling {
            // Rented screen time shows the Stats screen-time fox, not the app
            // icon — the same mascot that heads the Screen Time view.
            Image("StatsScreenTime")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: side, height: side)
        } else {
            Image("AuraAppIcon")
                .resizable()
                .scaledToFill()
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: side * 0.2237, style: .continuous))
        }
    }

    /// Grey, not white: the label is the caption under the number, and at
    /// full white it competed with it.
    private static let label = Color(white: 0.68)

    /// The unfilled part of the bar. Light rather than the system's own dark
    /// track, so the bar reads as a full-length shape with part of it filled
    /// instead of a short bar floating in the dark.
    static let track = Color(white: 0.82)

    static let barHeight: CGFloat = 14

    /// A hair past the numeral, which at 40pt Montserrat Black measures about
    /// 125pt for mm:ss and roughly 175pt once an hours digit appears.
    ///
    /// Set from the run's length rather than measured off the clock, because it
    /// can't be measured: a `Text(timerInterval:)` claims a frame sized for the
    /// widest reading it might ever show, not for the glyphs on screen, so
    /// anything derived from it comes back roughly 100pt too wide. `.fixedSize`
    /// doesn't help either — any fixed sizing around one of these renders the
    /// whole Live Activity as an empty card.
    static func barWidth(_ state: AuraTimerAttributes.ContentState) -> CGFloat {
        state.showsHours ? 195 : 145
    }

    /// One gutter for all four elements — fox, clock, label, bar — so they
    /// share a margin instead of each sitting at its own.
    ///
    /// Set by the clock, which is the one element that can't be pushed any
    /// further out. Measured off a real expanded Island: each region carries
    /// its own system inset, and they aren't equal — the leading region stops
    /// the fox at 13pt from the edge, the bottom region stops the bar at 17pt,
    /// but the trailing region stops the clock at 28.4pt no matter how hard
    /// it's pushed. So 28.4 is the tightest margin all four can share, and
    /// this is the padding that lands them there.
    ///
    /// The bar alone could sit another 11pt out — the corner curve only eats
    /// 7.3pt at the height its ends occupy — but not without breaking the
    /// alignment with the clock above it.
    private static let gutter: CGFloat = 7

    /// One colour for every state. The kind is already said in words on the
    /// card, so the background doesn't need to say it again in a second
    /// language — and three accents made the set look like three apps.
    static let accent = Color(red: 0.145, green: 0.525, blue: 1)   // Aura blue

}

/// The Lock Screen banner, which is also what every iPhone without an Island
/// gets — so it carries the whole story rather than being an afterthought: the
/// clock at full size, how far through it is, what's running, and the fox.
///
/// One treatment, always-on included. The system dims the whole banner itself
/// when the screen idles, and that's as far as it goes: the card keeps its
/// colour and the numeral keeps its outline rather than switching to a dark
/// ground and a plain white numeral, so a glance at a sleeping phone still
/// looks like Aura.
private struct LockScreenBanner: View {
    let state: AuraTimerAttributes.ContentState

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                AuraTimerLiveActivity.countdown(state)
                    .font(WidgetType.display(size: 40))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(.black)
                    .stickerOutline(width: 2.5, color: .white)

                AuraTimerLiveActivity.bar(state,
                                          fill: AuraTimerLiveActivity.accent,
                                          track: AuraTimerLiveActivity.track,
                                          height: AuraTimerLiveActivity.barHeight)
                    .frame(width: AuraTimerLiveActivity.barWidth(state))
                    .padding(.top, 8)

                Text(state.title)
                    .font(WidgetType.label(size: 15, weight: 700))
                    // The fox takes the right of the card, so the longest of
                    // these lines wraps rather than running under it. Shrinking
                    // a hair beats a second line, which would push the card
                    // taller than the ones beside it in Notification Centre.
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.white)
                    .padding(.top, 20)
            }

            Spacer(minLength: 0)

            AuraTimerLiveActivity.mascot(104, state: state)
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity)
    }
}

@main
struct AuraTimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        AuraTimerLiveActivity()
    }
}
