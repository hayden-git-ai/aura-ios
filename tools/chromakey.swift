//
//  chromakey.swift
//  Aura — green-screen keyer + alpha-video encoder (no external deps)
//
//  Reads one or more green-screen .mp4 clips, keys the green to transparency
//  with a spill-suppressing chroma key, downscales to Home size, and writes:
//    * mode "key":     one HEVC-with-alpha .mov (the shippable asset)
//    * mode "preview": one opaque .mov with the keyed fox composited over a
//                      background image, so the key can be eyeballed in context.
//
//  The key is a channel-space chroma key: greenness = g - max(r,b). Green screen
//  has a big positive spill (keyed out); white fur, black features and the red
//  dynamite all have ~zero-or-negative spill (kept). Despill pulls the green
//  channel down toward max(r,b) so there's no green fringe on the white edges.
//  Keying happens at full resolution, THEN we downscale — shrinking after the
//  key averages the edge pixels and hides any hard cut.
//
//  Stitch mode drops the last frame of every clip. Each clip starts and ends on
//  the same anchor pose, so dropping the trailing (duplicate) frame makes the
//  anchor appear exactly once at each seam and at the loop wrap — no held frame,
//  no visible skip.
//
//  Usage:
//    swift chromakey.swift key     <out.mov> <height> <strength> <despill> <stitch:0|1> <in...>
//    swift chromakey.swift preview <out.mov> <height> <strength> <despill> <bg.png>      <in...>
//

import AppKit
import AVFoundation
import CoreImage
import Foundation
import VideoToolbox

// MARK: - Args

let args = CommandLine.arguments
guard args.count >= 7 else {
    FileHandle.standardError.write(Data("usage: chromakey key|preview <out> <height> <strength> <despill> <stitch|bg> <in...>\n".utf8))
    exit(2)
}
let mode = args[1]
let outPath = args[2]
let targetHeight = CGFloat(Double(args[3]) ?? 660)
// `tolerance` is the outer color-distance radius: pixels farther than this from
// the sampled key colour are fully opaque. Inner radius (fully transparent) is
// derived below. `despill` (0..1) neutralizes green fringe on the fox edges.
let tolerance = Float(args[4]) ?? 0.36
let despill = Float(args[5]) ?? 1.0
let sixth = args[6]
let isPreview = (mode == "preview")
let isFrame = (mode == "frame")   // frame <out.png> <h> <tol> <despill> <input> <frameIdx>
let inputs = isFrame ? [sixth] : Array(args.dropFirst(7))
guard !inputs.isEmpty else {
    FileHandle.standardError.write(Data("no input clips given\n".utf8))
    exit(2)
}
let frameIdx = (isFrame && args.count > 7) ? (Int(args[7]) ?? 30) : 30
let stitch = (!isPreview && !isFrame && sixth == "1")
let bgPath: String? = isPreview ? sixth : nil

// MARK: - Core Image

let ciContext = CIContext(options: [
    .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
    .cacheIntermediates: false,
])

// Distance-space chroma key + despill, returning premultiplied RGBA.
// Alpha ramps from 0 (within `inner` of the key colour) to 1 (beyond `outer`),
// so the exact background colour is removed while the white fox and red dynamite
// — both far from the key colour — stay fully opaque with soft edges between.
// Two keys, whichever removes more (min alpha):
//  * distance to the sampled key colour — the bright green field.
//  * green dominance (g - max(r,b)) — catches the DARKENED green of the art's
//    own drop shadow, which the distance key leaves behind as a grey halo. The
//    fox (white / grey / black / red) is never green-dominant, so it's kept.
let kernelSource = """
kernel vec4 chromaKey(__sample s, vec3 keyColor, float inner, float outer, float despill, float spillLo, float spillHi, float keyIsBlue, float darkProtect) {
    vec3 c = s.rgb;
    float aDist = smoothstep(inner, outer, distance(c, keyColor));
    // Spill = how far the KEY channel (green, or BLUE when keyIsBlue) rises above the
    // other two. A blue screen is the opposite of the warm flame, so blue spill on the
    // flame's translucent edge despills straight back to warm — none of the olive /
    // yellow-green ambiguity green had (green sits next to the flame's yellow). And
    // nothing in the subject is blue (white fox, black eyes, warm flame), so the key
    // separates cleanly with no colour to argue about.
    // Contamination = key channel over its neighbour toward the warm subject: green
    // over RED (green mode), blue over GREEN (blue mode). A warm flame has b below g,
    // so `b - g` catches the blue/purple spill on its glow while sparing the flame
    // itself; the white fox has r=g=b so it is never touched.
    float keyCh = mix(c.g, c.b, keyIsBlue);
    // Blue-screen spill is measured against the brighter warm channel. Using
    // green alone treats blue-tinted black facial features as screen spill.
    float blueReference = mix(c.g, max(c.r, c.g), step(0.0, darkProtect));
    float refCh = mix(c.r, blueReference, keyIsBlue);
    float aSpill = 1.0 - smoothstep(spillLo, spillHi, keyCh - refCh);
    // Earn's dark facial features can carry blue spill-like tint. An opt-in
    // brightness threshold protects those interiors while leaving the default keyer
    // unchanged for every existing animation.
    // Keep low-luma facial details, but do not preserve a blue/purple screen
    // contour merely because it is dark. Earn's face tint is below this excess;
    // the saturated edge halo is above it and must remain keyable.
    float blueExcess = c.b - max(c.r, c.g);
    float dark = step(max(c.r, max(c.g, c.b)), darkProtect) * (1.0 - step(0.10, blueExcess));
    aSpill = mix(aSpill, 1.0, dark);
    float a = min(aDist, aSpill);
    // Despill: clamp the key channel down to that neighbour, so any surviving spill
    // goes neutral/warm, not tinted. White fox (r=g=b) is unchanged.
    float clamped = mix(min(keyCh, refCh), keyCh, dark);
    c.g = mix(clamped, c.g, keyIsBlue);   // green mode -> g:=clamped ; blue -> keep g
    c.b = mix(c.b, clamped, keyIsBlue);   // green mode -> keep b   ; blue -> b:=clamped
    return vec4(c * a, a);                // premultiplied
}
"""
guard let kernel = CIColorKernel(source: kernelSource) else {
    FileHandle.standardError.write(Data("failed to compile kernel\n".utf8))
    exit(1)
}

// The sampled background colour (set from the first frame). Inner radius is a
// fraction of the outer tolerance so there's always a soft transition band.
var keyColor = CIVector(x: 0.333, y: 0.655, z: 0.459)   // ~#55A775 fallback
let innerRadius = tolerance * 0.4
let outerRadius = tolerance
// Green-dominance band: below `lo` (neutral fox) kept, above `hi` (the shadow's
// darkened green) removed.
let spillLo = CGFloat(Double(ProcessInfo.processInfo.environment["CHROMA_SPILL_LO"] ?? "") ?? 0.02)
let spillHi = CGFloat(Double(ProcessInfo.processInfo.environment["CHROMA_SPILL_HI"] ?? "") ?? 0.07)
let darkProtect = CGFloat(Double(ProcessInfo.processInfo.environment["CHROMA_DARK_PROTECT"] ?? "") ?? -1)

// How far the removed green cast is pushed toward orange (vs grey). 0 = neutral
// despill (default, for the Home/Lock In clips); ~0.9 warms a flame's glow.
let warmth = CGFloat(Double(ProcessInfo.processInfo.environment["CHROMA_WARMTH"] ?? "") ?? 0)

// Per-clip colour gain (r,g,b), applied to the KEYED fox so a clip whose grey
// (tail / inner ears) drifted can be pulled back to match the others. Format:
// "r,g,b;r,g,b;..." — one triple per input clip, in input order; identity default.
let clipGains: [(CGFloat, CGFloat, CGFloat)] = (ProcessInfo.processInfo.environment["CHROMA_GAINS"] ?? "")
    .split(separator: ";")
    .map { triple in
        let p = triple.split(separator: ",").compactMap { Double($0) }
        return p.count == 3 ? (CGFloat(p[0]), CGFloat(p[1]), CGFloat(p[2])) : (CGFloat(1), CGFloat(1), CGFloat(1))
    }
/// Set before processing each clip; `process` multiplies the keyed RGB by it.
var currentGain: (r: CGFloat, g: CGFloat, b: CGFloat) = (1, 1, 1)

/// Multiply the keyed (premultiplied) RGB by `currentGain`, leaving alpha alone —
/// a gentle per-channel white-balance/brightness nudge on the kept fox.
func colourGain(_ img: CIImage) -> CIImage {
    if currentGain.r == 1 && currentGain.g == 1 && currentGain.b == 1 { return img }
    return img.applyingFilter("CIColorMatrix", parameters: [
        "inputRVector": CIVector(x: currentGain.r, y: 0, z: 0, w: 0),
        "inputGVector": CIVector(x: 0, y: currentGain.g, z: 0, w: 0),
        "inputBVector": CIVector(x: 0, y: 0, z: currentGain.b, w: 0),
        "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
    ])
}

func key(_ image: CIImage) -> CIImage {
    // Auto-detect the screen: blue if the sampled corner's blue channel dominates,
    // else green. Picks the right spill/despill axis with no flag to set.
    let keyIsBlue: CGFloat = (keyColor.z > keyColor.x && keyColor.z > keyColor.y) ? 1 : 0
    return kernel.apply(extent: image.extent,
                        arguments: [image, keyColor, innerRadius, outerRadius, despill, spillLo, spillHi, keyIsBlue, darkProtect])!
}

/// Average of the four corner pixels of a BGRA pixel buffer, in 0..1 sRGB — the
/// background colour, sampled straight off the source so the key tracks the
/// actual screen colour rather than a guess.
func sampleKeyColor(from pb: CVPixelBuffer) -> CIVector {
    CVPixelBufferLockBaseAddress(pb, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
    let w = CVPixelBufferGetWidth(pb), h = CVPixelBufferGetHeight(pb)
    let bpr = CVPixelBufferGetBytesPerRow(pb)
    guard let base = CVPixelBufferGetBaseAddress(pb) else { return keyColor }
    let ptr = base.assumingMemoryBound(to: UInt8.self)
    let corners = [(4, 4), (w - 5, 4), (4, h - 5), (w - 5, h - 5)]
    var r = 0.0, g = 0.0, b = 0.0
    for (x, y) in corners {
        let o = y * bpr + x * 4          // BGRA
        b += Double(ptr[o]); g += Double(ptr[o + 1]); r += Double(ptr[o + 2])
    }
    let n = Double(corners.count) * 255.0
    return CIVector(x: r / n, y: g / n, z: b / n)
}

func lanczosScaled(_ image: CIImage, to height: CGFloat) -> CIImage {
    let scale = height / image.extent.height
    let f = CIFilter(name: "CILanczosScaleTransform")!
    f.setValue(image, forKey: kCIInputImageKey)
    f.setValue(scale, forKey: kCIInputScaleKey)
    f.setValue(1.0, forKey: kCIInputAspectRatioKey)
    // Re-origin to (0,0) so render + pixel-buffer sizing line up.
    let out = f.outputImage!
    return out.transformed(by: CGAffineTransform(translationX: -out.extent.minX, y: -out.extent.minY))
}

// Optional normalization: a uniform scale + translate (given in normalized,
// TOP-LEFT canvas coords) that repositions the keyed fox so it lands in the
// square canvas exactly where a reference fox does. `CHROMA_S`/`CHROMA_TX`/
// `CHROMA_TY` set it; identity by default. Converts to Core Image's bottom-left
// origin internally.
let normS = CGFloat(Double(ProcessInfo.processInfo.environment["CHROMA_S"] ?? "1") ?? 1)
let normTX = CGFloat(Double(ProcessInfo.processInfo.environment["CHROMA_TX"] ?? "0") ?? 0)
let normTY = CGFloat(Double(ProcessInfo.processInfo.environment["CHROMA_TY"] ?? "0") ?? 0)

func normalized(_ img: CIImage, canvas c: CGFloat) -> CIImage {
    if normS == 1 && normTX == 0 && normTY == 0 { return img }
    let t = CGAffineTransform(a: normS, b: 0, c: 0, d: normS,
                              tx: normTX * c, ty: c * (1 - normS - normTY))
    return img.transformed(by: t)
}

/// Erode the alpha (and premultiplied colour) by `radius` px, shaving the outer
/// ring off every shape. This is how the flame's contaminated edge rim is removed
/// entirely rather than recoloured: a morphological min needs neighbours, which the
/// per-pixel colour kernel does not have. `CHROMA_ERODE` px at source resolution.
let erodePx = CGFloat(Double(ProcessInfo.processInfo.environment["CHROMA_ERODE"] ?? "0") ?? 0)
func erodeAlpha(_ img: CIImage) -> CIImage {
    if erodePx <= 0 { return img }
    // Erode the ALPHA ONLY, preserving true colour. Running CIMorphologyMinimum on
    // the premultiplied image mins the colour channels too, dragging the edge toward
    // black — a dark fringe around the white fox. Instead: recover straight colour,
    // build an alpha-only mask, erode THAT, and re-shape the full-alpha colour image
    // through the eroded mask. The colour image is opaque everywhere, so the eroded
    // boundary (which sits inside the original shape, over true colour) never picks
    // up black.
    let straight = img.unpremultiplyingAlpha()
    let colourOpaque = straight.applyingFilter("CIColorMatrix", parameters: [
        "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
        "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 1)   // alpha := 1, colour kept
    ])
    let alphaMask = straight.applyingFilter("CIColorMatrix", parameters: [
        "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 1),
        "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 1),
        "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 1),
        "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)      // rgb := a, alpha := a
    ])
    let erodedMask = alphaMask.applyingFilter("CIMorphologyMinimum", parameters: ["inputRadius": erodePx])
    let clear = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0)).cropped(to: img.extent)
    let out = colourOpaque.applyingFilter("CIBlendWithMask", parameters: [
        "inputBackgroundImage": clear,
        "inputMaskImage": erodedMask
    ])
    return out.cropped(to: img.extent)
}

/// Key -> scale to Home height -> erode rim -> reposition. One pipeline per frame.
/// Erosion runs at OUTPUT resolution: eroding before the Lanczos downscale just
/// lets the downscale re-feather the edge, so the rim comes back.
func process(_ src: CIImage) -> CIImage {
    let scaled = erodeAlpha(lanczosScaled(colourGain(key(src)), to: targetHeight))
    // Trim the faint Lanczos edge HERE, before normalization scales/shifts it
    // inward — a normalized fox (Home) moves that edge off the frame boundary,
    // where the buffer-edge clear can't reach it, so it must go first.
    let trimmed = scaled.cropped(to: scaled.extent.insetBy(dx: 4, dy: 4))
    return normalized(trimmed, canvas: targetHeight)
}

var previewBG: CIImage?
if let bgPath {
    if let data = FileManager.default.contents(atPath: bgPath),
       let img = CIImage(data: data) {
        previewBG = img
    } else {
        FileHandle.standardError.write(Data("could not load bg \(bgPath)\n".utf8))
        exit(1)
    }
}

// MARK: - Reader helpers

func makeReader(_ path: String) -> (AVAssetReader, AVAssetReaderTrackOutput, CGSize, Float)? {
    let asset = AVAsset(url: URL(fileURLWithPath: path))
    guard let track = asset.tracks(withMediaType: .video).first,
          let reader = try? AVAssetReader(asset: asset) else { return nil }
    let out = AVAssetReaderTrackOutput(track: track, outputSettings: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
    ])
    out.alwaysCopiesSampleData = false
    reader.add(out)
    let size = track.naturalSize.applying(track.preferredTransform)
    let dims = CGSize(width: abs(size.width), height: abs(size.height))
    return (reader, out, dims, track.nominalFrameRate)
}

// Frame mode: key a single frame and write it out as a straight-alpha PNG, for
// measuring the fox's real on-screen geometry off the actual keyed alpha.
if isFrame {
    guard let (reader, out, _, _) = makeReader(inputs[0]) else { exit(1) }
    reader.startReading()
    var idx = 0
    var chosen: CIImage?
    var canvasRect = CGRect.zero
    while let sb = out.copyNextSampleBuffer() {
        guard let buf = CMSampleBufferGetImageBuffer(sb) else { continue }
        if idx == frameIdx {
            // Sample the key colour from THIS frame (not frame 0 — a clip with a
            // stray intro frame of a different colour would mis-key otherwise).
            keyColor = sampleKeyColor(from: buf)
            currentGain = clipGains.first ?? (1, 1, 1)
            // Run the SAME pipeline the shipping writer uses (key -> erode -> scale
            // -> normalize), so a frame dump reflects exactly what ships.
            let img = process(CIImage(cvPixelBuffer: buf))
            canvasRect = CGRect(x: 0, y: 0, width: targetHeight, height: targetHeight)
            chosen = img
            break
        }
        idx += 1
    }
    reader.cancelReading()
    guard let outImg = chosen,
          let cg = ciContext.createCGImage(outImg, from: canvasRect,
                                           format: .RGBA8,
                                           colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!) else { exit(1) }
    let rep = NSBitmapImageRep(cgImage: cg)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: outPath))
    FileHandle.standardError.write(Data("wrote keyed frame \(frameIdx) -> \(outPath)\n".utf8))
    exit(0)
}

// Probe the first clip for output geometry + fps.
guard let (probeReader, _, srcSize, srcFps) = makeReader(inputs[0]) else {
    FileHandle.standardError.write(Data("cannot open \(inputs[0])\n".utf8))
    exit(1)
}
probeReader.cancelReading()

let fps: Int = srcFps > 1 ? Int(srcFps.rounded()) : 30
let outHeight = targetHeight
let outWidth = (srcSize.width / srcSize.height) * outHeight
// HEVC wants even dimensions.
let W = Int(outWidth.rounded() / 2) * 2
let H = Int(outHeight.rounded() / 2) * 2
FileHandle.standardError.write(Data("source \(Int(srcSize.width))x\(Int(srcSize.height)) @\(srcFps)fps -> \(W)x\(H) @\(fps)fps\n".utf8))

// MARK: - Writer

let outURL = URL(fileURLWithPath: outPath)
try? FileManager.default.removeItem(at: outURL)
guard let writer = try? AVAssetWriter(outputURL: outURL, fileType: .mov) else {
    FileHandle.standardError.write(Data("cannot create writer\n".utf8))
    exit(1)
}

var videoSettings: [String: Any]
if isPreview {
    videoSettings = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: W,
        AVVideoHeightKey: H,
    ]
} else {
    // Average-bitrate cap keeps motion-heavy clips (dynamite) from ballooning
    // the file the way pure quality-VBR does; alpha channel kept high-quality
    // separately so edges stay crisp. Override with CHROMA_BITRATE (bits/sec).
    let bitrate = Int(ProcessInfo.processInfo.environment["CHROMA_BITRATE"] ?? "") ?? 2_800_000
    let alphaQ = Double(ProcessInfo.processInfo.environment["CHROMA_ALPHAQ"] ?? "") ?? 0.9
    var compression: [String: Any] = [
        AVVideoAverageBitRateKey: bitrate,
        kVTCompressionPropertyKey_TargetQualityForAlpha as String: alphaQ,
    ]
    // CHROMA_KEYINT=1 forces every frame to be a keyframe (intra-only): no frame
    // depends on another, so a decode hiccup can't band through a run of frames.
    if let keyint = Int(ProcessInfo.processInfo.environment["CHROMA_KEYINT"] ?? "") {
        compression[AVVideoMaxKeyFrameIntervalKey] = keyint
        compression[AVVideoMaxKeyFrameIntervalDurationKey] = 0
    }
    videoSettings = [
        AVVideoCodecKey: AVVideoCodecType.hevcWithAlpha,
        AVVideoWidthKey: W,
        AVVideoHeightKey: H,
        AVVideoCompressionPropertiesKey: compression,
    ]
}

let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
input.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(
    assetWriterInput: input,
    sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: W,
        kCVPixelBufferHeightKey as String: H,
    ]
)
writer.add(input)
writer.startWriting()
writer.startSession(atSourceTime: .zero)

func makeBuffer() -> CVPixelBuffer? {
    guard let pool = adaptor.pixelBufferPool else { return nil }
    var pb: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pb)
    return pb
}

// Background scaled to fill the output canvas, for preview compositing.
var scaledBG: CIImage?
if let previewBG {
    // High-quality (Lanczos) fill so the mocked-in backdrop stays sharp — this
    // is preview-only dressing; the shipped asset is the fox on transparency.
    let s = max(CGFloat(W) / previewBG.extent.width, CGFloat(H) / previewBG.extent.height)
    let f = CIFilter(name: "CILanczosScaleTransform")!
    f.setValue(previewBG, forKey: kCIInputImageKey)
    f.setValue(s, forKey: kCIInputScaleKey)
    f.setValue(1.0, forKey: kCIInputAspectRatioKey)
    let scaled = f.outputImage!
    scaledBG = scaled.transformed(by: CGAffineTransform(translationX: -scaled.extent.minX, y: -scaled.extent.minY))
}

var frameIndex = 0
let queue = DispatchQueue(label: "chromakey.render")
let done = DispatchSemaphore(value: 0)

func render(_ keyedScaled: CIImage, into pb: CVPixelBuffer) {
    if isPreview, let bg = scaledBG {
        // Center the fox over the background at native (already target-height) size.
        let dx = (CGFloat(W) - keyedScaled.extent.width) / 2
        let composited = keyedScaled
            .transformed(by: CGAffineTransform(translationX: dx, y: 0))
            .composited(over: bg)
            .cropped(to: CGRect(x: 0, y: 0, width: W, height: H))
        ciContext.render(composited, to: pb)
    } else {
        ciContext.render(keyedScaled, to: pb)
    }
}

/// Zero the outer `b` pixels of a BGRA buffer. Lanczos downscale leaves a faint
/// (~11% black) alpha ring at the frame boundary; over a light background that
/// reads as a thin grey rectangle, so it's cleared to fully transparent.
func zeroBorder(_ pb: CVPixelBuffer, _ b: Int) {
    let w = CVPixelBufferGetWidth(pb), h = CVPixelBufferGetHeight(pb)
    let bpr = CVPixelBufferGetBytesPerRow(pb)
    guard let base = CVPixelBufferGetBaseAddress(pb) else { return }
    let ptr = base.assumingMemoryBound(to: UInt8.self)
    for y in 0..<b { memset(ptr + y * bpr, 0, w * 4); memset(ptr + (h - 1 - y) * bpr, 0, w * 4) }
    for y in 0..<h { for x in 0..<b {
        for o in [y * bpr + x * 4, y * bpr + (w - 1 - x) * 4] { ptr[o] = 0; ptr[o+1] = 0; ptr[o+2] = 0; ptr[o+3] = 0 }
    }}
}

func append(_ keyedScaled: CIImage) {
    while !input.isReadyForMoreMediaData { usleep(2000) }
    guard let pb = makeBuffer() else { return }
    CVPixelBufferLockBaseAddress(pb, [])
    render(keyedScaled, into: pb)
    if !isPreview { zeroBorder(pb, 5) }
    CVPixelBufferUnlockBaseAddress(pb, [])
    let pts = CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(fps))
    adaptor.append(pb, withPresentationTime: pts)
    frameIndex += 1
}

// Frames to drop from the START of the FIRST clip — a clip that opens on a stray
// frame (e.g. a green intro frame before the real blue take) would otherwise have
// its key colour sampled from that frame and mis-key everything after it.
let skipFirst = Int(ProcessInfo.processInfo.environment["CHROMA_SKIP"] ?? "") ?? 0

input.requestMediaDataWhenReady(on: queue) {
    for (clipIndex, path) in inputs.enumerated() {
        currentGain = clipIndex < clipGains.count ? clipGains[clipIndex] : (1, 1, 1)
        guard let (reader, out, _, _) = makeReader(path) else { continue }
        reader.startReading()
        var pending: CIImage?
        var sampledThisClip = false
        var skipRemaining = clipIndex == 0 ? skipFirst : 0
        while let sb = out.copyNextSampleBuffer() {
            guard let buf = CMSampleBufferGetImageBuffer(sb) else { continue }
            // Drop the intro frames BEFORE sampling, so the key colour comes from
            // the real take, not the stray frame.
            if skipRemaining > 0 { skipRemaining -= 1; continue }
            // Re-sample the background off each clip's first kept frame, so a slight
            // per-clip shift in the green/blue never leaves a halo.
            if !sampledThisClip { keyColor = sampleKeyColor(from: buf); sampledThisClip = true }
            let keyed = process(CIImage(cvPixelBuffer: buf))
            if let p = pending { append(p) }
            pending = keyed
        }
        // Drop the trailing anchor frame when stitching multiple clips (key mode
        // via the stitch flag, or any multi-clip preview) so the shared anchor
        // pose shows once per seam; keep it for a single-clip pass.
        let dropLast = stitch || (inputs.count > 1)
        if let p = pending, !dropLast { append(p) }
        reader.cancelReading()
    }
    input.markAsFinished()
    writer.finishWriting { done.signal() }
}

done.wait()
if writer.status == .failed {
    FileHandle.standardError.write(Data("writer failed: \(String(describing: writer.error))\n".utf8))
    exit(1)
}
FileHandle.standardError.write(Data("wrote \(frameIndex) frames -> \(outPath)\n".utf8))
