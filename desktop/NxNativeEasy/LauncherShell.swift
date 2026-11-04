import SwiftUI
import AppKit

@MainActor final class LauncherNavigation:ObservableObject {
    enum Page:Equatable {case library,prepare,settings,compatibility,engine}
    @Published private(set) var page=Page.library
    @Published private(set) var history:[Page]=[]
    var canGoBack:Bool {!history.isEmpty}
    func go(_ destination:Page) {guard destination != page else{return};history.append(page);if history.count>32{history.removeFirst()};page=destination}
    func back() {if let previous=history.popLast(){page=previous}}
}

// Native controls accept the first click even when another app has focus. Their
// entire visible bounds are clickable, independently of the label's geometry.
struct LauncherButton:NSViewRepresentable {
    let title:String
    var symbol:String?=nil
    var image:NSImage?=nil
    var selected=false
    var enabled=true
    var gameRow=false
    var action:()->Void
    func makeCoordinator()->Coordinator {Coordinator(action)}
    func makeNSView(context:Context)->Control {
        let control=Control();control.target=context.coordinator;control.action=#selector(Coordinator.invoke)
        control.isBordered=false;control.setButtonType(.momentaryPushIn);control.focusRingType = .default
        return control
    }
    func updateNSView(_ control:Control,context:Context) {
        context.coordinator.action=action;control.title=title;control.symbol=symbol;control.artwork=image;control.selected=selected;control.gameRow=gameRow;control.isEnabled=enabled;control.toolTip=title;control.needsDisplay=true
        control.setAccessibilityLabel(title)
    }
    final class Coordinator:NSObject {var action:()->Void;init(_ action:@escaping()->Void){self.action=action};@objc func invoke(){action()}}
    final class Control:NSButton {
        var symbol:String?;var artwork:NSImage?;var selected=false;var gameRow=false;private var hovering=false
        override var intrinsicContentSize:NSSize {NSSize(width:NSView.noIntrinsicMetric,height:gameRow ? 48 : 40)}
        override var focusRingMaskBounds:NSRect {bounds}
        override func drawFocusRingMask(){NSBezierPath(roundedRect:bounds.insetBy(dx:2,dy:2),xRadius:7,yRadius:7).fill()}
        override func acceptsFirstMouse(for event:NSEvent?)->Bool {true}
        override func updateTrackingAreas(){super.updateTrackingAreas();for area in trackingAreas{removeTrackingArea(area)};addTrackingArea(NSTrackingArea(rect:bounds,options:[.mouseEnteredAndExited,.activeAlways,.inVisibleRect],owner:self))}
        override func mouseEntered(with event:NSEvent){hovering=true;needsDisplay=true}
        override func mouseExited(with event:NSEvent){hovering=false;needsDisplay=true}
        override func draw(_ dirtyRect:NSRect) {
            if (selected && gameRow) || hovering || isHighlighted {
                NSColor.white.withAlphaComponent(selected ? 0.10 : isHighlighted ? 0.12 : 0.05).setFill()
                NSBezierPath(roundedRect:bounds.insetBy(dx:2,dy:2),xRadius:7,yRadius:7).fill()
            }
            let color=NSColor.white.withAlphaComponent(!isEnabled ? 0.3 : selected ? 1 : 0.75)
            var x:CGFloat=12
            let icon=artwork ?? symbol.flatMap{NSImage(systemSymbolName:$0,accessibilityDescription:nil)}
            if let icon {
                let side:CGFloat=gameRow ? 30 : 16,rect=NSRect(x:10,y:(bounds.height-side)/2,width:side,height:side)
                NSGraphicsContext.saveGraphicsState();NSBezierPath(roundedRect:rect,xRadius:5,yRadius:5).addClip()
                if artwork != nil {icon.draw(in:rect)}else{let tinted=icon.withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors:[color])) ?? icon;tinted.draw(in:rect)}
                NSGraphicsContext.restoreGraphicsState();x=rect.maxX+10
            }
            let style=NSMutableParagraphStyle();style.lineBreakMode = gameRow ? .byWordWrapping : .byTruncatingTail
            let font=NSFont.systemFont(ofSize:gameRow ? 12.5 : 13,weight:selected ? .semibold : .medium)
            let value=NSAttributedString(string:title,attributes:[.font:font,.foregroundColor:color,.paragraphStyle:style])
            let height=gameRow ? min(32,value.boundingRect(with:NSSize(width:max(1,bounds.width-x-10),height:40),options:.usesLineFragmentOrigin).height) : 17
            value.draw(with:NSRect(x:x,y:(bounds.height-height)/2,width:max(1,bounds.width-x-10),height:height),options:[.usesLineFragmentOrigin,.truncatesLastVisibleLine])
            if selected && !gameRow {NSColor(srgbRed:1,green:0.43,blue:0.25,alpha:1).setFill();NSBezierPath(roundedRect:NSRect(x:12,y:bounds.height-3,width:bounds.width-24,height:2),xRadius:1,yRadius:1).fill()}
        }
    }
}

struct LauncherSidebar:View {
    let entries:[LibraryEntry]
    let catalog:[CatalogGame]
    let text:(String)->String
    @Binding var selected:String?
    @Binding var query:String
    let add:()->Void
    let settings:()->Void
    private func name(_ entry:LibraryEntry)->String {catalog.first{$0.id==entry.titleID}?.name ?? entry.local?.folder.lastPathComponent ?? text("Juego guardado")}
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            HStack(spacing:7){Image(systemName:"magnifyingglass").font(.caption).foregroundStyle(.secondary);TextField(text("Buscar juegos"),text:$query).textFieldStyle(.plain).font(.system(size:12))}.padding(10).background(.white.opacity(0.045),in:RoundedRectangle(cornerRadius:7)).padding(.horizontal,12).padding(.top,18)
            HStack{Text(text("MIS JUEGOS")).font(.system(size:10,weight:.semibold)).tracking(1.6);Spacer();Text(String(entries.count)).font(.caption)}.foregroundStyle(.secondary).padding(.horizontal,20)
            ScrollView {
                LazyVStack(spacing:3) {
                    ForEach(entries.filter{query.isEmpty || name($0).localizedCaseInsensitiveContains(query)}) {entry in
                        LauncherButton(title:name(entry),image:catalog.first{$0.id==entry.titleID}.flatMap{GameArtworkCache.image($0.artworkURL)},selected:selected==entry.id,gameRow:true){selected=entry.id}.frame(height:48)
                    }
                }.padding(.horizontal,8)
            }
            Spacer(minLength:0)
            Divider().padding(.horizontal,16)
            LauncherButton(title:text("Configuración"),symbol:"gearshape",action:settings).frame(height:40).padding(.horizontal,8).padding(.bottom,12)
        }.frame(width:228).background(Color(red:0.047,green:0.055,blue:0.075)).overlay(alignment:.trailing){Rectangle().fill(.white.opacity(0.055)).frame(width:1)}
    }
}

struct LauncherWelcome:View {
    let text:(String)->String
    let add:()->Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var phase
    var body:some View {
        VStack(spacing:18) {
            LauncherPortal().frame(width:390,height:260).allowsHitTesting(false).accessibilityHidden(true)
            Text(text("Tu próxima aventura, aquí.")).font(.system(size:34,weight:.bold)).tracking(-1)
            Text(text("Añade tu juego. Elige tu pantalla. A jugar.")).font(.callout).foregroundStyle(.secondary)
            Button(action:add){Label(text("Añadir juego"),systemImage:"plus")}.buttonStyle(EasyPrimaryStyle())
        }.frame(maxWidth:.infinity,maxHeight:.infinity).background(EasyDesign.background)
    }
}
