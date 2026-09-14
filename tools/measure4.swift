import AppKit
let a=CommandLine.arguments
let img=NSImage(contentsOfFile:a[1])!, rep=NSBitmapImageRep(data:img.tiffRepresentation!)!
let W=rep.pixelsWide,H=rep.pixelsHigh,spp=rep.samplesPerPixel,bpr=rep.bytesPerRow,data=rep.bitmapData!
func alpha(_ x:Int,_ y:Int)->Double{ spp>=4 ? Double(data[y*bpr+x*spp+3])/255 : 1 }
func isFox(_ x:Int,_ y:Int)->Bool{ alpha(x,y)>0.5 }
var colC=[Int](repeating:0,count:W),rowC=[Int](repeating:0,count:H)
for y in 0..<H{for x in 0..<W{if isFox(x,y){colC[x]+=1;rowC[y]+=1}}}
let cMin=max(6,W/120),rMin=max(6,H/120)
let xs=(0..<W).filter{colC[$0]>=rMin},ys=(0..<H).filter{rowC[$0]>=cMin}
let minX=xs.first!,maxX=xs.last!,minY=ys.first!,maxY=ys.last!,foxH=maxY-minY
func bandAxis(_ y0:Int,_ y1:Int)->Double{var s=0.0,n=0.0;for y in y0...y1{for x in minX...maxX{if isFox(x,y){s+=Double(x);n+=1}}};return s/max(1,n)/Double(W)}
let headX=bandAxis(minY,minY+Int(0.20*Double(foxH)))
let feetX=bandAxis(maxY-Int(0.12*Double(foxH)),maxY)
print(String(format:"%@ headXn=%.4f feetXn=%.4f feetYn=%.4f foxHn=%.4f",(a[1] as NSString).lastPathComponent,headX,feetX,Double(maxY)/Double(H),Double(foxH)/Double(H)))
