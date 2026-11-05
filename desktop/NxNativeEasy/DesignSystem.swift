import SwiftUI

// Shared desktop design tokens. Keep account, installer and preparation on one visual system.
enum EasyDesign {
    static let background=Color(red:0.065,green:0.075,blue:0.098)
    static let accent=Color(red:1,green:0.43,blue:0.25)
    static let ink=Color(red:0.94,green:0.95,blue:0.98)
    static let violet=Color(red:0.56,green:0.47,blue:1)
    static let panel=Color(red:0.09,green:0.105,blue:0.135)
    static let surface=Color(red:0.12,green:0.14,blue:0.18)
    static let border=Color(red:0.27,green:0.31,blue:0.38)
    static let control=Color(red:39/255,green:46/255,blue:58/255)
    static let controlOutline=Color(red:117/255,green:131/255,blue:154/255)
    static let muted=Color(red:182/255,green:192/255,blue:208/255)
    static let disabledInk=Color(red:152/255,green:164/255,blue:182/255)
    static let focus=Color(red:154/255,green:203/255,blue:1)
    static let danger=Color(red:1,green:147/255,blue:152/255)
    static let metadata=Font.system(size:12)
    static let controlHeight:CGFloat=44
    static let radius:CGFloat=14
    static let pagePadding:CGFloat=28
    static let spacing:CGFloat=20
}

struct EasyCard<Content:View>:View {
    let content:Content
    init(@ViewBuilder content:()->Content) {self.content=content()}
    var body:some View {
        content.padding(22).frame(maxWidth:.infinity,alignment:.leading)
            .background(LinearGradient(colors:[EasyDesign.panel,EasyDesign.panel.opacity(0.65)],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:EasyDesign.radius))
            .overlay(RoundedRectangle(cornerRadius:EasyDesign.radius).strokeBorder(EasyDesign.border).allowsHitTesting(false))
    }
}
// Every style owns the complete padded hit region, activation-click policy and
// hover/focus/disabled treatment. Do not scale controls while pressing them.
struct EasyPrimaryStyle:ButtonStyle {
    func makeBody(configuration:Configuration)->some View {EasyControlBody(label:configuration.label,pressed:configuration.isPressed,kind:.primary)}
}
struct EasySecondaryStyle:ButtonStyle {
    func makeBody(configuration:Configuration)->some View {EasyControlBody(label:configuration.label,pressed:configuration.isPressed,kind:.secondary)}
}
struct EasyLinkStyle:ButtonStyle {
    func makeBody(configuration:Configuration)->some View {EasyControlBody(label:configuration.label,pressed:configuration.isPressed,kind:.quiet)}
}
struct EasyIconStyle:ButtonStyle {
    func makeBody(configuration:Configuration)->some View {EasyControlBody(label:configuration.label,pressed:configuration.isPressed,kind:.icon)}
}
struct EasySelectionStyle:ButtonStyle {
    var selected=false
    func makeBody(configuration:Configuration)->some View {EasyControlBody(label:configuration.label,pressed:configuration.isPressed,kind:.selection,selected:selected)}
}
private enum EasyControlKind:Equatable {case primary,secondary,quiet,icon,selection}
private struct EasyControlBody<Label:View>:View {
    let label:Label
    let pressed:Bool
    let kind:EasyControlKind
    var selected=false
    @Environment(\.isEnabled) private var enabled
    @Environment(\.isFocused) private var focused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovered=false
    private var fill:Color {
        if !enabled {return EasyDesign.surface}
        if kind == .primary {return pressed ? Color(red:0.96,green:0.36,blue:0.20) : hovered ? Color(red:1,green:0.54,blue:0.36) : EasyDesign.accent}
        return kind == .secondary || kind == .icon || pressed || hovered || selected ? EasyDesign.control : .clear
    }
    var body:some View {
        label
            .font(.system(size:kind == .primary ? 14 : 13,weight:kind == .primary ? .bold : .semibold))
            .foregroundStyle(!enabled ? EasyDesign.disabledInk : kind == .primary ? Color.black : kind == .quiet ? EasyDesign.accent : EasyDesign.ink)
            .padding(.horizontal, kind == .selection ? 0 : kind == .icon ? 0 : kind == .primary ? 20 : 12)
            .padding(.vertical,kind == .selection || kind == .icon ? 0 : 10)
            .frame(minWidth:kind == .icon ? EasyDesign.controlHeight : 0,minHeight:EasyDesign.controlHeight)
            .background(fill,in:RoundedRectangle(cornerRadius:9))
            .overlay {RoundedRectangle(cornerRadius:9).strokeBorder(enabled && (kind == .secondary || kind == .icon || hovered || selected) ? EasyDesign.controlOutline : .clear,lineWidth:1).allowsHitTesting(false)}
            .overlay {RoundedRectangle(cornerRadius:12).inset(by:-3).strokeBorder(focused ? EasyDesign.focus : .clear,lineWidth:2).allowsHitTesting(false)}
            .contentShape(.interaction,Rectangle())
            .onHover {hovered=$0}
            .allowsWindowActivationEvents()
            .animation(reduceMotion ? nil : .easeOut(duration:0.12),value:hovered)
            .animation(reduceMotion ? nil : .easeOut(duration:0.08),value:pressed)
    }
}
// AppKit's borderless Menu flattens a styled label and discards its background.
// Use the button-backed menu so the same control owns drawing and hit testing.
struct EasyMenuStyle:MenuStyle {
    var compact=false
    @ViewBuilder func makeBody(configuration:Configuration)->some View {
        if compact {Menu(configuration).menuStyle(.button).buttonStyle(EasyIconStyle()).menuIndicator(.hidden)}
        else {Menu(configuration).menuStyle(.button).buttonStyle(EasySecondaryStyle())}
    }
}
struct EasyField<Content:View>:View {
    @FocusState private var focused:Bool
    let title:String
    let content:Content
    init(_ title:String,@ViewBuilder content:()->Content) {self.title=title;self.content=content()}
    var body:some View {
        VStack(alignment:.leading,spacing:8) {
            Text(title).font(.callout.weight(.semibold))
            content.textFieldStyle(.plain).focused($focused).padding(13).frame(minHeight:44)
                .background(.black.opacity(0.18),in:RoundedRectangle(cornerRadius:10))
                .overlay(RoundedRectangle(cornerRadius:10).strokeBorder(focused ? EasyDesign.focus : EasyDesign.controlOutline,lineWidth:focused ? 2 : 1).allowsHitTesting(false))
                .contentShape(.interaction,Rectangle()).simultaneousGesture(TapGesture().onEnded {focused=true})
        }
    }
}
struct EasyStepRail:View {
    let titles:[String]
    let current:Int
    var body:some View {
        HStack(spacing:0) {
            ForEach(Array(titles.enumerated()),id:\.offset) {index,title in
                HStack(spacing:8) {
                    ZStack {
                        Circle().fill(index==current ? EasyDesign.accent : index<current ? EasyDesign.accent.opacity(0.1) : .white.opacity(0.04)).frame(width:25,height:25)
                        if index<current {Image(systemName:"checkmark").font(.system(size:10,weight:.bold)).foregroundStyle(EasyDesign.accent)}
                        else {Text(String(index+1)).font(.system(size:10,weight:.semibold,design:.monospaced)).foregroundStyle(index==current ? .black : EasyDesign.muted)}
                    }
                    Text(title).font(.system(size:12,weight:index==current ? .semibold : .regular)).foregroundStyle(index==current ? EasyDesign.ink : EasyDesign.muted).lineLimit(1)
                    if index<titles.count-1 {Rectangle().fill(.white.opacity(0.08)).frame(height:1).padding(.horizontal,12)}
                }.accessibilityElement(children:.combine)
            }
        }

    }
}

enum EasyMilestoneKind {case device,account,review,transfer,complete}
struct EasyMilestone:View {
    let kind:EasyMilestoneKind
    let title:String
    let subtitle:String
    var body:some View {
        HStack(spacing:36) {
            VStack(alignment:.leading,spacing:14) {
                EasyEyebrow(title:"NXNATIVE EASY")
                Text(title).font(.system(size:32,weight:.bold)).tracking(-0.9).foregroundStyle(EasyDesign.ink)
                Text(subtitle).font(.system(size:14)).lineSpacing(3).foregroundStyle(EasyDesign.muted).fixedSize(horizontal:false,vertical:true)
            }.frame(maxWidth:.infinity,alignment:.leading)
            illustration.scaleEffect(1.15).frame(width:190,height:154).accessibilityHidden(true)
        }.padding(.horizontal,26).padding(.vertical,22).frame(maxWidth:.infinity,alignment:.leading)
            .background(RadialGradient(colors:[EasyDesign.violet.opacity(0.17),EasyDesign.panel.opacity(0.2)],center:.trailing,startRadius:5,endRadius:520),in:RoundedRectangle(cornerRadius:16))
            .overlay(alignment:.bottom){Rectangle().fill(LinearGradient(colors:[EasyDesign.accent.opacity(0.35),.clear],startPoint:.leading,endPoint:.trailing)).frame(height:1)}
    }

    @ViewBuilder private var illustration:some View {
        ZStack {
            Circle().stroke(EasyDesign.accent.opacity(0.13),lineWidth:1).frame(width:116,height:116)
            Circle().stroke(EasyDesign.accent.opacity(0.08),style:StrokeStyle(lineWidth:1,dash:[3,6])).frame(width:92,height:92)
            switch kind {
            case .device:
                Image(systemName:"laptopcomputer").font(.system(size:62,weight:.ultraLight)).offset(x:-23,y:8)
                Image(systemName:"iphone").font(.system(size:70,weight:.light)).padding(6).background(EasyDesign.background,in:RoundedRectangle(cornerRadius:14)).rotationEffect(.degrees(10)).offset(x:38,y:-4)
                Image(systemName:"link").font(.system(size:23,weight:.semibold)).offset(y:43)
            case .account:
                Image(systemName:"person.crop.circle").font(.system(size:73,weight:.ultraLight)).offset(x:-16,y:-5)
                Image(systemName:"lock.shield.fill").font(.system(size:43,weight:.light)).padding(7).background(EasyDesign.background,in:RoundedRectangle(cornerRadius:14)).offset(x:34,y:24)
            case .review:
                RoundedRectangle(cornerRadius:12).fill(EasyDesign.accent.opacity(0.08)).frame(width:77,height:96).rotationEffect(.degrees(-12)).offset(x:-14,y:-2)
                Image(systemName:"list.bullet.clipboard").font(.system(size:65,weight:.ultraLight)).offset(x:-9,y:-3)
                Image(systemName:"checkmark.seal.fill").font(.system(size:39)).offset(x:35,y:30)
            case .transfer:
                Image(systemName:"shippingbox").font(.system(size:55,weight:.ultraLight)).offset(x:-39,y:-6)
                Image(systemName:"iphone").font(.system(size:75,weight:.ultraLight)).offset(x:39,y:0)
                Image(systemName:"arrow.right").font(.system(size:23,weight:.bold)).padding(8).background(EasyDesign.background,in:Circle()).offset(y:21)
            case .complete:
                Image(systemName:"ipad.and.iphone").font(.system(size:65,weight:.ultraLight)).opacity(0.7)
                Image(systemName:"checkmark.seal.fill").font(.system(size:44)).offset(x:39,y:30)
            }
        }.foregroundStyle(EasyDesign.accent)
    }
}

struct EasyEyebrow:View {
    let title:String
    var body:some View {Text(title).font(.system(size:10,weight:.semibold,design:.monospaced)).tracking(2.3).foregroundStyle(EasyDesign.accent.opacity(0.85))}
}
