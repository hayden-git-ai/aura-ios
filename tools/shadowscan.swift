import AppKit
for a in CommandLine.arguments.dropFirst() {
  guard let img=NSImage(contentsOfFile:a), let rep=NSBitmapImageRep(data:img.tiffRepresentation!) else { continue }
  let W=rep.pixelsWide,H=rep.pixelsHigh,spp=rep.samplesPerPixel,bpr=rep.bytesPerRow,d=rep.bitmapData!
  // buckets
  var transparent=0, opaque=0, semi=0
  var semiDark=0        // semi-transparent AND dark (shadow signature)
  var semiSumY=0.0, semiN=0.0
  // opaque silhouette bounds
  var minY=H,maxY=0
  for y in 0..<H { for x in 0..<W {
    let o=y*bpr+x*spp
    let al = spp>=4 ? Int(d[o+3]) : 255
    let r=Int(d[o]),g=Int(d[o+1]),b=Int(d[o+2])
    if al < 10 { transparent+=1 }
    else if al > 230 { opaque+=1; if y<minY{minY=y}; if y>maxY{maxY=y} }
    else {
      semi+=1
      // dark = low luminance; a drop shadow is gray/black at partial alpha
      let lum = (r+g+b)/3
      if lum < 130 { semiDark+=1; semiSumY+=Double(y); semiN+=1 }
    }
  }}
  let tot=W*H
  let semiDarkCY = semiN>0 ? semiSumY/semiN/Double(H) : 0
  print(String(format:"%@ %dx%d  opaque=%.1f%% semi=%.1f%% (of which dark=%.2f%% of img)  darkSemiCY=%.3f  foxYmid=%.3f",
    (a as NSString).lastPathComponent, W,H,
    100*Double(opaque)/Double(tot), 100*Double(semi)/Double(tot), 100*Double(semiDark)/Double(tot),
    semiDarkCY, Double(minY+maxY)/2/Double(H)))
}
