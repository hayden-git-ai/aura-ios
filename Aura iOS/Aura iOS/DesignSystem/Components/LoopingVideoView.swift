//
//  LoopingVideoView.swift
//  Aura iOS
//

import AVFoundation
import SwiftUI

/// A seamlessly-looping, transparent video, for character animations too long to
/// ship as a PNG flipbook (a 30s loop would be hundreds of MB of frames and blow
/// the RAM budget; as HEVC-with-alpha it's a few MB, hardware-decoded).
///
/// The source must be **HEVC with an alpha channel** (`AVVideoCodecType
/// .hevcWithAlpha`) so it composites over whatever's behind it — the layer is
/// non-opaque and the pixel-buffer attributes request a format that carries
/// alpha. `AVPlayerLooper` gives gapless looping; the clip is authored so its
/// last frame flows into its first, so the wrap reads as continuous motion.
///
/// Playback pauses automatically when the view leaves the window (tab switch,
/// navigation) and resumes on return, so it never burns battery off-screen.
struct LoopingVideoView: UIViewRepresentable {
    /// Bundled resource name and extension (e.g. "HomeBlockedFox", "mov").
    let resource: String
    var ext: String = "mov"
    var isPlaying: Bool = true

    func makeUIView(context: Context) -> LoopingPlayerView {
        LoopingPlayerView(resource: resource, ext: ext, isPlaying: isPlaying)
    }

    func updateUIView(_ uiView: LoopingPlayerView, context: Context) {
        uiView.setPlaying(isPlaying)
    }
}

final class LoopingPlayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    private var looper: AVPlayerLooper?
    private let queue = AVQueuePlayer()
    private var wantsPlayback = true

    init(resource: String, ext: String, isPlaying: Bool = true) {
        super.init(frame: .zero)
        wantsPlayback = isPlaying
        // Transparent so the alpha channel shows the background through it.
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false

        guard let url = Bundle.main.url(forResource: resource, withExtension: ext) else { return }
        queue.isMuted = true
        // Never let the looping fox duck other audio or grab the session.
        queue.actionAtItemEnd = .advance
        // A tiny local clip — never wait to rebuffer, which was hitching the loop.
        queue.automaticallyWaitsToMinimizeStalling = false

        playerLayer.player = queue
        playerLayer.videoGravity = .resizeAspect
        // NO pixelBufferAttributes. AVPlayerLayer renders HEVC-with-alpha
        // transparently on its own as long as the layer is non-opaque; forcing a
        // 32BGRA pixel format made it convert every frame, which tore an
        // intermittent black band through the video.

        looper = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(url: url))
        reconcilePlayback()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setPlaying(_ playing: Bool) {
        wantsPlayback = playing
        reconcilePlayback()
    }

    private func reconcilePlayback() {
        if wantsPlayback && window != nil { queue.play() } else { queue.pause() }
    }

    // Pause when pulled off-screen, resume when returned — no wasted decode.
    override func didMoveToWindow() {
        super.didMoveToWindow()
        reconcilePlayback()
    }
}
