import AppKit
// args: bg foxPng out W H foxSizePt baseY timerY shadowOpacity shadowDY(frac of foxSize, + = lower)
let a = CommandLine.arguments
let bg = NSImage(contentsOfFile: a[1])!, fox = NSImage(contentsOfFile: a[2])!
let W = CGFloat(Double(a[4])!), H = CGFloat(Double(a[5])!)
let foxSize = CGFloat(Double(a[6])!), baseY = CGFloat(Double(a[7])!), timerY = CGFloat(Double(a[8])!)
let shOp = CGFloat(Double(a[9]) ?? 0.18), shDY = CGFloat(Double(a[10]) ?? 0.0)
let sc: CGFloat = 2
let cw = Int(W*sc), ch = Int(H*sc)
let img = NSImage(size: NSSize(width: cw, height: ch)); img.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext
let br = bg.size; let s = max(CGFloat(cw)/br.width, CGFloat(ch)/br.height)
let bw = br.width*s, bh = br.height*s
bg.draw(in: NSRect(x: (CGFloat(cw)-bw)/2, y: (CGFloat(ch)-bh)/2, width: bw, height: bh))
let fs = foxSize*sc
let baseYpx = baseY*CGFloat(ch)
let shW = fs*0.64, shH = fs*0.15
let shCenterTop = baseYpx + shDY*fs
ctx.setFillColor(NSColor.black.withAlphaComponent(shOp).cgColor)
ctx.fillEllipse(in: CGRect(x: CGFloat(cw)/2 - shW/2, y: CGFloat(ch)-shCenterTop-shH/2, width: shW, height: shH))
let foxY = CGFloat(ch) - baseYpx - 0.11*fs
fox.draw(in: NSRect(x: CGFloat(cw)/2 - fs/2, y: foxY, width: fs, height: fs))
ctx.setFillColor(NSColor.systemRed.withAlphaComponent(0.9).cgColor)
ctx.fillEllipse(in: CGRect(x: CGFloat(cw)/2-14, y: CGFloat(ch)-timerY*CGFloat(ch)-14, width: 28, height: 28))
img.unlockFocus()
try! NSBitmapImageRep(data: img.tiffRepresentation!)!.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: a[3]))
print("wrote \(a[3])")
