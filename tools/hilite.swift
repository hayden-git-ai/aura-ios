import AppKit
let img=NSImage(contentsOfFile:CommandLine.arguments[1])!, rep=NSBitmapImageRep(data:img.tiffRepresentation!)!
let W=rep.pixelsWide,H=rep.pixelsHigh
let out=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:W,pixelsHigh:H,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
for y in 0..<H{ for x in 0..<W{
  guard let c=rep.colorAt(x:x,y:y)?.usingColorSpace(.sRGB) else {continue}
  let r=c.redComponent,g=c.greenComponent,b=c.blueComponent,a=c.alphaComponent
  if a>0.25 && (g-b)>0.10 && (r-g)<0.12 && max(r,max(g,b))<0.85 {
    out.setColor(NSColor(red:1,green:0,blue:1,alpha:1),atX:x,y:y)  // magenta = olive
  } else {
    out.setColor(NSColor(white:0.9,alpha:a>0.3 ?1:0.15),atX:x,y:y)  // gray fox silhouette
  }
}}
try! out.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:CommandLine.arguments[2]))
