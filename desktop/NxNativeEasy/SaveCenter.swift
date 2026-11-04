import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SaveRevision:Codable,Identifiable {
    let id,title,path,device,version:String
    let date:Double
}
struct SavePreview:Decodable {
    let title:String?
    let version:String?
    let device:String?
    let files,bytes:Int
    let fingerprint:String
    let roots:[String]
}

// The desktop transfers checked copies; active save restoration remains in the
// game runtime, with its existing conflict choice and durable recovery journal.
@MainActor final class SaveCenterModel:ObservableObject {
    @Published var cloud:URL?
    @Published private(set) var scanning=false
    @Published private(set) var cloudCheckedAt:Date?
    @Published private(set) var cloudIssue:String?
    @Published private(set) var knownCloudTitles:[String]=[]
    @Published var revisions:[SaveRevision]=[]
    @Published var pending=0
    @Published var invalid=0
    @Published var busy=false
    @Published var startedAt:Date?
    @Published var error:String?
    @Published var preview:SavePreview?
    @Published var source:URL?
    @Published var selectedRevision:SaveRevision?
    @Published var completed:URL?
    @Published var published=false
    @Published var localBackup:URL?
    @Published var localBackupTitle:String?
    @Published var kind="account"
    @Published var gameID=""
    @Published var filter=""
    private let defaults:UserDefaults
    private var access:URL?
    private var generation=UUID()
    private var listGeneration=UUID()
    private var signature:String?
    @Published private(set) var usesICloud=false
    private let isCloudLocation:(URL)->Bool
    private let managedDrive:()->URL?
    nonisolated static func isICloudLocation(_ folder:URL)->Bool {
        let root=FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs").standardizedFileURL.path
        let selected=folder.standardizedFileURL.path
        if selected==root || selected.hasPrefix(root+"/") {return true}
        return (try? folder.resourceValues(forKeys:[.isUbiquitousItemKey]).isUbiquitousItem)==true
    }
    private struct CloudCache:Codable {let bookmark:Data;let revisions:[SaveRevision];var titles:[String]?=nil}
    init(defaults:UserDefaults = .standard,isCloudLocation:@escaping(URL)->Bool = SaveCenterModel.isICloudLocation,managedDrive:@escaping()->URL? = {FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")}) {self.defaults=defaults;self.isCloudLocation=isCloudLocation;self.managedDrive=managedDrive}
    // Easy owns only this namespace. Never invent an iCloud root, follow a
    // symlink or replace an existing custom bookmark during automatic setup.
    func ensureManagedCloud(repo:URL) {
        restoreFolder()
        guard cloud==nil,!busy,!defaults.bool(forKey:"saveCenter.disabled.v1"),defaults.data(forKey:"saveCenter.folder.v1")==nil else{return}
        guard let drive=managedDrive() else{cloudIssue="icloud_unavailable";return}
        let fm=FileManager.default
        func safeDirectory(_ url:URL)->Bool {
            guard url.standardizedFileURL==url.resolvingSymlinksInPath().standardizedFileURL,let values=try? url.resourceValues(forKeys:[.isDirectoryKey,.isSymbolicLinkKey]),values.isDirectory==true,values.isSymbolicLink != true else{return false}
            return fm.isWritableFile(atPath:url.path)
        }
        guard safeDirectory(drive) else{cloudIssue="icloud_unavailable";return}
        do {
            var directory=drive
            for name in ["nxnative Easy","Saves"] {
                directory.appendPathComponent(name,isDirectory:true)
                if !fm.fileExists(atPath:directory.path) {try fm.createDirectory(at:directory,withIntermediateDirectories:false)}
                guard safeDirectory(directory) else{cloudIssue="folder_access";return}
            }
            connectCloud(folder:directory,repo:repo)
        } catch {cloudIssue="folder_access"}
    }
    func enableManagedCloud(repo:URL) {defaults.removeObject(forKey:"saveCenter.disabled.v1");ensureManagedCloud(repo:repo)}
    func restoreFolder() {
        guard cloud==nil,let data=defaults.data(forKey:"saveCenter.folder.v1") else {return}
        if let cached=defaults.data(forKey:"cloudLibrary.cache.v1"),cached.count<=1048576,let value=try? JSONDecoder().decode(CloudCache.self,from:cached),value.bookmark==data {knownCloudTitles=(value.titles ?? value.revisions.map(\.title)).filter{$0.range(of:"^[0-9A-F]{16}$",options:.regularExpression) != nil}}
        var stale=false
        if let url=try? URL(resolvingBookmarkData:data,options:[.withSecurityScope,.withoutUI],relativeTo:nil,bookmarkDataIsStale:&stale),!stale {
            if url.startAccessingSecurityScopedResource() {access=url};cloud=url;usesICloud=isCloudLocation(url)
            if let cached=defaults.data(forKey:"cloudLibrary.cache.v1"),cached.count<=1048576,let value=try? JSONDecoder().decode(CloudCache.self,from:cached),value.bookmark==data {
                revisions=value.revisions.compactMap{item in
                    guard item.title.range(of:"^[0-9A-F]{16}$",options:.regularExpression) != nil,item.id.range(of:"^[0-9a-f]{64}$",options:.regularExpression) != nil,item.date.isFinite else{return nil}
                    let expected=url.appendingPathComponent("nxnative-saves-v1/"+item.title+"/"+item.id+".nxsave")
                    // Never trust a cached absolute path. Rebuild it from the
                    // selected folder's bookmark and bounded title/hash IDs.
                    return SaveRevision(id:item.id,title:item.title,path:expected.path,device:item.device,version:item.version,date:item.date)
                }
                knownCloudTitles=(value.titles ?? revisions.map(\.title)).filter{$0.range(of:"^[0-9A-F]{16}$",options:.regularExpression) != nil}
            }
        } else {cloudIssue="folder_access"}
    }
    func chooseCloud(repo:URL) {
        guard !busy else {return}
        let panel=NSOpenPanel();panel.canChooseDirectories=true;panel.canChooseFiles=false;panel.allowsMultipleSelection=false
        panel.title="iCloud Drive";panel.canCreateDirectories=true
        let drive=FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        if FileManager.default.fileExists(atPath:drive.path) {panel.directoryURL=drive}
        guard panel.runModal() == .OK,let url=panel.url else {return}
        connectCloud(folder:url,repo:repo)
    }
    func connectCloud(folder url:URL,repo:URL) {
        guard !busy else{return}
        let scoped=url.startAccessingSecurityScopedResource()
        do {
            let data=try url.bookmarkData(options:.withSecurityScope,includingResourceValuesForKeys:nil,relativeTo:nil)
            access?.stopAccessingSecurityScopedResource();access=scoped ? url : nil
            listGeneration=UUID();scanning=false;defaults.removeObject(forKey:"saveCenter.disabled.v1");defaults.set(data,forKey:"saveCenter.folder.v1");defaults.removeObject(forKey:"cloudLibrary.cache.v1");revisions=[];knownCloudTitles=[];cloud=url;usesICloud=isCloudLocation(url);signature=nil;cloudCheckedAt=nil;cloudIssue=nil
            refresh(repo:repo)
        } catch {if scoped {url.stopAccessingSecurityScopedResource()};self.error="folder_access"}
    }
    nonisolated private static func execute(repo:URL,request:[String:Any])->Data {
        let process=Process(),input=Pipe(),output=Pipe()
        process.executableURL=PortableRuntime.python
        process.arguments=[repo.appendingPathComponent("scripts/save_transfer.py").path]
        process.environment=PortableRuntime.environment();process.currentDirectoryURL=repo
        process.standardInput=input;process.standardOutput=output;process.standardError=FileHandle.nullDevice
        do {
            let data=try JSONSerialization.data(withJSONObject:request)
            try process.run();try input.fileHandleForWriting.write(contentsOf:data);try input.fileHandleForWriting.close()
            let timeout=DispatchWorkItem {if process.isRunning {process.terminate()}}
            DispatchQueue.global(qos:.utility).asyncAfter(deadline:.now()+60,execute:timeout)
            defer {timeout.cancel()}
            let result=output.fileHandleForReading.readDataToEndOfFile();process.waitUntilExit()
            return result.count<=4*1024*1024 ? result : Data()
        } catch {return Data()}
    }
    func request(repo:URL,_ value:[String:Any],done:@escaping([String:Any])->Void) {
        guard !busy else {return};busy=true;error=nil;startedAt=Date()
        let token=UUID();generation=token
        Task {
            let data=await Task.detached(priority:.utility) {Self.execute(repo:repo,request:value)}.value
            guard generation==token else {return}
            busy=false
            guard let result=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any] else {error="save_operation_failed";return}
            guard result["ok"] as? Bool==true,let payload=result["result"] as? [String:Any] else {error=result["error"] as? String ?? "save_operation_failed";return}
            done(payload)
        }
    }
    func disconnectCloud() {
        defaults.set(true,forKey:"saveCenter.disabled.v1")
        listGeneration=UUID();access?.stopAccessingSecurityScopedResource();access=nil;cloud=nil
        revisions=[];knownCloudTitles=[];usesICloud=false;signature=nil;cloudCheckedAt=nil;cloudIssue=nil;scanning=false
        defaults.removeObject(forKey:"saveCenter.folder.v1");defaults.removeObject(forKey:"cloudLibrary.cache.v1")
    }
    nonisolated private static func cloudSignature(_ folder:URL)->String? {
        let root=folder.appendingPathComponent("nxnative-saves-v1"),fm=FileManager.default
        guard fm.fileExists(atPath:folder.path) else {return nil}
        guard fm.fileExists(atPath:root.path) else {return "empty"}
        guard let walk=fm.enumerator(at:root,includingPropertiesForKeys:[.fileSizeKey,.contentModificationDateKey,.isUbiquitousItemKey,.ubiquitousItemDownloadingStatusKey],options:[.skipsPackageDescendants]) else {return nil}
        var rows:[String]=[],visited=0
        while let url=walk.nextObject() as? URL {
            visited+=1;if visited>16384 {return nil}
            guard url.pathExtension=="nxsave" || url.lastPathComponent.hasSuffix(".nxsave.icloud") else {continue}
            guard let value=try? url.resourceValues(forKeys:[.fileSizeKey,.contentModificationDateKey,.isUbiquitousItemKey,.ubiquitousItemDownloadingStatusKey]) else{return nil}
            if value.isUbiquitousItem==true,value.ubiquitousItemDownloadingStatus != .current {try? fm.startDownloadingUbiquitousItem(at:url)}
            if url.lastPathComponent.hasPrefix("."),url.lastPathComponent.hasSuffix(".icloud") {let logical=String(url.lastPathComponent.dropFirst().dropLast(7));try? fm.startDownloadingUbiquitousItem(at:url.deletingLastPathComponent().appendingPathComponent(logical))}
            rows.append(url.path+":"+String(value.fileSize ?? -1)+":"+String(value.contentModificationDate?.timeIntervalSince1970 ?? 0))
        }
        return rows.sorted().joined(separator:"\n")
    }
    func watchCloud(repo:URL) async {
        ensureManagedCloud(repo:repo)
        while !Task.isCancelled {
            if cloud==nil {ensureManagedCloud(repo:repo)}
            refresh(repo:repo,force:false)
            do {try await Task.sleep(nanoseconds:5_000_000_000)}catch{return}
        }
    }
    func refresh(repo:URL,force:Bool=true) {
        guard let folder=cloud,!scanning else {return};scanning=true
        let token=UUID();listGeneration=token
        Task {
            let stamp=await Task.detached(priority:.utility){Self.cloudSignature(folder)}.value
            guard listGeneration==token,cloud==folder else{return}
            guard stamp != nil else {scanning=false;cloudIssue="folder_access";return}
            if !force,stamp==signature,cloudCheckedAt != nil,cloudIssue==nil {scanning=false;return}
            let data=await Task.detached(priority:.utility){Self.execute(repo:repo,request:["op":"list","cloud":folder.path])}.value
            guard listGeneration==token,cloud==folder else{return};scanning=false
            guard let result=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],result["ok"] as? Bool==true,let payload=result["result"] as? [String:Any],let encoded=try? JSONSerialization.data(withJSONObject:payload["revisions"] ?? []),let received=try? JSONDecoder().decode([SaveRevision].self,from:encoded) else {cloudIssue="folder_access";return}
            revisions=received;pending=payload["pending"] as? Int ?? 0;invalid=payload["invalid"] as? Int ?? 0
            knownCloudTitles=Array(Set(knownCloudTitles+received.map(\.title))).sorted()
            signature=stamp;cloudCheckedAt=Date();cloudIssue=nil
            if let bookmark=defaults.data(forKey:"saveCenter.folder.v1"),let cache=try? JSONEncoder().encode(CloudCache(bookmark:bookmark,revisions:received,titles:knownCloudTitles)),cache.count<=1048576 {defaults.set(cache,forKey:"cloudLibrary.cache.v1")}
        }
    }
    func download(repo:URL,revision:SaveRevision) {
        guard !busy,cloud != nil else{return}
        let panel=NSSavePanel();panel.nameFieldStringValue="Save-"+revision.title+"-"+String(Int(revision.date))+".zip"
        guard panel.runModal() == .OK,let destination=panel.url else{return}
        request(repo:repo,["op":"inspect","source":revision.path,"kind":"account"]) {checked in
            guard let fingerprint=checked["fingerprint"] as? String else {self.error="save_operation_failed";return}
            self.request(repo:repo,["op":"backup_revision","source":revision.path,"fingerprint":fingerprint,"destination":destination.path]) {result in
                if let path=result["path"] as? String {self.localBackup=URL(fileURLWithPath:path);self.localBackupTitle=revision.title}
            }
        }
    }
    func inspect(repo:URL,url:URL,revision:SaveRevision?=nil) {
        guard !busy else {return};source=url;selectedRevision=revision;preview=nil;completed=nil
        request(repo:repo,["op":"inspect","source":url.path,"kind":kind]) {result in
            if let data=try? JSONSerialization.data(withJSONObject:result) {self.preview=try? JSONDecoder().decode(SavePreview.self,from:data)}
        }
    }
    func chooseSource(repo:URL) {
        guard !busy else {return}
        let panel=NSOpenPanel();panel.canChooseDirectories=true;panel.canChooseFiles=true;panel.allowsMultipleSelection=false
        if panel.runModal() == .OK,let url=panel.url {inspect(repo:repo,url:url)}
    }
    func importSave(repo:URL,game:OwnedGameOutput) {
        guard let source,let cloud,let preview,let title=game.titleID else {return}
        var identity:[String:Any]=["title":title]
        if let mac=game.macApp {identity["mac"]=mac.path};if let ipa=game.iosIPA {identity["ipa"]=ipa.path}
        request(repo:repo,["op":"import","source":source.path,"cloud":cloud.path,"kind":kind,"fingerprint":preview.fingerprint,"game":identity,"confirmed_game":true]) {result in
            if let path=result["path"] as? String {self.completed=URL(fileURLWithPath:path);self.published=true}
        }
    }
    func exportSave(repo:URL) {
        guard !busy,let source,let preview,let title=preview.title else {return}
        let panel=NSOpenPanel();panel.canChooseDirectories=true;panel.canChooseFiles=false;panel.allowsMultipleSelection=false
        guard panel.runModal() == .OK,let destination=panel.url else {return}
        request(repo:repo,["op":"export","source":source.path,"destination":destination.path,"title":title,"fingerprint":preview.fingerprint,"confirmed_console_requirement":true]) {result in
            if let path=result["path"] as? String {self.completed=URL(fileURLWithPath:path);self.published=false}
        }
    }
    func backupMac(repo:URL,game:OwnedGameOutput) {
        guard !busy,let title=game.titleID else {return}
        if let app=game.macApp,let bundle=Bundle(url:app)?.bundleIdentifier,NSRunningApplication.runningApplications(withBundleIdentifier:bundle).contains(where:{!$0.isTerminated}) {error="close_game_first";return}
        let panel=NSSavePanel();panel.nameFieldStringValue="Mac-"+title+"-"+String(Int(Date().timeIntervalSince1970))+".zip"
        guard panel.runModal() == .OK,let url=panel.url else {return}
        request(repo:repo,["op":"backup_mac","title":title,"destination":url.path,"confirmed_closed":true]) {result in if let path=result["path"] as? String {self.localBackup=URL(fileURLWithPath:path);self.localBackupTitle=title}}
    }
    func backupRevision(repo:URL) {
        guard !busy,let source,let preview else {return}
        let panel=NSSavePanel();panel.nameFieldStringValue="Partida-"+(preview.title ?? "Easy")+"-"+String(Int(Date().timeIntervalSince1970))+".zip"
        guard panel.runModal() == .OK,let url=panel.url else {return}
        request(repo:repo,["op":"backup_revision","source":source.path,"fingerprint":preview.fingerprint,"destination":url.path]) {result in if let path=result["path"] as? String {self.localBackup=URL(fileURLWithPath:path);self.localBackupTitle=preview.title}}
    }
    func clearSelection() {guard !busy else {return};source=nil;preview=nil;selectedRevision=nil;completed=nil;error=nil;localBackup=nil;localBackupTitle=nil}
}

struct SaveCenterView:View {
    @ObservedObject var model:SaveCenterModel
    let repo:URL
    let games:[OwnedGameOutput]
    let catalog:[CatalogGame]
    let text:(String)->String
    var focusTitle:String?=nil
    let devices:()->Void
    @State private var importing=false
    @State private var agreed=false
    @State private var consoleReady=false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var chosenGame:OwnedGameOutput? {games.first(where:{$0.id==model.gameID})}
    private var visible:[SaveRevision] {model.revisions.filter {model.filter.isEmpty || $0.title==model.filter}}
    private func title(_ id:String)->String {catalog.first(where:{$0.id==id})?.name ?? id}
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:24) {
                if focusTitle==nil || model.source==nil {HStack(alignment:.center,spacing:28) {
                    VStack(alignment:.leading,spacing:15) {
                        EasyEyebrow(title:text("TUS PARTIDAS"))
                        Text(text(model.source==nil ? "Tu aventura continúa." : "Prepara el siguiente capítulo.")).font(.system(size:model.source==nil ? 38 : 28,weight:.bold)).tracking(-1.1)
                        if model.source==nil {
                        Text(text("De iPhone a Mac. De un respaldo a tu próximo juego. Tú eliges qué partida usar.")).font(.callout).foregroundStyle(.secondary).lineSpacing(3)
                        HStack(spacing:12) {
                            Button(model.cloud==nil ? text("Conectar carpeta de iCloud") : text("Cambiar carpeta")){model.chooseCloud(repo:repo)}.buttonStyle(EasyPrimaryStyle())
                            if model.cloud != nil {Button {model.refresh(repo:repo)} label:{Image(systemName:"arrow.clockwise")}.buttonStyle(EasySecondaryStyle()).accessibilityLabel(text("Actualizar partidas"))}
                        }.disabled(model.busy)
                        }
                        if let cloud=model.cloud {Label(cloud.lastPathComponent,systemImage:"icloud").font(.caption).foregroundStyle(.secondary)}
                    }.frame(maxWidth:.infinity,alignment:.leading)
                    if let image=Bundle.main.url(forResource:"save-vault",withExtension:"png",subdirectory:"Library").flatMap({NSImage(contentsOf:$0)}) {Image(nsImage:image).resizable().scaledToFit().frame(width:model.source==nil ? 300 : 180,height:model.source==nil ? 220 : 120).accessibilityHidden(true)}
                }}
                if model.source==nil {
                    VStack(alignment:.leading,spacing:10) {
                        Label(text("Guarda y continúa. Automáticamente."),systemImage:"arrow.triangle.2.circlepath.icloud").font(.headline).foregroundStyle(EasyDesign.accent)
                        Text(text("Una sola vez: prepara las versiones de Mac y iPhone con Easy actualizado y elige la misma carpeta de iCloud dentro de cada juego.")).font(.callout)
                        Text(text("Después, guarda y cierra el juego. Al abrirlo en el otro dispositivo, busca y recibe tu continuación antes de jugar. Si jugaste en ambos, te pide elegir y conserva las dos partidas.")).font(.callout).foregroundStyle(.secondary)
                        Text(text("Esta pantalla permite revisar copias y guardarlas a mano. No activa la sincronización dentro de una app antigua. iCloud puede tardar; no confirma entregas que aún no ha recibido.")).font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth:.infinity,alignment:.leading).padding(20).background(EasyDesign.panel,in:RoundedRectangle(cornerRadius:16))
                }
                if model.busy {
                    HStack(spacing:18) {
                        LibraryDropMotion(playing:scenePhase == .active && !reduceMotion,resource:"save-transfer").frame(width:110,height:82).accessibilityHidden(true)
                        VStack(alignment:.leading,spacing:7) {Text(text("Comprobando tu partida…")).font(.headline);Text(text("Leemos y verificamos la copia. Tus partidas activas siguen en su lugar.")).font(.callout).foregroundStyle(.secondary)}
                        Spacer()
                        if let start=model.startedAt {TimelineView(.periodic(from:.now,by:1)){context in Text(String(max(0,Int(context.date.timeIntervalSince(start))))+" s").font(.caption.monospacedDigit()).foregroundStyle(.secondary)}}
                        ProgressView().controlSize(.small)
                    }.padding(18).background(EasyDesign.panel,in:RoundedRectangle(cornerRadius:14))
                }
                if let error=model.error {Label(message(error),systemImage:"exclamationmark.triangle").font(.callout).foregroundStyle(.orange).textSelection(.enabled)}
                if let local=model.localBackup {HStack {Label(text("Tu respaldo local está listo"),systemImage:"checkmark.shield");Button(text("Mostrar respaldo")){NSWorkspace.shared.activateFileViewerSelecting([local])}.buttonStyle(EasyLinkStyle())}.font(.callout)}
                if let completed=model.completed {completion(completed)}
                else if model.source != nil {review}
                else {overview}
            }.frame(maxWidth:1100,alignment:.leading).frame(maxWidth:.infinity).padding(36)
        }.safeAreaInset(edge:.bottom,spacing:0) {
            if model.preview != nil && model.completed==nil {
                HStack(spacing:18) {
                    Text(text("Tu original y las otras versiones se conservan.")).font(.caption).foregroundStyle(.secondary).frame(maxWidth:.infinity,alignment:.leading)
                    if importing {
                        Button {if let game=chosenGame {model.importSave(repo:repo,game:game)}} label:{Label(text("Añadir a iCloud"),systemImage:"plus.icloud")}.buttonStyle(EasyPrimaryStyle()).disabled(!agreed || chosenGame==nil || model.cloud==nil || model.busy)
                    } else {
                        Button {model.exportSave(repo:repo)} label:{Label(text("Preparar respaldo"),systemImage:"square.and.arrow.up")}.buttonStyle(EasyPrimaryStyle()).disabled(!consoleReady || model.busy)
                    }
                }.frame(maxWidth:1100).padding(20).frame(maxWidth:.infinity).background(EasyDesign.background).overlay(alignment:.top){Divider()}
            }
        }.background(EasyDesign.background)
        .task {importing=model.source != nil && model.selectedRevision==nil;model.restoreFolder();if let focusTitle {model.filter=focusTitle};if model.cloud != nil {model.refresh(repo:repo)}}
        .onChange(of:model.kind){_,_ in agreed=false;if let source=model.source {model.inspect(repo:repo,url:source,revision:model.selectedRevision)}}
        .onChange(of:model.gameID){_,_ in agreed=false}
    }
    private var overview:some View {
        VStack(alignment:.leading,spacing:22) {
            HStack(alignment:.top,spacing:18) {
                action("Traer un respaldo","De Switch o de otro dispositivo. El original se conserva.",icon:"tray.and.arrow.down") {importing=true;agreed=false;consoleReady=false;model.chooseSource(repo:repo)}
                action("Sacar partidas del iPhone","Abre tu juego en Biblioteca y elige Partidas y copias. Conecta el iPhone para guardar un respaldo local, sin iniciar sesión.",icon:"iphone.and.arrow.forward") {devices()}
            }.disabled(model.busy)
            HStack {
                Text(text("En tu carpeta de iCloud")).font(.system(size:22,weight:.bold))
                Spacer()
                Picker(text("Juego"),selection:$model.filter) {Text(text("Todos los juegos")).tag("");ForEach(catalog.filter{game in model.revisions.contains(where:{$0.title==game.id})}) {game in Text(game.name).tag(game.id)}}.frame(maxWidth:260)
            }
            if model.cloud==nil {empty("Conecta tu carpeta","Elige la misma carpeta de iCloud Drive que usas dentro de tus juegos. No es la cuenta Apple de instalación.",icon:"icloud")}
            else if visible.isEmpty {empty("Aún no hay partidas aquí","Abre un juego preparado con continuidad, elige esta misma carpeta y guarda. Después vuelve a comprobar.",icon:"tray")}
            else {
                ForEach(visible) {revision in
                    Button {importing=false;agreed=false;consoleReady=false;model.inspect(repo:repo,url:URL(fileURLWithPath:revision.path),revision:revision)} label:{
                        HStack(spacing:16) {
                            if let game=catalog.first(where:{$0.id==revision.title}) {GameArtworkView(game:game).frame(width:104,height:62).clipped().clipShape(RoundedRectangle(cornerRadius:8))}
                            VStack(alignment:.leading,spacing:6) {Text(title(revision.title)).font(.headline);Text(revision.device+" · "+revision.version).font(.caption).foregroundStyle(.secondary)}
                            Spacer();Text(Date(timeIntervalSince1970:revision.date),style:.date).font(.caption).foregroundStyle(.secondary)
                            Image(systemName:"arrow.up.right").foregroundStyle(EasyDesign.accent)
                        }.padding(16).background(EasyDesign.panel,in:RoundedRectangle(cornerRadius:12)).foregroundStyle(EasyDesign.ink)
                    }.buttonStyle(.plain).disabled(model.busy)
                }
                Text(text("Elige una versión para comprobarla. Las fechas ayudan a reconocerla; no deciden cuál se conserva.")).font(.caption).foregroundStyle(.secondary)
            }
            if model.pending>0 {Label(text("Hay partidas pendientes de descargar de iCloud. Comprueba de nuevo cuando estén disponibles."),systemImage:"icloud.and.arrow.down").font(.callout).foregroundStyle(.orange)}
            if model.invalid>0 {Label(text("Algunos archivos no se pudieron leer. No se modificaron ni se ocultaron tus otras partidas."),systemImage:"exclamationmark.triangle").font(.caption).foregroundStyle(.orange)}
            consoleNotice
        }
    }
    private var review:some View {
        VStack(alignment:.leading,spacing:22) {
            EasyStepRail(titles:["Elegir partida","Revisar destino","Preparar copia"].map(text),current:model.preview==nil ? 0 : 1)
            HStack {Text(text(importing ? "Una partida más. Todas a salvo." : "Lleva esta partida contigo.")).font(.system(size:28,weight:.bold));Spacer();Button(text("Volver")){model.clearSelection()}.buttonStyle(EasyLinkStyle()).disabled(model.busy)}
            if importing && model.source?.pathExtension.lowercased() != "nxsave" {
                Picker(text("Tipo de respaldo"),selection:$model.kind) {Text(text("Partida personal")).tag("account");Text(text("Datos compartidos del juego")).tag("device");Text(text("Exportación de Easy: save y save_device")).tag("bundle")}.pickerStyle(.menu).disabled(model.busy)
            }
            if importing {Button(text("Elegir otro respaldo")){model.chooseSource(repo:repo)}.buttonStyle(EasyLinkStyle()).disabled(model.busy)}
            if let preview=model.preview {
                if !importing {Button(text("Guardar copia local")){model.backupRevision(repo:repo)}.buttonStyle(EasySecondaryStyle()).disabled(model.busy)}
                EasyCard {
                    VStack(alignment:.leading,spacing:14) {
                        Label(preview.title.map(title) ?? model.source?.lastPathComponent ?? text("Respaldo"),systemImage:"checkmark.shield").font(.title3.bold())
                        Text(String(preview.files)+" "+text("archivos verificados")+" · "+ByteCountFormatter.string(fromByteCount:Int64(preview.bytes),countStyle:.file)).font(.callout).foregroundStyle(.secondary)
                        if let version=preview.version {Label(text("Versión del juego")+" · "+version,systemImage:"tag").font(.callout)}
                        if preview.roots.contains("save_device") {Text(text("Incluye datos compartidos del juego. Se mantienen separados de la partida personal.")).font(.caption).foregroundStyle(.secondary)}
                        Text(text("El archivo original y el historial de iCloud se conservan. Esta operación prepara una copia nueva.")).font(.callout)
                    }
                }
                if importing {
                    EasyCard {
                        VStack(alignment:.leading,spacing:16) {
                            if let focusTitle {Label(title(focusTitle),systemImage:"gamecontroller").font(.headline)}
                            else {Text(text("¿A qué juego pertenece?")).font(.headline)
                            Picker(text("Tu juego"),selection:$model.gameID) {Text(text("Elige de tu biblioteca")).tag("");ForEach(games.filter{$0.titleID != nil}) {game in Text(title(game.titleID!)+" · "+(game.version ?? "—")).tag(game.id)}}}
                            Text(text("Los respaldos de consola no siempre indican versión o DLC. Comprueba que sean los mismos que preparaste; no convertimos partidas entre juegos ni ediciones.")).font(.callout).foregroundStyle(.secondary)
                            Toggle(text("Confirmo que es el mismo juego, versión y contenido."),isOn:$agreed)
                            if model.cloud==nil {Button(text("Elegir carpeta de iCloud")){model.chooseCloud(repo:repo)}.buttonStyle(EasySecondaryStyle())}
                            Text(text("Después abre el juego en Mac, iPhone o iPad. Su lanzador comprobará esta versión y te dejará elegir si encuentra otro progreso.")).font(.caption).foregroundStyle(.secondary)
                        }
                    }.disabled(model.busy)
                } else {
                    EasyCard {
                        VStack(alignment:.leading,spacing:16) {
                            Label(text("Preparar para Switch"),systemImage:"sdcard").font(.headline)
                            consoleNotice
                            Toggle(text("Entiendo que necesitaré una herramienta compatible para restaurar en la consola."),isOn:$consoleReady)
                            Text(text("Al continuar, elige tu SD o una carpeta. Se creará un respaldo nuevo, sin reemplazar los anteriores.")).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
    private var consoleNotice:some View {
        VStack(alignment:.leading,spacing:8) {
            Label(text("Tu consola necesita una vía de restauración"),systemImage:"info.circle").font(.callout.weight(.semibold))
            Text(text("Una Switch 1 o 2 sin modificar no importa partidas sólo por ponerlas en la SD. Easy prepara archivos; la restauración ocurre en una herramienta compatible de la consola. No conectamos con la nube de Nintendo ni modificamos tu consola.")).font(.callout).foregroundStyle(.secondary)
            Link(text("Cómo funciona la transferencia con Switch"),destination:URL(string:"https://github.com/nalancer08/nxnative-easy/blob/main/docs/save-transfer.md")!).font(.caption)
        }
    }
    private func completion(_ url:URL)->some View {
        VStack(alignment:.leading,spacing:20) {
            EasyStepRail(titles:["Elegir partida","Revisar destino","Preparar copia"].map(text),current:3)
            EasyMilestone(kind:.complete,title:text(model.published ? "Una nueva versión, a salvo." : "Respaldo listo para llevar."),subtitle:text(model.published ? "Se añadió sin reemplazar tus partidas. Espera a que iCloud la entregue al otro dispositivo." : "Los archivos están preparados. La restauración en Switch aún debe hacerse desde la consola."))
            if !model.published {consoleNotice}
            HStack {Button(text("Mostrar respaldo")){NSWorkspace.shared.activateFileViewerSelecting([url])}.buttonStyle(EasyPrimaryStyle());Button(text("Volver a mis partidas")){model.clearSelection();model.refresh(repo:repo)}.buttonStyle(EasySecondaryStyle())}
        }
    }
    private func action(_ title:String,_ subtitle:String,icon:String,run:@escaping()->Void)->some View {
        Button(action:run){HStack(alignment:.top,spacing:16) {Image(systemName:icon).font(.system(size:28,weight:.light)).foregroundStyle(EasyDesign.accent);VStack(alignment:.leading,spacing:10) {Text(text(title)).font(.headline);Text(text(subtitle)).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.leading)};Spacer(minLength:0)}.padding(22).frame(maxWidth:.infinity,minHeight:132,alignment:.topLeading).background(EasyDesign.panel,in:RoundedRectangle(cornerRadius:14)).foregroundStyle(EasyDesign.ink)}.buttonStyle(.plain)
    }
    private func empty(_ title:String,_ subtitle:String,icon:String)->some View {
        HStack(spacing:20) {Image(systemName:icon).font(.system(size:38,weight:.ultraLight)).foregroundStyle(EasyDesign.accent);VStack(alignment:.leading,spacing:9) {Text(text(title)).font(.title3.bold());Text(text(subtitle)).font(.callout).foregroundStyle(.secondary)}}.padding(28).frame(maxWidth:.infinity,alignment:.leading).background(EasyDesign.panel,in:RoundedRectangle(cornerRadius:14))
    }
    private func message(_ code:String)->String {
        let values=["wrong_save_layout":"El respaldo contiene carpetas distintas de las que usa este juego. Comprueba el tipo de partida y elige el respaldo correcto.","create_first_cloud_save":"Abre este juego, conecta esta carpeta de iCloud y guarda una vez. Así reconocemos su estructura antes de traer tu respaldo.","incomplete_save_pair":"Este juego usa dos carpetas de partidas. Elige un respaldo completo con save y save_device; nunca mezclamos versiones parciales.","rebuild_for_save_transfer":"Prepara este juego otra vez para añadir su identidad de partidas. No borres la app instalada.","platform_content_mismatch":"Las versiones de Mac y iPhone tienen contenido diferente. Prepara ambas con el mismo juego, update y DLC.","different_game_content":"Esta partida corresponde a otro juego o contenido. Se conservó sin importar.","source_changed":"El respaldo cambió mientras lo leíamos. Cierra el juego y vuelve a elegirlo.","case_collision_for_sd":"Este respaldo contiene nombres que tu SD no puede conservar. No se renombró ni se perdió ningún archivo.","missing_guest_metadata":"Este respaldo perdió metadatos de nombres. Usa una copia completa compatible.","not_save_data":"Seleccionaste archivos de juego o llaves. Elige sólo un respaldo de partidas.","not_committed_save_data":"Elige sólo la partida guardada, no romfs ni carpetas temporales.","empty_or_large_save":"No encontramos una partida completa dentro de los límites de transferencia.","checksum_mismatch":"El respaldo no pasó la comprobación. Se conservó el original.","folder_access":"Elige de nuevo la carpeta para dar acceso a tus partidas."]
        return text(values[code] ?? "No pudimos completar la copia. Tus partidas originales siguen intactas. Revisa la carpeta y vuelve a intentarlo.")
    }
}
