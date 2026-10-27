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
    // The handheld itself is the icon silhouette: no surrounding dark tile.
    let silhouette=NSBezierPath(roundedRect:NSRect(x:48,y:48,width:928,height:928),xRadius:210,yRadius:210)
    NSGraphicsContext.saveGraphicsState();silhouette.addClip()
    rounded(48,48,464,928,0,NSColor(srgbRed:0.76,green:0.94,blue:0.30,alpha:1))
    rounded(512,48,464,928,0,NSColor(srgbRed:0.20,green:0.82,blue:0.78,alpha:1))
    rounded(250,48,524,928,80,NSColor(srgbRed:0.02,green:0.035,blue:0.03,alpha:1))
    rounded(270,68,484,888,62,NSColor(srgbRed:0.28,green:0.35,blue:0.31,alpha:1))
    rounded(284,82,456,860,52,NSColor(srgbRed:0.10,green:0.17,blue:0.14,alpha:1))
    NSGraphicsContext.restoreGraphicsState()
    // A phone camera island, rotated for landscape orientation.
    rounded(298,459,24,106,12,NSColor(srgbRed:0.025,green:0.04,blue:0.03,alpha:1))
    rounded(720,462,5,100,2.5,NSColor.white.withAlphaComponent(0.45))
    let ink=NSColor(srgbRed:0.065,green:0.11,blue:0.09,alpha:1)
    rounded(111,623,100,100,50,ink)
    rounded(136,262,50,158,13,ink);rounded(82,316,158,50,13,ink)
    for (x,y) in [(863,747),(809,693),(917,693),(863,639)] {
        rounded(CGFloat(x-19),CGFloat(y-19),38,38,19,ink)
    }
    rounded(813,291,100,100,50,ink)
    // Simple luminous play mark on the phone screen.
    NSColor(srgbRed:0.77,green:0.96,blue:0.33,alpha:1).setFill()
    let play=NSBezierPath();play.move(to:NSPoint(x:445,y:382));play.line(to:NSPoint(x:445,y:642));play.line(to:NSPoint(x:635,y:512));play.close();play.fill()
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using:.png,properties:[:])!.write(to:directory.appendingPathComponent(name+".png"))
}
