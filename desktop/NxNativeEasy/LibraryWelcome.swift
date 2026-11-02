import SwiftUI
import AppKit

// Collection artwork always uses the player's own library; the empty state has no game covers.
struct EasyCollectionArtwork:View {
    let images:[NSImage]
    var body:some View {
        ZStack {
            Ellipse().fill(EasyDesign.accent.opacity(0.08)).frame(width:140,height:80).blur(radius:12)
            ForEach(0..<3) {index in
                ZStack {
                    RoundedRectangle(cornerRadius:12).fill(EasyDesign.background)
                    if images.indices.contains(index) {
                        Image(nsImage:images[index]).resizable().scaledToFill()
                    } else {
                        LinearGradient(colors:[EasyDesign.accent.opacity(0.16),EasyDesign.surface],startPoint:.topLeading,endPoint:.bottomTrailing)
                        Image(systemName:index==1 ? "gamecontroller" : index==0 ? "desktopcomputer" : "iphone").font(.system(size:25,weight:.light)).foregroundStyle(EasyDesign.accent)
                    }
                }.frame(width:64,height:82).clipped().clipShape(RoundedRectangle(cornerRadius:12))
                    .overlay(RoundedRectangle(cornerRadius:12).strokeBorder(EasyDesign.border))
                    .rotationEffect(.degrees(Double(index-1)*13))
                    .offset(x:CGFloat(index-1)*42,y:index==1 ? -5 : 6)
                    .zIndex(index==1 ? 1 : 0)
            }
        }.accessibilityHidden(true)
    }
}
struct LibraryWelcomeHeader:View {
    let text:(String)->String
    let images:[NSImage]
    let disabled:Bool
    var showAction=true
    let add:()->Void
    var body:some View {
        HStack(alignment:.center,spacing:20) {
            VStack(alignment:.leading,spacing:9) {
                Text(text("Mi biblioteca")).font(.system(size:34,weight:.bold,design:.rounded)).foregroundStyle(EasyDesign.ink)
                Text(text("Tus juegos. Tus archivos. Todo en un lugar.")).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            }.frame(maxWidth:.infinity,alignment:.leading)
            if showAction {ViewThatFits(in:.horizontal) {
                HStack(spacing:22) {
                    EasyCollectionArtwork(images:images).frame(width:158,height:104)
                    addButton
                }
                addButton
            }}
        }.padding(.vertical,3)
    }
    private var addButton:some View {
        Button(action:add){Label(text("Añadir juego"),systemImage:"plus")}.buttonStyle(EasyPrimaryStyle()).disabled(disabled)
    }
}
struct EasyLibraryMetric:View {
    let value:Int
    let title:String
    let symbol:String
    var body:some View {
        HStack(spacing:12) {
            Image(systemName:symbol).font(.system(size:18,weight:.medium)).foregroundStyle(EasyDesign.accent)
                .frame(width:34,height:34).background(EasyDesign.accent.opacity(0.08),in:RoundedRectangle(cornerRadius:9))
            VStack(alignment:.leading,spacing:3) {
                Text(value,format:.number).font(.system(size:21,weight:.semibold,design:.rounded)).foregroundStyle(EasyDesign.ink)
                Text(title).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            }
            Spacer(minLength:0)
        }.padding(.horizontal,14).padding(.vertical,12).frame(maxWidth:.infinity,alignment:.leading)
            .background(LinearGradient(colors:[EasyDesign.surface,.white.opacity(0.015)],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:13))
            .overlay(RoundedRectangle(cornerRadius:13).strokeBorder(EasyDesign.border))
            .accessibilityElement(children:.combine)
    }
}
