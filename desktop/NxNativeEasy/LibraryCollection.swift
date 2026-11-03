import SwiftUI
import AppKit
import WebKit

// Opening a cover only navigates. Building, signing and installation keep their existing guards.
struct LibraryCoverCard:View {
    let title:String
    let catalog:CatalogGame?
    let status:String
    let verified:Bool
    let macReady:Bool
    let ipaReady:Bool
    let rebuild:Bool
    let text:(String)->String
    let open:()->Void
    @State private var hovered=false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body:some View {
        Button(action:open) {
            VStack(alignment:.leading,spacing:0) {
                ZStack(alignment:.bottomLeading) {
                    if let catalog {GameArtworkView(game:catalog)}
                    else {EasyDesign.surface.overlay(Image(systemName:"gamecontroller").font(.system(size:48)).foregroundStyle(.secondary))}
                    LinearGradient(colors:[.clear,.black.opacity(0.8)],startPoint:.center,endPoint:.bottom)
                    HStack(spacing:6) {
                        if macReady {Label("Mac",systemImage:"desktopcomputer").padding(.horizontal,8).padding(.vertical,5).background(.black.opacity(0.65),in:Capsule())}
                        if ipaReady {Label(text("IPA lista"),systemImage:"iphone").padding(.horizontal,8).padding(.vertical,5).background(.black.opacity(0.65),in:Capsule())}
                        Spacer()
                        Image(systemName:"arrow.up.right").font(.system(size:14,weight:.semibold)).padding(8).background(.black.opacity(0.65),in:Circle())
                    }.font(.caption.weight(.medium)).foregroundStyle(.white).padding(14)
                }.frame(height:220).clipped()
                VStack(alignment:.leading,spacing:10) {
                    Text(title).font(.system(size:19,weight:.bold,design:.rounded)).foregroundStyle(EasyDesign.ink).lineLimit(2).frame(height:48,alignment:.topLeading)
                    Label(status,systemImage:verified ? "checkmark.circle.fill" : macReady ? "desktopcomputer" : ipaReady ? "shippingbox" : "folder").font(.callout).foregroundStyle(verified ? Color.green : .secondary).lineLimit(2).frame(minHeight:32,alignment:.topLeading)
                    if rebuild {Label(text("Conviene recompilar"),systemImage:"arrow.triangle.2.circlepath").font(.caption).foregroundStyle(.orange)}
                }.padding(18).frame(maxWidth:.infinity,alignment:.leading)
            }.background(EasyDesign.surface,in:RoundedRectangle(cornerRadius:18)).clipShape(RoundedRectangle(cornerRadius:18))
                .overlay(RoundedRectangle(cornerRadius:18).strokeBorder(hovered ? EasyDesign.accent.opacity(0.5) : EasyDesign.border,lineWidth:1))
                .offset(y:hovered && !reduceMotion ? -3 : 0)
                .animation(reduceMotion ? nil : .easeOut(duration:0.16),value:hovered)
                .contentShape(RoundedRectangle(cornerRadius:18))
        }.buttonStyle(.plain).onHover{hovered=$0}
            .accessibilityLabel(title+". "+status).accessibilityHint(text("Ver detalles del juego"))
    }
}

struct LibraryEmptyCollection:View {
    let text:(String)->String
    let disabled:Bool
    let add:()->Void
    let compatibility:()->Void
    private var artwork:NSImage? {
        Bundle.main.url(forResource:"empty-collection",withExtension:"png",subdirectory:"Library").flatMap {NSImage(contentsOf:$0)}
    }
    var body:some View {
        VStack(spacing:14) {
            if let artwork {Image(nsImage:artwork).resizable().scaledToFit().frame(width:260,height:174).accessibilityHidden(true)}
            Text(text("Tu colección empieza con tu primer juego")).font(.system(size:24,weight:.bold,design:.rounded))
            Text(text("Añade su carpeta. Conservamos los archivos donde están y recordamos tus versiones para Mac, iPhone y iPad.")).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth:480)
            Button(action:add){Label(text("Añadir juego"),systemImage:"plus")}.buttonStyle(EasyPrimaryStyle()).disabled(disabled)
            Button(text("Ver juegos compatibles"),action:compatibility).buttonStyle(EasyLinkStyle())
        }.padding(24)
    }
}

struct LibraryDropOverlay:View {
    let text:(String)->String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    var body:some View {
        VStack(spacing:18) {
            LibraryDropMotion(playing:scenePhase == .active && !reduceMotion).frame(width:240,height:180).accessibilityHidden(true)
            Text(text("Suelta tu juego aquí")).font(.system(size:28,weight:.bold,design:.rounded))
            Text(text("Una carpeta o sus archivos NSP, XCI, NSZ o XCZ. Los originales se quedan en su lugar.")).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth:460)
        }.padding(40).frame(maxWidth:.infinity,maxHeight:.infinity)
            .overlay(RoundedRectangle(cornerRadius:20).strokeBorder(EasyDesign.accent.opacity(0.65),style:StrokeStyle(lineWidth:2,dash:[10,8])).padding(20))
    }
}

// One local-only Lottie player exists while an actual file drag targets the workspace.
// It receives no filenames, account data or application state, and cannot navigate or fetch.
struct LibraryDropMotion:NSViewRepresentable {
    let playing:Bool
    func makeCoordinator()->Coordinator {Coordinator()}
    func makeNSView(context:Context)->WKWebView {
        let config=WKWebViewConfiguration();config.websiteDataStore = .nonPersistent()
        let view=WKWebView(frame:.zero,configuration:config)
        view.navigationDelegate=context.coordinator;view.underPageBackgroundColor=NSColor(EasyDesign.background)
        context.coordinator.playing=playing
        if let url=Bundle.main.url(forResource:"drop-game",withExtension:"html",subdirectory:"Library") {
            context.coordinator.directory=url.deletingLastPathComponent()
            view.loadFileURL(url,allowingReadAccessTo:url.deletingLastPathComponent())
        }
        return view
    }
    func updateNSView(_ view:WKWebView,context:Context) {
        context.coordinator.playing=playing
        context.coordinator.update(view)
    }
    static func dismantleNSView(_ view:WKWebView,coordinator:Coordinator) {
        view.evaluateJavaScript("window.motion && window.motion.destroy()",completionHandler:nil)
        view.stopLoading();view.navigationDelegate=nil
    }
    final class Coordinator:NSObject,WKNavigationDelegate {
        var playing=false
        var ready=false
        var directory:URL?
        func update(_ view:WKWebView) {
            guard ready else {return}
            view.evaluateJavaScript("window.setMotionPlaying && window.setMotionPlaying("+(playing ? "true" : "false")+")",completionHandler:nil)
        }
        func webView(_ view:WKWebView,didFinish navigation:WKNavigation!) {ready=true;update(view)}
        func webView(_ view:WKWebView,decidePolicyFor action:WKNavigationAction,decisionHandler:@escaping(WKNavigationActionPolicy)->Void) {
            guard let url=action.request.url,let directory,url.isFileURL,url.deletingLastPathComponent()==directory else {decisionHandler(.cancel);return}
            decisionHandler(.allow)
        }
    }
}
