import AppKit
let img=NSImage(contentsOfFile:CommandLine.arguments[1])!, rep=NSBitmapImageRep(data:img.tiffRepresentation!)!
var g05=0,g15=0
for y in 0..<rep.pixelsHigh{ for x in 0..<rep.pixelsWide{
  guard let c=rep.colorAt(x:x,y:y)?.usingColorSpace(.sRGB) else {continue}
  let r=c.redComponent,gg=c.greenComponent,b=c.blueComponent,a=c.alphaComponent
  if a>0.05 && gg>r+0.03 && gg>b+0.02 { g05+=1; if a>0.15 {g15+=1} }
}}
print("green a>0.05: \(g05)  |  green a>0.15: \(g15)")
