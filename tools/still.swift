import AVFoundation
import AppKit
let a = CommandLine.arguments
let asset = AVAsset(url: URL(fileURLWithPath: a[1]))
let g = AVAssetImageGenerator(asset: asset)
g.appliesPreferredTrackTransform = true
g.requestedTimeToleranceBefore = .zero; g.requestedTimeToleranceAfter = .zero
let t = CMTime(seconds: Double(a[3]) ?? 2.5, preferredTimescale: 600)
let cg = try! g.copyCGImage(at: t, actualTime: nil)
let rep = NSBitmapImageRep(cgImage: cg)
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: a[2]))
print("wrote \(a[2]) \(cg.width)x\(cg.height)")
