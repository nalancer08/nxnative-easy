import SwiftUI
import AppKit

// Cloud records are library evidence, never counterfeit local game folders or
// proof that the source device currently has the app installed.
struct LibraryEntry:Identifiable {
    let id:String
    var titleID:String?
    var sources:[OwnedGameOutput]=[]
    var revisions:[SaveRevision]=[]
    var knownInCloud=false
    var local:OwnedGameOutput? {sources.first(where:{$0.macApp != nil}) ?? sources.first}
    var mac:OwnedGameOutput? {sources.first(where:{$0.macApp != nil})}
    var ios:OwnedGameOutput? {sources.first(where:{$0.iosIPA != nil})}
    func source(_ target:String)->OwnedGameOutput? {(target=="mac" ? mac : ios) ?? sources.first}
    static func merge(local:[OwnedGameOutput],revisions:[SaveRevision],known:[String]=[],installed:[DeviceGameObservation]=[])->[LibraryEntry] {
        var values:[String:LibraryEntry]=[:]
        for game in local {
            let key=game.titleID?.uppercased() ?? game.id
            var row=values[key] ?? LibraryEntry(id:key,titleID:game.titleID)
            row.sources.append(game);values[key]=row
        }
        for report in installed {
            if let title=report.titleID?.uppercased(),title.range(of:"^[0-9A-F]{16}$",options:.regularExpression) != nil,values[title]==nil {values[title]=LibraryEntry(id:title,titleID:title)}
        }
        for title in Set(known+revisions.map(\.title)) where title.range(of:"^[0-9A-F]{16}$",options:.regularExpression) != nil {
            var row=values[title] ?? LibraryEntry(id:title,titleID:title)
            row.knownInCloud=true;row.revisions=revisions.filter{$0.title==title}.sorted{$0.date>$1.date};values[title]=row
        }
        return values.values.sorted{$0.id<$1.id}
    }
}

struct CloudLibraryHome:View {
    let entries:[LibraryEntry]
    let catalog:[CatalogGame]
    @ObservedObject var saves:SaveCenterModel
    @ObservedObject var sideload:SideloadModel
    let text:(String)->String
    @Binding var query:String
    let disabled:Bool
    let connect:()->Void
    let add:()->Void
    let open:(LibraryEntry)->Void
    private func title(_ entry:LibraryEntry)->String {catalog.first{$0.id==entry.titleID}?.name ?? entry.local?.folder.lastPathComponent ?? text("Juego guardado")}
    private var filtered:[LibraryEntry] {entries.filter{query.isEmpty || title($0).localizedCaseInsensitiveContains(query)}}
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:24) {
                HStack {
                    VStack(alignment:.leading,spacing:7) {
                        Text(text("Tu biblioteca")).font(.system(size:36,weight:.bold)).tracking(-1)
                        Text(text(saves.cloud==nil ? "Tus juegos y tu progreso. En todas tus pantallas." : "Tus juegos. Tus partidas. Siempre contigo.")).font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action:add){Label(text("Añadir juego"),systemImage:"plus")}.buttonStyle(EasyPrimaryStyle()).disabled(disabled)
                }
                if saves.cloud==nil {
                    HStack(spacing:24) {
                        VStack(alignment:.leading,spacing:12) {
                            Label(text("Tu aventura te sigue"),systemImage:"icloud").font(.title2.bold())
                            Text(text("Conecta iCloud y aparecerán también los juegos de tus partidas.")).font(.callout).foregroundStyle(.secondary)
                            Button(text("Conectar iCloud"),action:connect).buttonStyle(EasyPrimaryStyle())
                            Text(text("La cuenta de instalación se conecta sólo al instalar.")).font(.caption).foregroundStyle(.secondary)
                        }.frame(maxWidth:.infinity,alignment:.leading)
                        if let image=Bundle.main.url(forResource:"cloud-library",withExtension:"png",subdirectory:"Library").flatMap({NSImage(contentsOf:$0)}) {Image(nsImage:image).resizable().scaledToFit().frame(width:250,height:170).accessibilityHidden(true)}
                    }.padding(24).background(EasyDesign.panel,in:RoundedRectangle(cornerRadius:20))
                }
                HStack {
                    Text(String(entries.count)+" "+text(entries.count==1 ? "juego" : "juegos")).font(.headline).foregroundStyle(.secondary)
                    Spacer()
                    HStack {Image(systemName:"magnifyingglass").foregroundStyle(.secondary);TextField(text("Buscar un juego"),text:$query).textFieldStyle(.plain)}.padding(11).frame(maxWidth:300).background(EasyDesign.panel,in:RoundedRectangle(cornerRadius:10))
                }
                if entries.isEmpty {
                    VStack(spacing:13) {Image(systemName:saves.scanning ? "icloud.and.arrow.down" : "gamecontroller").font(.system(size:42,weight:.light)).foregroundStyle(EasyDesign.accent);Text(text(saves.scanning ? "Buscando tus aventuras…" : "Tu próxima aventura empieza aquí")).font(.title2.bold());Text(text("Añade tus archivos de juego. Tus partidas de iCloud aparecerán automáticamente.")).font(.callout).foregroundStyle(.secondary)}.frame(maxWidth:.infinity,minHeight:220)
                } else {
                    LazyVGrid(columns:[GridItem(.adaptive(minimum:220,maximum:330),spacing:20,alignment:.top)],alignment:.leading,spacing:24) {
                        ForEach(filtered) {entry in
                            Button {open(entry)} label:{
                                VStack(alignment:.leading,spacing:12) {
                                    ZStack(alignment:.topTrailing) {
                                        if let game=catalog.first(where:{$0.id==entry.titleID}) {GameArtworkView(game:game).frame(height:150).clipped()}
                                        else {Rectangle().fill(EasyDesign.panel).frame(height:150).overlay{Image(systemName:"gamecontroller").font(.system(size:36,weight:.light)).foregroundStyle(EasyDesign.accent)}}
                                        if !entry.revisions.isEmpty {Label(String(entry.revisions.count),systemImage:"icloud.fill").font(.caption.bold()).padding(7).background(EasyDesign.background.opacity(0.9),in:Capsule()).padding(9)}
                                    }.clipShape(RoundedRectangle(cornerRadius:14))
                                    Text(title(entry)).font(.headline).lineLimit(2).multilineTextAlignment(.leading).frame(minHeight:38,alignment:.topLeading)
                                    HStack(spacing:12) {
                                        if entry.mac != nil {Label("Mac",systemImage:"desktopcomputer")}
                                        let reports=sideload.observations(titleID:entry.titleID,originalID:entry.ios?.originalBundleID)
                                        if !reports.isEmpty {Label(text("iPhone / iPad"),systemImage:reports.contains(where:sideload.isVerified) ? "iphone.gen3.radiowaves.left.and.right" : "iphone")}
                                        if entry.sources.isEmpty {Label(text("Añadir archivos"),systemImage:"plus.circle")}
                                        else if entry.mac==nil && reports.isEmpty {Label(text(entry.ios==nil ? "Archivos añadidos" : "IPA lista"),systemImage:"shippingbox")}
                                    }.font(.caption).foregroundStyle(.secondary).frame(minHeight:22)
                                }.foregroundStyle(EasyDesign.ink).frame(maxWidth:.infinity,alignment:.leading).padding(12).background(EasyDesign.surface,in:RoundedRectangle(cornerRadius:20)).overlay(RoundedRectangle(cornerRadius:20).strokeBorder(.white.opacity(0.07)))
                            }.buttonStyle(.plain).accessibilityLabel(title(entry))
                        }
                    }
                }
                Text(text("Los juegos los añades tú. iCloud sólo conserva tus partidas.")).font(.caption).foregroundStyle(.secondary)
            }.padding(32).frame(maxWidth:1250).frame(maxWidth:.infinity,alignment:.top)
        }.background(EasyDesign.background)
    }
}

struct WorkspaceConnectionBar:View {
    @ObservedObject var sideload:SideloadModel
    @ObservedObject var saves:SaveCenterModel
    let text:(String)->String
    let connectCloud:()->Void
    @State private var cloudMenu=false
    @State private var deviceMenu=false
    private var ready:[SideloadDevice] {sideload.connectionIssue ? [] : sideload.devices.filter(\.ready)}
    var body:some View {
        ViewThatFits(in:.horizontal) {
            HStack(spacing:20) {cloudStatus;Spacer(minLength:12);deviceStatus}
            VStack(alignment:.leading,spacing:12) {cloudStatus;deviceStatus}
        }.font(.callout).padding(.horizontal,30).padding(.vertical,14).background(EasyDesign.surface).overlay(alignment:.bottom){Divider()}
    }
    private var cloudStatus:some View {
        Button {if saves.cloud==nil {connectCloud()}else{cloudMenu=true}} label:{
            HStack(spacing:9) {
                Image(systemName:saves.cloud==nil ? "icloud" : saves.cloudIssue != nil ? "icloud.slash" : "checkmark.icloud").foregroundStyle(saves.cloud != nil && saves.cloudIssue==nil ? EasyDesign.accent : .secondary)
                Text(text(saves.cloud==nil ? "Conectar iCloud" : saves.cloudIssue != nil ? "iCloud sin conexión" : saves.scanning ? "Buscando partidas…" : saves.usesICloud ? "iCloud conectado" : "Carpeta local conectada")).fontWeight(.semibold)
                if saves.scanning {ProgressView().controlSize(.mini)}
            }.padding(.vertical,4)
        }.buttonStyle(.plain).popover(isPresented:$cloudMenu) {
            VStack(alignment:.leading,spacing:14) {
                Label(text("iCloud de este Mac"),systemImage:"icloud").font(.headline)
                if let folder=saves.cloud {Text(folder.lastPathComponent).font(.callout)}
                Text(text("Usa la sesión de iCloud del sistema. Es independiente de la cuenta que firma tus apps.")).font(.caption).foregroundStyle(.secondary)
                Button(text("Cambiar carpeta")){cloudMenu=false;connectCloud()}
                Button(text("Desconectar iCloud")){saves.disconnectCloud();cloudMenu=false}
            }.padding(22).frame(width:300)
        }
    }
    private var deviceStatus:some View {
        Button {deviceMenu=true} label:{
            HStack(spacing:9) {
                Image(systemName:ready.isEmpty ? "cable.connector" : "checkmark.circle.fill").foregroundStyle(ready.isEmpty ? .secondary : EasyDesign.accent)
                VStack(alignment:.leading,spacing:2) {
                    Text(text(sideload.connectionIssue ? "No pudimos comprobar el iPhone" : !ready.isEmpty ? ready.count==1 ? "Dispositivo conectado" : "Dispositivos conectados" : sideload.devices.isEmpty ? sideload.checkingDevices && sideload.devicesCheckedAt==nil ? "Buscando tu dispositivo…" : "Conecta tu iPhone o iPad" : "Dispositivo detectado · Desbloquéalo")).fontWeight(.semibold)
                    if let device=ready.first {Text(device.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)}
                }
                Image(systemName:"chevron.down").font(.caption2).foregroundStyle(.secondary)
            }.padding(.vertical,4)
        }.buttonStyle(.plain).popover(isPresented:$deviceMenu) {
            VStack(alignment:.leading,spacing:14) {
                Label(text("Tus dispositivos"),systemImage:"ipad.and.iphone").font(.headline)
                if sideload.devices.isEmpty {Text(text("Conecta por USB, desbloquea y pulsa Confiar si te lo pide.")).font(.callout).foregroundStyle(.secondary)}
                ForEach(sideload.devices) {device in
                    VStack(alignment:.leading,spacing:6) {Label(device.name,systemImage:device.ready ? "checkmark.circle.fill" : "lock").font(.callout.bold());Text(device.detail).font(.caption).foregroundStyle(.secondary);if !device.ready {Text(text("Desbloquea y acepta Confiar en este Mac.")).font(.caption).foregroundStyle(.orange)}}
                }
                Button(text("Comprobar ahora")){Task{await sideload.refreshConnections()}}.disabled(sideload.checkingDevices)
            }.padding(22).frame(width:320)
        }
    }
}

struct GameContinuityDetail:View {
    let entry:LibraryEntry
    let title:String
    let catalog:CatalogGame?
    let context:GameCareContext?
    @ObservedObject var saves:SaveCenterModel
    @ObservedObject var localSaves:LocalSaveMonitor
    @ObservedObject var sideload:SideloadModel
    let repo:URL
    let text:(String)->String
    let disabled:Bool
    let prepare:(String)->Void
    let reviewSync:()->Void
    let chooseDestination:()->Void
    let maintain:()->Void
    let maintainDevice:(DeviceGameObservation)->Void
    let install:()->Void
    let files:()->Void
    let upload:()->Void
    let reviewRevision:(SaveRevision)->Void
    @State private var showScreenshot=false
    @State private var backup:DeviceGameObservation?
    @State private var backupMac=false
    @State private var copying:DeviceGameObservation?
    private var reports:[DeviceGameObservation] {sideload.observations(titleID:entry.titleID,originalID:entry.ios?.originalBundleID)}
    private var localPresence:LocalSavePresence? {entry.titleID.flatMap{localSaves.games[$0]}}
    private var hasFiles:Bool {entry.sources.contains{!$0.missing}}
    private var syncUpdateReady:Bool {entry.ios?.iosIPA != nil && (entry.ios?.iosSaveContinuity ?? 0)>=2}
    private var needsSyncUpdate:Bool {saves.cloud != nil && reports.contains{($0.saveContinuity ?? 0)<2}}
    private var primaryTitle:String {
        if entry.mac != nil {return "Jugar"}
        if !reports.isEmpty {
            if needsSyncUpdate {return syncUpdateReady ? "Actualizar en iPhone / iPad" : "Actualizar para sincronizar partidas"}
            if context?.state == .expired || context?.state == .expiring {return "Renovar firma"}
            return context?.state == .rebuild || context?.state == .contentUpdate ? "Actualizar en iPhone / iPad" : "Preparar en Mac"
        }
        return entry.ios != nil ? "Instalar en iPhone / iPad" : "Añadir para jugar"
    }
    private func play(_ app:URL) {
        let config=NSWorkspace.OpenConfiguration()
        if (Bundle(url:app)?.object(forInfoDictionaryKey:"DMEasySaveContinuity") as? Int ?? 0)>=2 {
            config.environment=["NXE_QUICK_PLAY":"1"]
            if let folder=saves.cloud,saves.cloudIssue==nil {config.environment["NXE_CLOUD_FOLDER"]=folder.path}
        }
        NSWorkspace.shared.openApplication(at:app,configuration:config)
    }
    private func primary() {
        if let app=entry.mac?.macApp {play(app)}
        else if !reports.isEmpty {
            if needsSyncUpdate {if syncUpdateReady {install()}else{reviewSync()}}
            else if context?.state == .unknown || context?.state == .current {prepare("mac")}
            else {maintain()}
        }
        else if entry.ios != nil {install()}
        else {chooseDestination()}
    }
    var body:some View {
        VStack(alignment:.leading,spacing:0) {
            ZStack(alignment:.bottomLeading) {
                GeometryReader {geometry in
                    if let catalog {GameArtworkView(game:catalog).frame(width:geometry.size.width,height:300).clipped()}
                    else {EasyDesign.panel}
                }
                LinearGradient(stops:[.init(color:.black.opacity(0.05),location:0),.init(color:EasyDesign.background.opacity(0.3),location:0.42),.init(color:EasyDesign.background,location:1)],startPoint:.top,endPoint:.bottom)
                VStack(alignment:.leading,spacing:12) {
                    Text(text("EN TU BIBLIOTECA")).font(.system(size:10,weight:.semibold)).tracking(2).foregroundStyle(.white.opacity(0.7))
                    Text(title).font(.system(size:36,weight:.bold)).tracking(-1).foregroundStyle(.white).fixedSize(horizontal:false,vertical:true)
                }.padding(.horizontal,28).padding(.bottom,12).shadow(color:.black.opacity(0.3),radius:16)
            }.frame(height:300).accessibilityElement(children:.combine)
            VStack(alignment:.leading,spacing:24) {
                ViewThatFits(in:.horizontal) {
                    HStack(spacing:16) {launchAction;Spacer(minLength:8);launchMetadata}
                    VStack(alignment:.leading,spacing:14) {launchAction;launchMetadata}
                }
                if let context,context.state != .unknown,context.state != .current {
                    HStack(spacing:9) {Image(systemName:context.state == .expired || context.state == .expiring ? "clock.badge.exclamationmark" : "sparkles").foregroundStyle(EasyDesign.accent);Text(text(context.reason)).font(.caption).foregroundStyle(.secondary);Spacer();Button(text("Revisar"),action:maintain).buttonStyle(EasyLinkStyle()).disabled(disabled)}
                }
                if !hasFiles {Text(text(entry.knownInCloud ? "Tu partida está aquí. Añade tus archivos para jugar." : "Añade tus archivos para preparar este juego.")).font(.callout).foregroundStyle(.secondary)}
            if sideload.blocksGameWork {InstallActivityView(model:sideload,text:text)}
                ViewThatFits(in:.horizontal) {
                    HStack(alignment:.top,spacing:24) {savedProgress.frame(minWidth:330,maxWidth:.infinity);destinations.frame(width:270)}
                    VStack(alignment:.leading,spacing:24) {savedProgress;destinations}
                }
            if let context {DisclosureGroup(text("Versión y mejoras")) {VStack(alignment:.leading,spacing:14) {GameVersionComparison(context:context,text:text);Button(text("Actualizar o renovar"),action:maintain).buttonStyle(EasyLinkStyle())}.padding(.top,12)}.font(.callout)}
            if let catalog {
                VStack(alignment:.leading,spacing:12) {
                    Text(text("CAPTURAS")).font(.system(size:10,weight:.semibold)).tracking(1.8).foregroundStyle(.secondary)
                    Button {showScreenshot=true}label:{GameArtworkView(game:catalog).frame(width:220,height:124).clipped().clipShape(RoundedRectangle(cornerRadius:8)).overlay(alignment:.bottomTrailing){Image(systemName:"arrow.up.left.and.arrow.down.right").font(.caption).padding(9).background(.black.opacity(0.5),in:RoundedRectangle(cornerRadius:6)).padding(7)}}.buttonStyle(.plain).accessibilityLabel(text("Ver captura"))
                }
            }
            if hasFiles {Button(text("Archivos y opciones"),action:files).buttonStyle(EasyLinkStyle())}
            }.padding(.horizontal,28).padding(.top,12).padding(.bottom,30)
        }.frame(maxWidth:.infinity,alignment:.topLeading).background(EasyDesign.background)
        .sheet(isPresented:$showScreenshot) {VStack(spacing:16){HStack{Text(title).font(.headline);Spacer();Button(text("Cerrar")){showScreenshot=false}};if let catalog {GameArtworkView(game:catalog).aspectRatio(16.0/9,contentMode:.fit)}}.padding(20).frame(minWidth:560,idealWidth:900).background(EasyDesign.background)}
        .alert(text("Respaldar tu partida"),isPresented:Binding(get:{backup != nil || backupMac},set:{if !$0 {backup=nil;backupMac=false}})) {
            Button(text("Cancelar"),role:.cancel){backup=nil;backupMac=false}
            Button(text("Ya guardé y cerré el juego")){if let backup {sideload.backupGame(backup,text:text)}else if let game=entry.local {saves.backupMac(repo:repo,game:game)};backup=nil;backupMac=false}
        }message:{Text(text("Se creará un ZIP en tu Mac con el guardado. La partida original no se modifica."))}
        .alert(text("Copiar archivos para jugar"),isPresented:Binding(get:{copying != nil},set:{if !$0 {copying=nil}})) {
            Button(text("Cancelar"),role:.cancel){copying=nil}
            Button(text("Ya guardé y cerré el juego")){if let report=copying {sideload.copyGame(report)};copying=nil}
        }message:{Text(text("Copia los archivos grandes necesarios para jugar desde este Mac al iPhone. No respalda ni sincroniza partidas. Mantén el juego cerrado hasta terminar."))}
    }
    private var destinations:some View {
VStack(alignment:.leading,spacing:7) {
                HStack {Text(text("JUGAR EN")).font(.system(size:10,weight:.semibold)).tracking(1.8).foregroundStyle(.secondary);Spacer();Button {Task {await sideload.refreshConnections()}}label:{Image(systemName:"arrow.clockwise")}.buttonStyle(EasyLinkStyle()).accessibilityLabel(text("Comprobar dispositivos")).disabled(sideload.busy)}
                destination("Este Mac",icon:"desktopcomputer",status:text(entry.mac != nil ? "Listo para jugar" : "Sin instalar"),connected:true) {
                    if entry.mac != nil {Button(text("Jugar"),action:primary).buttonStyle(EasySecondaryStyle())}
                    else {Button(text("Añadir en Mac")){prepare("mac")}.buttonStyle(EasyLinkStyle()).disabled(disabled)}
                }
                ForEach(reports) {report in
                    let connected=sideload.devices.contains{$0.id==report.device && $0.ready} && !sideload.connectionIssue
                    destination(report.deviceName,icon:"iphone",status:text(connected ? sideload.isVerified(report) ? "Conectado · Juego instalado" : "Conectado · Comprobando juego" : "Desconectado · Última instalación conocida"),connected:connected) {
                        Button(text("Respaldar partida")){backup=report}.buttonStyle(EasyLinkStyle()).disabled(disabled || !sideload.isVerified(report))
                        Menu {
                            Button(text((report.saveContinuity ?? 0)<2 ? "Actualizar para iCloud" : "Revisar app")){if (report.saveContinuity ?? 0)<2 {if syncUpdateReady {install()}else{reviewSync()}}else{maintainDevice(report)}}
                            if sideload.isVerified(report),sideload.dataFolder(for:InstalledGame(id:report.bundleID,name:title,version:report.version)) != nil {Button(text("Copiar archivos para jugar")){copying=report}}
                        }label:{Image(systemName:"ellipsis")}.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().disabled(disabled).accessibilityLabel(text("Más opciones"))

                    }
                }
                ForEach(sideload.devices.filter{device in !reports.contains{$0.device==device.id}}) {device in
                    destination(device.name,icon:device.kind=="iPad" ? "ipad" : "iphone",status:text(sideload.connectionIssue ? "Conexión sin verificar" : device.ready ? sideload.hasCheckedGames(device.id) ? "Conectado · Juego sin instalar" : "Conectado · Comprobando tus juegos…" : "Desbloquea y acepta Confiar"),connected:device.ready && !sideload.connectionIssue) {
                        Button(text("Añadir aquí")){if !sideload.busy {sideload.device=device.id};if entry.ios != nil {install()}else{prepare("ios")}}.buttonStyle(EasyLinkStyle()).disabled(disabled || !device.ready || sideload.connectionIssue)
                    }
                }
                if reports.isEmpty && sideload.devices.isEmpty {
                    destination("iPhone / iPad",icon:"ipad.and.iphone",status:text("Conecta tu dispositivo cuando quieras instalar"),connected:false) {
                        Button(text("Preparar versión móvil")){prepare("ios")}.buttonStyle(EasyLinkStyle()).disabled(disabled)
                    }
                }
            }
    }
    private var savedProgress:some View {
VStack(alignment:.leading,spacing:16) {
                HStack {
                    Label(text("Partidas guardadas"),systemImage:"icloud").font(.headline)
                    Spacer()
                    if saves.scanning {ProgressView().controlSize(.small)}
                    Text(text(saves.cloud==nil ? "iCloud no disponible" : saves.cloudIssue != nil ? "Últimas copias conocidas" : saves.usesICloud ? "iCloud conectado" : "Carpeta local conectada")).font(.caption).foregroundStyle(saves.cloud != nil && saves.cloudIssue==nil ? EasyDesign.accent : .secondary)
                }
                if saves.cloud==nil && saves.cloudIssue != nil {Text(text("Activa iCloud Drive en Ajustes del Sistema. Easy prepara su carpeta automáticamente.")).font(.caption).foregroundStyle(.secondary)}
                if (entry.mac?.macApp).flatMap({Bundle(url:$0)?.object(forInfoDictionaryKey:"DMEasySaveContinuity") as? Int}) == nil && entry.mac != nil {
                    HStack {Text(text("Actualiza la app de Mac para recibir las partidas automáticamente.")).font(.caption).foregroundStyle(.secondary);Spacer();Button(text("Activar iCloud en Mac")){prepare("mac")}.buttonStyle(EasyLinkStyle()).disabled(disabled)}
                }
                if let presence=localPresence,presence.state == .present {
                    HStack(spacing:14) {
                        Image(systemName:"desktopcomputer").foregroundStyle(EasyDesign.accent)
                        VStack(alignment:.leading,spacing:5) {
                            Text(text("Partida en este Mac")).font(.callout.bold())
                            if let date=presence.modified {Text(text("Última modificación")+" · "+date.formatted(date:.abbreviated,time:.shortened)).font(.caption).foregroundStyle(.secondary)}
                            EmptyView()
                        }
                        Spacer()
                    }.padding(14).background(EasyDesign.surface,in:RoundedRectangle(cornerRadius:12))
                } else if localPresence?.state == .unavailable {
                    Text(text("No pudimos comprobar la partida de este Mac.")).font(.caption).foregroundStyle(.orange)
                }
                if entry.revisions.isEmpty {
                    Text(text("Aún no recibimos una copia de iCloud.")).font(.callout).foregroundStyle(.secondary)

                } else {
                    Text(text("Continúa donde lo dejaste. Si hay un conflicto, conservamos ambas partidas.")).font(.caption).foregroundStyle(.secondary)
                    ForEach(Array(entry.revisions.prefix(2))) {revision in revisionRow(revision)}
                    if entry.revisions.count>2 {DisclosureGroup(text("Ver historial")+" · "+String(entry.revisions.count)) {ForEach(Array(entry.revisions.dropFirst(2))) {revision in revisionRow(revision)}}.font(.callout)}
                }
                ViewThatFits(in:.horizontal) {saveActions;VStack(alignment:.leading,spacing:8){saveActions}}
                if let url=saves.localBackup,saves.localBackupTitle==entry.titleID {Button{textShow(url)}label:{Label(text("Mostrar copia guardada"),systemImage:"checkmark.shield")}.buttonStyle(EasyLinkStyle())}
                if let url=sideload.exportedSaves,sideload.gameFolder==entry.ios?.folder {Button{textShow(url)}label:{Label(text("Mostrar copia guardada"),systemImage:"checkmark.shield")}.buttonStyle(EasyLinkStyle())}
                if saves.busy {ProgressView(text("Comprobando tu partida…"))}
                if saves.error != nil {Text(text("No pudimos preparar la copia. El original sigue intacto.")).font(.caption).foregroundStyle(.orange)}
                DisclosureGroup(text("Cómo funciona")) {Text(text("Guarda dentro del juego. Si ambas pantallas tienen contenido compatible, tu continuación se recibe antes de jugar. Si jugaste por separado, se conservan ambas partidas y eliges. Los juegos antiguos necesitan una actualización y la carpeta de iCloud se autoriza una vez dentro de cada juego.")).font(.caption).foregroundStyle(.secondary)}.font(.caption)
            }.padding(20).background(EasyDesign.panel,in:RoundedRectangle(cornerRadius:12))
    }
    private var launchAction:some View {
        HStack(spacing:8) {
            Button(action:primary){Label(text(primaryTitle),systemImage:entry.mac != nil ? "play.fill" : "arrow.down.to.line").frame(minWidth:120)}.buttonStyle(EasyPrimaryStyle()).disabled(disabled)
            Menu {Button(text("Preparar en Mac")){prepare("mac")};Button(text("Instalar en iPhone / iPad"),action:install).disabled(entry.ios==nil);Button(text("Preparar versión móvil")){prepare("ios")}}label:{Image(systemName:"chevron.down").frame(width:18,height:24)}.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().padding(9).background(.white.opacity(0.04),in:RoundedRectangle(cornerRadius:8)).disabled(disabled).accessibilityLabel(text("Elegir dónde jugar"))
        }
    }
    private var launchMetadata:some View {
        HStack(spacing:20) {
            VStack(alignment:.leading,spacing:4){Text(text("VERSIÓN DEL JUEGO")).font(.system(size:9,weight:.medium)).tracking(1);Text(entry.local?.version ?? entry.revisions.first?.version ?? "—").font(.system(size:12,weight:.medium))}
            VStack(alignment:.leading,spacing:4){Text(text("PARTIDAS")).font(.system(size:9,weight:.medium)).tracking(1);Text(text(entry.revisions.isEmpty && localPresence?.state != .present ? "Sin copias recibidas" : "Progreso guardado")).font(.system(size:12,weight:.medium))}
        }.foregroundStyle(.secondary)
    }
    @ViewBuilder private var saveActions:some View {
        HStack(spacing:14) {
            Menu {Button(text("Subir un respaldo"),action:upload).disabled(disabled || saves.busy || !hasFiles || saves.cloud==nil);if let local=entry.local,localPresence?.state == .present {Button(text("Guardar partida de este Mac")){backupMac=true}.disabled(saves.busy || local.missing)};ForEach(reports.filter{sideload.isVerified($0)}) {report in Button(text("Respaldar partida")+" · "+report.deviceName){backup=report}.disabled(sideload.busy)}}label:{Label(text("Respaldar o importar partida"),systemImage:"square.and.arrow.up")}.menuStyle(.borderlessButton).fixedSize().disabled(disabled)
            if saves.cloud==nil {Button(text("Activar iCloud")){saves.enableManagedCloud(repo:repo)}.buttonStyle(EasyLinkStyle()).disabled(saves.busy)}
        }
    }
    private func textShow(_ url:URL){NSWorkspace.shared.activateFileViewerSelecting([url])}
    private func revisionRow(_ revision:SaveRevision)->some View {
        HStack(spacing:14) {
            Image(systemName:"clock.arrow.circlepath").foregroundStyle(EasyDesign.accent)
            VStack(alignment:.leading,spacing:5) {Text(revision.device).font(.callout.bold());Text(Date(timeIntervalSince1970:revision.date).formatted(date:.abbreviated,time:.shortened)+(revision.version.isEmpty ? "" : " · "+revision.version)).font(.caption).foregroundStyle(.secondary)}
            Spacer()
            Button(text("Guardar copia")){saves.download(repo:repo,revision:revision)}.buttonStyle(EasySecondaryStyle()).disabled(saves.busy || saves.cloud==nil || saves.cloudIssue != nil)
            Menu {Button(text("Preparar para Switch")){reviewRevision(revision)}}label:{Image(systemName:"ellipsis")}.menuStyle(.borderlessButton).fixedSize().disabled(saves.busy || saves.cloud==nil || saves.cloudIssue != nil).accessibilityLabel(text("Más opciones"))
        }.padding(14).background(EasyDesign.surface,in:RoundedRectangle(cornerRadius:12))
    }
    private func destination<Actions:View>(_ name:String,icon:String,status:String,connected:Bool,@ViewBuilder actions:()->Actions)->some View {
        VStack(alignment:.leading,spacing:4) {
          HStack(spacing:10) {
            Image(systemName:icon).font(.system(size:23,weight:.light)).foregroundStyle(connected ? EasyDesign.accent : .secondary).frame(width:34)
            VStack(alignment:.leading,spacing:5) {Text(text(name)).font(.system(size:12,weight:.semibold));Text(status).font(.caption).foregroundStyle(.secondary)}
            Spacer(minLength:0)
          }
          HStack(spacing:12){actions()}.padding(.leading,44)
        }.padding(.vertical,7)
    }
}
