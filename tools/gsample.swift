import AppKit
let img=NSImage(contentsOfFile:CommandLine.arguments[1])!, rep=NSBitmapImageRep(data:img.tiffRepresentation!)!
let W=rep.pixelsWide,H=rep.pixelsHigh
// scan flame region (x 60-280, y 120-340), find most green-dominant opaque-ish pixels
var found:[(Int,Int,Double,Double,Double,Double)]=[]
for y in stride(from:120,to:340,by:2){ for x in stride(from:60,to:300,by:2){
  guard let c=rep.colorAt(x:x,y:y)?.usingColorSpace(.sRGB) else {continue}
  let r=c.redComponent,g=c.greenComponent,b=c.blueComponent,a=c.alphaComponent
  if a>0.25 && g>r+0.04 && g>b+0.04 { found.append((x,y,r,g,b,a)) }
}}
found.sort{ ($0.3 - max($0.2,$0.4)) > ($1.3 - max($1.2,$1.4)) } // Wrong idx; recompute
found.sort{ ($0.4 - max($0.3,$0.5)) > ($1.4 - max($1.3,$1.5)) }
print("greenest pixels (x,y,r,g,b,a):")
for p in found.prefix(8){ print(String(format:"  (%d,%d) #%02X%02X%02X a=%.2f  spill=%.3f",p.0,p.1,Int(p.2*255),Int(p.3*255),Int(p.4*255),p.5, p.3-max(p.2,p.4))) }
print("total greenish: \(found.count)")
