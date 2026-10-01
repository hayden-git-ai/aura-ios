//
//  TiredFoxFrameAnimation.swift
//  Aura iOS
//

import SwiftUI

/// A frame-by-frame sprite animation of the tired fox, driven by a set of
/// discrete PNGs (`tired_fox_animation_001`…`_NNN`) shown in sequence.
///
/// Design intent: this is a hard-cut flipbook, not a tween — there is no
/// crossfade or interpolation between frames, and the layout never resizes or
/// shifts as frames swap (the frame's own aspect ratio is fixed up front). The
/// PNGs' transparency is preserved so it drops onto any background. With a full
/// 120-frame export the hard cuts are imperceptible — it reads as continuous
/// motion, which is what makes a flipbook look smooth rather than stepped.
///
/// Playback is driven by `TimelineView(.animation)`, which ticks on the display
/// refresh (up to ProMotion 120Hz) — the shown frame is derived from *elapsed
/// time*, not a fixed-interval `Timer`, so it never drifts or stutters at high
/// frame rates the way a 24fps timer would. The timeline only advances while
/// the view is on screen, so it pauses on disappear for free; re-appearing
/// resets the clock and restarts from frame 0.
///
/// The images are decoded exactly once into a `[UIImage]` cache on first
/// appear — the render path only indexes that array each tick and never
/// re-reads the bundle. Frames are stored at 512px (see the asset catalog), so
/// the resident cost is ~1MB/frame rather than the ~4MB/frame a 1024px source
/// would incur.
struct TiredFoxFrameAnimation: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var isPlaying: Bool = true
    /// Playback rate. The loop length is `frameCount / fps` — e.g. 120 frames
    /// at 24fps is a 5.0s loop; at 30fps it's a 4.0s loop.
    var fps: Double = 24
    /// `true` loops forever; `false` plays the sequence once and holds the
    /// last frame.
    var loops: Bool = true

    /// Explicit frame asset names, in play order. `nil` (the default) auto-
    /// detects `tired_fox_animation_001`, `_002`, … until the first gap — so
    /// re-exporting with more or fewer frames needs no code change here.
    var frameNames: [String]? = nil

    /// Decoded once in `.onAppear` — the render path indexes this, never the
    /// bundle. Kept as `UIImage` because `UIImage(named:)` resolves both asset
    /// catalog entries and loose bundle PNGs, where SwiftUI's `Image(_:)` is
    /// unreliable for the latter.
    @State private var frames: [UIImage] = []
    /// The wall-clock instant playback (re)started. Reset on every appear so
    /// the loop always begins at frame 0 when the view returns.
    @State private var startedAt: Date?

    var body: some View {
        Group {
            if frames.isEmpty {
                // Holds the layout slot until the frames decode.
                Color.clear
            } else {
                TimelineView(.animation(paused: !isPlaying || scenePhase != .active || reduceMotion)) { context in
                    Image(uiImage: frames[frameIndex(at: context.date)])
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                }
            }
        }
        .onAppear {
            loadFramesIfNeeded()
            startedAt = Date()
        }
        .onDisappear {
            // Drop the clock so the next appear restarts cleanly from frame 0.
            startedAt = nil
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { startedAt = Date() }
        }
        .onChange(of: isPlaying) { _, playing in
            if playing { startedAt = Date() }
        }
    }

    // MARK: - Frame selection

    /// The frame to show at `date`, derived from elapsed time since playback
    /// started — so the animation is a pure function of the clock and can't
    /// drift regardless of refresh rate.
    private func frameIndex(at date: Date) -> Int {
        guard let startedAt, frames.count > 1 else { return 0 }
        let elapsed = max(0, date.timeIntervalSince(startedAt))
        let raw = Int(elapsed * fps)
        if loops {
            return raw % frames.count
        }
        // Play-once: advance to the last frame and hold it.
        return min(raw, frames.count - 1)
    }

    // MARK: - Frame loading

    private func loadFramesIfNeeded() {
        guard frames.isEmpty else { return }
        if let frameNames {
            frames = frameNames.compactMap { UIImage(named: $0) }
        } else {
            frames = Self.autoDetectedFrames()
        }
    }

    /// Loads `tired_fox_animation_001`, `_002`, … in order, stopping at the
    /// first index that doesn't resolve. The upper bound is just a runaway
    /// guard — real exports are far smaller.
    private static func autoDetectedFrames() -> [UIImage] {
        var loaded: [UIImage] = []
        for i in 1...999 {
            let name = String(format: "tired_fox_animation_%03d", i)
            guard let image = UIImage(named: name) else { break }
            loaded.append(image)
        }
        return loaded
    }
}

#Preview {
    ZStack {
        Theme.Color.background.ignoresSafeArea()
        TiredFoxFrameAnimation()
            .frame(width: 240, height: 240)
    }
    .preferredColorScheme(.dark)
}
