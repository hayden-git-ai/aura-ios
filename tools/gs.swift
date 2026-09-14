import AppKit
let img=NSImage(contentsOfFile:CommandLine.arguments[1])!, rep=NSBitmapImageRep(data:img.tiffRepresentation!)!
// sample points in the left + right flame glow
let pts=[(95,165),(110,185),(130,150),(120,210),(495,150),(510,175),(540,160),(480,200)]
for (x,y) in pts { if let c=rep.colorAt(x:x,y:y)?.usingColorSpace(.sRGB){
  let r=c.redComponent,g=c.greenComponent,b=c.blueComponent,a=c.alphaComponent
  print(String(format:"(%d,%d) #%02X%02X%02X a=%.2f  g-r=%.3f g-b=%.3f g-max(r,b)=%.3f",x,y,Int(r*255),Int(g*255),Int(b*255),a,g-r,g-b,g-max(r,b)))
}}
