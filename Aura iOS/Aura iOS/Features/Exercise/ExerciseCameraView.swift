//
//  ExerciseCameraView.swift
//  Aura iOS
//

import SwiftUI
import AVFoundation
import Vision

/// Screen 2 of the Exercise flow — the live camera that counts reps via
/// body-pose tracking and pays out in coins.
///
/// Chrome is `PhotoProofCameraView`'s, exactly: one row of back / pill / help
/// in `CircleIconButton` on `chromeOnPhoto` with halos under them, and a help
/// sheet behind the question mark. It had drifted a long way from that — an
/// Aura logo over the viewfinder, the identity on a second row, a close button
/// from a different component, and no way to reach the form tip once the camera
/// was open.
///
/// No frame and no scrim. Photo Proof's brackets say "put the book here", which
/// is a useful thing to say about a book on a table. Here you are somewhere in
/// a room several feet back, and a rectangle would be marking out a space the
/// person cannot use.
///
/// The count sits low, above the button. The middle of the frame stays empty on
/// purpose: it is where you are, and you need to see yourself.
struct ExerciseCameraView: View {
    let exercise: Exercise
    var onClose: () -> Void
    /// Reps done and coins earned, so the celebration can say both.
    var onFinish: (Int, Int) -> Void

    @Environment(HabitStore.self) private var store
    @StateObject private var controller: PoseCameraController

    /// Drives the floating "+N" earn popup — bumped each time `earned` gains a
    /// whole coin, carrying how many were just banked.
    @State private var earnEventID = 0
    @State private var earnEventAmount = 0
    @State private var showHelp = false
    @State private var showLeaveConfirm = false

    init(exercise: Exercise, onClose: @escaping () -> Void, onFinish: @escaping (Int, Int) -> Void) {
        self.exercise = exercise
        self.onClose = onClose
        self.onFinish = onFinish
        _controller = StateObject(wrappedValue: PoseCameraController(exercise: exercise))
    }

    /// Units performed — reps for rep exercises, seconds for holds.
    private var units: Int {
        controller.reps
    }

    private var earned: Int {
        exercise.earnedMinutes(forUnits: units, rate: store.rate(for: exercise), goal: store.goal(for: exercise))
    }

    /// `earnBar`, the app's one earn green. This screen was still on
    /// `signalGood`, twenty points away from the green on the Home card that
    /// shows the very coins it pays out.
    private let earnedGreen = Theme.Color.earnBar

    var body: some View {
        ZStack {
            cameraLayer
            GeometryReader { proxy in
                PoseSkeletonOverlay(poseLayer: controller.poseLayer,
                                    convert: converter(in: proxy.size))
            }
            .ignoresSafeArea()
            overlayUI

            if showLeaveConfirm { leaveConfirm }
        }
        .background(.black)
        .statusBarHidden()
        .onAppear {
            #if DEBUG
            if Self.isSkeletonDebug {
                controller.poseLayer.pose = .debugStanding
                return
            }
            #endif
            controller.start()
        }
        .onDisappear { controller.stop() }
        // Fire the earn popup whenever the whole-minute earned total ticks up.
        .onChange(of: earned) { oldValue, newValue in
            guard newValue > oldValue else { return }
            earnEventAmount = newValue - oldValue
            earnEventID += 1
        }
        .sheet(isPresented: $showHelp) {
            ExerciseHelpSheet(exercise: exercise)
                .presentationDetents([.fraction(0.82)])
                .presentationDragIndicator(.hidden)
        }
    }

    /// How a Vision point becomes a view point.
    ///
    /// Normally the preview layer does it, since it owns the aspect-fill crop
    /// and the front-camera mirroring. With no capture session there is no
    /// preview layer and no crop, so the stand-in pose maps straight onto the
    /// view: x across, y flipped, because Vision's origin is bottom-left.
    private func converter(in size: CGSize) -> (CGPoint) -> CGPoint {
        #if DEBUG
        if Self.isSkeletonDebug {
            return { CGPoint(x: $0.x * size.width, y: (1 - $0.y) * size.height) }
        }
        #endif
        return controller.viewPoint
    }

    #if DEBUG
    /// `-skeleton` draws a stand-in body so the overlay can be tuned in the
    /// Simulator, which has no camera and therefore never produces a pose.
    static var isSkeletonDebug: Bool {
        ProcessInfo.processInfo.arguments.contains("-skeleton")
    }
    #endif

    @ViewBuilder
    private var cameraLayer: some View {
        if controller.isAuthorized {
            PoseCameraPreview(controller: controller).ignoresSafeArea()
        } else {
            // Simulator / denied — no live feed to track against.
            CameraFallbackView(
                message: controller.isDenied ? "Camera access is off" : "Camera needed to count reps",
                center: UnitPoint(x: 0.5, y: 0.35),
                endRadius: 400
            )
        }
    }


    private var overlayUI: some View {
        VStack(spacing: 0) {
            topBar
            // A single top spacer pushes the count + subtitle down to sit just
            // above the button, leaving the middle of the frame clear so the
            // count never blocks the user's view of themselves.
            Spacer()
            framingHint
            countBlock
                .padding(.bottom, Theme.Spacing.xxl)
            finishButton
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.l)
        }
    }

    /// Back, which exercise, and help, on one line.
    ///
    /// The pill is centred in a `ZStack` rather than placed between the buttons
    /// in the `HStack`, so a long exercise name pushes into the space either
    /// side evenly instead of shoving the buttons off their corners.
    private var topBar: some View {
        ZStack {
            exercisePill

            HStack {
                CircleIconButton(symbol: "chevron.left",
                                 fill: LightSheet.chromeOnPhoto,
                                 glyphColor: .white) {
                    // Nothing done, nothing to lose: leave without a word.
                    // Asking somebody who did zero reps whether they're sure is
                    // a dialog for the sake of having one.
                    guard units > 0 else { onClose(); return }
                    Haptics.impact(.light)
                    withAnimation(.snappy(duration: 0.25)) { showLeaveConfirm = true }
                }
                    .photoHalo()
                Spacer()
                CircleIconButton(sticker: "FoxSettingsHelp",
                                 fill: LightSheet.chromeOnPhoto) {
                    Haptics.impact(.light)
                    showHelp = true
                }
                .photoHalo()
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, Theme.Spacing.m)
    }

    /// Which exercise you're doing. The fox carries it, the name confirms it.
    ///
    /// Side by side, the same shape as Photo Proof's habit pill, so the two
    /// cameras wear the same object.
    private var exercisePill: some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(exercise.iconAsset)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 27, height: 27)
            Text(exercise.name)
                .auraFont(.body, SheetType.cta, .bold)
                .foregroundStyle(.white)
        }
        .padding(.leading, Theme.Spacing.s)
        .padding(.trailing, Theme.Spacing.l)
        // `xs`, not `s`. The sticker already stands taller than the label, so
        // the capsule takes its height from that; matching the horizontal
        // padding on top of it left the pill deeper than it needed to be.
        .padding(.vertical, Theme.Spacing.xs)
        .background(LightSheet.chromeOnPhoto, in: Capsule())
    }

    /// Says so when the camera can't use what it's seeing.
    ///
    /// Without it a badly placed phone is silent: the count sits at zero, the
    /// skeleton is missing or half-drawn, and nothing on screen says which of
    /// those is the problem or what to do. Somebody doing perfectly good reps
    /// four feet out of frame has no way to find that out.
    ///
    /// Sits directly above the count rather than in the middle of the screen.
    /// The middle stays clear on principle, and this is where the eye already
    /// is when it goes to check the number that isn't moving.
    @ViewBuilder
    private var framingHint: some View {
        if let message = framingMessage {
            Text(message)
                .auraFont(.body, SheetType.cardTitle, .semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.vertical, Theme.Spacing.s)
                .background(LightSheet.chromeOnPhoto, in: Capsule())
                .padding(.bottom, Theme.Spacing.l)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    private var framingMessage: String? {
        switch controller.framing {
        case .good: return nil
        case .absent: return "I can't see you"
        case .partial: return "Back up so all of you fits"
        }
    }

    private var countBlock: some View {
        VStack(spacing: -Theme.Spacing.s) {
            Text("\(units)")
                .auraFont(.display, Self.countSize, .bold)
                .foregroundStyle(.white)
                .monospacedDigit()
                .contentTransition(.numericText())
                .shadow(color: .black.opacity(0.5), radius: 12)
                .animation(.snappy(duration: 0.25), value: units)
                // "+Nm" floats up and fades from the number's top-right each
                // time a whole minute is earned. Keyed by the event id so the
                // view is recreated and its animation restarts every time.
                .overlay(alignment: .topTrailing) {
                    if earnEventID > 0 {
                        EarnPopupView(coins: earnEventAmount, tint: earnedGreen)
                            .id(earnEventID)
                    }
                }

            Text(subtitle)
                .auraFont(.body, SheetType.cardTitle, .semibold)
                .foregroundStyle(earned > 0 ? earnedGreen : LightSheet.onColour)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.25), value: earned)
        }
    }

    /// Dialled back from 118, which was the streak screen's one-off before it
    /// was measured properly. A rep counter has to be readable at arm's length
    /// across a room without filling the frame it is laid over. 72 cleared the
    /// frame and stopped carrying across it; 84 is the streak numeral's size
    /// and reads from the far side of a room.
    private static let countSize: CGFloat = 84

    private var subtitle: String {
        if earned > 0 {
            return "+\(earned) coins earned"
        }
        return "\(Exercise.goalDisplay(store.goal(for: exercise))) to start earning"
    }

    /// The app's primary button in all three states, rather than the bespoke
    /// 58pt capsule this used to hand-roll — which made it the one CTA in the
    /// app with no drop edge, at a height on no rung of the scale.
    @ViewBuilder
    /// Stops somebody walking away from reps they already did.
    ///
    /// Two different problems wear the same shape. Past the threshold there are
    /// coins sitting there that leaving would bin, and one tap claims them.
    /// Short of it, the honest thing is to say how close they are, because
    /// "three more" is a very different fact from "you get nothing".
    ///
    /// Leaving stays available and is never hidden behind anything. This is a
    /// screen you can be stuck in front of, half-changed, in a gym; a dialog
    /// that argues with you is worse than losing four reps.
    private var leaveConfirm: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.snappy(duration: 0.2)) { showLeaveConfirm = false }
                }

            VStack(spacing: 0) {
                Text(earned > 0
                     ? "You've got \(earned) coins here."
                     : "You're nearly there.")
                    .auraFont(.display, SheetType.title, .bold)
                    .foregroundStyle(SheetType.titleColor)
                    .multilineTextAlignment(.center)

                Text(leaveBlurb)
                    .auraFont(.body, SheetType.cardBlurb, .regular)
                    .foregroundStyle(SheetType.subtitleColor)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Theme.Spacing.s)

                if earned > 0 {
                    LightPrimaryButton(title: "Claim \(earned) coins",
                                       face: LightSheet.green,
                                       shade: LightSheet.greenShade) {
                        onFinish(units, earned)
                    }
                    .padding(.top, Theme.Spacing.xl)
                } else {
                    LightPrimaryButton(title: "Keep going") {
                        withAnimation(.snappy(duration: 0.2)) { showLeaveConfirm = false }
                    }
                    .padding(.top, Theme.Spacing.xl)
                }

                Button(action: onClose) {
                    Text("Leave anyway")
                        .auraFont(.body, SheetType.cardTitle, .semibold)
                        .foregroundStyle(LightSheet.controlIdle)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.plain)
                .padding(.top, Theme.Spacing.s)
            }
            .padding(Theme.Spacing.xl)
            .background(LightSheet.bg,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
            .padding(.horizontal, Theme.Spacing.xl)
        }
        .transition(.opacity)
    }

    private var leaveBlurb: String {
        if earned > 0 {
            return "Leave now and they're gone."
        }
        let short = max(1, store.goal(for: exercise) - units)
        return "\(short) more \(exercise.unitNoun(for: short)) and you start earning. You've done \(units)."
    }

    @ViewBuilder
    private var finishButton: some View {
        if earned > 0 {
            LightPrimaryButton(title: "Claim \(earned) coins",
                               face: LightSheet.green,
                               shade: LightSheet.greenShade) {
                onFinish(units, earned)
            }
        } else {
            // Dead until the goal is met, at ANY rep count. There used to be a
            // live white "Finish" from the first rep that granted zero and
            // dismissed without a word — three reps of five, one tap, nothing.
            // Leaving early is a real thing to do, but it belongs on the back
            // button, where the sheet says how close you are and offers to keep
            // going. A primary CTA that silently throws the set away is not a
            // way out, it's a trap.
            LightPrimaryButton(title: "Finish",
                               face: LightSheet.chromeOnCamera,
                               textColor: .white.opacity(0.4),
                               shade: .clear,
                               enabled: false) {}
        }
    }
}

/// The "+N" that lifts off the count each time a whole coin lands.
///
/// Rewritten to match the Home card's, which is the version that was actually
/// tuned. This one was hardcoded to `.offset(x: 44)`, so it sat right for a
/// two-digit count and wrong for one or three. Measuring the badge and pushing
/// it by its own size puts its bottom-left corner on the count's top-right
/// corner at any width.
///
/// The parent recreates it via `.id` on each earn event, so the animation
/// replays every time.
private struct EarnPopupView: View {
    let coins: Int
    let tint: Color

    @State private var size: CGSize = .zero
    @State private var lift: CGFloat = 0
    @State private var fade: Double = 0

    var body: some View {
        Text("+\(coins)")
            .auraFont(.display, SheetType.hero, .bold)
            .foregroundStyle(tint)
            .shadow(color: tint.opacity(0.6), radius: 12)
            .fixedSize()
            .background {
                GeometryReader { geo in
                    Color.clear.preference(key: EarnPopupSizeKey.self, value: geo.size)
                }
            }
            .onPreferenceChange(EarnPopupSizeKey.self) { size = $0 }
            .offset(x: size.width + 3, y: -size.height - 3 + lift)
            .opacity(fade)
            .allowsHitTesting(false)
            .onAppear {
                // A beat to let the measurement land before anything shows, or
                // the badge renders once in the wrong place and snaps.
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(20))
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { fade = 1 }
                    try? await Task.sleep(for: .seconds(0.3))
                    // Straight up and unhurried, like the Home card's.
                    withAnimation(.easeOut(duration: 1.1)) {
                        lift = -34
                        fade = 0
                    }
                }
            }
    }
}

private struct EarnPopupSizeKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

/// Hosts the controller's preview layer, kept sized to the view.
private struct PoseCameraPreview: UIViewRepresentable {
    let controller: PoseCameraController

    func makeUIView(context: Context) -> PreviewHost {
        let view = PreviewHost()
        view.backgroundColor = .black
        view.previewLayer = controller.previewLayer
        return view
    }

    func updateUIView(_ uiView: PreviewHost, context: Context) {}

    final class PreviewHost: UIView {
        var previewLayer: AVCaptureVideoPreviewLayer? {
            didSet { if let previewLayer { layer.addSublayer(previewLayer) } }
        }
        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer?.frame = bounds
        }
    }
}

#if DEBUG
extension BodyPose {
    /// A person standing square to the camera, in Vision's normalized space
    /// (origin bottom-left, y up).
    ///
    /// Hand-placed rather than run through Vision against a bundled photo. The
    /// point of this is to tune line weight, colour and joint size, and for
    /// that a pose that is identical on every launch beats a real one that
    /// shifts by a few points each time and can be argued with.
    static let debugStanding = BodyPose(points: [
        .nose:          CGPoint(x: 0.50, y: 0.86),
        .neck:          CGPoint(x: 0.50, y: 0.78),
        .leftShoulder:  CGPoint(x: 0.40, y: 0.76),
        .rightShoulder: CGPoint(x: 0.60, y: 0.76),
        .leftElbow:     CGPoint(x: 0.34, y: 0.63),
        .rightElbow:    CGPoint(x: 0.66, y: 0.63),
        .leftWrist:     CGPoint(x: 0.30, y: 0.50),
        .rightWrist:    CGPoint(x: 0.70, y: 0.50),
        .leftHip:       CGPoint(x: 0.44, y: 0.50),
        .rightHip:      CGPoint(x: 0.56, y: 0.50),
        .leftKnee:      CGPoint(x: 0.43, y: 0.32),
        .rightKnee:     CGPoint(x: 0.57, y: 0.32),
        .leftAnkle:     CGPoint(x: 0.42, y: 0.14),
        .rightAnkle:    CGPoint(x: 0.58, y: 0.14),
    ])
}
#endif
