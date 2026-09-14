import AppKit
for a in CommandLine.arguments.dropFirst() {
  guard let img = NSImage(contentsOfFile: a), let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { continue }
  let pts = [(5,5),(rep.pixelsWide-6,5),(5,rep.pixelsHigh-6)]
  var s = (a as NSString).lastPathComponent + ": "
  for (x,y) in pts { if let c = rep.colorAt(x:x,y:y) { s += String(format:"#%02X%02X%02X ", Int(c.redComponent*255),Int(c.greenComponent*255),Int(c.blueComponent*255)) } }
  print(s)
}
