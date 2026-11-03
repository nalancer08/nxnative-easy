import SwiftUI
import AppKit

struct LibrarySpotlightItem:Identifiable {
    let game:OwnedGameOutput
    let catalog:CatalogGame?
    let title:String
    let status:String
    let verified:Bool
    let installed:Bool
    let rebuild:Bool
    var id:String {game.id}
}

// The selected cover changes the stage. Only explicit actions launch or open installation review.
struct CinematicLibrary:View {
    let items:[LibrarySpotlightItem]
    let total:Int
    let text:(String)->String
    @Binding var query:String
    @Binding var platform:String
    @Binding var spotlight:String?
    let disabled:Bool
    let installBusy:Bool
    let add:()->Void
    let refresh:()->Void
    let compatibility:()->Void
    let details:(OwnedGameOutput)->Void
    let primary:(OwnedGameOutput)->Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var featured:LibrarySpotlightItem? {items.first(where:{$0.id==spotlight}) ?? items.first}
    var body:some View {
        GeometryReader {geometry in
            ScrollView {
                VStack(alignment:.leading,spacing:0) {
                    if total==0 {
                        empty.frame(minHeight:max(480,geometry.size.height-32))
                    } else {
                        if let item=featured {
                            LibrarySpotlight(item:item,text:text,disabled:disabled || (item.game.macApp==nil && installBusy),details:{details(item.game)},primary:{primary(item.game)})
                                .frame(height:min(470,max(285,geometry.size.height-254)))
                        }
                        VStack(alignment:.leading,spacing:16) {
                            HStack(spacing:14) {
                                Text(text("Mi colección")).font(.system(size:18,weight:.semibold))
                                Text(String(total)).font(.system(size:11,weight:.medium,design:.monospaced)).foregroundStyle(.secondary).padding(.horizontal,8).padding(.vertical,4).background(.white.opacity(0.06),in:Capsule())
                                Spacer()
                                HStack(spacing:7) {Image(systemName:"magnifyingglass").foregroundStyle(.secondary);TextField(text("Buscar en mis juegos"),text:$query).textFieldStyle(.plain);if !query.isEmpty {Button {query=""} label:{Image(systemName:"xmark.circle.fill")}.buttonStyle(.plain).accessibilityLabel(text("Borrar búsqueda"))}}
                                    .font(.system(size:12)).padding(10).frame(width:240).background(.white.opacity(0.04),in:RoundedRectangle(cornerRadius:8))
                                Button(action:refresh){Image(systemName:"arrow.clockwise").frame(width:32,height:32)}.buttonStyle(.plain).help(text("Actualizar biblioteca")).accessibilityLabel(text("Actualizar biblioteca"))
                            }
                            HStack(spacing:20) {
                                ForEach(["all","mac","ios"],id:\.self) {value in
                                    Button {platform=value} label:{Text(text(value=="all" ? "Todos" : value=="mac" ? "Mac" : "iPhone / iPad")).font(.system(size:12,weight:platform==value ? .semibold : .regular)).foregroundStyle(platform==value ? EasyDesign.ink : .secondary).padding(.bottom,7).overlay(alignment:.bottom){if platform==value {Capsule().fill(EasyDesign.accent).frame(height:2)}}}.buttonStyle(.plain).accessibilityAddTraits(platform==value ? .isSelected : [])
                                }
                            }
                            if items.isEmpty {
                                VStack(spacing:12) {
                                    Image(systemName:"magnifyingglass").font(.system(size:30,weight:.light)).foregroundStyle(.secondary)
                                    Text(text("No hay juegos que coincidan con tu búsqueda.")).font(.callout)
                                    Button(text("Borrar búsqueda")){query="";platform="all"}.buttonStyle(EasyLinkStyle())
                                }.frame(maxWidth:.infinity,minHeight:220)
                            } else {
                                ScrollView(.horizontal) {
                                    LazyHStack(alignment:.top,spacing:16) {
                                        ForEach(items) {item in
                                            LibraryShelfCover(item:item,selected:featured?.id==item.id) {
                                                withAnimation(reduceMotion ? nil : .easeInOut(duration:0.22)){spotlight=item.id}
                                            }
                                        }
                                        Button(action:add) {
                                            VStack(spacing:7) {
                                                if let image=Bundle.main.url(forResource:"empty-collection",withExtension:"png",subdirectory:"Library").flatMap({NSImage(contentsOf:$0)}) {Image(nsImage:image).resizable().scaledToFit().frame(height:72)}
                                                Label(text("Añadir juego"),systemImage:"plus").font(.system(size:12,weight:.semibold))
                                            }.frame(width:150,height:110).foregroundStyle(EasyDesign.ink).background(.white.opacity(0.025),in:RoundedRectangle(cornerRadius:10)).overlay(RoundedRectangle(cornerRadius:10).strokeBorder(.white.opacity(0.12),style:StrokeStyle(lineWidth:1,dash:[5,4])))
                                        }.buttonStyle(.plain).disabled(disabled)
                                    }.padding(.top,3).padding(.bottom,8)
                                }.scrollIndicators(.hidden)
                            }
                        }.padding(.horizontal,36).padding(.top,8).padding(.bottom,10)
                    }
                    Text(text("Esta biblioteca sólo contiene las carpetas que tú añades. No incluye ni descarga juegos.")).font(.system(size:10)).foregroundStyle(.tertiary).padding(.horizontal,36).padding(.bottom,16)
                }
            }.scrollIndicators(.hidden)
        }.background(EasyDesign.background)
    }
    private var empty:some View {
        HStack(spacing:36) {
            VStack(alignment:.leading,spacing:20) {
                EasyEyebrow(title:text("MI BIBLIOTECA"))
                Text(text("Tu colección empieza contigo.")).font(.system(size:48,weight:.bold)).tracking(-1.7).fixedSize(horizontal:false,vertical:true)
                Text(text("Añade su carpeta. Conservamos los archivos donde están y recordamos tus versiones para Mac, iPhone y iPad.")).font(.system(size:15)).foregroundStyle(.secondary).lineSpacing(4)
                Button(action:add){Label(text("Añadir juego"),systemImage:"plus")}.buttonStyle(EasyPrimaryStyle()).disabled(disabled)
                Button(text("Ver juegos compatibles"),action:compatibility).buttonStyle(EasyLinkStyle())
            }.frame(maxWidth:510,alignment:.leading)
            if let image=Bundle.main.url(forResource:"empty-collection",withExtension:"png",subdirectory:"Library").flatMap({NSImage(contentsOf:$0)}) {Image(nsImage:image).resizable().scaledToFit().frame(maxWidth:420).accessibilityHidden(true)}
        }.padding(48).frame(maxWidth:.infinity,alignment:.leading).background(RadialGradient(colors:[EasyDesign.violet.opacity(0.13),.clear],center:.trailing,startRadius:30,endRadius:560))
    }
}

struct LibrarySpotlight:View {
    let item:LibrarySpotlightItem
    let text:(String)->String
    let disabled:Bool
    var secondaryTitle="Ver detalles"
    let details:()->Void
    let primary:()->Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var primaryTitle:String {
        if item.game.macApp != nil {return "Jugar en Mac"}
        if item.game.iosIPA != nil {return item.installed ? "Actualizar en iPhone / iPad" : "Instalar en iPhone / iPad"}
        return "Preparar juego"
    }
    var body:some View {
        GeometryReader {geometry in
            ZStack(alignment:.leading) {
                Group {
                    if let catalog=item.catalog {GameArtworkView(game:catalog)}
                    else {LinearGradient(colors:[EasyDesign.violet.opacity(0.25),EasyDesign.background],startPoint:.topTrailing,endPoint:.bottomLeading)}
                }.id(item.id).transition(.opacity).animation(reduceMotion ? nil : .easeInOut(duration:0.28),value:item.id)
                LinearGradient(stops:[.init(color:EasyDesign.background.opacity(0.96),location:0),.init(color:EasyDesign.background.opacity(0.74),location:0.38),.init(color:EasyDesign.background.opacity(0.08),location:0.78)],startPoint:.leading,endPoint:.trailing)
                LinearGradient(stops:[.init(color:.clear,location:0.35),.init(color:EasyDesign.background.opacity(0.6),location:0.78),.init(color:EasyDesign.background,location:1)],startPoint:.top,endPoint:.bottom)
                VStack(alignment:.leading,spacing:15) {
                    EasyEyebrow(title:text("MI BIBLIOTECA")+(item.game.version.map {"  /  "+text("Versión preparada")+" "+$0} ?? ""))
                    Spacer(minLength:0)
                    Text(item.title).font(.system(size:geometry.size.width>1100 ? 54 : 44,weight:.bold)).tracking(-1.8).lineLimit(2).minimumScaleFactor(0.72).foregroundStyle(.white).frame(maxWidth:570,alignment:.leading)
                    Label(item.status,systemImage:item.verified ? "checkmark.circle.fill" : item.installed ? "clock" : "square.stack").font(.system(size:12,weight:.medium)).foregroundStyle(item.verified ? Color.green : EasyDesign.ink.opacity(0.8)).lineLimit(2)
                    HStack(spacing:12) {
                        Button(action:primary){Label(text(primaryTitle),systemImage:item.game.macApp != nil ? "play.fill" : item.game.iosIPA != nil ? "iphone" : "hammer.fill")}.buttonStyle(EasyPrimaryStyle()).disabled(disabled || item.game.missing)
                        Button(action:details){HStack(spacing:9){Text(text(secondaryTitle));Image(systemName:"arrow.up.right")}}.buttonStyle(EasySecondaryStyle())
                    }
                    HStack(spacing:16) {
                        Label(text(item.game.macApp != nil ? "Mac listo" : "Mac sin preparar"),systemImage:"desktopcomputer")
                        Label(text(item.game.iosIPA != nil ? "IPA lista" : "IPA sin preparar"),systemImage:"iphone")
                        if item.rebuild {Label(text("Conviene recompilar"),systemImage:"arrow.triangle.2.circlepath").foregroundStyle(.orange)}
                    }.font(.system(size:10,weight:.medium)).foregroundStyle(.secondary)
                }.padding(.horizontal,36).padding(.top,22).padding(.bottom,28).frame(maxWidth:.infinity,alignment:.leading)
            }.clipped()
        }
    }
}

struct LibraryShelfCover:View {
    let item:LibrarySpotlightItem
    let selected:Bool
    let choose:()->Void
    @State private var hovered=false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body:some View {
        Button(action:choose) {
            VStack(alignment:.leading,spacing:9) {
                ZStack(alignment:.bottomTrailing) {
                    if let catalog=item.catalog {GameArtworkView(game:catalog)}else {EasyDesign.panel.overlay(Image(systemName:"gamecontroller"))}
                    if selected {Image(systemName:"checkmark").font(.system(size:10,weight:.bold)).foregroundStyle(.black).padding(6).background(EasyDesign.accent,in:Circle()).padding(8)}
                }.frame(width:192,height:108).clipped().clipShape(RoundedRectangle(cornerRadius:9)).overlay(RoundedRectangle(cornerRadius:9).strokeBorder(selected ? EasyDesign.accent : .white.opacity(hovered ? 0.35 : 0.1),lineWidth:selected ? 2 : 1))
                Text(item.title).font(.system(size:12,weight:.semibold)).lineLimit(2).frame(width:192,height:30,alignment:.topLeading).foregroundStyle(selected ? .white : EasyDesign.ink.opacity(0.65))
            }.offset(y:hovered && !reduceMotion ? -2 : 0).animation(reduceMotion ? nil : .easeOut(duration:0.16),value:hovered)
        }.buttonStyle(.plain).onHover{hovered=$0}.accessibilityLabel(item.title).accessibilityAddTraits(selected ? .isSelected : [])
    }
}
