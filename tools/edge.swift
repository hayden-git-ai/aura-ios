import AppKit
let img=NSImage(contentsOfFile:CommandLine.arguments[1])!, rep=NSBitmapImageRep(data:img.tiffRepresentation!)!
let W=rep.pixelsWide,H=rep.pixelsHigh
func al(_ x:Int,_ y:Int)->CGFloat{ rep.colorAt(x:x,y:y)?.alphaComponent ?? 0 }
func rgb(_ x:Int,_ y:Int)->String{ let c=rep.colorAt(x:x,y:y)!.usingColorSpace(.sRGB)!; return String(format:"#%02X%02X%02X",Int(c.redComponent*255),Int(c.greenComponent*255),Int(c.blueComponent*255)) }
for (name,pts) in [("top",(0..<W).map{($0,0)}),("bottom",(0..<W).map{($0,H-1)}),("left",(0..<H).map{(0,$0)}),("right",(0..<H).map{(W-1,$0)})] {
  var mx:CGFloat=0, pt=(0,0)
  for (x,y) in pts { let a=al(x,y); if a>mx{mx=a;pt=(x,y)} }
  print("\(name): maxAlpha=\(String(format:"%.3f",Double(mx))) rgb=\(rgb(pt.0,pt.1))")
}
