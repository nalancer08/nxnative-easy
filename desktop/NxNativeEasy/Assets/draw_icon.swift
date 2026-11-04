import AppKit

// One flat silhouette at every size. The SVG is the editable source of truth.
let directory=URL(fileURLWithPath:CommandLine.arguments[1])
let source=URL(fileURLWithPath:#filePath).deletingLastPathComponent().appendingPathComponent("Launcher/brand-mark.svg")
let svg=try String(contentsOf:source,encoding:.utf8)
guard let range=svg.range(of:"points=\"([^\"]+)\"",options:.regularExpression) else {fputs("Missing brand silhouette\n",stderr);exit(1)}
let points=svg[range].dropFirst(8).dropLast().split(separator:" ").map {pair in pair.split(separator:",").compactMap{Double($0)}}
guard points.count>=3,points.allSatisfy({$0.count==2}) else {fputs("Invalid brand silhouette\n",stderr);exit(1)}
func mark(_ rect:NSRect) {
    let path=NSBezierPath()
    for (index,point) in points.enumerated() {
        let p=NSPoint(x:rect.minX+point[0]/32*rect.width,y:rect.minY+(32-point[1])/32*rect.height)
        if index==0 {path.move(to:p)} else {path.line(to:p)}
    }
    path.close();NSColor(srgbRed:1,green:110.0/255,blue:64.0/255,alpha:1).setFill();path.fill()
}
do {
    for (name,size) in [("icon_16x16",16),("icon_16x16@2x",32),("icon_32x32",32),("icon_32x32@2x",64),("icon_128x128",128),("icon_128x128@2x",256),("icon_256x256",256),("icon_256x256@2x",512),("icon_512x512",512),("icon_512x512@2x",1024)] {
        guard let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:size,pixelsHigh:size,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0),let context=NSGraphicsContext(bitmapImageRep:bitmap) else {throw CocoaError(.fileWriteUnknown)}
        NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=context
        let side=CGFloat(size)
        NSColor(srgbRed:0.065,green:0.075,blue:0.098,alpha:1).setFill()
        NSBezierPath(roundedRect:NSRect(x:0,y:0,width:side,height:side),xRadius:side*0.22,yRadius:side*0.22).fill()
        mark(NSRect(x:side*0.19,y:side*0.19,width:side*0.62,height:side*0.62))
        NSGraphicsContext.restoreGraphicsState()
        guard let data=bitmap.representation(using:.png,properties:[:]) else{throw CocoaError(.fileWriteUnknown)}
        try data.write(to:directory.appendingPathComponent(name+".png"))
    }
    // Header art has no tile, bevel, shadow or miniature physical details.
    let side=256
    guard let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:side,pixelsHigh:side,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0),let context=NSGraphicsContext(bitmapImageRep:bitmap) else {throw CocoaError(.fileWriteUnknown)}
    NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=context
    mark(NSRect(x:0,y:0,width:side,height:side));NSGraphicsContext.restoreGraphicsState()
    guard let data=bitmap.representation(using:.png,properties:[:]) else {throw CocoaError(.fileWriteUnknown)}
    try data.write(to:directory.appendingPathComponent("BrandMark.png"))
} catch {fputs("Icon export failed: \(error)\n",stderr);exit(1)}
