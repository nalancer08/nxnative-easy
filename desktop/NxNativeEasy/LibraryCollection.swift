import SwiftUI
import AppKit
import WebKit

struct LibraryDropOverlay:View {
    let text:(String)->String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    var body:some View {
        VStack(spacing:18) {
            LibraryDropMotion(playing:scenePhase == .active && !reduceMotion).frame(width:240,height:180).accessibilityHidden(true)
            Text(text("Suelta tu juego aquí")).font(.system(size:28,weight:.bold,design:.default))
            Text(text("Una carpeta o sus archivos NSP, XCI, NSZ, XCZ o NUP. Los originales se quedan en su lugar.")).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth:460)
        }.padding(40).frame(maxWidth:.infinity,maxHeight:.infinity)
            .overlay(RoundedRectangle(cornerRadius:20).strokeBorder(EasyDesign.accent.opacity(0.65),style:StrokeStyle(lineWidth:2,dash:[10,8])).padding(20))
    }
}

// A local-only Lottie player decorates file drags or a running save-copy operation.
// It receives no filenames, account data or application state, and cannot navigate or fetch.
struct LibraryDropMotion:NSViewRepresentable {
    let playing:Bool
    var resource="drop-game"
    func makeCoordinator()->Coordinator {Coordinator()}
    func makeNSView(context:Context)->WKWebView {
        let config=WKWebViewConfiguration();config.websiteDataStore = .nonPersistent()
        let view=WKWebView(frame:.zero,configuration:config)
        view.navigationDelegate=context.coordinator;view.underPageBackgroundColor=NSColor(EasyDesign.background)
        context.coordinator.playing=playing
        if let url=Bundle.main.url(forResource:resource,withExtension:"html",subdirectory:"Library") {
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
