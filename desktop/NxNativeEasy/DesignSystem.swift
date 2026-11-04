import SwiftUI

// Shared desktop design tokens. Keep account, installer and preparation on one visual system.
enum EasyDesign {
    static let background=Color(red:0.065,green:0.075,blue:0.098)
    static let accent=Color(red:1,green:0.43,blue:0.25)
    static let ink=Color(red:0.94,green:0.95,blue:0.98)
    static let violet=Color(red:0.56,green:0.47,blue:1)
    static let panel=Color(red:0.09,green:0.105,blue:0.135)
    static let surface=Color.white.opacity(0.04)
    static let border=Color.white.opacity(0.075)
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
            .overlay(RoundedRectangle(cornerRadius:EasyDesign.radius).strokeBorder(EasyDesign.border))
    }
}
struct EasyPrimaryStyle:ButtonStyle {
    func makeBody(configuration:Configuration)->some View {EasyPrimaryBody(label:configuration.label,pressed:configuration.isPressed)}
}
private struct EasyPrimaryBody<Label:View>:View {
    let label:Label
    let pressed:Bool
    @Environment(\.isEnabled) private var enabled
    var body:some View {
        label.font(.system(size:14,weight:.bold)).padding(.horizontal,20).padding(.vertical,12).frame(minHeight:44).contentShape(Rectangle())
            .foregroundStyle(enabled ? Color.black : Color.secondary)
            .background(LinearGradient(colors:enabled ? [EasyDesign.accent,Color(red:1,green:0.59,blue:0.31)] : [.white.opacity(0.065),.white.opacity(0.065)],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:9))
            .shadow(color:enabled ? EasyDesign.accent.opacity(0.14) : .clear,radius:14,y:4).opacity(pressed ? 0.8 : 1).scaleEffect(pressed ? 0.985 : 1)
    }
}
struct EasySecondaryStyle:ButtonStyle {
    func makeBody(configuration:Configuration)->some View {EasySecondaryBody(label:configuration.label,pressed:configuration.isPressed)}
}
private struct EasySecondaryBody<Label:View>:View {
    let label:Label
    let pressed:Bool
    @Environment(\.isEnabled) private var enabled
    var body:some View {
        label.font(.system(size:13,weight:.semibold)).padding(.horizontal,14).padding(.vertical,10).frame(minHeight:38).contentShape(Rectangle())
            .foregroundStyle(enabled ? EasyDesign.ink : Color.secondary)
            .background(Color.white.opacity(pressed ? 0.1 : 0.025),in:RoundedRectangle(cornerRadius:9))
            .overlay(RoundedRectangle(cornerRadius:9).strokeBorder(.white.opacity(enabled ? 0.16 : 0.06))).scaleEffect(pressed ? 0.985 : 1)
    }
}
struct EasyLinkStyle:ButtonStyle {
    func makeBody(configuration:Configuration)->some View {EasyLinkBody(label:configuration.label,pressed:configuration.isPressed)}
}
private struct EasyLinkBody<Label:View>:View {
    let label:Label
    let pressed:Bool
    @Environment(\.isEnabled) private var enabled
    var body:some View {label.font(.callout).foregroundStyle(enabled ? EasyDesign.accent : Color.secondary).padding(.horizontal,8).frame(minHeight:34).contentShape(Rectangle()).opacity(pressed ? 0.7 : 1)}
}
struct EasyField<Content:View>:View {
    let title:String
    let content:Content
    init(_ title:String,@ViewBuilder content:()->Content) {self.title=title;self.content=content()}
    var body:some View {
        VStack(alignment:.leading,spacing:8) {
            Text(title).font(.callout.weight(.semibold))
            content.textFieldStyle(.plain).padding(13).frame(minHeight:44)
                .background(.black.opacity(0.18),in:RoundedRectangle(cornerRadius:10))
                .overlay(RoundedRectangle(cornerRadius:10).strokeBorder(EasyDesign.border))
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
                        else {Text(String(index+1)).font(.system(size:10,weight:.semibold,design:.monospaced)).foregroundStyle(index==current ? .black : .secondary)}
                    }
                    Text(title).font(.system(size:11,weight:index==current ? .semibold : .regular)).foregroundStyle(index==current ? EasyDesign.ink : .secondary).lineLimit(1)
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
                Text(subtitle).font(.system(size:14)).lineSpacing(3).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
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
