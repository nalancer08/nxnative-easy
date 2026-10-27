import SwiftUI

// Shared desktop design tokens. Keep account, installer and preparation on one visual system.
enum EasyDesign {
    static let background=Color(red:0.065,green:0.075,blue:0.07)
    static let accent=Color(red:0.79,green:0.95,blue:0.37)
    static let ink=Color(red:0.93,green:0.94,blue:0.90)
    static let surface=Color.white.opacity(0.045)
    static let border=Color.white.opacity(0.075)
    static let radius:CGFloat=18
    static let pagePadding:CGFloat=28
    static let spacing:CGFloat=20
}

struct EasyCard<Content:View>:View {
    let content:Content
    init(@ViewBuilder content:()->Content) {self.content=content()}
    var body:some View {
        content.padding(22).frame(maxWidth:.infinity,alignment:.leading)
            .background(EasyDesign.surface,in:RoundedRectangle(cornerRadius:EasyDesign.radius))
            .overlay(RoundedRectangle(cornerRadius:EasyDesign.radius).strokeBorder(EasyDesign.border))
    }
}
struct EasyPrimaryStyle:ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration:Configuration)->some View {
        configuration.label.font(.system(size:14,weight:.bold)).padding(.horizontal,20).padding(.vertical,12).frame(minHeight:44)
            .foregroundStyle(enabled ? Color.black : Color.secondary)
            .background(enabled ? EasyDesign.accent : Color.white.opacity(0.065),in:RoundedRectangle(cornerRadius:10))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
struct EasySecondaryStyle:ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration:Configuration)->some View {
        configuration.label.font(.system(size:13,weight:.semibold)).padding(.horizontal,14).padding(.vertical,10).frame(minHeight:38)
            .foregroundStyle(enabled ? EasyDesign.ink : Color.secondary)
            .background(Color.white.opacity(configuration.isPressed ? 0.10 : 0.055),in:RoundedRectangle(cornerRadius:9))
    }
}
struct EasyLinkStyle:ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration:Configuration)->some View {
        configuration.label.font(.callout).foregroundStyle(enabled ? EasyDesign.accent : Color.secondary).frame(minHeight:32).opacity(configuration.isPressed ? 0.7 : 1)
    }
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
        HStack(alignment:.top,spacing:8) {
            ForEach(Array(titles.enumerated()),id:\.offset) {index,title in
                VStack(alignment:.leading,spacing:8) {
                    Capsule().fill(index<=current ? EasyDesign.accent : Color.white.opacity(0.09)).frame(height:4)
                    Label(title,systemImage:index<current ? "checkmark.circle.fill" : "\(index+1).circle")
                        .font(.system(size:11,weight:index==current ? .bold : .medium)).foregroundStyle(index==current ? EasyDesign.ink : .secondary)
                        .fixedSize(horizontal:false,vertical:true)
                }.frame(maxWidth:.infinity,alignment:.leading)
            }
        }.accessibilityElement(children:.combine)
    }
}

enum EasyMilestoneKind {case device,account,review,transfer,complete}
struct EasyMilestone:View {
    let kind:EasyMilestoneKind
    let title:String
    let subtitle:String
    var body:some View {
        HStack(spacing:24) {
            illustration.frame(width:150,height:126).accessibilityHidden(true)
            VStack(alignment:.leading,spacing:9) {
                Text(title).font(.system(size:24,weight:.bold,design:.rounded)).foregroundStyle(EasyDesign.ink)
                Text(subtitle).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            }.frame(maxWidth:.infinity,alignment:.leading)
        }.padding(20).frame(maxWidth:.infinity,alignment:.leading)
            .background(LinearGradient(colors:[EasyDesign.accent.opacity(0.10),Color.white.opacity(0.025)],startPoint:.leading,endPoint:.trailing),in:RoundedRectangle(cornerRadius:20))
            .overlay(RoundedRectangle(cornerRadius:20).strokeBorder(EasyDesign.accent.opacity(0.12)))
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
