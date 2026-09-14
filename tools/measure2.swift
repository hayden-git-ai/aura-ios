import AppKit
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
  if mode == "alpha" { return spp >= 4 ? Double(data[o+3])/255 > 0.5 : false }
  let r = Double(data[o])/255, g = Double(data[o+1])/255, b = Double(data[o+2])/255
  let d = ((r-key.0)*(r-key.0)+(g-key.1)*(g-key.1)+(b-key.2)*(b-key.2)).squareRoot()
  return d > 0.42
}
var colCount = [Int](repeating:0,count:W), rowCount = [Int](repeating:0,count:H)
var total = 0
for y in 0..<H { for x in 0..<W { if isFox(x,y){ colCount[x]+=1; rowCount[y]+=1; total+=1 } } }
let colMin = max(4, W/150), rowMin = max(4, H/150)   // ignore speckle
let xs = (0..<W).filter{ colCount[$0] >= rowMin }
let ys = (0..<H).filter{ rowCount[$0] >= colMin }
let minX = xs.first ?? 0, maxX = xs.last ?? W-1, minY = ys.first ?? 0, maxY = ys.last ?? H-1
let foxH = maxY-minY
let headBand = minY + Int(0.20*Double(foxH))
var sx=0.0, n=0.0
for y in minY...headBand { for x in minX...maxX { if isFox(x,y){ sx+=Double(x); n+=1 } } }
let headAxis = sx/max(1,n)
print(String(format:"%@  foxFrac=%.3f  bboxX[%d..%d] bboxY[%d..%d]  headAxisXn=%.4f  feetYn=%.4f  topYn=%.4f  foxHn=%.4f  bboxCXn=%.4f",
  (a[1] as NSString).lastPathComponent, Double(total)/Double(W*H), minX,maxX,minY,maxY,
  headAxis/Double(W), Double(maxY)/Double(H), Double(minY)/Double(H), Double(foxH)/Double(H), Double(minX+maxX)/2/Double(W)))
