//
//  SelfMirrorCameraView.swift
//  Aura iOS
//

import SwiftUI
import AVFoundation
import Combine

/// Drives a front-camera capture session. Owns the session lifecycle so the
/// view can start it on appear and stop it on disappear without leaking the
/// camera running in the background.
final class CameraPreviewController: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var isDenied = false

    let previewLayer = AVCaptureVideoPreviewLayer()
    private let session = AVCaptureSession()
    private var isConfigured = false

    override init() {
        super.init()
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
    }

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    self?.isDenied = !granted
                    if granted { self?.configureAndStart() }
                }
            }
        default:
            isDenied = true
        }
    }

    func stop() {
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [session] in
            session.stopRunning()
        }
    }

    private func configureAndStart() {
        if !isConfigured {
            session.beginConfiguration()
            session.sessionPreset = .high
            guard
                let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                let input = try? AVCaptureDeviceInput(device: device),
                session.canAddInput(input)
            else {
                session.commitConfiguration()
                return
            }
            session.addInput(input)
            session.commitConfiguration()
            isConfigured = true
        }
        DispatchQueue.global(qos: .userInitiated).async { [session] in
            session.startRunning()
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
                .offset(y: 30)
        }
    }
}

#Preview {
    SelfMirrorCameraView()
        .frame(width: 280, height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .padding()
        .background(Theme.Color.background)
        .preferredColorScheme(.dark)
}
