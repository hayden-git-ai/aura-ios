import AppKit
let img=NSImage(contentsOfFile:CommandLine.arguments[1])!, rep=NSBitmapImageRep(data:img.tiffRepresentation!)!
var b08=0,b25=0,b50=0
for y in 0..<rep.pixelsHigh{ for x in 0..<rep.pixelsWide{
  guard let c=rep.colorAt(x:x,y:y)?.usingColorSpace(.sRGB) else {continue}
  let r=c.redComponent,g=c.greenComponent,bl=c.blueComponent,a=c.alphaComponent
  if (g-bl)>0.10 && (r-g)<0.12 && max(r,max(g,bl))<0.85 {
    if a>0.08{b08+=1}; if a>0.25{b25+=1}; if a>0.50{b50+=1}
  }
}}
print("olive a>0.08: \(b08)  a>0.25: \(b25)  a>0.50: \(b50)")
