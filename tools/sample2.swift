import AppKit
let img = NSImage(contentsOfFile: CommandLine.arguments[1])!
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
let W = rep.pixelsWide, H = rep.pixelsHigh
func hex(_ x:Int,_ y:Int)->String { guard let c=rep.colorAt(x:x,y:y)?.usingColorSpace(.sRGB) else {return "?"}; return String(format:"#%02X%02X%02X", Int(c.redComponent*255),Int(c.greenComponent*255),Int(c.blueComponent*255)) }
let y = Int(Double(H)*0.13)
var line = ""
for i in 0..<18 { let x = Int(Double(W)*(0.05 + 0.05*Double(i))); line += hex(x,y)+" " }
print("y=\(Int(Double(H)*0.13)): "+line)
