import AppKit
let img = NSImage(contentsOfFile: CommandLine.arguments[1])!
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
let W = rep.pixelsWide, H = rep.pixelsHigh, spp = rep.samplesPerPixel, bpr = rep.bytesPerRow, d = rep.bitmapData!
func hex(_ x:Int,_ y:Int)->String { let o=y*bpr+x*spp; return String(format:"#%02X%02X%02X", Int(d[o]),Int(d[o+1]),Int(d[o+2])) }
// sample a horizontal strip near the top where rays are wide
let y = Int(Double(H)*0.13)
var line = "y=\(y): "
for i in 0..<16 { let x = Int(Double(W)*(0.06 + 0.055*Double(i))); line += hex(x,y)+" " }
print(line)
