//
//  SelfMirrorCameraView.swift
//  Aura iOS
//

import SwiftUI
@preconcurrency import AVFoundation
import Combine

/// Drives a front-camera capture session. Owns the session lifecycle so the
/// view can start it on appear and stop it on disappear without leaking the
/// camera running in the background.
final class CameraPreviewController: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var isDenied = false

    let previewLayer = AVCaptureVideoPreviewLayer()
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "aura.self-mirror.session")
    private var isConfigured = false
    /// Main-thread ownership generation. A delayed permission result may start
    /// only the same appearance that requested it; `stop()` invalidates it.
    private var lifecycleGeneration: UInt64 = 0

    override init() {
        super.init()
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
    }

    @MainActor
    func start() {
        lifecycleGeneration &+= 1
        let generation = lifecycleGeneration
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            configureAndStart(generation: generation)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor [weak self] in
                    guard let self, self.lifecycleGeneration == generation else { return }
                    self.isAuthorized = granted
                    self.isDenied = !granted
                    if granted { self.configureAndStart(generation: generation) }
                }
            }
        default:
            isDenied = true
        }
    }

    @MainActor
    func stop() {
        lifecycleGeneration &+= 1
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    @MainActor
    private func configureAndStart(generation: UInt64) {
        guard lifecycleGeneration == generation else { return }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.isConfigured {
                self.session.beginConfiguration()
                self.session.sessionPreset = .high
                guard
                    let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                    let input = try? AVCaptureDeviceInput(device: device),
                    self.session.canAddInput(input)
                else {
                    self.session.commitConfiguration()
                    return
                }
                self.session.addInput(input)
                self.session.commitConfiguration()
                self.isConfigured = true
            }
            if !self.session.isRunning { self.session.startRunning() }
        }
    }
}

/// Hosts the `AVCaptureVideoPreviewLayer` and keeps it sized to the view's
/// actual bounds — `updateUIView` alone doesn't fire reliably on resize/rotation.
private final class PreviewContainerView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer? {
        didSet {
            if let previewLayer {
                layer.addSublayer(previewLayer)
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}

private struct CameraPreviewRepresentable: UIViewRepresentable {
    let controller: CameraPreviewController

    func makeUIView(context: Context) -> PreviewContainerView {
        let view = PreviewContainerView()
        view.backgroundColor = .black
        view.previewLayer = controller.previewLayer
        return view
    }

    func updateUIView(_ uiView: PreviewContainerView, context: Context) {}
}

/// The confrontation device on the Emergency Unlock screen: a live mirror of
/// yourself in the moment you're about to cave. Falls back to a generic
/// silhouette if camera access is denied — never blocks the flow on it.
struct SelfMirrorCameraView: View {
    @StateObject private var controller = CameraPreviewController()

    var body: some View {
        ZStack {
            if controller.isAuthorized {
                // AVCaptureVideoPreviewLayer already mirrors the front camera
                // by default — no extra flip needed, that would double it.
                CameraPreviewRepresentable(controller: controller)
            } else {
                fallback
            }
        }
        .onAppear { controller.start() }
        .onDisappear { controller.stop() }
    }

    private var fallback: some View {
        ZStack {
            RadialGradient(
                colors: [Color(hex: "3A3A42"), Color(hex: "222227"), Color(hex: "131316"), Color(hex: "0C0C0F")],
                center: UnitPoint(x: 0.5, y: 0.3), startRadius: 10, endRadius: 220
            )
            Image(systemName: "person.fill")
                .font(.system(size: 90))
                .foregroundStyle(Theme.Color.background)
                .opacity(0.5)
                .offset(y: 32)
        }
    }
}

#Preview {
    SelfMirrorCameraView()
        .frame(width: 280, height: 320)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
        .padding()
        .background(Theme.Color.background)
        .preferredColorScheme(.dark)
}
