import SwiftUI

struct EasyDestinationCard:View {
    let target:String
    let selected:Bool
    let text:(String)->String
    var body:some View {
        HStack(spacing:22) {
            ZStack {
                Circle().fill(EasyDesign.accent.opacity(selected ? 0.12 : 0.03)).frame(width:90,height:90)
                Image(systemName:target=="mac" ? "desktopcomputer" : "ipad.and.iphone").font(.system(size:43,weight:.ultraLight)).foregroundStyle(selected ? EasyDesign.accent : EasyDesign.muted)
            }
            VStack(alignment:.leading,spacing:9) {
                Text(target=="mac" ? "Mac" : "iPhone / iPad").font(.system(size:22,weight:.bold))
                Text(text(target=="ios" ? "Prepara la IPA y te guiamos para instalarla." : "Una app completa. Preparar y jugar en este Mac.")).font(.system(size:12)).foregroundStyle(EasyDesign.muted).multilineTextAlignment(.leading)
            }
            Spacer(minLength:0)
            Image(systemName:selected ? "checkmark.circle.fill" : "circle").font(.system(size:18)).foregroundStyle(selected ? EasyDesign.accent : EasyDesign.controlOutline)
        }.padding(22).frame(maxWidth:.infinity,minHeight:140,alignment:.leading)
            .background(LinearGradient(colors:[EasyDesign.panel,EasyDesign.panel.opacity(0.3)],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:14))
            .overlay(RoundedRectangle(cornerRadius:14).strokeBorder(selected ? EasyDesign.accent.opacity(0.65) : EasyDesign.controlOutline))
            .foregroundStyle(EasyDesign.ink)
    }
}
struct EasyBuildMeter:View {
    let fraction:Double?
    let text:(String)->String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body:some View {
        ZStack {
            Circle().stroke(.white.opacity(0.04),lineWidth:11).frame(width:146,height:146)
            if let fraction {Circle().trim(from:0,to:min(1,max(0,fraction))).stroke(AngularGradient(colors:[EasyDesign.violet,EasyDesign.accent],center:.center),style:StrokeStyle(lineWidth:7,lineCap:.round)).frame(width:146,height:146).rotationEffect(.degrees(-90)).animation(reduceMotion ? nil : .easeOut(duration:0.25),value:fraction)}
            else {Circle().stroke(EasyDesign.accent.opacity(0.25),style:StrokeStyle(lineWidth:2,dash:[3,8])).frame(width:146,height:146)}
            VStack(spacing:8) {
                if let fraction {Text(String(Int(min(1,max(0,fraction))*100))+"%").font(.system(size:34,weight:.medium,design:.monospaced)).foregroundStyle(EasyDesign.ink)}
                else {Image(systemName:"cpu").font(.system(size:34,weight:.ultraLight)).foregroundStyle(EasyDesign.accent)}
                Text(text("Etapa actual")).font(.system(size:10)).foregroundStyle(EasyDesign.muted)
            }
        }
    }
}

struct DeviceHubArtwork:View {
    let devices:[SideloadDevice]
    var body:some View {
        ZStack {
            Ellipse().fill(EasyDesign.violet.opacity(0.1)).frame(width:220,height:95).blur(radius:15).offset(y:30)
            device(isPad:true).rotationEffect(.degrees(-10)).offset(x:-45,y:3).opacity(devices.isEmpty ? 0.35 : 0.8)
            device(isPad:false).rotationEffect(.degrees(10)).offset(x:44,y:12)
            if !devices.isEmpty {Image(systemName:"checkmark.circle.fill").font(.system(size:27)).foregroundStyle(EasyDesign.accent).padding(6).background(EasyDesign.background,in:Circle()).offset(x:82,y:54)}
        }
    }
    private func device(isPad:Bool)->some View {
        ZStack(alignment:.top) {
            RoundedRectangle(cornerRadius:isPad ? 13 : 16).fill(LinearGradient(colors:[Color(red:0.18,green:0.21,blue:0.3),EasyDesign.background],startPoint:.topLeading,endPoint:.bottomTrailing))
            RoundedRectangle(cornerRadius:isPad ? 9 : 12).fill(LinearGradient(colors:[EasyDesign.violet.opacity(0.5),EasyDesign.accent.opacity(0.1),EasyDesign.background],startPoint:.topTrailing,endPoint:.bottomLeading)).padding(5)
            Capsule().fill(.black.opacity(0.9)).frame(width:isPad ? 5 : 23,height:5).padding(.top,9)
            Image(systemName:isPad ? "square.stack.3d.up" : "gamecontroller").font(.system(size:isPad ? 27 : 23,weight:.ultraLight)).foregroundStyle(EasyDesign.accent.opacity(0.8)).frame(maxHeight:.infinity)
        }.frame(width:isPad ? 112 : 64,height:130).overlay(RoundedRectangle(cornerRadius:isPad ? 13 : 16).strokeBorder(.white.opacity(0.2)))
    }
}

struct AccountSceneIntro:View {
    let authenticated:Bool
    let text:(String)->String
    var body:some View {
        VStack(alignment:.leading,spacing:22) {
            ZStack {
                Circle().stroke(EasyDesign.accent.opacity(0.1),lineWidth:1).frame(width:180,height:180)
                Circle().fill(RadialGradient(colors:[EasyDesign.violet.opacity(0.2),.clear],center:.center,startRadius:5,endRadius:90)).frame(width:180,height:180)
                Image(systemName:"person.crop.circle").font(.system(size:95,weight:.ultraLight)).foregroundStyle(EasyDesign.accent)
                Image(systemName:authenticated ? "checkmark.shield.fill" : "lock.shield.fill").font(.system(size:40,weight:.light)).foregroundStyle(EasyDesign.accent).padding(10).background(EasyDesign.background,in:RoundedRectangle(cornerRadius:14)).offset(x:57,y:42)
            }.frame(width:200,height:190).accessibilityHidden(true)
            EasyEyebrow(title:text("CUENTA APPLE"))
            Text(text(authenticated ? "Tu cuenta, lista para instalar" : "Conecta tu cuenta Apple")).font(.system(size:28,weight:.bold)).tracking(-0.7)
            Text(text("Una cuenta para firmar e instalar en todos tus dispositivos.")).font(.callout).foregroundStyle(EasyDesign.muted).lineSpacing(4)
        }.padding(.top,12)
    }
}
