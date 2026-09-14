import AppKit
// crop a region and scale up: in out x y w h
let a=CommandLine.arguments
let img=NSImage(contentsOfFile:a[1])!, rep=NSBitmapImageRep(data:img.tiffRepresentation!)!
let x=Int(a[3])!,y=Int(a[4])!,w=Int(a[5])!,h=Int(a[6])!
let crop=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:w,pixelsHigh:h,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.calibratedRGB,bytesPerRow:0,bitsPerPixel:0)!
for j in 0..<h { for i in 0..<w { if let c=rep.colorAt(x:x+i,y:y+j){ crop.setColor(c,atX:i,y:j) } } }
try! crop.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:a[2]))
