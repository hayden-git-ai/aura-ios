import AppKit
// args: <image> <mode alpha|green>
let a = CommandLine.arguments
let img = NSImage(contentsOfFile: a[1])!
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
let W = rep.pixelsWide, H = rep.pixelsHigh
let spp = rep.samplesPerPixel, bpr = rep.bytesPerRow
let data = rep.bitmapData!
let mode = a[2]
let key = (0.333, 0.655, 0.459)
func isFox(_ x:Int,_ y:Int)->Bool {
  let o = y*bpr + x*spp
  let r = Double(data[o])/255, g = Double(data[o+1])/255, b = Double(data[o+2])/255
  if mode == "alpha" { return spp >= 4 ? Double(data[o+3])/255 > 0.5 : false }
  let d = ((r-key.0)*(r-key.0)+(g-key.1)*(g-key.1)+(b-key.2)*(b-key.2)).squareRoot()
  return d > 0.36
}
var minX=W,maxX=0,minY=H,maxY=0
for y in 0..<H { for x in 0..<W { if isFox(x,y){ if x<minX{minX=x}; if x>maxX{maxX=x}; if y<minY{minY=y}; if y>maxY{maxY=y} } } }
let foxH = maxY-minY
let headBand = minY + Int(0.20*Double(foxH))
var sx=0.0, n=0.0
for y in minY...headBand { for x in 0..<W { if isFox(x,y){ sx+=Double(x); n+=1 } } }
let headAxis = sx/max(1,n)
print(String(format:"%@ %dx%d  bboxX[%d..%d] bboxY[%d..%d]  headAxisX=%.1f (%.4f)  feetY=%d (%.4f)  bboxCX=%.4f  foxH=%.4f",
  (a[1] as NSString).lastPathComponent, W,H, minX,maxX,minY,maxY, headAxis, headAxis/Double(W), maxY, Double(maxY)/Double(H), Double(minX+maxX)/2/Double(W), Double(foxH)/Double(H)))
