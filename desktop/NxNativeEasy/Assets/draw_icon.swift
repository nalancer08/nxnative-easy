import AppKit

// Export the original generated launcher sculpture consistently at Dock sizes.
let directory=URL(fileURLWithPath:CommandLine.arguments[1])
let source=URL(fileURLWithPath:#filePath).deletingLastPathComponent().appendingPathComponent("Launcher/app-icon-3d.png")
guard let image=NSImage(contentsOf:source) else {fputs("Missing launcher icon\n",stderr);exit(1)}
do {
    for (name,size) in [("icon_16x16",16),("icon_16x16@2x",32),("icon_32x32",32),("icon_32x32@2x",64),("icon_128x128",128),("icon_128x128@2x",256),("icon_256x256",256),("icon_256x256@2x",512),("icon_512x512",512),("icon_512x512@2x",1024)] {
        guard let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:size,pixelsHigh:size,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0),let context=NSGraphicsContext(bitmapImageRep:bitmap) else {throw CocoaError(.fileWriteUnknown)}
        NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=context;context.imageInterpolation = .high
        NSBezierPath(roundedRect:NSRect(x:0,y:0,width:size,height:size),xRadius:CGFloat(size)*0.22,yRadius:CGFloat(size)*0.22).addClip()
        image.draw(in:NSRect(x:0,y:0,width:size,height:size));NSGraphicsContext.restoreGraphicsState()
        guard let data=bitmap.representation(using:.png,properties:[:]) else{throw CocoaError(.fileWriteUnknown)}
        try data.write(to:directory.appendingPathComponent(name+".png"))
    }
} catch {fputs("Icon export failed: \(error)\n",stderr);exit(1)}
