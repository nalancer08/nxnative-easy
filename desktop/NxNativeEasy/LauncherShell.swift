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
        control.isBordered=false;control.setButtonType(.momentaryPushIn);control.focusRingType = .default;control.refusesFirstResponder=false
        return control
    }
    func updateNSView(_ control:Control,context:Context) {
        context.coordinator.action=action;control.title=title;control.symbol=symbol;control.artwork=image;control.selected=selected;control.gameRow=gameRow;control.isEnabled=enabled;control.toolTip=title;control.needsDisplay=true
        control.setAccessibilityLabel(title)
    }
    final class Coordinator:NSObject {var action:()->Void;init(_ action:@escaping()->Void){self.action=action};@objc func invoke(){action()}}
    final class Control:NSButton {
        var symbol:String?;var artwork:NSImage?;var selected=false;var gameRow=false;private var hovering=false
        override var acceptsFirstResponder:Bool {isEnabled}
        override var intrinsicContentSize:NSSize {NSSize(width:NSView.noIntrinsicMetric,height:gameRow ? 48 : 40)}
        override var focusRingMaskBounds:NSRect {bounds}
        override func drawFocusRingMask(){NSBezierPath(roundedRect:bounds.insetBy(dx:2,dy:2),xRadius:7,yRadius:7).fill()}
        override func acceptsFirstMouse(for event:NSEvent?)->Bool {true}
        override func updateTrackingAreas(){super.updateTrackingAreas();for area in trackingAreas{removeTrackingArea(area)};addTrackingArea(NSTrackingArea(rect:bounds,options:[.mouseEnteredAndExited,.activeAlways,.inVisibleRect],owner:self))}
        override func mouseEntered(with event:NSEvent){hovering=true;needsDisplay=true}
        override func mouseExited(with event:NSEvent){hovering=false;needsDisplay=true}
        override func draw(_ dirtyRect:NSRect) {
            if selected || (isEnabled && (hovering || isHighlighted)) {
                NSColor(EasyDesign.control).setFill()
                NSBezierPath(roundedRect:bounds.insetBy(dx:2,dy:2),xRadius:7,yRadius:7).fill()
            }
            let color=NSColor(!isEnabled ? EasyDesign.disabledInk : selected ? EasyDesign.ink : EasyDesign.muted)
            var x:CGFloat=12
            let icon=artwork ?? symbol.flatMap{NSImage(systemSymbolName:$0,accessibilityDescription:nil)}
            if let icon {
                let side:CGFloat=gameRow ? 30 : 16,rect=NSRect(x:10,y:(bounds.height-side)/2,width:side,height:side)
                NSGraphicsContext.saveGraphicsState();NSBezierPath(roundedRect:rect,xRadius:5,yRadius:5).addClip()
                if artwork != nil {icon.draw(in:rect)}else{let tinted=icon.withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors:[color])) ?? icon;tinted.draw(in:rect)}
                NSGraphicsContext.restoreGraphicsState();x=rect.maxX+10
            }
            let style=NSMutableParagraphStyle();style.lineBreakMode = gameRow ? .byWordWrapping : .byTruncatingTail
            let font=NSFont.systemFont(ofSize:gameRow ? 13 : 13,weight:selected ? .semibold : .medium)
            let value=NSAttributedString(string:title,attributes:[.font:font,.foregroundColor:color,.paragraphStyle:style])
            let height=gameRow ? min(32,value.boundingRect(with:NSSize(width:max(1,bounds.width-x-10),height:40),options:.usesLineFragmentOrigin).height) : 17
            value.draw(with:NSRect(x:x,y:(bounds.height-height)/2,width:max(1,bounds.width-x-10),height:height),options:[.usesLineFragmentOrigin,.truncatesLastVisibleLine])
            if selected && gameRow {NSColor(EasyDesign.accent).setFill();NSBezierPath(roundedRect:NSRect(x:2,y:8,width:3,height:bounds.height-16),xRadius:1.5,yRadius:1.5).fill()}
            if selected && !gameRow {NSColor(srgbRed:1,green:0.43,blue:0.25,alpha:1).setFill();NSBezierPath(roundedRect:NSRect(x:12,y:bounds.height-3,width:bounds.width-24,height:2),xRadius:1,yRadius:1).fill()}
        }
    }
}

struct LauncherSidebar:View {
    let entries:[LibraryEntry]
    let catalog:[CatalogGame]
    let text:(String)->String
    @Binding var selected:String?
    @FocusState private var searchFocused:Bool
    @Binding var query:String
    let add:()->Void
    let settings:()->Void
    private func name(_ entry:LibraryEntry)->String {catalog.first{$0.id==entry.titleID}?.name ?? entry.local?.folder.lastPathComponent ?? text("Juego guardado")}
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            HStack(spacing:7){Image(systemName:"magnifyingglass").font(EasyDesign.metadata).foregroundStyle(EasyDesign.muted);TextField(text("Buscar juegos"),text:$query).textFieldStyle(.plain).font(.system(size:13)).focused($searchFocused);if !query.isEmpty {Button {query=""}label:{Image(systemName:"xmark")}.buttonStyle(EasyIconStyle()).accessibilityLabel(text("Limpiar búsqueda"))}}.padding(.horizontal,10).frame(minHeight:44).background(EasyDesign.control,in:RoundedRectangle(cornerRadius:7)).overlay(RoundedRectangle(cornerRadius:7).strokeBorder(searchFocused ? EasyDesign.focus : EasyDesign.controlOutline,lineWidth:searchFocused ? 2 : 1).allowsHitTesting(false)).padding(.horizontal,12).padding(.top,18)
            HStack{Text(text("MIS JUEGOS")).font(.system(size:11,weight:.semibold)).tracking(1.6);Spacer();Text(String(entries.count)).font(EasyDesign.metadata)}.foregroundStyle(EasyDesign.muted).padding(.horizontal,20)
            ScrollView {
                LazyVStack(spacing:3) {
                    if !query.isEmpty && !entries.contains(where:{name($0).localizedCaseInsensitiveContains(query)}) {Text(text("No encontramos juegos con esa búsqueda.")).font(EasyDesign.metadata).foregroundStyle(EasyDesign.muted).padding(12).frame(maxWidth:.infinity,alignment:.leading)}
                    ForEach(entries.filter{query.isEmpty || name($0).localizedCaseInsensitiveContains(query)}) {entry in
                        LauncherButton(title:name(entry),image:catalog.first{$0.id==entry.titleID}.flatMap{GameArtworkCache.image($0.artworkURL)},selected:selected==entry.id,gameRow:true){selected=entry.id}.frame(height:48)
                    }
                }.padding(.horizontal,8)
            }
            Spacer(minLength:0)
            Divider().padding(.horizontal,16)
            LauncherButton(title:text("Configuración"),symbol:"gearshape",action:settings).frame(height:44).padding(.horizontal,8).padding(.bottom,12)
        }.onReceive(NotificationCenter.default.publisher(for:Notification.Name("nxnative.focusSearch"))){_ in searchFocused=true}.frame(width:228).background(Color(red:0.047,green:0.055,blue:0.075)).overlay(alignment:.trailing){Rectangle().fill(.white.opacity(0.055)).frame(width:1)}
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
            Text(text("Añade tu juego. Elige tu pantalla. A jugar.")).font(.callout).foregroundStyle(EasyDesign.muted)
            Button(action:add){Label(text("Añadir juego"),systemImage:"plus")}.buttonStyle(EasyPrimaryStyle())
        }.frame(maxWidth:.infinity,maxHeight:.infinity).background(EasyDesign.background)
    }
}
