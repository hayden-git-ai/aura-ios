//
//  InterventionView.swift
//  Aura iOS
//

import SwiftUI

/// What you get when you open a blocked app and tap through the shield.
///
/// Four beats: the fox asks whether you actually need it, you either back out
/// or insist, you pick how long, and the fox reacts to what it cost. The point
/// is that the decision happens somewhere you can hear yourself think, instead
/// of behind a system alert with an OK button.
///
/// Aura's version prices the choice. Brainrot's mascot only gets sad; ours
/// spends coins you earned, so "no" is sometimes the honest answer rather than
/// a guilt trip.
struct InterventionView: View {
    /// The app that was opened, if we know it. Nil until the shield extension
    /// is wired and can tell us.
    var appName: String?
    /// Only changes how the moment opens. Every style ends in the same
    /// challenge, duration and pay beats.
    var style: InterventionStyle = .dialogue
    var onFinish: () -> Void

    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private enum Beat: Equatable {
        /// The style's opening, before the fox says anything.
        case preamble
        case challenge
        case encouraged
        case duration
        case pay(Int)
        case spent(Int)
    }

    /// Chosen once per presentation, so the whole conversation is in one
    /// voice.
    @State private var script = InterventionScript.random
    @State private var beat: Beat
    /// Held so the line only types once per beat, not on every re-render.
    @State private var spoken = ""
    /// The duration wheel's selection. The wheel settles on the first option.
    @State private var pickedMinutes = 10

    private static let options = [10, 20, 30]

    init(appName: String? = nil,
         style: InterventionStyle = .dialogue,
         onFinish: @escaping () -> Void) {
        self.appName = appName
        self.style = style
        self.onFinish = onFinish
        _beat = State(initialValue: style.hasPreamble ? .preamble : .challenge)
    }

    var body: some View {
        ZStack {
            if style == .message {
                // The only style that replaces the conversation rather than
                // opening it: the thread carries every beat itself.
                MessageThreadView(appName: appName, onFinish: onFinish)
            } else {
                // One scene held behind the whole flow, outside the transition.
                // The preamble and the conversation layer on top and cross-fade
                // between *themselves*; the background never fades, so the
                // hand-off can't dip to the dark base. (Two separate backgrounds
                // each passing through 50% opacity leave the black ZStack floor
                // showing for a frame — that was the flash.)
                HomeBackground()

                if beat == .preamble {
                    preamble.transition(.opacity)
                } else {
                    conversation.transition(.opacity)
                }
            }
        }
    }

    /// The style's opening. Handing off to `.challenge` is the only thing these
    /// have to do.
    @ViewBuilder private var preamble: some View {
        switch style {
        case .breathing:
            BreathingView { withAnimation(.easeInOut(duration: 0.55)) { beat = .challenge } }

        case .mirror:
            IncomingCallView {
                withAnimation(.easeInOut(duration: 0.35)) { beat = .challenge }
            } onDecline: {
                // Straight out. Declining a call doesn't earn you a talking-to,
                // and the apps were already blocked.
                finish()
            }

        default:
            Color.clear.onAppear { beat = .challenge }
        }
    }

    private var conversation: some View {
        // No background of its own — `body` holds one persistent HomeBackground
        // behind the entire flow, so the preamble hand-off never flashes.
        ZStack {
            // The fox is centred on the screen, the line hangs above it, and
            // the controls fill from the bottom — so the mascot holds the same
            // position through every beat and matches the breathing screen.
            ZStack {
                fox

                Text(spoken)
                    .auraFont(.display, SheetType.banner, .bold)
                    // White over the mountain scene, with a soft shadow so it holds
                    // against both the bright day sky and the dark night.
                    .foregroundStyle(.white)
                    // Two shadows: a tight one for edge definition and a soft, wide
                    // one that darkens the scene behind the whole line, so it reads
                    // over bright clouds or the moon as well as the dark sky.
                    .shadow(color: .black.opacity(0.55), radius: 4, y: 1)
                    .shadow(color: .black.opacity(0.5), radius: 16, y: 3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    // A fixed slot, so a two-line beat doesn't shift the fox.
                    .frame(height: Self.lineHeight, alignment: linePlacement.align)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .offset(y: linePlacement.offset)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Lifted off dead-centre so his feet land on the rock ledge at the same
            // screen height as the Home fox (~49pt up).
            .offset(y: Self.foxLedgeLift)
            // Centred on the whole screen, not on the safe area. The breathing
            // screen ignores the insets, so centring inside them here put the
            // fox ~12pt lower and it appeared to drop when the water handed
            // over. The controls below keep their own safe-area padding.
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                controls
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.bottom, Theme.Spacing.xxl)
            }

            if style == .mirror { selfView }
        }
        .preferredColorScheme(.light)
        .task(id: beat) { await speak() }
    }

    // MARK: - Fox

    /// The conversation fox matches the Home fox exactly — same 220pt size and the
    /// same day/night contact shadow — so "Talk to Aura" reads as the same mascot in
    /// the same place, not a shrunk copy on a different screen.
    private static let foxHeight: CGFloat = 220
    /// Nudge up from screen-centre so the fox's feet meet the rock ledge at the same
    /// screen height as the Home fox (measured: Home feet 0.542 of screen height;
    /// dead-centre puts them at 0.598, so lift ~49pt).
    private static let foxLedgeLift: CGFloat = -49

    /// Where the fox's line sits. Above him for every style — except Mirror Check,
    /// whose self-view PiP fills the top-right and would cover the line, so it drops
    /// below the fox (about where Home's "Earned Today" bar sits) to clear it.
    private var linePlacement: (offset: CGFloat, align: Alignment) {
        // Below the fox for every style, where Home's "Earned Today" card sits (fox
        // frame bottom + one `xxl` gap — the same fox → card spacing `focal` uses).
        // Keeps the line clear of the Mirror self-view and reads the same everywhere.
        (Self.foxHeight / 2 + Theme.Spacing.xxl + Self.lineHeight / 2, .top)
    }

    @ViewBuilder private var foxArt: some View {
        switch beat {
        case .preamble:
            EmptyView()
        case .encouraged:
            // You backed out — the good choice. He puts his shades on. Green-keyed
            // (no flame on the tail here, so green is clean) and normalized to the
            // same geometry as the talk fox, so he stays put through the swap.
            LoopingVideoView(resource: "InterventionEncourageFox")
        case .duration:
            // "Alright. How long?" — arms crossed, judging you while you pick.
            LoopingVideoView(resource: "InterventionDurationFox")
        case .pay:
            // "Alright. Pay up." — slumped and drained, there goes your time.
            LoopingVideoView(resource: "InterventionPayFox")
        case .spent:
            // The receipt: he's sat down and slumped, crying under a little rain
            // cloud. Blue-keyed, opens already settled, and dismisses before the
            // ~4s clip wraps, so it never needs to loop seamlessly.
            LoopingVideoView(resource: "InterventionSpentFox")
        default:
            // His default while he waits for your answer: the thinking → idle loop,
            // blue-keyed and normalized to sit exactly where the Home fox does.
            LoopingVideoView(resource: "InterventionTalkFox")
        }
    }

    private var fox: some View {
        foxArt
            .frame(height: Self.foxHeight)
            .frame(maxWidth: .infinity)
            // The Home fox's contact shadow — stronger at night, as there.
            .background(alignment: .bottom) {
                Ellipse()
                    .fill(Color.black.opacity(HomeDaylight.isDay() ? 0.12 : 0.30))
                    .frame(width: 112, height: 30)
                    .offset(y: -11)
            }
            .offset(x: 4)
    }

    /// Room for the longest line at two rows, held whatever the beat says.
    private static let lineHeight: CGFloat = 88

    // MARK: - Controls

    @ViewBuilder private var controls: some View {
        switch beat {
        case .preamble:
            EmptyView()
        case .challenge:
            VStack(spacing: Theme.Spacing.m) {
                LightPrimaryButton(title: script.decline) {
                    Haptics.impact(.light)
                    beat = .encouraged
                }

                // Red, because it's the choice that costs you something.
                Button(script.accept) {
                    Haptics.impact(.light)
                    beat = .duration
                }
                .auraFont(.body, SheetType.cardTitle, .semibold)
                .foregroundStyle(LightSheet.danger)
                .frame(height: CircleIconButton.minimumTarget)
                .buttonStyle(.plain)
            }

        case .encouraged:
            // Nothing to press. Backing out shouldn't ask for one more decision.
            EmptyView()

        case .duration:
            // Only the durations they can actually afford — so 20/30 never appear as
            // a pick they can't make (the wheel just doesn't list them).
            let affordable = Self.options.filter { store.coinBalance >= $0 }
            if affordable.isEmpty {
                // Out of coins: nothing to pick, so no wheel and no "nevermind". The
                // fox's line already says to go earn some; this just closes it.
                LightPrimaryButton(title: "Got it") {
                    Haptics.impact(.light)
                    finish()
                }
            } else {
                VStack(spacing: Theme.Spacing.l) {
                    // A wheel of the affordable durations, scrolled right on the
                    // scene, so choosing doesn't stack full-width buttons under the line.
                    Picker("", selection: $pickedMinutes) {
                        ForEach(affordable, id: \.self) { minutes in
                            Text("\(minutes) min")
                                // Smaller than the fox's line above (20pt), so the
                                // question stays the loudest thing on the screen.
                                .auraFont(.body, 18, .bold)
                                .foregroundStyle(.white)
                                .tag(minutes)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 132)
                    // Dark, so the wheel's band reads on the night scene (the screen is
                    // otherwise pinned to `.light` for the cards).
                    .colorScheme(.dark)
                    // Snap the selection to something affordable — it can carry over
                    // from a richer state, or default higher than they can now afford.
                    .onAppear { if !affordable.contains(pickedMinutes) { pickedMinutes = affordable[0] } }

                    // Always affordable now (the wheel only lists what they can pay).
                    LightPrimaryButton(title: "Continue") {
                        Haptics.impact(.light)
                        beat = .pay(pickedMinutes)
                    }

                    Button(script.nevermind) {
                        Haptics.impact(.light)
                        beat = .encouraged
                    }
                    .auraFont(.body, SheetType.cardTitle, .semibold)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.45), radius: 6, y: 1)
                    .frame(height: CircleIconButton.minimumTarget)
                    .buttonStyle(.plain)
                }
            }

        case .pay(let minutes):
            VStack(spacing: Theme.Spacing.m) {
                // A hold, like every other moment in the app where something
                // leaves your account.
                HoldToConfirmButton(
                    tint: LightSheet.danger,
                    idleCaption: script.holdIdle(coins: minutes),
                    holdingCaption: script.holdHolding,
                    doneCaption: script.holdDone,
                    // On the night scene, not a white sheet: white caption with a
                    // shadow and a softer track, so the hold reads over the photo.
                    idleCaptionColor: .white,
                    captionShadow: true,
                    trackColor: .white.opacity(0.28),
                    duration: 3
                ) {
                    buy(minutes)
                }

                Button(script.nevermind) {
                    Haptics.impact(.light)
                    beat = .encouraged
                }
                .auraFont(.body, SheetType.cardTitle, .semibold)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.45), radius: 6, y: 1)
                .frame(height: CircleIconButton.minimumTarget)
                .buttonStyle(.plain)
            }

        case .spent:
            EmptyView()
        }
    }

    /// The call's self-view, parked above the controls.
    ///
    /// This is the whole point of the style: the fox does the asking, and your
    /// own face is in the corner while you answer. It stays for every beat,
    /// including the one where you're picking how many minutes to buy.
    private var selfView: some View {
        SelfMirrorCameraView()
            .frame(width: Self.pipWidth, height: Self.pipWidth * 4 / 3)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.xxxl + Theme.Spacing.l)
            .allowsHitTesting(false)
    }

    private static let pipWidth: CGFloat = 96

    // MARK: - Words

    private var line: String {
        switch beat {
        case .preamble:
            return ""
        case .challenge:
            return script.challenge(app: appName)
        case .encouraged:
            return script.backedOut
        case .duration:
            return store.coinBalance >= Self.options[0] ? script.howLong : script.broke
        case .pay(let minutes):
            return script.pay(coins: minutes)
        case .spent(let minutes):
            return script.paid(minutes: minutes)
        }
    }

    /// Types the beat's line out, then leaves the room when the beat is an
    /// ending. The pauses are the performance, so they're deliberate: a beat
    /// before the fox speaks, and a longer one after it's done.
    private func speak() async {
        spoken = ""
        try? await Task.sleep(for: .milliseconds(320))

        for character in line {
            spoken.append(character)
            try? await Task.sleep(for: .milliseconds(22))
        }

        switch beat {
        case .encouraged:
            try? await Task.sleep(for: .milliseconds(1400))
            finish()
        case .spent:
            try? await Task.sleep(for: .milliseconds(1600))
            finish()
        default:
            break
        }
    }

    // MARK: - Actions

    private func buy(_ minutes: Int) {
        guard InterventionPurchase.buy(minutes: minutes, from: store) else {
            beat = .duration
            return
        }
        beat = .spent(minutes)
    }

    private func finish() {
        onFinish()
        dismiss()
    }
}

#Preview {
    InterventionView(appName: "Instagram") {}
        .environment(HabitStore())
}
