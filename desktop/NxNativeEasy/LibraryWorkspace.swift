import SwiftUI
import AppKit

struct LibraryWorkspace:View {
    @ObservedObject var model:BuildModel
    @ObservedObject var library:GameLibrary
    @ObservedObject var updater:AppUpdater
    @ObservedObject var sideload:SideloadModel
    private enum Page {case library,prepare,devices,settings,compatibility,saves}
    @StateObject private var saves=SaveCenterModel()
    @State private var saveFocus:String?
    @State private var maintaining:OwnedGameOutput?
    @State private var maintenanceAction:GameMaintenanceAction?
    @State private var maintenanceGame:OwnedGameOutput?
    @State private var page=Page.library
    private var preparing:Bool {page == .prepare}
    @State private var query=""
    @State private var platform="all"
    @State private var spotlightGameID:String?
    @State private var selectedGameID:String?
    @State private var dropTargeted=false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rebuildAdvice:[String:String]=[:]
    @State private var adviceGeneration=UUID()
    @State private var removing:OwnedGameOutput?
    @Environment(\.scenePhase) private var scenePhase
    private let accent=EasyDesign.accent
    private var occupied:Bool {model.running || updater.busy || sideload.blocksGameWork || saves.busy}
    private func name(_ game:OwnedGameOutput)->String {model.catalog.first(where:{$0.id==game.titleID})?.name ?? game.folder.lastPathComponent}
    private var results:[OwnedGameOutput] {
        library.games.filter {game in
            let mobile=game.iosIPA != nil || !sideload.observations(titleID:game.titleID,originalID:game.originalBundleID).isEmpty
            let matches=platform=="all" || (platform=="mac" ? game.macApp != nil : mobile)
            return matches && (query.isEmpty || (name(game)+" "+(game.titleID ?? "")+" "+game.item.folder).localizedCaseInsensitiveContains(query))
        }
    }

    private var selectedResult:OwnedGameOutput? {library.games.first(where:{$0.id==selectedGameID})}
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
        guard !occupied,!sideload.busy,let ipa=game.iosIPA else {return}
        model.installingInline=false;sideload.configure(ipa:ipa,folder:game.folder,romfs:game.romfs);model.showSideload=true
    }
    private func add() {
        guard !occupied else {return}
        query="";platform="all";spotlightGameID=nil;model.installingInline=false;model.folder=nil;model.target="";model.failed=false;model.preparationStep=0;page = .prepare
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
            HStack(spacing:18) {
                HStack(spacing:9) {
                    Image(nsImage:AppArtwork.icon).resizable().frame(width:30,height:30)
                    VStack(alignment:.leading,spacing:0) {Text("nxnative").font(.system(size:15,weight:.bold));Text("EASY").font(.system(size:8,weight:.bold,design:.monospaced)).tracking(3).foregroundStyle(accent)}
                }.foregroundStyle(EasyDesign.ink).padding(.trailing,10)
                nav("Biblioteca",icon:"square.grid.2x2",selected:page == .library){selectedGameID=nil;page = .library}
                nav("Preparar",icon:"hammer",selected:preparing){page = .prepare}
                nav("Dispositivos",icon:"ipad.and.iphone",selected:page == .devices){page = .devices}
                nav("Partidas",icon:"icloud",selected:page == .saves){saveFocus=nil;saves.filter="";page = .saves}
                nav("Compatibilidad",icon:"checklist",selected:page == .compatibility){model.openCatalog()}
                Spacer(minLength:0)
                if page == .library && !library.games.isEmpty {Button(action:add){Image(systemName:"plus").frame(width:22,height:22)}.buttonStyle(EasySecondaryStyle()).accessibilityLabel(model.text("Añadir juego")).disabled(occupied)}
                Button {page = .settings} label:{Image(systemName:"gearshape").font(.system(size:17)).frame(width:40,height:40)}
                    .buttonStyle(.plain).foregroundStyle(page == .settings ? accent : .secondary)
                    .background(page == .settings ? accent.opacity(0.1) : .clear,in:RoundedRectangle(cornerRadius:10))
                    .help(model.text("Configuración")).accessibilityLabel(model.text("Configuración"))
            }.padding(.leading,82).padding(.trailing,24).padding(.vertical,10).background(EasyDesign.background.opacity(0.96))
            Divider()
                ZStack {
                    // Keep one preparation model/view alive: its task, logs, cancellation,
                    // update checks and sheets continue when browsing the library.
                    ContentView(updater:updater,sideload:sideload,model:model)
                        .opacity(preparing ? 1 : 0).allowsHitTesting(preparing).accessibilityHidden(!preparing)
                    if page == .settings {WorkspaceSettingsView(model:model,sideload:sideload)}
                    if page == .compatibility {GameCatalogView(model:model)}
                    if page == .saves {
                            SaveCenterView(model:saves,repo:model.repo,games:library.games,catalog:model.catalog,text:model.text,focusTitle:saveFocus,devices:{page = .devices}).id(saveFocus ?? "all")
                        } else if page == .devices {
                        SideloadLibraryView(model:sideload,text:model.text,canInstall:!model.running && !updater.busy,prepareGame:{
                            page = .prepare;model.folder=sideload.hasPendingUpdate ? sideload.gameFolder : nil;model.failed=false;model.preparationStep=0;model.target="ios"
                        },embedded:true,artwork:{app in
                            guard let id=sideload.titleID(for:app) else {return nil}
                            return GameArtworkCache.image(model.catalog.first(where:{$0.id==id})?.artworkURL)
                        })
                    }
                    if page == .library {
                        VStack(alignment:.leading,spacing:18) {
                            if let game=selectedResult {
                                HStack {
                                    Button {withAnimation(reduceMotion ? nil : .easeInOut(duration:0.18)){selectedGameID=nil}} label:{Label(model.text("Mi biblioteca"),systemImage:"arrow.left")}
                                        .buttonStyle(EasyLinkStyle()).keyboardShortcut("[",modifiers:.command)
                                    Text("/").foregroundStyle(.tertiary)
                                    Text(name(game)).font(.callout).lineLimit(1).foregroundStyle(.secondary)
                                    Spacer()
                                }.padding(.horizontal,36).padding(.top,16)
                                ScrollView {
                                    GameLibraryDetail(game:game,title:name(game),catalog:model.catalog.first(where:{$0.id==game.titleID}),text:model.text,building:model.running && model.folder?.resolvingSymlinksInPath().path==game.folder.resolvingSymlinksInPath().path,disabled:occupied,installBusy:sideload.busy,observations:sideload.observations(titleID:game.titleID,originalID:game.originalBundleID),isVerified:sideload.isVerified,needsRebuild:needsRebuild(game),advice:["Mac","iPhone / iPad"].compactMap {platform in rebuildAdvice[game.id+platform].map {value in platform+": "+model.text(value=="rebuild" ? "Conviene recompilar: cambiaron herramientas o el perfil de este juego." : "No hay historial suficiente para comparar esta preparación.") }},sourceRepo:model.repo,checkDevices:{if sideload.devices.count>1 && sideload.device.isEmpty {page = .devices}else{sideload.listDevices()}},open:{if let mac=game.macApp {NSWorkspace.shared.open(mac)}},prepare:{configure(game)},install:{install(game)},remove:{removing=game},prepareMac:{guard !occupied else {return};configure(game);model.target="mac"},prepareIOS:{guard !occupied else {return};configure(game);model.target="ios";model.splitIOS=game.romfs != nil},manageDevices:{page = .devices},manageSaves:{saveFocus=game.titleID;page = .saves},maintain:{maintaining=game})
                                        .frame(maxWidth:.infinity)
                                }.id(game.id)
                            } else {
                                CinematicLibrary(items:results.map {game in
                                    let observations=sideload.observations(titleID:game.titleID,originalID:game.originalBundleID)
                                    return LibrarySpotlightItem(game:game,catalog:model.catalog.first(where:{$0.id==game.titleID}),title:name(game),status:libraryStatus(game),verified:observations.contains(where:sideload.isVerified),installed:!observations.isEmpty,rebuild:needsRebuild(game))
                                },total:library.games.count,text:model.text,query:$query,platform:$platform,spotlight:$spotlightGameID,disabled:occupied,installBusy:sideload.busy,add:add,refresh:{library.refresh()},compatibility:{model.openCatalog()},details:{game in selectedGameID=game.id},primary:{game in
                                    guard !occupied,!game.missing else {return}
                                    if let mac=game.macApp {NSWorkspace.shared.open(mac)}else if game.iosIPA != nil {if sideload.observations(titleID:game.titleID,originalID:game.originalBundleID).isEmpty {install(game)}else {maintaining=game}}else {configure(game)}
                                })
                                if updater.visible {Button {page = .prepare} label:{Label(model.text(updater.busy ? updater.phaseText : "Hay una nueva versión"),systemImage:"arrow.down.circle")}.buttonStyle(.link).padding(.horizontal,36)}
                                if let error=library.error {Text(model.text(error)).font(.callout).foregroundStyle(.orange).textSelection(.enabled).padding(.horizontal,36)}
                                if sideload.showsRefreshNotice {Button(model.text("Revisar renovación")){page = .devices}.disabled(sideload.busy).padding(.horizontal,36)}
                            }
                        }.padding(0).frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading)
                            .transition(.opacity)
                    }
                }.overlay {
                    if dropTargeted && !occupied {
                        LibraryDropOverlay(text:model.text).frame(maxWidth:.infinity,maxHeight:.infinity).background(EasyDesign.background.opacity(0.97)).allowsHitTesting(false)
                    }
                }
            if sideload.recoveringSession && !sideload.recoveringQuietlyAtStartup && page != .settings && !model.showSideload && !model.installingInline {
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
        }.frame(minWidth:1000,minHeight:640).tint(accent).background(EasyDesign.background).preferredColorScheme(.dark)
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
        } isTargeted:{dropTargeted=$0}
        .onReceive(NotificationCenter.default.publisher(for:Notification.Name("nxnative.showDevices"))){_ in page = .devices}
        .onReceive(NotificationCenter.default.publisher(for:Notification.Name("nxnative.openSettings"))){_ in page = .settings}
        .onChange(of:model.installingInline){_,inline in if inline {page = .prepare}}
        .onReceive(NotificationCenter.default.publisher(for:Notification.Name("nxnative.showLibrary"))){_ in page = .library;selectedGameID=nil;if !sideload.busy {model.showSideload=false};library.refresh()}
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
        .sheet(item:$maintaining,onDismiss:{
            guard let action=maintenanceAction,let game=maintenanceGame else {return}
            maintenanceAction=nil;maintenanceGame=nil
            switch action {
            case .renew(let job):sideload.reviewRenewal(job);model.showSideload=true
            case .install:install(game)
            case .rebuild(let target):configure(game);model.target=target
            }
        }) {game in
            GameMaintenanceView(game:game,title:name(game),jobs:sideload.jobs,needsRebuild:needsRebuild(game),text:model.text,choose:{action in maintenanceAction=action;maintenanceGame=game;maintaining=nil},close:{maintaining=nil})
        }
        .alert(model.text("¿Quitar de la biblioteca?"),isPresented:Binding(get:{removing != nil},set:{if !$0 {removing=nil}})) {
            Button(model.text("Cancelar"),role:.cancel){removing=nil}
            Button(model.text("Quitar de esta lista"),role:.destructive){if let removing {library.remove(removing.id);selectedGameID=nil};removing=nil}
        } message:{Text(model.text("Sólo quitamos el acceso de la biblioteca. No borramos juegos, cachés, llaves ni partidas."))}
    }
    private func nav(_ title:String,icon:String,selected:Bool,action:@escaping()->Void)->some View {
        Button(action:action){Text(model.text(title)).font(.system(size:12,weight:selected ? .semibold : .regular)).fixedSize().padding(.vertical,13).foregroundStyle(selected ? EasyDesign.ink : .secondary).overlay(alignment:.bottom){if selected {Capsule().fill(accent).frame(height:2)}}}.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }

}

struct WorkspaceSettingsView:View {
    @ObservedObject var model:BuildModel
    @ObservedObject var sideload:SideloadModel
    enum Section:String,CaseIterable {case general,apple,controllers}
    @State var section=Section.general
    @State private var copiedDiagnostics=false
    @State private var backgroundRenewal=SideloadModel.backgroundEnabled
    @AppStorage("buildNotifications") private var buildNotifications=true
    private var version:String {Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "development"}
    private func title(_ section:Section)->String {
        switch section {case .general:return "General";case .apple:return "Cuenta Apple";case .controllers:return "Control"}
    }
    var body:some View {
        VStack(alignment:.leading,spacing:0) {
            VStack(alignment:.leading,spacing:20) {
                EasyEyebrow(title:model.text("PREFERENCIAS"))
                Text(model.text("Configuración")).font(.system(size:36,weight:.bold)).tracking(-1)
                HStack(spacing:28) {
                    ForEach(Section.allCases,id:\.self) {item in
                        Button {section=item} label:{Label(model.text(title(item)),systemImage:item == .general ? "slider.horizontal.3" : item == .apple ? "person.crop.circle" : "gamecontroller").font(.system(size:13,weight:section==item ? .semibold : .regular)).foregroundStyle(section==item ? EasyDesign.ink : .secondary).padding(.vertical,12).overlay(alignment:.bottom){if section==item {Capsule().fill(EasyDesign.accent).frame(height:2)}}}.buttonStyle(.plain)
                    }
                }
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
                            Divider()
                            Toggle(model.text("Renovar aunque la ventana esté cerrada"),isOn:$backgroundRenewal).toggleStyle(.switch).onChange(of:backgroundRenewal){_,value in sideload.setLoginItem(value)}
                            Text(model.text("Sólo renueva los juegos que hayas autorizado. Requiere este Mac despierto, sesión guardada y el dispositivo emparejado accesible por USB o Wi-Fi. macOS puede pedir permiso en Elementos de inicio.")).font(.caption).foregroundStyle(.secondary)

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
    var installBusy=false
    var observations:[DeviceGameObservation]=[]
    var isVerified:(DeviceGameObservation)->Bool={_ in false}
    var needsRebuild=false
    var advice:[String]=[]
    var sourceRepo:URL?=nil
    var checkDevices:()->Void={}
    let open:()->Void
    let prepare:()->Void
    let install:()->Void
    let remove:()->Void
    var prepareMac:()->Void={}
    var prepareIOS:()->Void={}
    var manageDevices:()->Void={}
    var manageSaves:()->Void={}
    var maintain:()->Void={}
    @State private var section="status"
    private var status:String {
        if building {return text("Compilando")}
        if let device=observations.first(where:isVerified) ?? observations.first {return text(isVerified(device) ? "Instalado en" : device.checkedAt==nil ? "Instalación registrada en" : "Última vez en")+" "+device.deviceName}
        return text(game.macApp != nil ? "Listo para jugar en Mac" : game.iosIPA != nil ? "IPA lista para instalar" : "Sin preparar")
    }
    var body:some View {
        VStack(alignment:.leading,spacing:0) {
            LibrarySpotlight(item:LibrarySpotlightItem(game:game,catalog:catalog,title:title,status:status,verified:!building && observations.contains(where:isVerified),installed:!observations.isEmpty,rebuild:needsRebuild),text:text,disabled:disabled || (game.macApp==nil && installBusy),secondaryTitle:"Mostrar carpeta",details:{NSWorkspace.shared.activateFileViewerSelecting([game.folder])},primary:{if game.macApp != nil {open()}else if game.iosIPA != nil {install()}else {prepare()}}).frame(height:310)
            VStack(alignment:.leading,spacing:24) {
                HStack(spacing:24) {
                    ForEach(["status","options","saves"],id:\.self) {value in
                        Button {section=value} label:{Text(text(value=="status" ? "Dónde jugar" : value=="options" ? "Archivos y opciones" : "Partidas")).font(.system(size:13,weight:section==value ? .semibold : .regular)).foregroundStyle(section==value ? EasyDesign.ink : .secondary).padding(.vertical,12).overlay(alignment:.bottom){if section==value {Capsule().fill(EasyDesign.accent).frame(height:2)}}}.buttonStyle(.plain)
                    }
                    Spacer()
                    Menu {
                        Button(text("Actualizar o renovar"),action:maintain).disabled(disabled || game.missing)
                        Button(text("Mostrar carpeta")){NSWorkspace.shared.activateFileViewerSelecting([game.folder])}
                        Button(text("Quitar de esta lista"),role:.destructive,action:remove).disabled(disabled)
                    } label:{Image(systemName:"ellipsis")}.menuStyle(.borderlessButton).fixedSize().accessibilityLabel(text("Acciones del juego"))
                }
                if game.missing {Label(text("Carpeta no disponible"),systemImage:"externaldrive.badge.exclamationmark").foregroundStyle(.orange)}
                if section=="status" {
                    Button {maintain()} label:{Label(text("Actualizar o renovar"),systemImage:"arrow.triangle.2.circlepath")}.buttonStyle(EasySecondaryStyle()).disabled(disabled)
                    if needsRebuild {Label(text("Conviene recompilar: cambiaron herramientas o el perfil de este juego."),systemImage:"arrow.triangle.2.circlepath").font(.callout).foregroundStyle(.orange)}
                    HStack(alignment:.top,spacing:18) {
                        EasyCard {
                            VStack(alignment:.leading,spacing:16) {
                                HStack {Image(systemName:"desktopcomputer").font(.system(size:26,weight:.ultraLight)).foregroundStyle(EasyDesign.accent);Spacer();Image(systemName:game.macApp != nil ? "checkmark.circle.fill" : "circle.dashed").foregroundStyle(game.macApp != nil ? EasyDesign.accent : .secondary)}
                                Text("Mac").font(.system(size:23,weight:.bold))
                                Text(text(game.macApp != nil ? "Mac: listo para jugar" : "Mac: sin app creada")).font(.callout).foregroundStyle(.secondary)
                                Button(text(game.macApp != nil ? "Preparar actualización" : "Preparar en Mac"),action:prepareMac).buttonStyle(EasySecondaryStyle()).disabled(disabled || game.missing)
                            }
                        }
                        EasyCard {
                            VStack(alignment:.leading,spacing:16) {
                                HStack {Image(systemName:"ipad.and.iphone").font(.system(size:26,weight:.ultraLight)).foregroundStyle(EasyDesign.accent);Spacer();Button(action:checkDevices){Image(systemName:"arrow.clockwise")}.buttonStyle(.plain).disabled(disabled).accessibilityLabel(text("Comprobar dispositivos"))}
                                Text("iPhone / iPad").font(.system(size:23,weight:.bold))
                                if observations.isEmpty {Text(text("Todavía no verificamos este juego en un iPhone o iPad. Conéctalo para comprobarlo.")).font(.callout).foregroundStyle(.secondary)}
                                ForEach(observations) {item in
                                    VStack(alignment:.leading,spacing:4) {
                                        Label(item.deviceName,systemImage:isVerified(item) ? "checkmark.circle.fill" : "clock").font(.callout.weight(.semibold)).foregroundStyle(isVerified(item) ? Color.green : .secondary)
                                        Text(text(isVerified(item) ? "Instalación verificada" : item.checkedAt==nil ? "Instalación registrada" : "Última instalación observada")+(item.version.isEmpty ? "" : " · "+item.version)).font(.caption).foregroundStyle(.secondary)
                                        if let checked=item.checkedAt {Text(checked.formatted(date:.abbreviated,time:.shortened)).font(.caption).foregroundStyle(.tertiary)}
                                        if item.checkedAt==nil {Text(text("Hay un registro de instalación. Conecta el dispositivo para comprobar su estado actual.")).font(.caption).foregroundStyle(.secondary)}
                                    }
                                }
                                Text(text(game.iosIPA != nil ? "Archivo IPA: listo para instalar" : "Archivo IPA: sin crear")).font(.caption).foregroundStyle(.secondary)
                                if game.macApp != nil,game.iosIPA != nil {Button(text(observations.isEmpty ? "Instalar en iPhone / iPad" : "Actualizar en iPhone / iPad"),action:install).buttonStyle(EasySecondaryStyle()).disabled(disabled || installBusy || game.missing)}
                                else if game.iosIPA==nil {Button(text("Preparar para iPhone / iPad"),action:prepareIOS).buttonStyle(EasySecondaryStyle()).disabled(disabled || game.missing)}
                            }
                        }
                    }
                    if let version=game.version {Label(text("Versión preparada")+" · "+version,systemImage:"tag").font(.caption).foregroundStyle(.secondary)}
                    if !advice.isEmpty {DisclosureGroup(text("Historial de preparación")) {ForEach(advice,id:\.self){Text($0).font(.caption).foregroundStyle(.secondary).padding(.top,8)}}.font(.callout)}
                } else if section=="options" {
                    if let app=game.macApp {GameLaunchOptionsView(app:app,text:text).id(app.path).disabled(disabled)}
                    if let repo=sourceRepo {CacheCleanupView(folder:game.folder,repo:repo,text:text,disabled:disabled).id(game.folder.path)}
                    EasyCard {VStack(alignment:.leading,spacing:12) {Label(text("Tus archivos"),systemImage:"folder").font(.headline);Text(game.folder.path).font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled);Button(text("Mostrar carpeta")){NSWorkspace.shared.activateFileViewerSelecting([game.folder])}.buttonStyle(EasySecondaryStyle());Button(text("Preparar o actualizar"),action:prepare).buttonStyle(EasyLinkStyle()).disabled(disabled || game.missing);Text(text("Usa tus archivos para preparar otra plataforma o aplicar un update. Tus partidas y archivos originales se conservan.")).font(.caption).foregroundStyle(.secondary)}}
                } else {
                    EasyMilestone(kind:.transfer,title:text("Continúa tu partida"),subtitle:text("Guarda en tu dispositivo. Continúa en otra pantalla."))
                    EasyCard {
                        VStack(alignment:.leading,spacing:14) {
                            Label(text("Continuar entre iPhone y Mac"),systemImage:"icloud").font(.headline)
                            Text(text("Prepara las versiones para Mac y iPhone / iPad con esta actualización. Instala sobre la app existente para conservar sus partidas."))
                            Text(text("Abre cada juego y elige la misma carpeta de iCloud Drive. Usa la misma versión y contenido del juego en ambos dispositivos."))
                            Text(text("Guarda y cierra antes de cambiar de dispositivo. Si hay dos progresos distintos, eliges con cuál seguir y se conservan ambos."))
                            Text(text("No requiere iniciar sesión con tu cuenta de firma. iCloud usa la cuenta del propio dispositivo.")).foregroundStyle(.secondary)
                            Link(text("Ver guía de partidas"),destination:URL(string:"https://github.com/nalancer08/nxnative-easy/blob/main/docs/icloud-saves.md")!)
                        }.font(.callout)
                    }
                    HStack {Button(text("Abrir mis partidas de iCloud"),action:manageSaves).buttonStyle(EasyPrimaryStyle());Button(text("Ver partidas del dispositivo"),action:manageDevices).buttonStyle(EasySecondaryStyle())}
                }
            }.padding(.horizontal,36).padding(.bottom,30).frame(maxWidth:1160).frame(maxWidth:.infinity)
        }.frame(maxWidth:.infinity,alignment:.leading)
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
