import SwiftUI
import AppKit

struct LibraryWorkspace:View {
    @ObservedObject var model:BuildModel
    @ObservedObject var library:GameLibrary
    @ObservedObject var updater:AppUpdater
    @ObservedObject var sideload:SideloadModel
    private enum Page {case library,prepare,devices}
    @State private var page=Page.library
    private var preparing:Bool {page == .prepare}
    @State private var query=""
    @State private var removing:OwnedGameOutput?
    @Environment(\.scenePhase) private var scenePhase
    private let accent=Color(red:0.79,green:0.95,blue:0.37)
    private var occupied:Bool {model.running || updater.busy || sideload.busy}
    private func name(_ game:OwnedGameOutput)->String {model.catalog.first(where:{$0.id==game.titleID})?.name ?? game.folder.lastPathComponent}
    private var results:[OwnedGameOutput] {library.games.filter {query.isEmpty || (name($0)+" "+($0.titleID ?? "")+" "+$0.item.folder).localizedCaseInsensitiveContains(query)}}
    private func configure(_ game:OwnedGameOutput) {
        guard !occupied else {return}
        model.folder=game.folder;model.defaults.set(game.item.folder,forKey:"lastGameFolder")
        model.output=nil;model.assets=nil;model.target=game.macApp != nil ? "mac" : game.iosIPA != nil ? "ios" : ""
        if model.target=="ios" {model.splitIOS=game.romfs != nil}
        model.restoreOutput();page = .prepare
    }
    private func install(_ game:OwnedGameOutput) {
        guard !occupied,let ipa=game.iosIPA else {return}
        sideload.configure(ipa:ipa,folder:game.folder,romfs:game.romfs);model.showSideload=true
    }
    private func add() {
        guard !occupied else {return}
        if model.chooseFolder() {remember();page = .prepare}
    }
    private func remember() {
        guard let folder=model.folder else {return}
        do {try library.add(folder)}catch{library.error="No pudimos añadir esa carpeta a la biblioteca. Tus archivos siguen intactos."}
    }
    var body:some View {
        VStack(spacing:0) {
            HStack(spacing:0) {
                VStack(alignment:.leading,spacing:22) {
                    HStack(spacing:8) {Image(nsImage:AppArtwork.icon).resizable().frame(width:30,height:30);Text("nxnative\neasy").font(.headline).lineSpacing(-2)}.foregroundStyle(accent).padding(.bottom,12)
                    nav("Mi biblioteca",icon:"square.grid.2x2",selected:page == .library){page = .library}
                    nav("Preparar juego",icon:"hammer",selected:preparing){page = .prepare}
                    Divider()
                    nav("Dispositivos",icon:"ipad.and.iphone",selected:page == .devices){page = .devices}
                    nav("Compatibilidad",icon:"checklist",selected:false){model.openCatalog()}
                    Spacer()
                    Picker(model.text("Idioma de la interfaz"),selection:$model.language){Text("English").tag(EasyLanguage.english);Text("Español").tag(EasyLanguage.spanish)}.labelsHidden()
                    Text(Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "nxnative Easy").font(.caption).foregroundStyle(.secondary)
                }.padding(20).frame(width:190).frame(maxHeight:.infinity).background(.white.opacity(0.025))
                Divider()
                ZStack {
                    // Keep one preparation model/view alive: its task, logs, cancellation,
                    // update checks and sheets continue when browsing the library.
                    ContentView(updater:updater,sideload:sideload,model:model)
                        .opacity(preparing ? 1 : 0).allowsHitTesting(preparing).accessibilityHidden(!preparing)
                    if page == .devices {
                        SideloadLibraryView(model:sideload,text:model.text,canInstall:!model.running && !updater.busy,prepareGame:{
                            page = .prepare;model.target="ios";if !model.chooseFolder() {sideload.cancelPendingUpdate()}
                        },embedded:true,artwork:{app in
                            guard let id=sideload.titleID(for:app) else {return nil}
                            return GameArtworkCache.image(model.catalog.first(where:{$0.id==id})?.artworkURL)
                        })
                    }
                    if page == .library {
                        VStack(alignment:.leading,spacing:20) {
                            HStack(alignment:.top) {
                                VStack(alignment:.leading,spacing:7) {Text(model.text("Mi biblioteca")).font(.system(size:30,weight:.bold,design:.rounded));Text(model.text("Tus juegos. Tus archivos. Todo en un lugar.")).foregroundStyle(.secondary)}
                                Spacer();Button {add()} label:{Label(model.text("Añadir juego"),systemImage:"plus")}.buttonStyle(LibraryPrimaryButtonStyle()).disabled(occupied)
                            }
                            HStack {
                                TextField(model.text("Buscar en mis juegos"),text:$query).textFieldStyle(.roundedBorder)
                                Text(String(library.games.count)+" "+model.text("juegos")).font(.caption).foregroundStyle(.secondary)
                                Button {library.refresh()} label:{Image(systemName:"arrow.clockwise")}.help(model.text("Actualizar biblioteca")).accessibilityLabel(model.text("Actualizar biblioteca"))
                            }
                            if updater.visible {
                                Button {page = .prepare} label:{Label(model.text(updater.busy ? updater.phaseText : "Hay una nueva versión"),systemImage:"arrow.down.circle")}.buttonStyle(.link)
                            }
                            if let error=library.error {Text(model.text(error)).font(.callout).foregroundStyle(.orange).textSelection(.enabled)}
                            if sideload.showsRefreshNotice {Button(model.text("Revisar renovación")){page = .devices}.disabled(sideload.busy)}
                            if library.games.isEmpty {
                                VStack(spacing:16) {
                                    Image(systemName:"square.stack.3d.up").font(.system(size:42,weight:.light)).foregroundStyle(accent)
                                    Text(model.text("Tu colección empieza con tu primer juego")).font(.title2.bold())
                                    Text(model.text("Añade su carpeta. Conservamos los archivos donde están y recordamos tus versiones para Mac, iPhone y iPad.")).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth:440)
                                    Button(model.text("Añadir juego")){add()}.buttonStyle(LibraryPrimaryButtonStyle()).disabled(occupied)
                                    Button(model.text("Ver juegos compatibles")){model.openCatalog()}.buttonStyle(.link)
                                }.frame(maxWidth:.infinity,maxHeight:.infinity)
                            } else if results.isEmpty {Text(model.text("No hay juegos que coincidan con tu búsqueda.")).foregroundStyle(.secondary).frame(maxWidth:.infinity,maxHeight:.infinity)}
                            else {
                                ScrollView {
                                    LazyVGrid(columns:[GridItem(.adaptive(minimum:230,maximum:340),spacing:18)],alignment:.leading,spacing:18) {
                                        ForEach(results) {game in
                                            GameLibraryCard(game:game,title:name(game),catalog:model.catalog.first(where:{$0.id==game.titleID}),text:model.text,building:model.running && model.folder?.resolvingSymlinksInPath().path==game.folder.resolvingSymlinksInPath().path,disabled:occupied,open:{
                                                if let mac=game.macApp {NSWorkspace.shared.open(mac)}
                                                else if game.iosIPA != nil {install(game)}
                                                else {configure(game)}
                                            },prepare:{configure(game)},install:{install(game)},remove:{removing=game})
                                        }
                                    }.padding(.bottom,8)
                                }
                            }
                            Text(model.text("Esta biblioteca sólo contiene las carpetas que tú añades. No incluye ni descarga juegos.")).font(.caption).foregroundStyle(.secondary)
                        }.padding(28).frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading)
                    }
                }
            }
            if model.running || model.failed || !model.activity.history.isEmpty {
                Divider()
                BuildDock(model:model,show:{page = .prepare;model.showDetails=true})
            }
        }.frame(minWidth:1000,minHeight:640).tint(accent).background(Color(red:0.065,green:0.075,blue:0.07)).preferredColorScheme(.dark)
        .task {if model.folder != nil && library.games.isEmpty && library.error==nil {remember()}}
        .onChange(of:model.showDeviceLibrary){_,show in if show {page = .devices;model.showDeviceLibrary=false}}
        .onReceive(library.$games){games in sideload.preparedFolders=Dictionary(games.compactMap {game in game.titleID.map {($0,game.folder)}},uniquingKeysWith:{first,_ in first});sideload.preparedIdentifiers=games.compactMap {game in game.originalBundleID ?? game.titleID.map {"org.nxnative."+$0.lowercased()}}}
        .onChange(of:model.folder){_,_ in if model.folder != nil {remember()}}
        .onChange(of:model.running){old,new in if old && !new {library.refresh()}}
        .onChange(of:scenePhase){_,phase in if phase == .active {library.refresh()}}
        .alert(model.text("¿Quitar de la biblioteca?"),isPresented:Binding(get:{removing != nil},set:{if !$0 {removing=nil}})) {
            Button(model.text("Cancelar"),role:.cancel){removing=nil}
            Button(model.text("Quitar de esta lista"),role:.destructive){if let removing {library.remove(removing.id)};removing=nil}
        } message:{Text(model.text("Sólo quitamos el acceso de la biblioteca. No borramos juegos, cachés, llaves ni partidas."))}
    }
    private func nav(_ title:String,icon:String,selected:Bool,action:@escaping()->Void)->some View {
        Button(action:action){Label(model.text(title),systemImage:icon).font(.system(size:12,weight:selected ? .semibold : .regular)).frame(maxWidth:.infinity,alignment:.leading).padding(.vertical,10).padding(.horizontal,9).background(selected ? accent.opacity(0.1) : .clear,in:RoundedRectangle(cornerRadius:9)).foregroundStyle(selected ? accent : Color.primary)}.buttonStyle(.plain)
    }
}

struct GameLibraryCard:View {
    let game:OwnedGameOutput
    let title:String
    let catalog:CatalogGame?
    let text:(String)->String
    let building:Bool
    let disabled:Bool
    let open:()->Void
    let prepare:()->Void
    let install:()->Void
    let remove:()->Void
    private let accent=Color(red:0.79,green:0.95,blue:0.37)
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            ZStack(alignment:.bottomLeading) {
                if let catalog {GameArtworkView(game:catalog)}else{Rectangle().fill(accent.opacity(0.08)).overlay(Image(systemName:"gamecontroller").font(.system(size:38,weight:.light)).foregroundStyle(accent))}
                LinearGradient(colors:[.clear,.black.opacity(0.75)],startPoint:.center,endPoint:.bottom)
                if building {Label(text("Compilando"),systemImage:"hammer.fill").font(.caption.bold()).padding(10).foregroundStyle(.white)}
            }.frame(height:132).clipped().clipShape(RoundedRectangle(cornerRadius:10))
            Text(title).font(.headline).lineLimit(2).frame(height:40,alignment:.topLeading)
            HStack(spacing:8) {
                if game.macApp != nil {Label("Mac",systemImage:"desktopcomputer").foregroundStyle(accent)}
                if game.iosIPA != nil {Label("iPhone / iPad",systemImage:"iphone").foregroundStyle(accent)}
                if !game.ready {Label(text(game.missing ? "Carpeta no disponible" : "Sin preparar"),systemImage:game.missing ? "externaldrive.badge.exclamationmark" : "circle.dashed").foregroundStyle(.secondary)}
            }.font(.caption)
            HStack {
                Button(text(game.macApp != nil ? "Abrir juego" : game.iosIPA != nil ? "Instalar" : "Preparar"),action:open).buttonStyle(LibraryPrimaryButtonStyle()).disabled(disabled || game.missing)
                Spacer()
                Menu {
                    if game.macApp != nil && game.iosIPA != nil {Button(text("Instalar en iPhone / iPad"),action:install).disabled(disabled)}
                    Button(text("Preparar o actualizar"),action:prepare).disabled(disabled || game.missing)
                    Button(text("Mostrar carpeta")){NSWorkspace.shared.activateFileViewerSelecting([game.folder])}
                    Button(text("Quitar de esta lista"),role:.destructive,action:remove).disabled(disabled)
                } label:{Image(systemName:"ellipsis")}.menuStyle(.borderlessButton).fixedSize().accessibilityLabel(text("Acciones del juego"))
            }
        }.padding(13).background(.white.opacity(0.035),in:RoundedRectangle(cornerRadius:15)).overlay(RoundedRectangle(cornerRadius:15).strokeBorder(.white.opacity(0.055)))
    }
}

struct BuildDock:View {
    @ObservedObject var model:BuildModel
    let show:()->Void
    var body:some View {
        HStack(spacing:20) {
            VStack(alignment:.leading,spacing:5) {
                HStack {Image(systemName:model.failed ? "exclamationmark.triangle" : "hammer");Text(model.gameName).font(.headline);Text(model.isMac ? "Mac" : "iPhone / iPad").font(.caption).foregroundStyle(.secondary)}
                Text(!model.running ? model.text(model.phase) : [model.activity.stage,model.activity.step,model.activity.count].filter{!$0.isEmpty}.joined(separator:" · ")).font(.caption).lineLimit(1).foregroundStyle(.secondary)
            }.frame(maxWidth:.infinity,alignment:.leading)
            if model.running {
                VStack(alignment:.leading,spacing:5) {
                    if let fraction=model.activity.fraction {ProgressView(value:fraction)}else{ProgressView().progressViewStyle(.linear)}
                    Text(model.text("Etapa actual")+(model.activity.fraction.map{" · "+String(Int($0*100))+" %"} ?? "")+(model.activity.eta.map{" · ~"+String(Int($0))+" s"} ?? "")).font(.caption2).foregroundStyle(.secondary)
                }.frame(width:220)
            }
            Button(model.text("Ver actividad"),action:show)
            if model.running {Button(model.text("Cancelar")){model.cancel()}}
        }.padding(.horizontal,24).padding(.vertical,16)
    }
}

struct BuildTimeline:View {
    let activity:BuildActivity
    let text:(String)->String
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            HStack {Text(text("Etapas de compilación")).font(.headline);Spacer();if activity.stages>0 {Text(String(activity.history.filter{$0.state == .done && $0.number>0}.count)+" / "+String(activity.stages)).font(.caption).monospacedDigit().foregroundStyle(.secondary)}}
            ForEach(activity.history) {stage in
                HStack(alignment:.top,spacing:10) {
                    VStack(spacing:4) {Image(systemName:stage.state == .done ? "checkmark.circle.fill" : stage.state == .failed ? "xmark.circle.fill" : stage.state == .cancelled ? "pause.circle" : "circle.inset.filled").foregroundStyle(stage.state == .failed ? Color.orange : stage.state == .done ? Color.green : Color.primary)
                        if stage.id != activity.history.last?.id {Rectangle().fill(.secondary.opacity(0.3)).frame(width:1,height:14)}
                    }
                    VStack(alignment:.leading,spacing:3) {Text(stage.name).font(.callout.weight(stage.state == .active ? .semibold : .regular));if stage.state == .active && !activity.step.isEmpty {Text(activity.step).font(.caption).foregroundStyle(.secondary)}}
                    Spacer()
                }
            }
            if let eta=activity.eta {Text(text("Tiempo restante informado")+": ~"+String(Int(eta))+" s").font(.caption).foregroundStyle(.secondary)}
        }.padding(16).background(.white.opacity(0.035),in:RoundedRectangle(cornerRadius:12))
    }
}


struct LibraryPrimaryButtonStyle:ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration:Configuration)->some View {
        configuration.label.font(.system(size:13,weight:.semibold))
            .padding(.horizontal,13).padding(.vertical,8).frame(minHeight:34)
            .foregroundStyle(enabled ? Color.black : Color.secondary)
            .background(enabled ? Color(red:0.79,green:0.95,blue:0.37) : Color.white.opacity(0.065),in:RoundedRectangle(cornerRadius:8))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
