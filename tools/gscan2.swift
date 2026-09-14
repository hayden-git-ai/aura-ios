import AppKit
let img=NSImage(contentsOfFile:CommandLine.arguments[1])!, rep=NSBitmapImageRep(data:img.tiffRepresentation!)!
let W=rep.pixelsWide,H=rep.pixelsHigh
var green=0, tot=0
var samples:[(Int,Int,Int,Int,Int,Double)]=[]
for y in stride(from:0,to:H,by:1){ for x in stride(from:0,to:W,by:1){
  guard let c=rep.colorAt(x:x,y:y)?.usingColorSpace(.sRGB) else {continue}
  let r=Int(c.redComponent*255),g=Int(c.greenComponent*255),b=Int(c.blueComponent*255),a=c.alphaComponent
  if a>0.15 { tot+=1; if g>r+10 && g>b+5 { green+=1; if samples.count<10 && (x%20==0||y%20==0){samples.append((x,y,r,g,b,a))} } }
}}
print("green-ish pixels: \(green) of \(tot) opaque")
for s in samples { print(String(format:"  (%d,%d) #%02X%02X%02X a=%.2f",s.0,s.1,s.2,s.3,s.4,s.5)) }
