import AppKit
let img=NSImage(contentsOfFile:CommandLine.arguments[1])!, rep=NSBitmapImageRep(data:img.tiffRepresentation!)!
var olive=0
for y in 0..<rep.pixelsHigh{ for x in 0..<rep.pixelsWide{
  guard let c=rep.colorAt(x:x,y:y)?.usingColorSpace(.sRGB) else {continue}
  let r=c.redComponent,g=c.greenComponent,b=c.blueComponent,a=c.alphaComponent
  // olive-ish: g above blue, not orange, muted, visible
  if a>0.08 && (g-b)>0.10 && (r-g)<0.12 && max(r,max(g,b))<0.85 { olive+=1 }
}}
print("olive-ish pixels a>0.08: \(olive)")
