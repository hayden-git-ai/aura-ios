import AppKit
for a in CommandLine.arguments.dropFirst() {
  guard let img=NSImage(contentsOfFile:a), let rep=NSBitmapImageRep(data:img.tiffRepresentation!) else { continue }
  let W=rep.pixelsWide,H=rep.pixelsHigh,spp=rep.samplesPerPixel,bpr=rep.bytesPerRow,d=rep.bitmapData!
  var minX=W,maxX=0,minY=H,maxY=0
  for y in 0..<H { for x in 0..<W {
    let al = spp>=4 ? Int(d[y*bpr+x*spp+3]) : 255
    if al > 40 { if x<minX{minX=x}; if x>maxX{maxX=x}; if y<minY{minY=y}; if y>maxY{maxY=y} }
  }}
  let cx = Double(minX+maxX)/2/Double(W), cy = Double(minY+maxY)/2/Double(H)
  print(String(format:"%@  cx=%.4f cy=%.4f  (bbox x[%d..%d] y[%d..%d] of %dx%d)",(a as NSString).lastPathComponent,cx,cy,minX,maxX,minY,maxY,W,H))
}
