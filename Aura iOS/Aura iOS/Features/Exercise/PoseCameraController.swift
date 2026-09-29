//
//  PoseCameraController.swift
//  Aura iOS
//

import SwiftUI
import Combine
import AVFoundation
import Vision

/// Runs the front camera, feeds each frame to Vision's body-pose detector, and
/// drives a `RepEngine` for the chosen exercise. Publishes the latest pose (for
/// the skeleton overlay) plus the live rep count.
///
/// Only meaningful on a physical device — the simulator has no camera, so this
/// stays in the not-authorized/denied state and the view shows a fallback.
final class PoseCameraController: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var isDenied = false
    @Published var reps = 0
    /// Whether the camera can see enough of the person to count.
    ///
    /// Starts `.good` so the hint doesn't flash on for the second before the
    /// first frame arrives.
    @Published private(set) var framing: Framing = .good

    enum Framing {
        /// Nothing that looks like a body.
        case absent
        /// A body, but not the joints this exercise needs.
        case partial
        case good
    }

    /// The live pose is updated every camera frame (~30–60 Hz). It lives in its
    /// own observable object — NOT `@Published` on the controller — so only the
    /// skeleton overlay re-renders each frame, not the whole camera view. If it
    /// were on the controller, every frame would rebuild the count, buttons, and
    /// chrome, saturating the main thread and making the close button
    /// effectively untappable on a real device.
    let poseLayer = PoseLayer()

    let previewLayer = AVCaptureVideoPreviewLayer()

    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sampleQueue = DispatchQueue(label: "aura.pose.samples")
    private let poseRequest = VNDetectHumanBodyPoseRequest()
    private let engine: RepEngine
    private var isConfigured = false
    private var portraitBufferSize: CGSize = .zero
    /// Main-thread ownership generation. A delayed permission result may start
    /// only the same appearance that requested it; `stop()` invalidates it.
    private var lifecycleGeneration: UInt64 = 0

    /// Framing is debounced because pose detection flickers frame to frame — a
    /// hint that appears and vanishes twice a second is worse than no hint.
    /// Slow to complain and quick to shut up: two thirds of a second of trouble
    /// before it speaks, a third of a second of being fine before it goes.
    private var candidateFraming: Framing = .good
    private var candidateSince = Date()
    private static let complainAfter: TimeInterval = 0.7
    private static let clearAfter: TimeInterval = 0.3

    init(exercise: Exercise) {
        self.engine = RepEngine(exercise: exercise)
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
        sampleQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    /// Converts a Vision-normalized point (origin bottom-left) to a point in
    /// the preview layer's coordinate space, honouring aspect-fill + front-
    /// camera mirroring. The overlay fills the same frame as the preview, so
    /// these read directly as view coordinates.
    func viewPoint(for visionPoint: CGPoint) -> CGPoint {
        PoseCoordinateTransform.previewPoint(fromVisionPoint: visionPoint,
            bufferSize: portraitBufferSize, previewSize: previewLayer.bounds.size,
            mirrored: true)
    }

    @MainActor
    private func configureAndStart(generation: UInt64) {
        guard lifecycleGeneration == generation else { return }
        sampleQueue.async { [weak self] in
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

                self.videoOutput.setSampleBufferDelegate(self, queue: self.sampleQueue)
                self.videoOutput.alwaysDiscardsLateVideoFrames = true
                if self.session.canAddOutput(self.videoOutput) {
                    self.session.addOutput(self.videoOutput)
                }
                // Deliver an upright, unmirrored portrait buffer to Vision.
                // Mirror only the preview so the skeleton follows the visible
                // front-camera image without mirroring the buffer twice.
                if let connection = self.videoOutput.connection(with: .video) {
                    connection.videoOrientation = .portrait
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = false
                }
                if let connection = self.previewLayer.connection {
                    connection.videoOrientation = .portrait
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = true
                }
                self.session.commitConfiguration()
                self.isConfigured = true
            }
            if !self.session.isRunning { self.session.startRunning() }
        }
    }
}

extension PoseCameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // The output connection requests portrait buffers and leaves them
        // unmirrored, so Vision's native `.up` orientation matches the source.
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let bufferSize = CGSize(width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer))
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])
        try? handler.perform([poseRequest])

        // No early return on a missing observation any more: "no body at all"
        // is a state the screen has to be told about, and returning here meant
        // it never was.
        var bodyPose: BodyPose?
        if let observation = poseRequest.results?.first,
           let recognized = try? observation.recognizedPoints(.all) {
            var points: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
            for (name, point) in recognized where point.confidence >= 0.5 {
                points[name] = point.location
            }
            bodyPose = BodyPose(points: points)
        }

        let now = Date()
        let raw: Framing
        if let bodyPose {
            engine.consume(bodyPose, at: now)
            raw = engine.canRead ? .good : .partial
        } else {
            raw = .absent
        }

        if raw != candidateFraming {
            candidateFraming = raw
            candidateSince = now
        }
        let settleTime = raw == .good ? Self.clearAfter : Self.complainAfter
        let settled = now.timeIntervalSince(candidateSince) >= settleTime

        let reps = engine.reps
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.portraitBufferSize = bufferSize
            // Pose updates every frame (isolated to the overlay's own object).
            self.poseLayer.pose = bodyPose
            // Reps and framing change rarely — only publish on an actual change
            // so the main view isn't rebuilt on every frame.
            if self.reps != reps { self.reps = reps }
            if settled, self.framing != raw {
                withAnimation(.snappy(duration: 0.25)) { self.framing = raw }
            }
        }
    }
}

/// Vision sees an upright, unmirrored portrait buffer. Apply the same centered
/// aspect-fill crop as the preview, then its front-camera mirror exactly once.
enum PoseCoordinateTransform {
    static func previewPoint(fromVisionPoint point: CGPoint, bufferSize: CGSize,
                             previewSize: CGSize, mirrored: Bool) -> CGPoint {
        guard bufferSize.width > 0, bufferSize.height > 0 else { return .zero }
        let scale = max(previewSize.width / bufferSize.width, previewSize.height / bufferSize.height)
        let width = bufferSize.width * scale
        let height = bufferSize.height * scale
        return CGPoint(x: (mirrored ? 1 - point.x : point.x) * width + (previewSize.width - width) / 2,
                       y: (1 - point.y) * height + (previewSize.height - height) / 2)
    }
}

/// Holds just the live body pose, updated every camera frame. Kept separate
/// from `PoseCameraController` so the high-frequency pose stream only re-renders
/// the skeleton overlay that observes it — not the whole camera screen.
final class PoseLayer: ObservableObject {
    @Published var pose: BodyPose?
}
