import AppKit
import CoreGraphics

// Bakes Aura's sticker treatment into flat art: a white contour and a soft
// shadow beneath it.
//
//   swift sticker_outline.swift <out-dir> <in.png> [in2.png ...]
//
// Env overrides, all measured against a 512px source and scaled per file:
//   AURA_OUTLINE       white contour radius            (14)
//   AURA_DROP          how far the shadow sits below   (8)
//   AURA_BLUR          shadow softness                 (26)
//   AURA_SHADOW        shadow opacity                  (0.30)
//   AURA_STICKER_SIZE  final output side in px         (source size)
//
// Two things here are load-bearing and easy to undo by accident.
//
// The contour is built at 4x and downsampled. Stamping a silhouette around a
// circle at 1x destroys the anti-aliasing: each stamp writes hard alpha, they
// overlap, and every edge pixel saturates. The result is a binary mask and it
// looks exactly as ragged as that sounds.
//
// The ARTWORK is never upscaled. Only the mask is built big; the original
// composites at native size on top, so nothing softens.

let env = ProcessInfo.processInfo.environment
let args = CommandLine.arguments
guard args.count >= 3 else {
    print("usage: sticker_outline.swift <out-dir> <in.png>...")
    exit(1)
}
let outDir = URL(fileURLWithPath: args[1])
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let outlineRadius = CGFloat(env["AURA_OUTLINE"].flatMap(Double.init) ?? 18)
/// A soft shadow spreading evenly beneath, not a hard silhouette shoved aside.
/// The offset version read as a die-cut sticker lying on a page; this reads as
/// one floating just above it. The small downward nudge is gravity, not
/// displacement — enough to say which way is down, not enough to look doubled.
let shadowDrop = CGFloat(env["AURA_DROP"].flatMap(Double.init) ?? 8)
let shadowBlur = CGFloat(env["AURA_BLUR"].flatMap(Double.init) ?? 26)
let shadowAlpha = CGFloat(env["AURA_SHADOW"].flatMap(Double.init) ?? 0.30)
let outSize: Int? = env["AURA_STICKER_SIZE"].flatMap(Int.init)
/// A dark contour drawn between the artwork and the white one. Off by default.
///
/// For the fox, which is the one sticker whose artwork has no edge of its own.
/// Every other icon carries a drawn dark rim — the lock's grey, the chest's
/// brown, the calendar's blue — so a white contour has something to sit against.
/// White art on a white contour has nothing, and it disappears on light
/// grounds. This gives it the edge the others were drawn with.
/// How much of its box the artwork's ink takes up, after normalisation.
let fill = CGFloat(env["AURA_FILL"].flatMap(Double.init) ?? 0.82)
let inkRadius = CGFloat(env["AURA_INK"].flatMap(Double.init) ?? 0)
let inkGrey = CGFloat(env["AURA_INK_GREY"].flatMap(Double.init) ?? 0.62)

/// Whether the flood-filled holes get cut out of the contour entirely.
///
/// Off by default now. Dilation on its own already leaves a hole open with a
/// white rim inside it, which is what a die-cut sticker looks like — the white
/// follows every edge, including a hole's. Cutting the hole out flat removed
/// that rim. It only needs cutting when a hole is narrower than twice the
/// radius and would close completely.
let cutHoles = env["AURA_CUT_HOLES"] == "1"
let ss: CGFloat = 4
let ringSteps = 96

func context(_ w: Int, _ h: Int) -> CGContext? {
    CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
              space: CGColorSpaceCreateDeviceRGB(),
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
}

/// The art's shape, flat-filled: draw it, then paint the canvas through it.
/// `sourceIn` keeps the alpha and discards the colour, which is a silhouette.
func silhouette(_ image: CGImage, side: Int, height: Int? = nil, rect: CGRect, color: CGColor) -> CGImage? {
    let h = height ?? side
    guard let ctx = context(side, h) else { return nil }
    ctx.interpolationQuality = .high
    ctx.draw(image, in: rect)
    ctx.setBlendMode(.sourceIn)
    ctx.setFillColor(color)
    ctx.fill(CGRect(x: 0, y: 0, width: side, height: h))
    return ctx.makeImage()
}

/// The artwork's actual ink, ignoring transparent margin. In CG coordinates,
/// origin bottom-left.
///
/// Every export pads differently, so "the sticker" is never the same fraction of
/// the file twice. Drawing the file edge-to-edge therefore produces stickers at
/// different visual sizes AND outlines at different proportions, because a fixed
/// contour is a bigger share of a small drawing than of a large one. Measuring
/// the ink is what lets both be normalised.
/// Bounding box AND how many pixels inside it are actually inked.
///
/// The box alone is not size. A book fills its box; a guitar is a neck and some
/// gaps. Normalising boxes made every sticker occupy the same rectangle and the
/// dense ones still read half again as big.
/// Inked pixels — anything more than half opaque.
func alphaCoverage(of image: CGImage) -> CGFloat {
    let w = image.width, h = image.height
    guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
          let data = ctx.data else { return CGFloat(w * h) }
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    let px = data.bindMemory(to: UInt8.self, capacity: h * ctx.bytesPerRow)
    var n = 0
    for y in 0..<h {
        for x in 0..<w where px[y * ctx.bytesPerRow + x * 4 + 3] > 128 { n += 1 }
    }
    return max(1, CGFloat(n))
}

func alphaBounds(of image: CGImage) -> CGRect? {
    let w = image.width, h = image.height
    guard let ctx = context(w, h), let raw = ctx.data else { return nil }
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    let px = raw.bindMemory(to: UInt8.self, capacity: h * ctx.bytesPerRow)
    let row = ctx.bytesPerRow
    var minX = w, minY = h, maxX = -1, maxY = -1
    for y in 0..<h {
        for x in 0..<w where px[y * row + x * 4 + 3] > 8 {
            if x < minX { minX = x }
            if x > maxX { maxX = x }
            if y < minY { minY = y }
            if y > maxY { maxY = y }
        }
    }
    guard maxX >= minX, maxY >= minY else { return nil }
    return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
}

/// The enclosed transparent regions of a silhouette, as a solid mask.
///
/// Dilation closes any hole narrower than twice the contour radius, which is how
/// a padlock loses the gap under its shackle: the white grows in from both rims
/// and meets. A hole is not somewhere the sticker's edge should grow into, so
/// it gets cut back out. Found by flooding the transparent region inward from
/// the border — what the flood cannot reach is enclosed.
func holeMask(of image: CGImage, side: Int) -> CGImage? {
    guard let ctx = context(side, side), let raw = ctx.data else { return nil }
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
    let px = raw.bindMemory(to: UInt8.self, capacity: side * ctx.bytesPerRow)
    let rowBytes = ctx.bytesPerRow
    func alpha(_ x: Int, _ y: Int) -> UInt8 { px[y * rowBytes + x * 4 + 3] }

    var seen = [UInt8](repeating: 0, count: side * side)
    var stack: [Int] = []
    for x in 0..<side {
        for y in [0, side - 1] where alpha(x, y) < 128 && seen[y * side + x] == 0 {
            seen[y * side + x] = 1; stack.append(y * side + x)
        }
    }
    for y in 0..<side {
        for x in [0, side - 1] where alpha(x, y) < 128 && seen[y * side + x] == 0 {
            seen[y * side + x] = 1; stack.append(y * side + x)
        }
    }
    while let i = stack.popLast() {
        let x = i % side, y = i / side
        for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
            let nx = x + dx, ny = y + dy
            guard nx >= 0, nx < side, ny >= 0, ny < side else { continue }
            let j = ny * side + nx
            guard seen[j] == 0, alpha(nx, ny) < 128 else { continue }
            seen[j] = 1; stack.append(j)
        }
    }

    guard let out = context(side, side), let outRaw = out.data else { return nil }
    let outPx = outRaw.bindMemory(to: UInt8.self, capacity: side * out.bytesPerRow)
    let outRow = out.bytesPerRow
    for y in 0..<side {
        for x in 0..<side where alpha(x, y) < 128 && seen[y * side + x] == 0 {
            let o = y * outRow + x * 4
            outPx[o] = 255; outPx[o + 1] = 255; outPx[o + 2] = 255; outPx[o + 3] = 255
        }
    }
    return out.makeImage()
}

for path in args.dropFirst(2) {
    let url = URL(fileURLWithPath: path)
    guard let src = NSImage(contentsOf: url),
          let image = src.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        print("skip (unreadable): \(url.lastPathComponent)")
        continue
    }

    // A wordmark is not a sticker-shaped thing. Squaring the canvas letterboxes
    // it into a tall box that is mostly empty, which wastes resolution and makes
    // it awkward to place. `AURA_KEEP_ASPECT=1` sizes the canvas to the drawing
    // instead, keeping every ratio below relative to the LONGER side so the
    // contour and shadow come out the same weight as on a square sticker.
    let side = max(image.width, image.height)
    let sideF = CGFloat(side)
    let keepAspect = env["AURA_KEEP_ASPECT"] == "1"
    let canvasW = keepAspect ? CGFloat(image.width) : sideF
    let canvasH = keepAspect ? CGFloat(image.height) : sideF
    let scale = sideF / 512
    let r = outlineRadius * scale
    let dy = shadowDrop * scale
    let blur = shadowBlur * scale
    // Even on three sides, a little deeper underneath for the drop.
    let padSide = r + blur * 0.5 + 4 * scale
    // Where the INK has to land, not where the file goes.
    let box = CGRect(x: padSide, y: padSide + dy,
                     width: canvasW - padSide * 2,
                     height: canvasH - padSide * 2 - dy)

    // Scale the file so its ink fills that box on its longer axis, then centre
    // it. Every sticker ends up the same visual size in its own canvas, which
    // is what makes one contour width read the same on all of them.
    var artRect = box
    if let ink = alphaBounds(of: image) {
        // Matched by AREA, not by the longer side.
        //
        // Fitting the long side to the box makes every sticker the same HEIGHT
        // or the same WIDTH, which is not the same as the same size. A water
        // drop is tall and narrow, so filling the box vertically left it
        // covering 54% of its canvas while a dumbbell covered 75% — a third
        // less drawing, and it read a third smaller in a list beside it.
        //
        // The geometric mean matches the amount of ink instead, which is what
        // the eye compares. `fill` then hands back the margin most exports
        // carry, so a sticker doesn't come out bigger than the one it replaced.
        // Every sticker the same INK HEIGHT. Nothing cleverer.
        //
        // Area and ink-mass matching were both tried and both make the size
        // depend on the drawing's shape, which means you cannot look at a
        // number and know how big something will be. Height is one rule, it is
        // predictable, and a row of stickers is read along a line — so the
        // thing the eye lines up is how tall they are.
        //
        // Width still gets a clamp, so a very wide sticker can't run off the
        // canvas trying to hit the height.
        let k = min(box.height * fill / ink.height, box.width / ink.width)
        let drawn = CGSize(width: CGFloat(image.width) * k, height: CGFloat(image.height) * k)
        artRect = CGRect(x: box.midX - (ink.midX * k),
                         y: box.midY - (ink.midY * k),
                         width: drawn.width, height: drawn.height)
    }

    // --- contour, built at 4x ---
    let bigW = Int(canvasW * ss)
    let bigH = Int(canvasH * ss)
    let big = bigW
    var bigArt = artRect
    bigArt.origin.x *= ss; bigArt.origin.y *= ss
    bigArt.size.width *= ss; bigArt.size.height *= ss
    guard let sil = silhouette(image, side: bigW, height: bigH, rect: bigArt,
                               color: CGColor(red: 1, green: 1, blue: 1, alpha: 1)),
          let ringCtx = context(bigW, bigH) else { continue }

    let bigFull = CGRect(x: 0, y: 0, width: bigW, height: bigH)
    for step in 0..<ringSteps {
        let a = CGFloat(step) / CGFloat(ringSteps) * 2 * .pi
        ringCtx.draw(sil, in: bigFull.offsetBy(dx: cos(a) * r * ss, dy: sin(a) * r * ss))
    }
    guard var bigMask = ringCtx.makeImage() else { continue }

    if cutHoles, let holes = holeMask(of: sil, side: big), let cut = context(big, big) {
        cut.draw(bigMask, in: bigFull)
        cut.setBlendMode(.destinationOut)
        cut.draw(holes, in: bigFull)
        if let img = cut.makeImage() { bigMask = img }
    }

    let outW = Int(canvasW), outH = Int(canvasH)
    guard let downCtx = context(outW, outH) else { continue }
    downCtx.interpolationQuality = .high
    downCtx.draw(bigMask, in: CGRect(x: 0, y: 0, width: outW, height: outH))
    guard let mask = downCtx.makeImage(), let out = context(outW, outH) else { continue }

    // --- compose ---
    let full = CGRect(x: 0, y: 0, width: outW, height: outH)
    // Cast by the CONTOUR, not the artwork, so the shadow follows the white
    // border's silhouette the way a real sticker's would.
    out.setShadow(offset: CGSize(width: 0, height: -dy), blur: blur,
                  color: CGColor(red: 0, green: 0, blue: 0, alpha: shadowAlpha))
    out.draw(mask, in: full)
    out.setShadow(offset: .zero, blur: 0, color: nil)
    out.draw(mask, in: full)

    // The dark contour, if this asset asked for one: the same dilation at a
    // smaller radius, so it shows as a rim between the white and the art.
    if inkRadius > 0, let inkCtx = context(big, big) {
        let ir = inkRadius * scale
        for step in 0..<ringSteps {
            let a = CGFloat(step) / CGFloat(ringSteps) * 2 * .pi
            inkCtx.draw(sil, in: bigFull.offsetBy(dx: cos(a) * ir * ss, dy: sin(a) * ir * ss))
        }
        if let bigInk = inkCtx.makeImage(), let inkDown = context(outW, outH) {
            inkDown.interpolationQuality = .high
            inkDown.draw(bigInk, in: full)
            if let inkMask = inkDown.makeImage(), let tint = context(outW, outH) {
                tint.draw(inkMask, in: full)
                tint.setBlendMode(.sourceIn)
                tint.setFillColor(CGColor(red: inkGrey, green: inkGrey, blue: inkGrey * 1.04, alpha: 1))
                tint.fill(full)
                if let ink = tint.makeImage() { out.draw(ink, in: full) }
            }
        }
    }

    out.interpolationQuality = .high
    out.draw(image, in: artRect)

    guard var result = out.makeImage() else { continue }

    // Optional downsample to the size it's actually drawn at, in halving steps.
    // A 512px asset in a 48pt slot is a 3.5x minification done at draw time with
    // no mipmaps, on artwork whose character is a thin high-contrast edge. That
    // is what aliases. Halving steps rather than one jump: a single big leap
    // samples too sparsely and moves the aliasing rather than removing it.
    if let target = outSize, target < side {
        var current = result
        var w = side
        while w / 2 > target {
            let half = w / 2
            guard let c = context(half, half) else { break }
            c.interpolationQuality = .high
            c.draw(current, in: CGRect(x: 0, y: 0, width: half, height: half))
            guard let img = c.makeImage() else { break }
            current = img; w = half
        }
        if let c = context(target, target) {
            c.interpolationQuality = .high
            c.draw(current, in: CGRect(x: 0, y: 0, width: target, height: target))
            if let img = c.makeImage() { result = img }
        }
    }

    guard let data = NSBitmapImageRep(cgImage: result).representation(using: .png, properties: [:])
    else { continue }
    try? data.write(to: outDir.appendingPathComponent(url.lastPathComponent))
    print("outlined \(url.lastPathComponent) (\(side)px in, \(result.width)px out)")
}
