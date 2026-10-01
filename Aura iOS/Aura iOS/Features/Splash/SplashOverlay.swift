//
//  SplashOverlay.swift
//  Aura iOS
//
//  The launch splash: the fox animates (a transparent PNG sequence) centred on an
//  Aura-blue field, driven in sync with an audio track. In its last fraction a
//  circle opens from the centre to reveal whatever screen is mounted behind it —
//  Home for a returning user, onboarding for a new one. The circle is never drawn;
//  it's the boundary of a growing hole punched through the splash.
//

import AVFoundation
import SwiftUI
import UIKit

/// SwiftUI wrapper. Sits at the top of the app's ZStack over `RootGate`; calls
/// `onFinished` once the reveal has fully opened, at which point the parent drops
/// it from the hierarchy (invisibly, since by then the hole covers the screen).
struct SplashOverlay: View {
    /// How long the reveal takes, and therefore how far before the end it starts —
    /// so the circle finishes opening exactly as the animation and its audio end.
    var revealLead: Double = 0.4
    let onFinished: () -> Void

    var body: some View {
        SplashPlayerRepresentable(revealLead: revealLead, onFinished: onFinished)
            .ignoresSafeArea()
    }
}

private struct SplashPlayerRepresentable: UIViewRepresentable {
    var revealLead: Double = 0.4
    let onFinished: () -> Void

    func makeUIView(context: Context) -> SplashPlayerView {
        SplashPlayerView(revealLead: revealLead, onFinished: onFinished)
    }

    func updateUIView(_ uiView: SplashPlayerView, context: Context) {}

    static func dismantleUIView(_ uiView: SplashPlayerView, coordinator: ()) {
        uiView.cancelPlayback()
    }
}

/// Does the real work in UIKit: a fox image view flipped through the frame
/// sequence off a display link, an `AVAudioPlayer`, and a `CAShapeLayer` hole
/// animated with Core Animation for the reveal.
final class SplashPlayerView: UIView {
    /// Holds the rays + shadow + fox as one group, so the whole scene can scale/
    /// fade in together on appear (and the rays' own spin stays isolated inside it).
    private let contentView = UIView()
    private var didAnimateIn = false
    /// A rotating sunburst behind the fox — 8 lighter + 8 darker wedges, centred on
    /// the fox (screen centre), the same treatment the streak screen uses.
    private let raysLayer = CAGradientLayer()
    /// A solid oval shadow grounding the fox.
    private let groundShadow = CAShapeLayer()
    private let foxView = UIImageView()
    private var audioPlayer: AVAudioPlayer?
    private var displayLink: CADisplayLink?

    /// The fox frame sequence. Each frame's path is resolved and its image loaded
    /// fresh when shown, so the whole sequence never sits decoded in memory at once
    /// and only frame 0 is touched at launch.
    private let frameCount = 121
    private func framePath(_ index: Int) -> String? {
        Bundle.main.path(forResource: String(format: "Splash Screen_%03d", index + 1), ofType: "png")
    }
    private var frameDuration: Double = 1.0 / 30.0
    private var total: Double = 4.1
    private var lastIndex = -1
    private var start: CFTimeInterval = 0

    private let revealLead: Double
    private let onFinished: () -> Void
    private var revealing = false
    private var finished = false

    init(revealLead: Double, onFinished: @escaping () -> Void) {
        self.revealLead = revealLead
        self.onFinished = onFinished
        super.init(frame: .zero)
        // One shared asset colour, used here and by the launch screen, so the blue
        // is pixel-identical across the hand-off and doesn't shift when the app takes
        // over from the launch screen.
        let bg = UIColor(named: "SplashBackground")
            ?? UIColor(red: 0.2588, green: 0.6471, blue: 0.9608, alpha: 1) // #42A5F5
        backgroundColor = bg

        // Everything but the solid-blue field lives in `contentView`, so it can
        // scale + fade in as one on appear. Starts small and clear; `layoutSubviews`
        // animates it to full size the first time it lays out.
        contentView.isUserInteractionEnabled = false
        contentView.alpha = 0
        contentView.transform = CGAffineTransform(scaleX: 0.86, y: 0.86)
        addSubview(contentView)

        // Rotating sunburst behind everything: 16 hard-edged wedges, the DARKER of
        // which is the splash colour itself and the lighter a touch toward white, so
        // the field the fox already sat on now fans out from behind him. Centre is
        // the layer's centre, pinned to the fox's centre (screen centre) in layout.
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        bg.getRed(&r, green: &g, blue: &b, alpha: &a)
        let darkRay = bg.cgColor
        let lightRay = UIColor(red: r + (1 - r) * 0.15,
                               green: g + (1 - g) * 0.15,
                               blue: b + (1 - b) * 0.15, alpha: a).cgColor
        raysLayer.type = .conic
        raysLayer.startPoint = CGPoint(x: 0.5, y: 0.5)   // centre
        raysLayer.endPoint = CGPoint(x: 0.5, y: 0.0)     // 12 o'clock = 0
        var cols: [CGColor] = []
        var locs: [NSNumber] = []
        let rayCount = 16
        for i in 0..<rayCount {
            let c = i % 2 == 0 ? lightRay : darkRay
            cols.append(c); locs.append(NSNumber(value: Double(i) / Double(rayCount)))
            cols.append(c); locs.append(NSNumber(value: Double(i + 1) / Double(rayCount)))
        }
        raysLayer.colors = cols
        raysLayer.locations = locs
        contentView.layer.addSublayer(raysLayer)

        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = 0
        spin.toValue = 2 * Double.pi
        spin.duration = 24            // one slow turn; visible drift over the splash
        spin.repeatCount = .infinity
        spin.isRemovedOnCompletion = false
        raysLayer.add(spin, forKey: "spin")

        // A soft, dark oval shadow grounding the fox on the blue.
        groundShadow.fillColor = UIColor.black.withAlphaComponent(0.14).cgColor
        contentView.layer.addSublayer(groundShadow)

        foxView.contentMode = .scaleAspectFit
        foxView.clipsToBounds = true
        contentView.addSubview(foxView)

        // Only the first frame's path is resolved upfront — the other 120 are looked
        // up lazily per tick, off the launch path, so the splash shows sooner.
        guard let first = framePath(0), let firstImage = UIImage(contentsOfFile: first) else {
            DispatchQueue.main.async { [weak self] in self?.finish() }
            return
        }
        foxView.image = firstImage

        // Always audible, even with the ring switch off.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback)
        try? session.setActive(true)
        if let url = Bundle.main.url(forResource: "SplashScreen", withExtension: "mp3") {
            audioPlayer = try? AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
        }

        // The audio's length is the source of truth for how long the frames last,
        // so the two can't drift apart.
        total = audioPlayer?.duration ?? (Double(frameCount) / 30.0)
        frameDuration = total / Double(frameCount)

        start = CACurrentMediaTime()
        audioPlayer?.play()
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link

        // A splash that stalls must never sit on top of the app forever.
        DispatchQueue.main.asyncAfter(deadline: .now() + total + 2) { [weak self] in self?.finish() }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // The knobs. foxWidthFraction sizes the fox (body ÷ screen width); the fox's
    // centre is pinned to the screen centre; the nudges fine-tune by eye.
    private let foxWidthFraction: CGFloat = 0.40
    private let nudgeX: CGFloat = 0
    private let nudgeY: CGFloat = 0

    // Measured off the current frames, canvas 512×910: the fox's body centres at
    // (0.503, 0.494), feet at 0.652 down, and fills 0.416 of the canvas width.
    private let foxCanvasAspect: CGFloat = 910.0 / 512.0
    private let foxCenterXInCanvas: CGFloat = 0.503   // body centre, ignoring the tail
    private let foxCenterYInCanvas: CGFloat = 0.494
    private let foxFeetYInCanvas: CGFloat = 0.652
    private let foxBodyWidthInCanvas: CGFloat = 0.416

    override func layoutSubviews() {
        super.layoutSubviews()

        // Container fills the view. Set bounds + centre (not frame), so the scale-in
        // transform on `contentView` isn't clobbered by layout.
        contentView.bounds = bounds
        contentView.center = CGPoint(x: bounds.midX, y: bounds.midY)

        // Sunburst — a big square (so its corners still cover the screen as it spins)
        // centred on screen, which is also the fox's centre. No implicit animation on
        // the resize, or it would fight the spin.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let raySide = 2.6 * max(bounds.width, bounds.height)
        raysLayer.bounds = CGRect(x: 0, y: 0, width: raySide, height: raySide)
        raysLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        CATransaction.commit()

        // Fox, centred on screen.
        let bodyWidth = foxWidthFraction * bounds.width
        let canvasWidth = bodyWidth / foxBodyWidthInCanvas
        let canvasHeight = canvasWidth * foxCanvasAspect
        let originX = 0.5 * bounds.width - foxCenterXInCanvas * canvasWidth + nudgeX
        let originY = 0.5 * bounds.height - foxCenterYInCanvas * canvasHeight + nudgeY
        foxView.frame = CGRect(x: originX, y: originY, width: canvasWidth, height: canvasHeight)

        // Solid oval shadow under the fox's feet.
        let feetY = originY + foxFeetYInCanvas * canvasHeight
        let foxCenterXScreen = originX + foxCenterXInCanvas * canvasWidth
        // Match Home's shadow in its 260pt rendering frame; bodyWidth measures
        // only the visible fox and would make the contact shadow too small.
        let shadowW: CGFloat = 260 * 0.51
        let shadowH: CGFloat = 260 * 0.136
        groundShadow.frame = bounds
        // Nudged up 2px — it read a touch low under his body.
        groundShadow.path = UIBezierPath(ovalIn: CGRect(x: foxCenterXScreen - shadowW / 2,
                                                        y: feetY - shadowH / 2 - 2,
                                                        width: shadowW, height: shadowH)).cgPath

        // Scale + fade the whole scene in the first time we have a real size, so the
        // fox and rays grow in from the centre instead of snapping on.
        if !didAnimateIn, bounds.width > 0 {
            didAnimateIn = true
            UIView.animate(withDuration: 0.45, delay: 0, options: [.curveEaseOut]) {
                self.contentView.alpha = 1
                self.contentView.transform = .identity
            }
        }
    }

    /// Wall clock drives the frames — it keeps advancing even if audio fails, and
    /// over four seconds it stays locked to the audio, which runs at the same rate.
    @objc private func tick() {
        let elapsed = CACurrentMediaTime() - start
        let index = min(frameCount - 1, max(0, Int(elapsed / frameDuration)))
        if index != lastIndex {
            lastIndex = index
            if let path = framePath(index) { foxView.image = UIImage(contentsOfFile: path) }
        }
        if !revealing, elapsed >= total - revealLead { startReveal() }
    }

    /// Opens the hole from the centre out to the far corner over `revealLead`.
    private func startReveal() {
        guard !revealing, !finished, bounds.width > 0 else { return }
        revealing = true

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let maxRadius = hypot(bounds.width, bounds.height) / 2 + 1

        // Everything is filled except a circle at the centre; even-odd makes that
        // circle a hole. Grow the circle and the hole eats the splash outward.
        func holePath(_ radius: CGFloat) -> CGPath {
            let path = UIBezierPath(rect: bounds)
            path.append(UIBezierPath(ovalIn: CGRect(x: center.x - radius, y: center.y - radius,
                                                    width: radius * 2, height: radius * 2)))
            return path.cgPath
        }

        let mask = CAShapeLayer()
        mask.frame = bounds
        mask.fillRule = .evenOdd
        mask.path = holePath(maxRadius)   // final state, so it holds open after
        layer.mask = mask

        let anim = CABasicAnimation(keyPath: "path")
        anim.fromValue = holePath(0.0001)
        anim.toValue = holePath(maxRadius)
        anim.duration = revealLead
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        anim.isRemovedOnCompletion = false
        anim.fillMode = .forwards
        mask.add(anim, forKey: "reveal")

        DispatchQueue.main.asyncAfter(deadline: .now() + revealLead) { [weak self] in self?.finish() }
    }

    private func finish() {
        guard !finished else { return }
        cancelPlayback()
        onFinished()
    }

    /// A notification can remove the splash before its reveal completes. Stop
    /// immediately: the display link otherwise retains this view and its audio.
    func cancelPlayback() {
        guard !finished else { return }
        finished = true
        displayLink?.invalidate()
        displayLink = nil
        audioPlayer?.stop()
        audioPlayer = nil
        layer.removeAllAnimations()
        raysLayer.removeAllAnimations()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    deinit { displayLink?.invalidate() }
}
