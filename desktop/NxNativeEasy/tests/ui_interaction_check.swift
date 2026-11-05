import SwiftUI
import AppKit

private enum Failure:Error {case check(String)}
private func require(_ value:Bool,_ message:String)throws {if !value {throw Failure.check(message)}}
private func luminance(_ color:Color)->Double {
    let resolved=NSColor(color).usingColorSpace(.sRGB)!
    func linear(_ v:CGFloat)->Double {let x=Double(v);return x<=0.04045 ? x/12.92 : pow((x+0.055)/1.055,2.4)}
    return 0.2126*linear(resolved.redComponent)+0.7152*linear(resolved.greenComponent)+0.0722*linear(resolved.blueComponent)
}
private func contrast(_ a:Color,_ b:Color)->Double {let x=luminance(a),y=luminance(b);return (max(x,y)+0.05)/(min(x,y)+0.05)}
private final class Target:NSObject {var count=0;@objc func invoke(){count+=1}}
@MainActor private final class ProbeState:ObservableObject {@Published var visible=true}
private struct Marker:NSViewRepresentable {
    let nonce:String
    func makeNSView(context:Context)->NSView {let view=NSButton(title:"State marker",target:nil,action:nil);view.identifier=NSUserInterfaceItemIdentifier(nonce);return view}
    func updateNSView(_ view:NSView,context:Context){view.identifier=NSUserInterfaceItemIdentifier(nonce)}
}
private struct StatefulPage:View {
    @State private var nonce="audit-state-"+UUID().uuidString
    var body:some View {Marker(nonce:nonce)}
}
private struct ProbeRoot:View {
    @ObservedObject var state:ProbeState
    var body:some View {RetainedPage(visible:state.visible){StatefulPage()}.frame(width:240,height:80)}
}
@main private struct Check {
    @MainActor static func main()async {
        do {try await run();print("Desktop interaction PASS: contrast, full native targets, activation clicks, retained-page isolation and truthful primary actions")}
        catch {fputs("Desktop interaction failed: \(error)\n",stderr);exit(1)}
    }
    @MainActor private static func run()async throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        for fill in [EasyDesign.background,EasyDesign.panel,EasyDesign.control] {
            try require(contrast(EasyDesign.ink,fill)>=4.5,"primary text contrast")
            try require(contrast(EasyDesign.muted,fill)>=4.5,"secondary text contrast")
            try require(contrast(EasyDesign.focus,fill)>=3,"keyboard focus contrast")
        }
        try require(contrast(.black,EasyDesign.accent)>=4.5,"primary button label contrast")
        try require(contrast(EasyDesign.controlOutline,EasyDesign.control)>=3,"interactive control boundary contrast")
        try require(contrast(EasyDesign.disabledInk,EasyDesign.control)>=4.5,"disabled labels remain legible")
        let control=LauncherButton.Control(frame:NSRect(x:0,y:0,width:180,height:44)),target=Target()
        control.target=target;control.action=#selector(Target.invoke)
        for point in [NSPoint(x:2,y:2),NSPoint(x:178,y:2),NSPoint(x:2,y:42),NSPoint(x:178,y:42),NSPoint(x:90,y:22)] {try require(control.hitTest(point)===control,"native target must include padding/corners")}
        try require(control.acceptsFirstMouse(for:nil) && control.acceptsFirstResponder,"activation click and keyboard focus")
        control.performClick(nil);try require(target.count==1,"one action per native click")
        control.isEnabled=false;try require(!control.acceptsFirstResponder,"disabled controls must leave keyboard traversal")

        let state=ProbeState(),view=NSHostingView(rootView:ProbeRoot(state:state))
        view.frame=NSRect(x:0,y:0,width:240,height:80)
        let window=NSWindow(contentRect:view.frame,styleMask:.borderless,backing:.buffered,defer:false);window.isReleasedWhenClosed=false;window.contentView=view
        defer{window.close()}
        func nodes(_ root:NSView)->[NSView] {[root]+root.subviews.flatMap(nodes)}
        func marker()->String? {nodes(view).compactMap{$0.identifier?.rawValue}.first{$0.hasPrefix("audit-state-")}}
        func page()->NSHostingView<StatefulPage>? {nodes(view).compactMap{$0 as? NSHostingView<StatefulPage>}.first}
        view.layoutSubtreeIfNeeded();try await Task.sleep(nanoseconds:100_000_000)
        let initial=marker();try require(initial != nil && page()?.isHidden==false,"visible retained page must be mounted")
        state.visible=false;try await Task.sleep(nanoseconds:100_000_000)
        try require(page()?.isHidden==true,"inactive native descendants must really be hidden")
        try require(page()?.hitTest(NSPoint(x:120,y:40))==nil,"hidden preparation must not intercept clicks")
        state.visible=true;try await Task.sleep(nanoseconds:100_000_000)
        try require(marker()==initial && page()?.isHidden==false,"navigation must preserve local form state")

        let expired=GamePrimaryIntent.resolve(macReady:false,hasDevice:true,needsSync:true,syncReady:true,hasIPA:true,state:.expired)
        try require(expired == .renew && expired.title=="Renovar firma","expired signing must not be labeled/routed as a sync rebuild")
        try require(GamePrimaryIntent.resolve(macReady:false,hasDevice:true,needsSync:true,syncReady:true,hasIPA:true,state:.current) == .installSync,"ready sync update uses existing IPA")
        try require(GamePrimaryIntent.resolve(macReady:false,hasDevice:true,needsSync:true,syncReady:false,hasIPA:false,state:.current) == .prepareSync,"sync preparation is explicit")
        try require(GamePrimaryIntent.resolve(macReady:true,hasDevice:true,needsSync:true,syncReady:false,hasIPA:false,state:.expired) == .play,"Mac play remains separate from phone signing")
    }
}
