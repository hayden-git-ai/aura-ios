import AppKit
let a = CommandLine.arguments
let img = NSImage(contentsOfFile: a[1])!
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
let W = rep.pixelsWide, H = rep.pixelsHigh
let spp = rep.samplesPerPixel, bpr = rep.bytesPerRow
let data = rep.bitmapData!
let mode = a[2]
func rgb(_ x:Int,_ y:Int)->(Double,Double,Double){ let o=y*bpr+x*spp; return (Double(data[o])/255,Double(data[o+1])/255,Double(data[o+2])/255) }
func alpha(_ x:Int,_ y:Int)->Double{ let o=y*bpr+x*spp; return spp>=4 ? Double(data[o+3])/255 : 1 }
// sample key from this image's own corners
var kr=0.0,kg=0.0,kb=0.0
for (x,y) in [(6,6),(W-7,6),(6,H-7),(W-7,H-7)]{ let c=rgb(x,y); kr+=c.0;kg+=c.1;kb+=c.2 }
kr/=4;kg/=4;kb/=4
func isFox(_ x:Int,_ y:Int)->Bool {
  if mode=="alpha" { return alpha(x,y) > 0.5 }
  let c=rgb(x,y); let d=((c.0-kr)*(c.0-kr)+(c.1-kg)*(c.1-kg)+(c.2-kb)*(c.2-kb)).squareRoot(); return d>0.33
}
var colCount=[Int](repeating:0,count:W), rowCount=[Int](repeating:0,count:H), total=0
for y in 0..<H { for x in 0..<W { if isFox(x,y){ colCount[x]+=1; rowCount[y]+=1; total+=1 } } }
let colMin=max(6,W/120), rowMin=max(6,H/120)
let xs=(0..<W).filter{colCount[$0]>=rowMin}, ys=(0..<H).filter{rowCount[$0]>=colMin}
let minX=xs.first ?? 0,maxX=xs.last ?? W-1,minY=ys.first ?? 0,maxY=ys.last ?? H-1
let foxH=maxY-minY, headBand=minY+Int(0.20*Double(foxH))
var sx=0.0,n=0.0
for y in minY...headBand { for x in minX...maxX { if isFox(x,y){sx+=Double(x);n+=1} } }
print(String(format:"%@ key#%02X%02X%02X foxFrac=%.3f headAxisXn=%.4f feetYn=%.4f topYn=%.4f foxHn=%.4f bboxCXn=%.4f",
 (a[1] as NSString).lastPathComponent, Int(kr*255),Int(kg*255),Int(kb*255), Double(total)/Double(W*H),
 sx/max(1,n)/Double(W), Double(maxY)/Double(H), Double(minY)/Double(H), Double(foxH)/Double(H), Double(minX+maxX)/2/Double(W)))
