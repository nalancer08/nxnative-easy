import SwiftUI
import WebKit

// Decorative, offline renderer. It receives only lifecycle/accessibility state,
// never account information, paths, saves or permission to navigate.
struct LivingCloudScene:NSViewRepresentable {
    let playing:Bool
    let reducedMotion:Bool
    let label:String
    func makeCoordinator()->Coordinator {Coordinator()}
    func makeNSView(context:Context)->WKWebView {
        let configuration=WKWebViewConfiguration();configuration.websiteDataStore = .nonPersistent()
        let view=WKWebView(frame:.zero,configuration:configuration)
        view.navigationDelegate=context.coordinator;view.underPageBackgroundColor=NSColor(EasyDesign.background)
        context.coordinator.playing=playing;context.coordinator.reducedMotion=reducedMotion;context.coordinator.label=label
        if let url=Bundle.main.url(forResource:"continuity-world",withExtension:"html",subdirectory:"Library") {
            context.coordinator.directory=url.deletingLastPathComponent()
            view.loadFileURL(url,allowingReadAccessTo:url.deletingLastPathComponent())
        }
        return view
    }
    func updateNSView(_ view:WKWebView,context:Context) {
        context.coordinator.playing=playing;context.coordinator.reducedMotion=reducedMotion;context.coordinator.label=label
        context.coordinator.update(view)
    }
    static func dismantleNSView(_ view:WKWebView,coordinator:Coordinator) {
        view.evaluateJavaScript("window.destroyScene && window.destroyScene()",completionHandler:nil)
        view.stopLoading();view.navigationDelegate=nil
    }
    final class Coordinator:NSObject,WKNavigationDelegate {
        var playing=false,reducedMotion=false,ready=false
        var label=""
        var directory:URL?
        func update(_ view:WKWebView) {
            guard ready,let data=try? JSONSerialization.data(withJSONObject:[playing,reducedMotion,label]),let state=String(data:data,encoding:.utf8) else{return}
            view.evaluateJavaScript("window.setSceneState && window.setSceneState.apply(null,"+state+")",completionHandler:nil)
        }
        func webView(_ view:WKWebView,didFinish navigation:WKNavigation!) {ready=true;update(view)}
        func webView(_ view:WKWebView,decidePolicyFor action:WKNavigationAction,decisionHandler:@escaping(WKNavigationActionPolicy)->Void) {
            guard let url=action.request.url,let directory,url.isFileURL,url.deletingLastPathComponent()==directory else{decisionHandler(.cancel);return}
            decisionHandler(.allow)
        }
    }
}
