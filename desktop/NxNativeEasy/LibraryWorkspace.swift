import SwiftUI
import AppKit

struct LibraryWorkspace:View {
    @ObservedObject var model:BuildModel
    @ObservedObject var library:GameLibrary
    @ObservedObject var updater:AppUpdater
    @ObservedObject var sideload:SideloadModel
    private enum Page {case library,prepare,devices,settings,compatibility}
    @State private var page=Page.library
    private var preparing:Bool {page == .prepare}
    @State private var query=""
    @State private var selectedGameID:String?
    @State private var rebuildAdvice:[String:String]=[:]
    @State private var adviceGeneration=UUID()
    @State private var removing:OwnedGameOutput?
    @Environment(\.scenePhase) private var scenePhase
    private let accent=EasyDesign.accent
    private var occupied:Bool {model.running || updater.busy || sideload.busy}
    private func name(_ game:OwnedGameOutput)->String {model.catalog.first(where:{$0.id==game.titleID})?.name ?? game.folder.lastPathComponent}
    private var results:[OwnedGameOutput] {library.games.filter {query.isEmpty || (name($0)+" "+($0.titleID ?? "")+" "+$0.item.folder).localizedCaseInsensitiveContains(query)}}
    private var selectedResult:OwnedGameOutput? {results.first(where:{$0.id==selectedGameID}) ?? results.first}
    private func needsRebuild(_ game:OwnedGameOutput)->Bool {["Mac","iPhone / iPad"].contains {rebuildAdvice[game.id+$0]=="rebuild"}}
    private func libraryStatus(_ game:OwnedGameOutput)->String {
        let observations=sideload.observations(titleID:game.titleID,originalID:game.originalBundleID)
        if let item=observations.first(where:sideload.isVerified) {return model.text("Instalado en")+" "+item.deviceName}
        if let item=observations.first {return model.text(item.checkedAt==nil ? "Instalación registrada en" : "Última vez en")+" "+item.deviceName}
        if game.macApp != nil && game.iosIPA != nil {return model.text("Mac listo · IPA lista")}
        if game.macApp != nil {return model.text("Listo para jugar en Mac")}
        return model.text(game.iosIPA != nil ? "IPA lista para instalar" : "Sin preparar")
    }
    private func configure(_ game:OwnedGameOutput) {
        guard !occupied else {return}
        model.folder=game.folder;model.defaults.set(game.item.folder,forKey:"lastGameFolder")
        model.output=nil;model.assets=nil;model.target=game.macApp != nil ? "mac" : game.iosIPA != nil ? "ios" : ""
        if model.target=="ios" {model.splitIOS=game.romfs != nil}
        model.restoreOutput();model.installingInline=false;model.preparationStep=0;page = .prepare
    }
    private func install(_ game:OwnedGameOutput) {
        guard !occupied,let ipa=game.iosIPA else {return}
        model.installingInline=false;sideload.configure(ipa:ipa,folder:game.folder,romfs:game.romfs);model.showSideload=true
    }
    private func add() {
        guard !occupied else {return}
        model.installingInline=false;model.folder=nil;model.target="";model.failed=false;model.preparationStep=0;page = .prepare
    }
    private func remember() {
        guard let folder=model.folder else {return}
        do {try library.add(folder)}catch{library.error="No pudimos añadir esa carpeta a la biblioteca. Tus archivos siguen intactos."}
    }
    private func checkBuildAdvice(_ snapshot:[OwnedGameOutput]?=nil) {
        let generation=UUID();adviceGeneration=generation
        let games=snapshot ?? library.games,repo=model.repo
        Task {
            let advice=await Task.detached(priority:.utility) { ()->[String:String] in
                var result:[String:String]=[:]
                for game in games {
                    guard let id=game.titleID else {continue}
                    for (platform,revision,ready) in [("Mac",game.macRevision,game.macApp != nil),("iPhone / iPad",game.iosRevision,game.iosIPA != nil)] where ready {
                        let value=BuildProvenance.recommendation(repo:repo,revision:revision,titleID:id)
                        if value==true {result[game.id+platform]="rebuild"}
                        else if value==nil {result[game.id+platform]="unknown"}
                    }
                }
                return result
            }.value
            if adviceGeneration==generation {rebuildAdvice=advice}
        }
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
                    nav("Compatibilidad",icon:"checklist",selected:page == .compatibility){model.openCatalog()}
                    Spacer()
                    Divider()
                    nav("Configuración",icon:"gearshape",selected:page == .settings){page = .settings}
                }.padding(20).frame(width:190).frame(maxHeight:.infinity).background(.white.opacity(0.025))
                Divider()
                ZStack {
                    // Keep one preparation model/view alive: its task, logs, cancellation,
                    // update checks and sheets continue when browsing the library.
                    ContentView(updater:updater,sideload:sideload,model:model)
                        .opacity(preparing ? 1 : 0).allowsHitTesting(preparing).accessibilityHidden(!preparing)
                    if page == .settings {WorkspaceSettingsView(model:model,sideload:sideload)}
                    if page == .compatibility {GameCatalogView(model:model)}
                    if page == .devices {
                        SideloadLibraryView(model:sideload,text:model.text,canInstall:!model.running && !updater.busy,prepareGame:{
                            page = .prepare;model.folder=sideload.hasPendingUpdate ? sideload.gameFolder : nil;model.failed=false;model.preparationStep=0;model.target="ios"
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
                                Text(String(library.games.count)+" "+model.text(library.games.count==1 ? "juego" : "juegos")).font(.caption).foregroundStyle(.secondary)
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
                                HStack(alignment:.top,spacing:0) {
                                    ScrollView {
                                        LazyVStack(spacing:5) {
                                            ForEach(results) {game in
                                                Button {selectedGameID=game.id} label:{
                                                    HStack(spacing:9) {
                                                        if let image=GameArtworkCache.image(model.catalog.first(where:{$0.id==game.titleID})?.artworkURL) {Image(nsImage:image).resizable().scaledToFill().frame(width:42,height:42).clipped().clipShape(RoundedRectangle(cornerRadius:6))}
                                                        else {Image(systemName:"gamecontroller").frame(width:42,height:42)}
                                                        VStack(alignment:.leading,spacing:3) {Text(name(game)).font(.system(size:12,weight:.semibold)).lineLimit(2);Text(libraryStatus(game)).font(.caption2).foregroundStyle(.secondary).lineLimit(2);if needsRebuild(game) {Text(model.text("Conviene recompilar")).font(.caption2).foregroundStyle(.orange)}}
                                                        Spacer(minLength:0)
                                                    }.padding(8).background(selectedResult?.id==game.id ? accent.opacity(0.12) : .clear,in:RoundedRectangle(cornerRadius:8))
                                                }.buttonStyle(.plain)
                                            }
                                        }.padding(.trailing,12)
                                    }.frame(width:210)
                                    Divider()
                                    if let game=selectedResult {
                                        ScrollView {
                                            GameLibraryDetail(game:game,title:name(game),catalog:model.catalog.first(where:{$0.id==game.titleID}),text:model.text,building:model.running && model.folder?.resolvingSymlinksInPath().path==game.folder.resolvingSymlinksInPath().path,disabled:occupied,observations:sideload.observations(titleID:game.titleID,originalID:game.originalBundleID),isVerified:sideload.isVerified,needsRebuild:needsRebuild(game),advice:["Mac","iPhone / iPad"].compactMap {platform in rebuildAdvice[game.id+platform].map {value in platform+": "+model.text(value=="rebuild" ? "Conviene recompilar: cambiaron herramientas o el perfil de este juego." : "No hay historial suficiente para comparar esta preparación.") }},checkDevices:{if sideload.devices.count>1 && sideload.device.isEmpty {page = .devices}else{sideload.listDevices()}},open:{if let mac=game.macApp {NSWorkspace.shared.open(mac)}},prepare:{configure(game)},install:{install(game)},remove:{removing=game})
                                        }.padding(.leading,20)
                                    }
                                }

                            }
                            Text(model.text("Esta biblioteca sólo contiene las carpetas que tú añades. No incluye ni descarga juegos.")).font(.caption).foregroundStyle(.secondary)
                        }.padding(28).frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading)
                    }
                }
            }
            if sideload.recoveringSession && page != .settings && !model.showSideload && !model.installingInline {
                Divider()
                HStack(spacing:12) {
                    ProgressView().controlSize(.small)
                    Text(model.text("Recuperando tu sesión del Llavero…")).font(.callout)
                    Spacer()
                    Button(model.text("Cancelar")){sideload.cancel()}
                }.padding(.horizontal,24).padding(.vertical,12)
            }
            if model.running || (!model.buildDockDismissed && (model.failed || !model.activity.history.isEmpty)) {
                Divider()
                BuildDock(model:model,completion:sideload.completedInstallation && sideload.gameFolder?.path==model.folder?.path ? model.text("Instalación completada en")+" "+(sideload.devices.first(where:{$0.id==sideload.device})?.name ?? "iPhone / iPad") : nil,show:{page = .prepare;model.installingInline=false;model.preparationStep=model.running || model.failed || model.output==nil ? 4 : 5;model.showDetails=true})
            }
        }.frame(minWidth:1000,minHeight:640).tint(accent).background(Color(red:0.065,green:0.075,blue:0.07)).preferredColorScheme(.dark)
        .task {
            if model.folder != nil && library.games.isEmpty && library.error==nil {remember()}
            checkBuildAdvice()
            if !occupied && !library.games.isEmpty {sideload.listDevices()}
            sideload.recoverRememberedSessionIfNeeded()
        }
        .dropDestination(for:URL.self) {items,_ in
            guard !occupied else {return false}
            if page != .prepare {model.target="";model.folder=nil;model.preparationStep=0}
            model.acceptDrop(items);if !model.failed {remember()};page = .prepare;return true
        }
        .onReceive(NotificationCenter.default.publisher(for:Notification.Name("nxnative.openSettings"))){_ in page = .settings}
        .onChange(of:model.installingInline){_,inline in if inline {page = .prepare}}
        .onReceive(NotificationCenter.default.publisher(for:Notification.Name("nxnative.showLibrary"))){_ in page = .library;if !sideload.busy {model.showSideload=false};library.refresh()}
        .onReceive(NotificationCenter.default.publisher(for:Notification.Name("nxnative.showBuildActivity"))){_ in page = .prepare;model.installingInline=false;model.preparationStep=model.running || model.failed || model.output==nil ? 4 : 5;model.showDetails=true}
        .onChange(of:model.showCatalog){_,show in if show {page = .compatibility;model.showCatalog=false}}
        .onChange(of:model.showDeviceLibrary){_,show in if show {page = .devices;model.showDeviceLibrary=false}}
        .onReceive(library.$games){games in checkBuildAdvice(games);sideload.preparedFolders=Dictionary(games.compactMap {game in game.titleID.map {($0,game.folder)}},uniquingKeysWith:{first,_ in first});sideload.preparedIdentifiers=games.compactMap {game in game.originalBundleID ?? game.titleID.map {"org.nxnative."+$0.lowercased()}}}
        .onChange(of:model.folder){_,_ in if model.folder != nil {remember()}}
        .onChange(of:model.running){old,new in
            if old && !new {
                if !model.failed,model.output != nil,let folder=model.folder,let revision=model.buildRevision {library.recordBuild(folder:folder,target:model.target,revision:revision)}
                library.refresh();checkBuildAdvice()
            }
        }
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

struct WorkspaceSettingsView:View {
    @ObservedObject var model:BuildModel
    @ObservedObject var sideload:SideloadModel
    enum Section:String,CaseIterable {case general,apple,controllers}
    @State var section=Section.general
    @State private var copiedDiagnostics=false
    @AppStorage("buildNotifications") private var buildNotifications=true
    private var version:String {Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "development"}
    private func title(_ section:Section)->String {
        switch section {case .general:return "General";case .apple:return "Cuenta Apple";case .controllers:return "Control"}
    }
    var body:some View {
        VStack(alignment:.leading,spacing:0) {
            VStack(alignment:.leading,spacing:20) {
                Text(model.text("Configuración")).font(.system(size:30,weight:.bold,design:.rounded))
                Picker(model.text("Sección de configuración"),selection:$section) {
                    ForEach(Section.allCases,id:\.self) {item in Text(model.text(title(item))).tag(item)}
                }.pickerStyle(.segmented).labelsHidden()
            }.padding(28)
            Divider()
            switch section {
            case .general:
                ScrollView {
                    VStack(alignment:.leading,spacing:24) {
                        VStack(alignment:.leading,spacing:20) {
                            Label(model.text("Personaliza la app"),systemImage:"slider.horizontal.3").font(.headline)
                            HStack {
                                VStack(alignment:.leading,spacing:5) {Text(model.text("Idioma de la interfaz")).font(.callout.bold());Text(model.text("El idioma del juego se configura por separado.")).font(.caption).foregroundStyle(.secondary)}
                                Spacer()
                                Picker(model.text("Idioma de la interfaz"),selection:$model.language){Text("English").tag(EasyLanguage.english);Text("Español").tag(EasyLanguage.spanish)}.labelsHidden().frame(width:180)
                            }
                            Divider()
                            Toggle(model.text("Notificar cuando termine una preparación"),isOn:$buildNotifications).toggleStyle(.switch)
                        }.padding(22).frame(maxWidth:.infinity,alignment:.leading).background(.white.opacity(0.035),in:RoundedRectangle(cornerRadius:16))
                        VStack(alignment:.leading,spacing:16) {
                            Label(model.text("Ayuda y diagnóstico"),systemImage:"lifepreserver").font(.headline)
                            Text(model.text("Comparte un resumen de la app y del último proceso, con datos sensibles ocultos.")).font(.callout).foregroundStyle(.secondary)
                            Button(model.text(copiedDiagnostics ? "Diagnóstico copiado" : "Copiar diagnóstico")){model.copyDiagnostics();copiedDiagnostics=true}
                        }.padding(22).frame(maxWidth:.infinity,alignment:.leading).background(.white.opacity(0.035),in:RoundedRectangle(cornerRadius:16))
                        Text("nxnative Easy · "+version).font(.caption).foregroundStyle(.secondary)
                    }.padding(28)
                }
            case .apple:
                SideloadView(model:sideload,text:model.text,accountOnly:true,embedded:true)
            case .controllers:
                ScrollView {
                    VStack(alignment:.leading,spacing:12) {
                        Text(model.text("Prueba el control conectado a este Mac sin abrir ni preparar un juego.")).font(.callout).foregroundStyle(.secondary).padding(.horizontal,26).padding(.top,24)
                        ControllerTestView(text:model.text,embedded:true)
                    }
                }
            }
        }.frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading)
    }
}

struct GameLibraryDetail:View {
    let game:OwnedGameOutput
    let title:String
    let catalog:CatalogGame?
    let text:(String)->String
    let building:Bool
    let disabled:Bool
    var observations:[DeviceGameObservation]=[]
    var isVerified:(DeviceGameObservation)->Bool={_ in false}
    var needsRebuild=false
    var advice:[String]=[]
    var checkDevices:()->Void={}
    let open:()->Void
    let prepare:()->Void
    let install:()->Void
    let remove:()->Void
    var body:some View {
        VStack(alignment:.leading,spacing:18) {
            ZStack(alignment:.bottomLeading) {
                if let catalog {GameArtworkView(game:catalog)}else {Rectangle().fill(.white.opacity(0.05)).overlay(Image(systemName:"gamecontroller").font(.system(size:50)).foregroundStyle(.secondary))}
                LinearGradient(colors:[.clear,.black.opacity(0.85)],startPoint:.center,endPoint:.bottom)
                VStack(alignment:.leading,spacing:6) {
                    if building {Label(text("Compilando"),systemImage:"hammer.fill").font(.caption.bold())}
                    Text(title).font(.system(size:28,weight:.bold,design:.rounded)).lineLimit(2)
                }.padding(20).foregroundStyle(.white)
            }.frame(height:240).clipped().clipShape(RoundedRectangle(cornerRadius:14))
            if let device=observations.first(where:isVerified) ?? observations.first {
                Label(text(isVerified(device) ? "Instalación verificada" : device.checkedAt==nil ? "Instalación registrada" : "Última instalación observada")+" · "+device.deviceName,systemImage:isVerified(device) ? "checkmark.circle.fill" : "clock").font(.callout.weight(.semibold)).foregroundStyle(isVerified(device) ? Color.green : .secondary)
            }
            if needsRebuild {Label(text("Conviene recompilar: cambiaron herramientas o el perfil de este juego."),systemImage:"arrow.triangle.2.circlepath").font(.callout).foregroundStyle(.orange)}
            HStack(spacing:12) {
                if game.macApp != nil {Button(action:open){Label(text("Jugar en Mac"),systemImage:"play.fill")}.buttonStyle(LibraryPrimaryButtonStyle()).disabled(disabled || game.missing)}
                if game.iosIPA != nil {Button(action:install){Label(text(observations.isEmpty ? "Instalar en iPhone / iPad" : "Actualizar en iPhone / iPad"),systemImage:"iphone")}.buttonStyle(LibraryPrimaryButtonStyle()).disabled(disabled || game.missing)}
                if !game.ready {Button(text("Preparar juego"),action:prepare).buttonStyle(LibraryPrimaryButtonStyle()).disabled(disabled || game.missing)}
                Spacer(minLength:0)
                Menu {
                    Button(text("Preparar o actualizar"),action:prepare).disabled(disabled || game.missing)
                    Button(text("Mostrar carpeta")){NSWorkspace.shared.activateFileViewerSelecting([game.folder])}
                    Button(text("Quitar de esta lista"),role:.destructive,action:remove).disabled(disabled)
                } label:{Image(systemName:"ellipsis")}.menuStyle(.borderlessButton).fixedSize().accessibilityLabel(text("Acciones del juego"))
            }
            HStack(spacing:18) {
                Label(text(game.macApp != nil ? "Mac: listo para jugar" : "Mac: sin app creada"),systemImage:"desktopcomputer")
                Label(text(game.iosIPA != nil ? "Archivo IPA: listo para instalar" : "Archivo IPA: sin crear"),systemImage:"iphone")
            }.font(.caption).foregroundStyle(.secondary)
            VStack(alignment:.leading,spacing:10) {
                HStack {Text(text("En tus dispositivos")).font(.headline);Spacer();Button(text("Comprobar dispositivos"),action:checkDevices).disabled(disabled)}
                if observations.isEmpty {Text(text("Todavía no verificamos este juego en un iPhone o iPad. Conéctalo para comprobarlo.")).font(.caption).foregroundStyle(.secondary)}
                ForEach(observations) {item in
                    HStack(alignment:.top,spacing:9) {
                        Image(systemName:isVerified(item) ? "checkmark.circle.fill" : "clock").foregroundStyle(isVerified(item) ? Color.green : .secondary)
                        VStack(alignment:.leading,spacing:4) {
                            Text(item.deviceName).font(.callout.bold())
                            Text(text(isVerified(item) ? "Instalación verificada" : item.checkedAt==nil ? "Instalación registrada" : "Última instalación observada")+(item.checkedAt.map {" · "+$0.formatted(date:.abbreviated,time:.shortened)} ?? "")).font(.caption).foregroundStyle(.secondary)
                            if !item.version.isEmpty {Text(text("Versión instalada")+" · "+item.version).font(.caption).foregroundStyle(.secondary)}
                            if item.checkedAt==nil {Text(text("Hay un registro de instalación. Conecta el dispositivo para comprobar su estado actual.")).font(.caption).foregroundStyle(.secondary)}
                        }
                    }
                }
            }.padding(14).frame(maxWidth:.infinity,alignment:.leading).background(.white.opacity(0.035),in:RoundedRectangle(cornerRadius:12))
            ForEach(advice,id:\.self) {note in Label(note,systemImage:"arrow.triangle.2.circlepath").font(.caption).foregroundStyle(.secondary)}
            if let version=game.version {Text(text("Versión preparada")+" · "+version).font(.callout).foregroundStyle(.secondary)}
            if game.missing {Label(text("Carpeta no disponible"),systemImage:"externaldrive.badge.exclamationmark").foregroundStyle(.orange)}
            Divider()
            Button(text("Preparar o actualizar"),action:prepare).disabled(disabled || game.missing)
            Text(text("Usa tus archivos para preparar otra plataforma o aplicar un update. Tus partidas y archivos originales se conservan.")).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth:.infinity,alignment:.leading).padding(.bottom,12)
    }
}

struct BuildDock:View {
    @ObservedObject var model:BuildModel
    var completion:String?=nil
    let show:()->Void
    var body:some View {
        HStack(spacing:20) {
            VStack(alignment:.leading,spacing:5) {
                HStack {Image(systemName:model.failed ? "exclamationmark.triangle" : "hammer");Text(model.gameName).font(.headline);Text(model.isMac ? "Mac" : "iPhone / iPad").font(.caption).foregroundStyle(.secondary)}
                Text(!model.running ? (completion ?? model.text(model.phase)) : [model.activity.stage,model.activity.step,model.activity.count].filter{!$0.isEmpty}.joined(separator:" · ")).font(.caption).lineLimit(1).foregroundStyle(.secondary)
            }.frame(maxWidth:.infinity,alignment:.leading)
            if model.running {
                VStack(alignment:.leading,spacing:5) {
                    if let fraction=model.activity.fraction {ProgressView(value:fraction)}else{ProgressView().progressViewStyle(.linear)}
                    Text(model.text("Etapa actual")+(model.activity.fraction.map{" · "+String(Int($0*100))+" %"} ?? "")+(model.activity.eta.map{" · ~"+String(Int($0))+" s"} ?? "")).font(.caption2).foregroundStyle(.secondary)
                }.frame(width:220)
            }
            Button(model.text("Ver actividad"),action:show)
            if model.running {Button(model.text("Cancelar")){model.cancel()}}
            else {Button {model.dismissBuildDock()} label:{Image(systemName:"xmark")}.buttonStyle(EasySecondaryStyle()).accessibilityLabel(model.text("Cerrar aviso de actividad")).help(model.text("Cerrar aviso de actividad"))}
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
    func makeBody(configuration:Configuration)->some View {EasyPrimaryStyle().makeBody(configuration:configuration)}
}
