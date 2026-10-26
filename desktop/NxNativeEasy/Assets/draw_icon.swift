import AppKit

// Original vector artwork: a landscape phone with handheld controls.
let directory = URL(fileURLWithPath:CommandLine.arguments[1])
func rounded(_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ h:CGFloat,_ radius:CGFloat,_ color:NSColor) {
    color.setFill(); NSBezierPath(roundedRect:NSRect(x:x,y:y,width:w,height:h),xRadius:radius,yRadius:radius).fill()
}
for (name,size) in [("icon_16x16",16),("icon_16x16@2x",32),("icon_32x32",32),("icon_32x32@2x",64),("icon_128x128",128),("icon_128x128@2x",256),("icon_256x256",256),("icon_256x256@2x",512),("icon_512x512",512),("icon_512x512@2x",1024)] {
    let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:size,pixelsHigh:size,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap)
    let transform=NSAffineTransform();transform.scale(by:CGFloat(size)/1024);transform.concat()
    rounded(48,48,928,928,210,NSColor(srgbRed:0.07,green:0.10,blue:0.09,alpha:1))
    rounded(111,284,180,456,86,NSColor(srgbRed:0.76,green:0.94,blue:0.30,alpha:1))
    rounded(733,284,180,456,86,NSColor(srgbRed:0.20,green:0.82,blue:0.78,alpha:1))
    rounded(250,266,524,492,80,NSColor(srgbRed:0.02,green:0.035,blue:0.03,alpha:1))
    rounded(270,286,484,452,62,NSColor(srgbRed:0.28,green:0.35,blue:0.31,alpha:1))
    rounded(284,300,456,424,52,NSColor(srgbRed:0.10,green:0.17,blue:0.14,alpha:1))
    // A phone camera island, rotated for landscape orientation.
    rounded(298,459,24,106,12,NSColor(srgbRed:0.025,green:0.04,blue:0.03,alpha:1))
    rounded(720,462,5,100,2.5,NSColor.white.withAlphaComponent(0.45))
    let ink=NSColor(srgbRed:0.065,green:0.11,blue:0.09,alpha:1)
    rounded(162,542,66,66,33,ink)
    rounded(172,384,46,116,12,ink);rounded(137,419,116,46,12,ink)
    for (x,y) in [(823,608),(787,572),(859,572),(823,536)] {
        rounded(CGFloat(x-14),CGFloat(y-14),28,28,14,ink)
    }
    rounded(790,397,66,66,33,ink)
    // Simple luminous play mark on the phone screen.
    NSColor(srgbRed:0.77,green:0.96,blue:0.33,alpha:1).setFill()
    let play=NSBezierPath();play.move(to:NSPoint(x:465,y:418));play.line(to:NSPoint(x:465,y:606));play.line(to:NSPoint(x:609,y:512));play.close();play.fill()
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using:.png,properties:[:])!.write(to:directory.appendingPathComponent(name+".png"))
}
