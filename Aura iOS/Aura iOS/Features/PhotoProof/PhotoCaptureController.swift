//
//  PhotoCaptureController.swift
//  Aura iOS
//

import SwiftUI
import Combine
import AVFoundation

/// Runs the (back, flippable) camera and captures a single still for the Photo
/// Proof flow. Kept in-memory only — the captured `UIImage` is never written to
/// disk or Photos. Meaningful only on a physical device; the simulator has no
/// camera, so the view shows a fallback.
final class PhotoCaptureController: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var isDenied = false
    @Published var capturedImage: UIImage?
    @Published private(set) var position: AVCaptureDevice.Position = .back

    let previewLayer = AVCaptureVideoPreviewLayer()

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "aura.photo.session")
    private var currentInput: AVCaptureDeviceInput?
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

    func flip() {
        position = position == .back ? .front : .back
        sessionQueue.async { [weak self] in self?.reconfigureInput() }
    }

    func capture() {
        sessionQueue.async { [weak self] in
            guard let self, self.isConfigured else { return }
            self.photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
    }

    @MainActor
    private func configureAndStart(generation: UInt64) {
        guard lifecycleGeneration == generation else { return }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.isConfigured {
                self.session.beginConfiguration()
                self.session.sessionPreset = .photo
                self.addInput()
                if self.session.canAddOutput(self.photoOutput) {
                    self.session.addOutput(self.photoOutput)
                }
                self.session.commitConfiguration()
                self.isConfigured = true
            }
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    private func addInput() {
        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else { return }
        session.addInput(input)
        currentInput = input
    }

    private func reconfigureInput() {
        session.beginConfiguration()
        if let currentInput { session.removeInput(currentInput) }
        addInput()
        session.commitConfiguration()
    }
}

extension PhotoCaptureController: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { return }
        DispatchQueue.main.async { [weak self] in self?.capturedImage = image }
    }
}
