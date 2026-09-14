//
//  PhotoProofCameraView.swift
//  Aura iOS
//

import SwiftUI
import AVFoundation

/// Where the viewfinder ended up, so the scrim can cut its hole in the same
/// place. A preference rather than a shared constant because the frame's
/// position is decided by the layout, not by us.
private struct ViewfinderFrameKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

/// Screen 2 of the Photo Proof flow — the back camera the user photographs
/// their habit with. On capture the frame freezes and `VerifyingOverlay` runs
/// over it while the model looks.
///
/// A pass leaves immediately for `ProofSuccessView`. A failure stays here and
/// draws `ProofFailureView` over the top, so retaking is a state change rather
/// than a trip out to the flow root and back. Three transitions to end up where
/// you started is how somebody standing in a gym holding their phone up decides
/// they can't be bothered.
///
/// The verdict comes from `HabitStore.proofVerifier`, which is the live
/// endpoint when one is configured and the mock otherwise.
struct PhotoProofCameraView: View {
    let habit: Habit
    /// Session length, for what the verdict screen says a pass is worth.
    var minutes: Int
    var onClose: () -> Void
    /// A pass, and the frame that earned it — the wall needs the picture, and
    /// this is the only place it exists.
    var onPassed: (ProofVerdict, UIImage?) -> Void

    @Environment(HabitStore.self) private var store
    @StateObject private var controller = PhotoCaptureController()
    @State private var hasAISharingConsent = false
    @State private var frozen: UIImage?
    @State private var verdict: ProofVerdict?
    @State private var showHelp = false
    @State private var showAISharingConsent = false

    var body: some View {
        ZStack {
            if let frozen {
                // The photo, exactly as taken. The 25% black that used to sit
                // over it made the app look like it was hiding the thing it was
                // examining; the evidence should be the brightest thing here.
                // The photo draws INSIDE a `Color.clear`, rather than being the
                // view that gets laid out.
                //
                // A `scaledToFill()` Image reports the size of its scaled
                // content, and on a 1:2 photo in a 402pt-wide screen that is
                // 438pt. Everything measured against it inherited that width:
                // the failure screen's 24pt inset was resolving to 6pt of
                // visible margin, so its button came out 36pt wider than every
                // other button in the app, and the verifying field was spreading
                // its dots across 36pt of canvas nobody can see.
                //
                // `.frame(maxWidth:.infinity).clipped()` does NOT fix this; it
                // was tried and the view still measured 438. `Color.clear`
                // takes the proposal exactly, an overlay never resizes its
                // parent, and the clip cuts the overhang.
                Color.clear
                    .overlay {
                        Image(uiImage: frozen)
                            .resizable()
                            .scaledToFill()
                    }
                    .clipped()
                    .ignoresSafeArea()

                // Only a failure lands here; a pass leaves for its own screen
                // the moment the verdict arrives. The failure screen covers the
                // photo completely, but the camera underneath stays mounted so
                // retaking is instant.
                if let verdict {
                    ProofFailureView(habit: habit,
                                     verdict: verdict,
                                     onRetake: retake,
                                     onClose: onClose)
                } else {
                    VerifyingOverlay(habit: habit)
                        .ignoresSafeArea(edges: .bottom)
                }
            } else {
                cameraLayer
                CameraScrim()
                liveOverlay
            }
        }
        .background(.black)
        .statusBarHidden()
        .onAppear {
            #if DEBUG
            // The Simulator has no camera, so every state past the shutter is
            // otherwise unreachable. `-verifying` holds on the scan, `-pass`
            // and `-fail` jump to each verdict, all over a stand-in photo.
            let args = ProcessInfo.processInfo.arguments
            if let stand = UIImage(named: "AuraHomeBackgroundDay"),
               args.contains(where: { ["-verifying", "-pass", "-fail", "-blocked"].contains($0) }) {
                frozen = stand
                if args.contains("-pass") {
                    onPassed(ProofVerdict(passed: true, reason: "Book open in frame, clearly readable."), stand)
                } else if args.contains("-fail") {
                    verdict = ProofVerdict(passed: false,
                                           reason: "This looks like a phone screen, not a book.",
                                           fix: "Hold an open book up and fill the frame with it.")
                } else if args.contains("-blocked") {
                    verdict = ProofVerdict(passed: false, isBlocked: true)
                }
                return
            }
            #endif
            hasAISharingConsent = PhotoProofAIConsent.isGranted(
                for: SupabaseManager.shared.currentUserID
            )
            if hasAISharingConsent {
                controller.start()
            } else {
                showAISharingConsent = true
            }
        }
        .onDisappear { controller.stop() }
        .onChange(of: controller.capturedImage) { _, image in
            guard let image, frozen == nil else { return }
            beginVerification(image)
        }
        .sheet(isPresented: $showHelp) {
            ProofHelpSheet(habit: habit)
                // One detent, taller than `.medium`, so the content isn't
                // pressed against the bottom edge. `.hidden` because the sheet
                // draws Aura's own drag capsule in its header and the system
                // was adding a second one above it.
                .presentationDetents([.fraction(0.82)])
                .presentationDragIndicator(.hidden)
        }
        .alert("Allow AI photo verification?", isPresented: $showAISharingConsent) {
            Button("Not now", role: .cancel) { onClose() }
            Button("Allow and continue") {
                PhotoProofAIConsent.grant(for: SupabaseManager.shared.currentUserID)
                hasAISharingConsent = true
                controller.start()
            }
        } message: {
            Text(PhotoProofAIConsent.disclosure)
        }
    }

    private func beginVerification(_ image: UIImage) {
        guard hasAISharingConsent else {
            controller.capturedImage = nil
            controller.stop()
            showAISharingConsent = true
            return
        }
        frozen = image
        controller.stop()

        Task {
            let started = Date()
            let answer = await store.proofVerifier.verify(image: image, habit: habit)

            // A floor, not a delay on top. The endpoint answers in about a
            // second, and a verdict that lands in 200ms reads as though nothing
            // was checked. This holds the overlay to a minimum without adding
            // to a call that already took longer than it.
            let elapsed = Date().timeIntervalSince(started)
            if elapsed < Self.minimumVerifyTime {
                try? await Task.sleep(for: .seconds(Self.minimumVerifyTime - elapsed))
            }

            // A pass leaves immediately: the celebration is its own screen and
            // holding a verdict card on the photo first would put two answers
            // in a row. A failure stays here, where retaking is a state change
            // rather than a trip through the flow root and back.
            if answer.passed {
                onPassed(answer, image)
            } else {
                withAnimation(.easeInOut(duration: 0.2)) { verdict = answer }
            }
        }
    }

    /// Back to the viewfinder without going anywhere. The controller's last
    /// captured frame is cleared too, or `onChange` sees the old photo the
    /// moment the next one differs from nothing.
    private func retake() {
        withAnimation(.easeInOut(duration: 0.2)) {
            verdict = nil
            frozen = nil
        }
        controller.capturedImage = nil
        controller.start()
    }

    /// How long the verifying state stays up at minimum.
    private static let minimumVerifyTime: TimeInterval = 1.4

    // MARK: - Camera

    @ViewBuilder
    private var cameraLayer: some View {
        if controller.isAuthorized {
            PhotoCameraPreview(controller: controller).ignoresSafeArea()
        } else {
            CameraFallbackView(
                message: controller.isDenied ? "Camera access is off" : "Camera needed to verify your habit",
                center: UnitPoint(x: 0.5, y: 0.4),
                endRadius: 420
            )
        }
    }


    // MARK: - Overlay

    private var liveOverlay: some View {
        ZStack {
            // The brackets sit in the flow between the top bar and the shutter,
            // so they centre in the space actually left over rather than on the
            // screen. The scrim can't be in that stack with them, because it has
            // to bleed to every edge, so it reads their resolved frame and cuts
            // its hole there.
            VStack(spacing: 0) {
                topBar
                Spacer(minLength: Theme.Spacing.l)
                brackets
                Spacer(minLength: Theme.Spacing.l)
                bottomControls.padding(.bottom, Theme.Spacing.xl)
            }
        }
        .backgroundPreferenceValue(ViewfinderFrameKey.self) { frame in
            GeometryReader { proxy in
                if let frame {
                    scrim(around: proxy[frame])
                }
            }
        }
    }

    private var brackets: some View {
        ViewfinderBrackets(cornerLength: ViewfinderFrame.cornerLength,
                           cornerRadius: ViewfinderFrame.radius)
            .stroke(.white.opacity(0.92), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            .frame(width: ViewfinderFrame.size.width, height: ViewfinderFrame.size.height)
            .anchorPreference(key: ViewfinderFrameKey.self, value: .bounds) { $0 }
            .allowsHitTesting(false)
    }

    /// Everything outside the frame, darkened.
    ///
    /// The brackets on their own were decoration: they said "put it here" while
    /// the rest of the picture was exactly as bright, so the eye had no reason
    /// to go there. Dimming the outside does the work the brackets were only
    /// gesturing at.
    private func scrim(around rect: CGRect) -> some View {
        Color.black.opacity(0.35)
            .reverseMask {
                RoundedRectangle(cornerRadius: ViewfinderFrame.radius, style: .continuous)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }

    /// Back, which habit, and help, on one line.
    ///
    /// The pill is centred in a `ZStack` rather than placed between the buttons
    /// in the `HStack`, so a long habit name pushes into the space either side
    /// evenly instead of shoving the buttons off their corners.
    private var topBar: some View {
        ZStack {
            habitPill

            HStack {
                CircleIconButton(symbol: "chevron.left",
                                 fill: LightSheet.chromeOnPhoto,
                                 glyphColor: .white,
                                 action: onClose)
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

    /// Which habit you're proving. The sticker carries it, the name confirms it.
    ///
    /// The instruction that briefly lived here has moved behind the question
    /// mark: it was a paragraph of text laid over the thing you're trying to
    /// look through.
    private var habitPill: some View {
        HStack(spacing: Theme.Spacing.s) {
            habitSticker
            Text(habit.name)
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

    @ViewBuilder
    private var habitSticker: some View {
        if let asset = habit.iconAsset {
            Image(asset)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 34, height: 34)
        } else {
            Text(habit.emoji.isEmpty ? "📸" : habit.emoji)
                .font(.system(size: 26))
                .frame(width: 34, height: 34)
        }
    }

    private var bottomControls: some View {
        ZStack {
            Button { controller.capture() } label: {
                Circle()
                    .fill(.white)
                    .frame(width: 72, height: 72)
                    .contentShape(Circle())
                    // The stroked ring that used to float around this was a
                    // second outline saying nothing; the halo every other
                    // control wears says the same thing and says it once.
                    .photoHalo(diameter: 72)
            }
            .buttonStyle(PressBounceStyle())

            HStack {
                // `stepper`, the 44pt grade, rather than the hand-rolled 52
                // this used to be. 52 is on no rung of the scale, and the
                // justification for it (matching a shutter that was 80 with a
                // ring around it) stopped being true when the ring came off.
                // 44 is the grade for a control you aim at rather than corner
                // chrome, which is exactly what this is.
                CircleIconButton(symbol: "arrow.triangle.2.circlepath",
                                 grade: .stepper,
                                 fill: LightSheet.chromeOnPhoto,
                                 glyphColor: .white) {
                    controller.flip()
                }
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.xxl)
        }
    }
}

enum PhotoProofAIConsent {
    // Version this key whenever the named providers or material handling changes,
    // so existing users receive the revised disclosure before another upload.
    private static let storageKey = "aura.photoProof.aiSharingConsent.v1"

    static let disclosure = "To verify this habit, Aura will send your photo to Google Gemini. If Gemini fails, Aura may send it to OpenAI. Aura does not keep the verification copy. After a pass, Aura attempts to save the photo to your Wall of Wins and, when signed in, sync it to your private Aura storage."

    static func isGranted(for userID: UUID?, defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: scopedStorageKey(for: userID))
    }

    static func grant(for userID: UUID?, defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: scopedStorageKey(for: userID))
    }

    static func revoke(for userID: UUID?, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: scopedStorageKey(for: userID))
    }

    static func scopedStorageKey(for userID: UUID?) -> String {
        if let userID { return "\(storageKey).user.\(userID.uuidString)" }
        return "\(storageKey).signedOut"
    }
}

/// Hosts the controller's preview layer, kept sized to the view.
private struct PhotoCameraPreview: UIViewRepresentable {
    let controller: PhotoCaptureController

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
