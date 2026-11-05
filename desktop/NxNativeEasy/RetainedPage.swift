import SwiftUI
import AppKit

// Keep local form/installer state alive, but actually hide the native hierarchy.
// Opacity alone leaves NSViewRepresentable descendants in AppKit's event/AX tree.
struct RetainedPage<Content:View>:NSViewRepresentable {
    let visible:Bool
    let content:Content
    init(visible:Bool,@ViewBuilder content:()->Content) {self.visible=visible;self.content=content()}
    func makeNSView(context:Context)->NSHostingView<Content> {
        let view=NSHostingView(rootView:content);view.sizingOptions=[];view.wantsLayer=true;view.layer?.masksToBounds=true;view.isHidden = !visible
        return view
    }
    func updateNSView(_ view:NSHostingView<Content>,context:Context) {view.rootView=content;view.isHidden = !visible}
    func sizeThatFits(_ proposal:ProposedViewSize,nsView:NSHostingView<Content>,context:Context)->CGSize? {CGSize(width:proposal.width ?? 760,height:proposal.height ?? 530)}
}
