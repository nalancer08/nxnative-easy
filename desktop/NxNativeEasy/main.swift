import SwiftUI
import Combine
import AppKit
import Foundation
import Darwin
import UserNotifications

// Read only top-level package metadata. Never open encrypted packages or key contents here.
struct PreparationFile:Identifiable {
    let name:String
    let size:Int64
    let readable:Bool
    var id:String {name}
    static func inspect(_ folder:URL)->[PreparationFile] {
        let properties:Set<URLResourceKey>=[.isRegularFileKey,.isReadableKey,.fileSizeKey]
        return ((try? FileManager.default.contentsOfDirectory(at:folder,includingPropertiesForKeys:Array(properties),options:.skipsHiddenFiles)) ?? []).compactMap {url in
            guard ["nsp","xci","nsz","xcz"].contains(url.pathExtension.lowercased()),
                  let values=try? url.resourceValues(forKeys:properties),values.isRegularFile==true else {return nil}
            return PreparationFile(name:url.lastPathComponent,size:Int64(values.fileSize ?? 0),readable:values.isReadable==true && (values.fileSize ?? 0)>0)
        }.sorted {$0.name.localizedStandardCompare($1.name) == .orderedAscending}
    }
}

struct PreparationInventory:View {
    let files:[PreparationFile]
    let text:(String)->String
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            HStack {
                Label(text(files.isEmpty ? "Esperando tus archivos" : "Archivos detectados"),systemImage:files.isEmpty ? "tray.and.arrow.down" : "checkmark.circle.fill").font(.headline)
                Spacer()
                if !files.isEmpty {Text("\(files.count) · "+ByteCountFormatter.string(fromByteCount:files.reduce(0){$0+$1.size},countStyle:.file)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)}
            }
            ForEach(Array(files.prefix(8))) {file in
                HStack(spacing:12) {
                    Text(URL(fileURLWithPath:file.name).pathExtension.uppercased()).font(.system(size:10,weight:.bold,design:.monospaced)).frame(width:44).padding(.vertical,8).background(.white.opacity(0.07),in:RoundedRectangle(cornerRadius:6))
                    Text(file.name).font(.callout).lineLimit(2).textSelection(.enabled)
                    Spacer()
                    Text(file.readable ? ByteCountFormatter.string(fromByteCount:file.size,countStyle:.file) : text("No se puede leer o está vacío")).font(.caption).foregroundStyle(file.readable ? Color.secondary : Color.orange)
                    Image(systemName:file.readable ? "checkmark.circle" : "exclamationmark.triangle").foregroundStyle(file.readable ? Color.green : Color.orange).accessibilityLabel(text(file.readable ? "Archivo legible" : "Revisa este archivo"))
                }
            }
            if files.count>8 {Text(text("Más archivos detectados")+": \(files.count-8)").font(.caption).foregroundStyle(.secondary)}
            if files.isEmpty {Text(text("Añade una carpeta con archivos NSP, XCI, NSZ o XCZ para verlos aquí.")).font(.callout).foregroundStyle(.secondary)}
        }.padding(18).background(.black.opacity(0.17),in:RoundedRectangle(cornerRadius:14))
    }
}

// Each milestone has its own vector composition, independent from game artwork.
struct PreparationIllustration:View {
    let step:Int
    let isMac:Bool
    let text:(String)->String
    private let accent=EasyDesign.accent
    private var symbol:String {["gamecontroller","tray.and.arrow.down","key.horizontal","point.topleft.down.to.point.bottomright.curvepath","cpu","checkmark.seal"][min(5,max(0,step))]}
    private var title:String {["Tu juego, en tu pantalla","Ve lo que vas a preparar","La llave la eliges tú","Un plan antes de empezar","Del archivo a tu app","El siguiente paso: jugar"][min(5,max(0,step))]}
    private var subtitle:String {["Elige tu destino. El resto se adapta a ti.","Tus archivos aparecen aquí antes de compilar.","Un archivo local. Sin subirlo ni copiarlo.","Destino, archivos y datos: todo a la vista.","Cada etapa muestra lo que está ocurriendo.","Tu preparación está lista para el destino elegido."][min(5,max(0,step))]}
    var body:some View {
        HStack(spacing:28) {
            artwork.frame(width:210,height:146).accessibilityHidden(true)
            VStack(alignment:.leading,spacing:10) {
                Text(text(title)).font(.system(size:23,weight:.bold,design:.rounded))
                Text(text(subtitle)).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            }.frame(maxWidth:.infinity,alignment:.leading)
        }.padding(20).frame(maxWidth:.infinity,alignment:.leading)
            .background(LinearGradient(colors:[accent.opacity(0.10),.white.opacity(0.025)],startPoint:.leading,endPoint:.trailing),in:RoundedRectangle(cornerRadius:20))
            .overlay(RoundedRectangle(cornerRadius:20).strokeBorder(accent.opacity(0.12)))
    }
    @ViewBuilder private var artwork:some View {
        ZStack {
            Circle().stroke(accent.opacity(0.10),lineWidth:1).frame(width:140,height:140)
            Circle().stroke(accent.opacity(0.08),style:StrokeStyle(lineWidth:1,dash:[3,6])).frame(width:110,height:110)
            if step==0 {
                Image(systemName:"desktopcomputer").font(.system(size:76,weight:.ultraLight)).foregroundStyle(accent.opacity(0.8)).offset(x:-24,y:-5)
                Image(systemName:"iphone").font(.system(size:68,weight:.light)).foregroundStyle(accent).padding(8).background(Color(red:0.08,green:0.12,blue:0.08),in:RoundedRectangle(cornerRadius:18)).rotationEffect(.degrees(12)).offset(x:54,y:18)
            } else if step==1 {
                package("XCI",angle:-12,x:-45,y:6)
                package("NSP",angle:8,x:14,y:-8)
                Image(systemName:"magnifyingglass").font(.system(size:44,weight:.light)).foregroundStyle(accent).offset(x:65,y:38)
            } else if step==2 {
                RoundedRectangle(cornerRadius:18).fill(accent.opacity(0.07)).frame(width:102,height:116).rotationEffect(.degrees(-9))
                Image(systemName:"lock.shield").font(.system(size:68,weight:.ultraLight)).foregroundStyle(accent.opacity(0.55)).offset(x:-23,y:-6)
                Image(systemName:"key.horizontal.fill").font(.system(size:50)).foregroundStyle(accent).rotationEffect(.degrees(-28)).offset(x:32,y:24)
            } else if step==3 {
                HStack(spacing:10) {
                    Image(systemName:"doc.zipper");Image(systemName:"arrow.right").font(.caption)
                    Image(systemName:"cpu");Image(systemName:"arrow.right").font(.caption)
                    Image(systemName:isMac ? "desktopcomputer" : "iphone")
                }.font(.system(size:31,weight:.light)).foregroundStyle(accent)
                Image(systemName:"checkmark.circle.fill").font(.system(size:25)).foregroundStyle(accent).offset(y:48)
            } else if step==4 {
                RoundedRectangle(cornerRadius:16).stroke(accent.opacity(0.25),lineWidth:1).frame(width:120,height:110).rotationEffect(.degrees(12))
                Image(systemName:"cpu").font(.system(size:70,weight:.ultraLight)).foregroundStyle(accent)
                HStack(spacing:5) {ForEach(0..<5) {n in Capsule().fill(accent.opacity(Double(n+1)/5)).frame(width:16,height:4)}}.offset(y:55)
            } else {
                Image(systemName:isMac ? "desktopcomputer" : "ipad.and.iphone").font(.system(size:74,weight:.ultraLight)).foregroundStyle(accent.opacity(0.65))
                Image(systemName:"checkmark.seal.fill").font(.system(size:44)).foregroundStyle(accent).offset(x:55,y:35)
            }
        }
    }
    private func package(_ label:String,angle:Double,x:CGFloat,y:CGFloat)->some View {
        VStack(spacing:10) {Image(systemName:"doc.zipper").font(.system(size:36,weight:.light));Text(label).font(.system(size:12,weight:.bold,design:.monospaced))}
            .foregroundStyle(accent).frame(width:78,height:103).background(Color(red:0.13,green:0.18,blue:0.11),in:RoundedRectangle(cornerRadius:12))
            .overlay(RoundedRectangle(cornerRadius:12).stroke(accent.opacity(0.35))).rotationEffect(.degrees(angle)).offset(x:x,y:y)
    }
}

struct InspectedPackage:Decodable,Identifiable {
    let file:String
    let title_id:String
    let kind:String
    let version:UInt64
    let name:String?
    let display_version:String?
    var id:String {file+title_id+kind+String(version)}
}
struct PackageInspection:Decodable {
    let schema:Int
    let status:String
    let title_id:String?
    let name:String?
    let display_version:String?
    let version:UInt64?
    let selected_file:String?
    let base_version:String?
    let updates:[InspectedPackage]?
    let dlc:[InspectedPackage]?
    var ready:Bool {schema==1 && status=="ready"}
}

struct PackageIdentityView:View {
    @State private var started=Date()
    let inspection:PackageInspection?
    let inspecting:Bool
    let hasKeys:Bool
    let catalog:[CatalogGame]
    let text:(String)->String
    let chooseKeys:()->Void
    let retry:()->Void
    let setup:()->Void
    let cancel:()->Void
    private var message:String {
        switch inspection?.status {
        case "files_changed":return "Los archivos cambiaron. Vuelve a identificar la carpeta antes de continuar."
        case "base_missing":return "No encontramos un juego base. Añade el archivo base, además del update."
        case "multiple_games":return "Hay varios juegos en esta carpeta. Deja un solo juego con sus updates y DLC."
        case "tools_missing","tools_unavailable":return "Necesitamos preparar la herramienta de lectura de metadatos. El juego todavía no se compila."
        case "incomplete":return "Algunos archivos no se pudieron identificar. Revisa tus llaves y que los archivos estén completos."
        default:return "No pudimos leer los metadatos. Revisa tus llaves y los archivos del juego."
        }
    }
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            if inspecting {
                HStack {ProgressView().controlSize(.small);Text(text("Leyendo el juego y sus actualizaciones…")).font(.headline);Spacer();Button(text("Cancelar"),action:cancel)}
                Text(text("Sólo leemos los metadatos internos. No extraemos romfs ni compilamos el juego.")).font(.caption).foregroundStyle(.secondary)
                TimelineView(.periodic(from:.now,by:1)) {context in
                    Text(text("Tiempo transcurrido")+": "+String(max(0,Int(context.date.timeIntervalSince(started))))+" s").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            } else if !hasKeys {
                Label(text("Identifica tu juego antes de compilar"),systemImage:"magnifyingglass").font(.headline)
                Text(text("Necesitamos tu prod.keys para leer el nombre, la versión y los updates dentro de tus archivos.")).font(.callout).foregroundStyle(.secondary)
                Button(text("Elegir prod.keys e identificar"),action:chooseKeys)
            } else if let result=inspection,result.ready {
                Label(result.name ?? catalog.first(where:{$0.id.uppercased()==result.title_id})?.name ?? text("Juego identificado"),systemImage:"checkmark.seal.fill").font(.title2.bold())
                HStack(spacing:20) {
                    Label(text("Versión a preparar")+": "+(result.display_version ?? text("Versión interna")+" \(result.version ?? 0)"),systemImage:"tag")
                    Text(result.title_id ?? "").font(.caption.monospaced()).foregroundStyle(.secondary)
                }
                if let base=result.base_version,!base.isEmpty {Text(text("Juego base")+": "+base).font(.callout).foregroundStyle(.secondary)}
                if let updates=result.updates,!updates.isEmpty {
                    Text(text("Actualizaciones detectadas")+": \(updates.count)").font(.headline)
                    ForEach(updates) {update in
                        HStack {
                            Image(systemName:update.file==result.selected_file ? "checkmark.circle.fill" : "arrow.down.circle")
                            Text(update.display_version ?? text("Versión interna")+" \(update.version)").fontWeight(.semibold)
                            Text(update.file).lineLimit(2).foregroundStyle(.secondary)
                            if update.file==result.selected_file {Text(text("Se usará esta")).font(.caption.bold())}
                        }.font(.callout)
                    }
                } else {Label(text("Sin updates detectados: se preparará el juego base."),systemImage:"info.circle").font(.callout)}
                if let dlc=result.dlc,!dlc.isEmpty {Label(text("DLC detectados")+": \(dlc.count)",systemImage:"square.stack.3d.up").font(.callout)}
                if let id=result.title_id,!catalog.contains(where:{$0.id.uppercased()==id}) {Text(text("Este juego no tiene un perfil probado en el catálogo. Prepararlo no garantiza que funcione.")).font(.caption).foregroundStyle(.orange)}
                Button(text("Volver a comprobar"),action:retry).font(.caption)
            } else {
                Label(text(message),systemImage:"exclamationmark.triangle").foregroundStyle(.orange)
                HStack {
                    if ["tools_missing","tools_unavailable"].contains(inspection?.status ?? "") {Button(text("Preparar herramienta de lectura"),action:setup)}
                    else {Button(text("Volver a comprobar"),action:retry);Button(text("Cambiar prod.keys"),action:chooseKeys)}
                }
            }
        }.padding(18).frame(maxWidth:.infinity,alignment:.leading).background(Color(red:0.79,green:0.95,blue:0.37).opacity(0.065),in:RoundedRectangle(cornerRadius:14))
            .onChange(of:inspecting) {_,active in if active {started=Date()}}
    }
}

@MainActor final class BuildModel: ObservableObject {
    @Published var language: EasyLanguage = EasyLanguage.load() {
        didSet {language.save(defaults:defaults)}
    }
    func text(_ source: String) -> String {EasyStrings.text(source, language:language)}
    @Published var preparationStep=0
    var buildRevision:String?
    @Published var target = "" {
        didSet { output=nil;assets=nil;failed=false;restoreOutput() }
    }
    @Published var splitIOS=true {didSet {defaults.set(splitIOS,forKey:"iosSplitGameData");output=nil;assets=nil;restoreOutput()}}
    var isMac: Bool {target == "mac"}
    @Published var folder: URL? {didSet {inspectFiles()}}
    @Published var keysFolder: URL? {didSet {identifyGame()}}
    @Published var inspecting=false
    @Published var inspection:PackageInspection?
    private var inspectionData:Data?
    private var inspectionManifest:URL?
    private var inspectionProcess:Process?
    private var inspectionGeneration=UUID()
    @Published var detectedFiles:[PreparationFile]=[]
    var readableKeys:Bool {
        guard let key=keysFolder?.appendingPathComponent("prod.keys"),
              let values=try? key.resourceValues(forKeys:[.isRegularFileKey,.isReadableKey,.fileSizeKey]) else {return false}
        return values.isRegularFile==true && values.isReadable==true && (values.fileSize ?? 0)>0
    }
    func inspectFiles() {
        guard let folder else {detectedFiles=[];return}
        detectedFiles=PreparationFile.inspect(folder)
        identifyGame()
    }
    @Published var running = false
    @Published var phase = "Tu próximo juego empieza aquí."
    @Published var detail = "Elige su carpeta. Nosotros preparamos la IPA ligera."
    @Published var transcript = ""
    @Published var activity=BuildActivity()
    @Published var startedAt:Date?
    @Published var lastOutputAt:Date?
    @Published var logURL:URL?
    @Published var previous:PreviousPreparation?
    @Published var output: URL?
    @Published var assets: URL?
    @Published var failed = false
    @Published var showDetails = false
    @Published var showCatalog = false
    @Published var showAnalysis = false
    @Published var showSaves = false
    @Published var showSideload = false
    @Published var showDeviceLibrary = false
    @Published var installerReady = false
    @Published var installingInline=false
    @Published var buildDockDismissed=false
    func dismissBuildDock() {if !running {buildDockDismissed=true}}
    @Published var catalog: [CatalogGame] = []
    @Published var catalogFailed = false
    private var process: Process?
    private var cancelled = false
    let repo: URL
    let defaults:UserDefaults
    init(defaults:UserDefaults = .standard,sourceRepo:URL?=nil) {
        self.defaults=defaults
        language=EasyLanguage.load(defaults:defaults)
        let configured=Bundle.main.object(forInfoDictionaryKey:"NxNativeSource") as? String ?? ""
        repo=sourceRepo ?? URL(fileURLWithPath:configured)
        splitIOS=defaults.object(forKey:"iosSplitGameData") as? Bool ?? true
        refreshCatalog()
        if let path=defaults.string(forKey:"keysDirectory"), FileManager.default.fileExists(atPath:path+"/prod.keys") {
            keysFolder=URL(fileURLWithPath:path)
        }
        if let path = defaults.string(forKey:"lastGameFolder"), FileManager.default.fileExists(atPath:path) {
            folder=URL(fileURLWithPath:path)
            inspectFiles();restoreOutput()
        }
    }
    var gameName: String { folder?.lastPathComponent ?? text("Ningún juego seleccionado") }
    private func refreshCatalog() {
        do {catalog=try GameCatalog.load(repo:repo);catalogFailed=false}
        catch {catalog=[];catalogFailed=true}
    }
    func cancelInspection() {
        inspectionGeneration=UUID()
        if let task=inspectionProcess,task.isRunning {if kill(-task.processIdentifier,SIGTERM) != 0 {task.terminate()}}
        inspectionProcess=nil;inspecting=false
    }
    func identifyGame(setupTools:Bool=false) {
        cancelInspection();inspection=nil;inspectionData=nil
        guard let folder,readableKeys,!detectedFiles.isEmpty else {return}
        let script=repo.appendingPathComponent("scripts/inspect_game.py")
        guard FileManager.default.fileExists(atPath:script.path),let keysFolder else {return}
        let generation=inspectionGeneration,task=Process(),pipe=Pipe()
        task.executableURL=URL(fileURLWithPath:"/usr/bin/python3")
        task.arguments=[repo.appendingPathComponent("desktop/NxNativeEasy/build_session.py").path,script.path,folder.path,"--keys",keysFolder.appendingPathComponent("prod.keys").path]+(setupTools ? ["--setup-tools"] : [])
        task.standardOutput=pipe;task.standardError=FileHandle.nullDevice
        var env=ProcessInfo.processInfo.environment
        env.removeValue(forKey:"NXE_BUILD_LOG");env.removeValue(forKey:"NXE_GAME_DIR")
        task.environment=env
        do {try task.run();inspectionProcess=task;inspecting=true}
        catch {inspection=try? JSONDecoder().decode(PackageInspection.self,from:Data("{\"schema\":1,\"status\":\"metadata_unreadable\"}".utf8));return}
        DispatchQueue.global(qos:.userInitiated).async { [weak self] in
            let data=try? pipe.fileHandleForReading.readToEnd()
            task.waitUntilExit()
            Task {@MainActor in
                guard let self,self.inspectionGeneration==generation else {return}
                self.inspectionProcess=nil;self.inspecting=false
                if let data,data.count<=1048576,let result=try? JSONDecoder().decode(PackageInspection.self,from:data),result.schema==1 {self.inspection=result;self.inspectionData=data}
                else {self.inspection=try? JSONDecoder().decode(PackageInspection.self,from:Data("{\"schema\":1,\"status\":\"metadata_unreadable\"}".utf8))}
            }
        }
    }
    func openCatalog() {
        refreshCatalog()
        showCatalog=true
    }
    @discardableResult func chooseFolder()->Bool {
        let panel=NSOpenPanel();panel.canChooseDirectories=true;panel.canChooseFiles=false
        panel.allowsMultipleSelection=false;panel.prompt=text("Elegir juego")
        panel.message=text("Selecciona la carpeta con el juego base y sus actualizaciones NSP/XCI.")
        guard panel.runModal() == .OK, let url=panel.url else { return false }
        return acceptFolder(url)
    }
    @discardableResult func acceptFolder(_ url:URL)->Bool {
        guard !running else {return false}
        let url=url.resolvingSymlinksInPath().standardizedFileURL
        let root=repo.resolvingSymlinksInPath().standardizedFileURL
        do {
            let files=try FileManager.default.contentsOfDirectory(at:url,includingPropertiesForKeys:nil)
            guard files.contains(where:{["nsp","xci","nsz","xcz"].contains($0.pathExtension.lowercased())}) else {
                output=nil;assets=nil;phase="No encontramos el juego en esa carpeta."
                detail="Elige la carpeta que contiene los archivos NSP o XCI directamente."
                failed=true;return false
            }
            guard !url.path.hasPrefix(root.path+"/"), url.path != root.path else {
                phase="Guarda el juego fuera del repositorio.";detail="Así tus juegos y llaves se quedan fuera de GitHub.";failed=true;return false
            }
            folder=url;defaults.set(url.path,forKey:"lastGameFolder")
            phase="Listo para preparar el juego.";detail="Un clic más. Los archivos anteriores se conservan."
            failed=false;output=nil;assets=nil;transcript="";inspectFiles();restoreOutput();return true
        } catch { phase="No pudimos leer esa carpeta.";detail=error.localizedDescription;failed=true;return false }
    }
    func chooseKeysFolder() {
        let panel=NSOpenPanel();panel.canChooseDirectories=false;panel.canChooseFiles=true
        panel.allowsMultipleSelection=false;panel.prompt=text("Usar mis llaves")
        panel.message=text("Selecciona el archivo prod.keys de tu Mac.")
        guard panel.runModal() == .OK, let url=panel.url else {return}
        _=acceptKeysFile(url)
    }
    @discardableResult func acceptKeysFile(_ url:URL)->Bool {
        guard !running else {return false}
        let key=url.resolvingSymlinksInPath().standardizedFileURL
        let root=repo.resolvingSymlinksInPath().standardizedFileURL
        guard key.lastPathComponent=="prod.keys",!key.path.hasPrefix(root.path+"/"),
              let values=try? key.resourceValues(forKeys:[.isRegularFileKey,.isReadableKey,.fileSizeKey]),
              values.isRegularFile==true,values.isReadable==true,(values.fileSize ?? 0)>0 else {
            failed=true;phase="Selecciona un archivo prod.keys legible y no vacío, fuera del repositorio."
            detail="No se proporcionan llaves. Debes seleccionar las tuyas.";return false
        }
        keysFolder=key.deletingLastPathComponent();defaults.set(keysFolder!.path,forKey:"keysDirectory")
        failed=false;phase="Tus llaves están seleccionadas.";detail="Sólo guardamos la ruta en este Mac, nunca su contenido."
        return true
    }
    func restoreOutput() {
        previous=folder.flatMap {PreviousPreparation.load(folder:$0,target:target)}
        if isMac {
            guard let folder,
                  let data=try? Data(contentsOf:folder.appendingPathComponent("nxnative-mac.json")),
                  let record=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],
                  let path=record["app_path"] as? String,
                  FileManager.default.fileExists(atPath:path+"/Contents/MacOS/dmhost") else {return}
            output=URL(fileURLWithPath:path);return
        }
        guard target == "ios", let folder,
              let data=try? Data(contentsOf:folder.appendingPathComponent("nxnative-ios.json")),
              let record=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],
              let prepared=IOSPackageOutput.load(record:record,split:splitIOS) else {return}
        output=prepared.ipa;assets=prepared.romfs
    }

    func build() {
        guard let folder, !running, !inspecting,inspection?.ready==true,!target.isEmpty else {return}
        let script=repo.appendingPathComponent("scripts/prepare_ios.sh")
        guard FileManager.default.fileExists(atPath:script.path) else {
            phase="No encontramos el código de nxnative.";detail="Vuelve a crear la app desde el repositorio con Abrir-interfaz.command.";failed=true;return
        }
        if !readableKeys {chooseKeysFolder()}
        guard readableKeys,let keysFolder else {return}
        let task=Process();let pipe=Pipe()
        task.executableURL=URL(fileURLWithPath:"/usr/bin/python3")
        var arguments=[repo.appendingPathComponent("desktop/NxNativeEasy/build_session.py").path,script.path,"--target",target,folder.path]
        guard let inspectionData else {return}
        let manifest=FileManager.default.temporaryDirectory.appendingPathComponent("nxnative-inspection-"+UUID().uuidString+".json")
        do {try inspectionData.write(to:manifest,options:.atomic);inspectionManifest=manifest}
        catch {failed=true;phase="No pudimos guardar la comprobación del juego.";return}
        arguments += ["--keys-folder",keysFolder.path,"--package-metadata",manifest.path]
        if target=="ios" && !splitIOS {arguments.append("--full-only")}
        task.arguments=arguments;task.currentDirectoryURL=repo
        task.standardOutput=pipe;task.standardError=pipe
        var environment=ProcessInfo.processInfo.environment
        environment["PYTHONUNBUFFERED"]="1"
        environment["NXE_PROGRESS"]="json"
        let log=folder.appendingPathComponent("nxnative-tools/logs/build-"+UUID().uuidString+".log")
        logURL=log;environment["NXE_BUILD_LOG"]=log.path;environment["NXE_GAME_DIR"]=folder.path
        startedAt=Date();lastOutputAt=nil;activity=BuildActivity()
        task.environment=environment
        buildRevision=BuildProvenance.head(repo)
        BuildCompletionNotice.requestIfEnabled(defaults:defaults)
        preparationStep=4
        buildDockDismissed=false;installingInline=false;installerReady=false;running=true;cancelled=false;failed=false;showDetails=true;output=nil;assets=nil;transcript=""
        phase="Preparando herramientas…";detail="Puedes dejar esta ventana abierta. No necesitas usar Terminal."
        pipe.fileHandleForReading.readabilityHandler={ [weak self] handle in
            let data=handle.availableData
            guard !data.isEmpty else { handle.readabilityHandler=nil;return }
            Task { @MainActor in self?.append(data) }
        }
        task.terminationHandler={ [weak self] task in
            let status=task.terminationStatus
            Task { @MainActor in
                guard let self else{return}
                self.activity.finish(logURL:self.logURL);self.activity.complete(exitCode:status,cancelled:self.cancelled);self.transcript=self.activity.transcript
                self.running=false;self.process=nil
                if let manifest=self.inspectionManifest {try? FileManager.default.removeItem(at:manifest);self.inspectionManifest=nil}
                if self.cancelled {
                    self.phase="Preparación cancelada.";self.detail="Tus archivos y partidas anteriores se conservaron."
                } else if status==0 {
                    self.restoreOutput()
                    self.failed=self.output==nil
                    self.installerReady = !self.isMac && self.output != nil
                    self.phase=self.output == nil ? "Terminó, pero no encontramos la app." : (self.isMac ? "Tu juego está listo para Mac." : "Tu juego está listo para instalar en iPhone / iPad.")
                    self.detail=self.output == nil ? "Usa Ver error para revisar lo que ocurrió." : "Pulsa Instalar en iPhone / iPad. Inicia sesión con tu cuenta personal para firmar e instalar el juego y sus datos."
                } else {
                    self.failed=true;self.showDetails=true;self.phase="No pudimos preparar el juego."
                    let log=self.transcript.lowercased()
                    if log.contains("install and open full xcode") {
                        self.detail="Instala Xcode y ábrelo una vez. Después vuelve a intentar."
                    } else if log.contains("install homebrew") {
                        self.detail="Instala Homebrew desde brew.sh y vuelve a intentar."
                    } else if log.contains("ios sdk 26 or newer") {
                        self.detail="Actualiza Xcode: necesitas el SDK de iOS 26 o posterior."
                    } else {
                        self.detail="Tus archivos anteriores se conservaron. Puedes ver o copiar el error para revisarlo."
                    }
                }
                if !self.cancelled {
                    BuildCompletionNotice.post(success:status==0 && !self.failed,game:self.gameName,target:self.isMac ? "Mac" : "iPhone / iPad",text:self.text,defaults:self.defaults)
                }
                if status==0 && self.output != nil {self.preparationStep=5}
            }
        }
        do { process=task;try task.run() }
        catch { if let manifest=inspectionManifest {try? FileManager.default.removeItem(at:manifest);inspectionManifest=nil};running=false;process=nil;failed=true;phase="No pudimos iniciar la preparación.";detail=error.localizedDescription }
    }
    func append(_ data:Data) {
        guard running else {return}
        activity.receive(data);transcript=activity.transcript;lastOutputAt=Date()
        let lower=activity.stage.lowercased()
        if lower.contains("pack") || lower.contains("export") {phase=isMac ? "Compilando la app para Mac…" : "Creando tu IPA ligera…"}
        else if lower.contains("app") || lower.contains("host") {phase=isMac ? "Compilando la app para Mac…" : "Compilando la app para iPhone…"}
        else if lower.contains("shader") {phase="Preparando los gráficos del juego…"}
        else if lower.contains("extract") {phase="Preparando los archivos del juego…"}
    }
    func copyDiagnostics() {
        let report=BuildDiagnostics.report(version:Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "development",system:ProcessInfo.processInfo.operatingSystemVersionString+" · "+(ProcessInfo.processInfo.environment["HOSTTYPE"] ?? "Apple silicon"),revision:BuildProvenance.head(repo),target:target,stage:activity.stage,log:transcript)
        NSPasteboard.general.clearContents();NSPasteboard.general.setString(report,forType:.string)
    }
    func acceptDrop(_ urls:[URL]) {
        guard !running else {return}
        let fm=FileManager.default
        let files=urls.filter{$0.isFileURL}
        if files.count==1,let item=files.first,item.lastPathComponent=="prod.keys" {
            if acceptKeysFile(item) {preparationStep=target.isEmpty ? 0 : 2};return
        }
        var folders=Set<URL>()
        for file in files {
            var directory:ObjCBool=false
            guard fm.fileExists(atPath:file.path,isDirectory:&directory) else {continue}
            if directory.boolValue {folders.insert(file.resolvingSymlinksInPath())}
            else if ["nsp","xci","nsz","xcz"].contains(file.pathExtension.lowercased()) {folders.insert(file.deletingLastPathComponent().resolvingSymlinksInPath())}
        }
        guard folders.count==1,let folder=folders.first else {failed=true;phase="Arrastra los archivos de un solo juego desde la misma carpeta.";return}
        if acceptFolder(folder) {if !target.isEmpty {preparationStep=1}}
    }
    func revealLog() {if let logURL {NSWorkspace.shared.activateFileViewerSelecting([logURL])}}
    func revealCompilerLogs() {
        guard let folder else {return}
        let paths=((try? FileManager.default.contentsOfDirectory(at:folder,includingPropertiesForKeys:nil)) ?? [])
            .filter {$0.lastPathComponent.range(of:"^[0-9A-Fa-f]{16}_build$",options:.regularExpression) != nil}
            .map {$0.appendingPathComponent("logs")}.filter {FileManager.default.fileExists(atPath:$0.path)}
        NSWorkspace.shared.activateFileViewerSelecting(paths.isEmpty ? [folder] : paths)
    }
    func cancel() {
        cancelInspection()
        guard let process,process.isRunning else{return}
        cancelled=true
        if kill(-process.processIdentifier,SIGTERM) != 0 {process.terminate()}
        phase="Cancelando…"
    }
    func openMacGame() {if let output, isMac {NSWorkspace.shared.open(output)}}
    func revealIPA() {if let output {NSWorkspace.shared.activateFileViewerSelecting([output])}}
    func revealAssets() {if let assets {NSWorkspace.shared.activateFileViewerSelecting([assets])}}
    var sideloadlyURL: URL? {NSWorkspace.shared.urlForApplication(withBundleIdentifier:"io.sideloadly.sideloadly")}
    func openSideloadly() {
        if let app=sideloadlyURL, let output {
            NSWorkspace.shared.open([output],withApplicationAt:app,configuration:NSWorkspace.OpenConfiguration())
        } else {NSWorkspace.shared.open(URL(string:"https://sideloadly.io")!)}
    }
}

@MainActor enum GameArtworkCache {
    static var images: [URL:NSImage] = [:]
    static func image(_ url:URL?) -> NSImage? {
        guard let url else {return nil}
        if let image=images[url] {return image}
        guard let image=NSImage(contentsOf:url) else {return nil}
        images[url]=image;return image
    }
}

struct GameArtworkView: View {
    let game: CatalogGame
    var body: some View {
        GeometryReader { geometry in
            if let image=GameArtworkCache.image(game.artworkURL) {
                Image(nsImage:image).resizable().scaledToFill()
                    .frame(width:geometry.size.width,height:geometry.size.height).clipped()
            } else {Color.white.opacity(0.05)}
        }.accessibilityLabel(game.name)
    }
}

struct SupportCarousel: View {
    let games: [CatalogGame]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var started = Date()
    @State private var pausedAt: Date?

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval:1.0 / 30.0,paused:pausedAt != nil || reduceMotion)) { context in
                let width = CGFloat(games.count) * 177
                let elapsed = max(0,(pausedAt ?? context.date).timeIntervalSince(started))
                let offset = width > 0 && !reduceMotion ? CGFloat(elapsed * 22).truncatingRemainder(dividingBy:width) : 0
                HStack(spacing:12) {
                    ForEach(0..<2,id:\.self) { copy in
                        ForEach(Array(games.enumerated()),id:\.element.id) { index, game in
                            VStack(alignment:.leading,spacing:7) {
                                GameArtworkView(game:game).frame(height:92).clipShape(RoundedRectangle(cornerRadius:12))
                                Text(game.name).font(.system(size:11,weight:.medium))
                                    .foregroundStyle(Color(red:0.91,green:0.93,blue:0.88))
                                    .lineLimit(2).frame(height:30,alignment:.topLeading)
                            }.frame(width:165).accessibilityHidden(copy == 1)
                        }
                    }
                }.offset(x:-offset).frame(width:geometry.size.width,alignment:.leading)
            }
        }.frame(height:129).clipped()
        .accessibilityElement(children:.ignore)
        .accessibilityLabel(games.map(\.name).joined(separator:", "))
        .onHover { hovering in
            if hovering { pausedAt = Date() }
            else if let pause = pausedAt {
                started = started.addingTimeInterval(Date().timeIntervalSince(pause))
                pausedAt = nil
            }
        }
    }
}

// Apply the compact launch height even when macOS restores an older window size.
struct CompactWindow: NSViewRepresentable {
    let height: CGFloat
    func makeNSView(context:Context) -> NSView {let view=WindowView();view.height=height;return view}
    func updateNSView(_ nsView:NSView,context:Context) {(nsView as? WindowView)?.height=height}
    private final class WindowView: NSView {
        var height: CGFloat=650 {didSet {if height != oldValue {resize()}}}
        private var lastHeight: CGFloat?
        override func viewDidMoveToWindow() {super.viewDidMoveToWindow();resize()}
        private func resize() {
            guard let window=window, lastHeight != height else {return}
            let target=height;lastHeight=target
            DispatchQueue.main.async {
                guard !window.styleMask.contains(.fullScreen) else {return}
                window.setContentSize(NSSize(width:max(760,window.contentLayoutRect.width),height:target))
            }
        }
    }
}

enum AppArtwork {
    static let icon: NSImage = {
        guard let url=Bundle.main.url(forResource:"BrandIcon",withExtension:"png"),
              let image=NSImage(contentsOf:url) else {return NSImage(size:NSSize(width:32,height:32))}
        return image
    }()
}

struct ContentView: View {
    @ObservedObject var updater: AppUpdater
    @ObservedObject var sideload:SideloadModel
    @ObservedObject var model:BuildModel
    private let ink=EasyDesign.ink
    private let lime=EasyDesign.accent
    var body: some View {
        ZStack {
            Color(red:0.065,green:0.075,blue:0.07).ignoresSafeArea()
            if model.installingInline {
                SideloadView(model:sideload,text:model.text,embedded:true,guided:true,gameName:model.inspection?.name,onReturn:{model.installingInline=false})
            } else {
            ScrollView {
                VStack(alignment:.leading,spacing:22) {
                    if updater.visible {
                        VStack(alignment:.leading,spacing:10) {
                            HStack(alignment:.top) {
                                VStack(alignment:.leading,spacing:4) {
                                    Text(model.text(updater.busy ? updater.phaseText : updater.error ?? "Hay una nueva versión")+(updater.busy || updater.error != nil ? "" : " "+(updater.available?.version ?? "")))
                                        .font(.system(size:14,weight:.semibold))
                                    if !updater.busy && updater.error == nil {
                                        Text(model.text("Actualiza la app y sus perfiles de juegos."))
                                            .font(.system(size:12)).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if !updater.busy {
                                    if updater.available != nil {
                                        Button(model.text(updater.error == nil ? "Actualizar ahora" : "Intentar de nuevo")){updater.start()}
                                            .disabled(model.running || updater.busy || sideload.busy).accessibilityIdentifier("install-update")
                                    } else {
                                        Button(model.text("Intentar de nuevo")){Task {await updater.check(manual:true)}}
                                    }
                                    if updater.error != nil {Button(model.text("Cerrar")){updater.dismissError()}}
                                }
                            }
                            if updater.busy {
                                if let progress=updater.progress {ProgressView(value:progress).tint(lime)}
                                else {ProgressView().progressViewStyle(.linear).tint(lime)}
                            }
                        }.padding(16).background(lime.opacity(0.07),in:RoundedRectangle(cornerRadius:12))
                    }
                    if sideload.showsRefreshNotice {
                        HStack {
                            Text(model.text(sideload.error ?? sideload.phase)).font(.system(size:12)).textSelection(.enabled)
                            Spacer()
                            if !sideload.busy {Button(model.text("Revisar renovación")){model.showDeviceLibrary=true}}
                        }.padding(14).background(Color.orange.opacity(0.08),in:RoundedRectangle(cornerRadius:12))
                    }
                    VStack(alignment:.leading,spacing:12) {
                        HStack {
                            Text(model.text(["¿Dónde quieres jugar?","Añade tu juego","Tus llaves, en tu Mac","Todo listo para preparar","Creando tu juego","Tu juego está preparado"][min(5,model.preparationStep)])).font(.system(size:32,weight:.bold,design:.rounded)).foregroundStyle(ink)
                            Spacer()
                            if model.preparationStep>0 && model.preparationStep<4 {Button(model.text("Atrás")){model.preparationStep-=1}.disabled(model.running || sideload.busy || updater.busy)}
                        }
                        HStack(spacing:6) {
                            ForEach(0..<5) {step in Capsule().fill(step<=model.preparationStep ? lime : .white.opacity(0.08)).frame(height:4)}
                        }
                        Text(model.text(["Elige el dispositivo. Te guiamos con el resto.","Elige su carpeta o arrastra tus archivos aquí. No los moveremos.","Selecciona tu prod.keys. Sólo recordamos su ubicación.","Revisa el destino antes de empezar. Conservamos tus originales y partidas.","Sigue cada etapa y abre el registro en vivo cuando quieras.","La preparación terminó. El siguiente paso depende de tu dispositivo."][min(5,model.preparationStep)])).foregroundStyle(.secondary)
                    }
                    PreparationIllustration(step:model.preparationStep,isMac:model.isMac,text:model.text)
                    VStack(alignment:.leading,spacing:18) {
                        if model.preparationStep==0 {
                        HStack(spacing:16) {
                            ForEach(["ios","mac"],id:\.self) { target in
                                Button {model.target=target} label: {
                                    VStack(spacing:16) {Image(systemName:target=="ios" ? "ipad.and.iphone" : "desktopcomputer").font(.system(size:46,weight:.light));Text(target == "ios" ? "iPhone / iPad" : "Mac").font(.title2.bold());Text(model.text(target=="ios" ? "Prepara la IPA y te guiamos para instalarla." : "Una app completa. Preparar y jugar en este Mac.")).font(.callout).multilineTextAlignment(.center)}.frame(maxWidth:.infinity,minHeight:200).padding(20)
                                        .foregroundStyle(model.target == target ? Color.black : ink)
                                        .background(model.target == target ? lime : Color.white.opacity(0.06),in:RoundedRectangle(cornerRadius:9))
                                }.buttonStyle(.plain).disabled(model.running || updater.busy || sideload.busy).accessibilityIdentifier("target-"+target)
                            }
                        }
                        Button(model.text("Continuar")){model.preparationStep=1}.buttonStyle(LibraryPrimaryButtonStyle()).disabled(model.target.isEmpty || model.running || sideload.busy || updater.busy)
                        }
                        if model.preparationStep==1 {
                        HStack(spacing:12) {
                            Image(systemName:"folder.fill").font(.system(size:24)).foregroundStyle(lime)
                            VStack(alignment:.leading,spacing:4) {
                                Text(model.folder == nil ? model.text("Carpeta de tu juego") : model.gameName)
                                    .font(.system(size:16,weight:.semibold)).foregroundStyle(ink)
                                if model.folder == nil {
                                    Text(model.text("Con el juego base y sus actualizaciones.")).font(.system(size:12)).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button(model.folder == nil ? model.text("Elegir") : model.text("Cambiar")) {model.chooseFolder()}.disabled(model.running || updater.busy || sideload.busy).accessibilityLabel(model.text("Carpeta de tu juego"))
                        }
                        PackageIdentityView(inspection:model.inspection,inspecting:model.inspecting,hasKeys:model.readableKeys,catalog:model.catalog,text:model.text,chooseKeys:{model.chooseKeysFolder()},retry:{model.identifyGame()},setup:{model.identifyGame(setupTools:true)},cancel:{model.cancelInspection()})
                        if model.inspection?.ready==true {
                            DisclosureGroup(model.text("Ver archivos detectados")) {PreparationInventory(files:model.detectedFiles,text:model.text)}.font(.callout).foregroundStyle(.secondary)
                        } else {PreparationInventory(files:model.detectedFiles,text:model.text)}
                        Button(model.text("Continuar")){model.preparationStep=model.readableKeys ? 3 : 2}.buttonStyle(LibraryPrimaryButtonStyle()).disabled(model.inspecting || model.inspection?.ready != true || model.failed || model.folder==nil || (model.detectedFiles.isEmpty || model.detectedFiles.contains(where:{!$0.readable})) || model.running || sideload.busy || updater.busy)
                        }
                        if model.preparationStep==2 {
                        HStack(spacing:12) {
                            Image(systemName:"key.horizontal").font(.system(size:19)).foregroundStyle(lime).frame(width:24)
                            VStack(alignment:.leading,spacing:4) {
                                Text("prod.keys").font(.system(size:14,weight:.medium))
                                Text(model.readableKeys ? model.text("Archivo detectado · listo para la preparación") : model.text("Selecciona tus propias prod.keys."))
                                    .font(.system(size:12)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(model.keysFolder == nil ? model.text("Elegir") : model.text("Cambiar")) {model.chooseKeysFolder()}.disabled(model.running || updater.busy || sideload.busy).accessibilityLabel(model.text("Seleccionar prod.keys"))
                        }
                        Label(model.text(model.readableKeys ? "Recordamos su ubicación. La compatibilidad de las llaves se comprueba al preparar." : "Elige prod.keys o arrástralo aquí. No necesitas seleccionar una carpeta."),systemImage:model.readableKeys ? "checkmark.shield" : "hand.draw").font(.callout).foregroundStyle(.secondary)
                        if model.folder != nil {PackageIdentityView(inspection:model.inspection,inspecting:model.inspecting,hasKeys:model.readableKeys,catalog:model.catalog,text:model.text,chooseKeys:{model.chooseKeysFolder()},retry:{model.identifyGame()},setup:{model.identifyGame(setupTools:true)},cancel:{model.cancelInspection()})}
                        Button(model.text("Continuar")){model.preparationStep=3}.buttonStyle(LibraryPrimaryButtonStyle()).disabled(model.inspecting || model.inspection?.ready != true || model.failed || !model.readableKeys || model.running || sideload.busy || updater.busy)
                        }
                        if model.preparationStep==3 {
                            Label(model.isMac ? "Mac" : "iPhone / iPad",systemImage:model.isMac ? "desktopcomputer" : "ipad.and.iphone").font(.title2.bold())
                            Text(model.inspection?.name ?? model.gameName).font(.headline)
                            if let version=model.inspection?.display_version {Label(model.text("Versión a preparar")+": "+version,systemImage:"tag")}
                            Label(model.text("Llaves seleccionadas"),systemImage:"key.horizontal").foregroundStyle(.secondary)
                        }
                        if model.target=="ios" && model.preparationStep==3 {
                            Toggle(model.text("IPA ligera: separar los datos del juego"),isOn:$model.splitIOS).disabled(model.running || updater.busy || sideload.busy)
                            Text(model.text(model.splitIOS ? "Recomendado: la app pesa menos y el instalador copia romfs por separado." : "IPA completa: incluye el juego dentro. Ocupa más y cada renovación vuelve a transferir toda la app.")).font(.caption).foregroundStyle(.secondary)
                            Label(model.text("Carpeta y llaves → Preparar → Cuenta Apple → Instalar y copiar datos"),systemImage:"arrow.right.circle").font(.caption).foregroundStyle(.secondary)
                        }
                        if model.running {
                            Divider().overlay(Color.white.opacity(0.08))
                            HStack {
                                Text(model.text(model.phase)).font(.system(size:14,weight:.medium))
                                Spacer()
                                Button(model.text("Cancelar")){model.cancel()}
                            }
                            if let fraction=model.activity.fraction {ProgressView(value:fraction).tint(lime)}
                            else {ProgressView().progressViewStyle(.linear).tint(lime)}
                            if !model.activity.stage.isEmpty {
                                Text((model.activity.stages>0 ? "\(model.activity.stageNumber)/\(model.activity.stages) · " : "")+model.activity.stage+(model.activity.step.isEmpty ? "" : " · "+model.activity.step))
                                    .font(.system(size:12)).foregroundStyle(.secondary)
                            }
                            if !model.activity.count.isEmpty {Text(model.activity.count).font(.system(size:12,design:.monospaced))}
                            TimelineView(.periodic(from:.now,by:1)) {context in
                                let elapsed=Int(context.date.timeIntervalSince(model.startedAt ?? context.date))
                                let quiet=Int(context.date.timeIntervalSince(model.lastOutputAt ?? model.startedAt ?? context.date))
                                Text(model.text("Tiempo transcurrido")+String(format:" %d:%02d",max(0,elapsed)/60,max(0,elapsed)%60)+(quiet>=15 ? " · "+model.text("Sin salida nueva; el proceso sigue activo.") : ""))
                                    .font(.system(size:11)).foregroundStyle(.secondary)
                            }
                            if !model.activity.latest.isEmpty {Text(model.activity.latest).font(.system(size:11,design:.monospaced)).lineLimit(2).textSelection(.enabled)}
                            else if model.activity.stage.isEmpty {Text(model.text("Esperando la primera salida del compilador…")).font(.caption).foregroundStyle(.secondary)}
                        } else if model.failed {
                            Text(model.text(model.phase)).font(.system(size:14,weight:.semibold)).foregroundStyle(.orange)
                            Text(model.text(model.detail)).font(.system(size:12)).foregroundStyle(.secondary)
                        }
                        if model.previous != nil && !model.running && model.preparationStep==3 {
                            Label(model.text("Ya preparaste este juego antes"),systemImage:"arrow.triangle.2.circlepath").font(.system(size:13,weight:.medium))
                            if let version=model.previous?.version {Text(model.text("Versión anterior")+": "+version).font(.system(size:12)).foregroundStyle(.secondary)}
                            Text(model.text(model.isMac ? "Crearás una app nueva. Tus partidas siguen en este Mac, fuera de la app. Cierra el juego antes de abrir la versión nueva." : "Crearás una IPA para actualizar tu app. En Instalar en iPhone / iPad, elige la app existente y su misma cuenta. No desinstales el juego. La preparación no comprueba qué está instalado en tu iPhone."))
                                .font(.system(size:12)).foregroundStyle(.secondary)
                        }
                        if !model.running && model.preparationStep==3 {
                            Button {model.build()} label: {
                                HStack {
                                    Text(model.text(model.failed ? "Intentar de nuevo" : (model.previous == nil ? "Preparar juego" : "Preparar actualización")))
                                    Spacer()
                                    Image(systemName:"arrow.right")
                                }.font(.system(size:15,weight:.bold)).padding(15).foregroundStyle(Color.black)
                                    .background(model.folder == nil || model.target.isEmpty ? Color.gray : lime,in:RoundedRectangle(cornerRadius:10))
                            }.buttonStyle(.plain).disabled(model.folder == nil || model.target.isEmpty || updater.busy || sideload.busy)
                        }
                        if model.output != nil && model.preparationStep==3 {Button(model.text("Usar la preparación existente")){model.preparationStep=5}.disabled(sideload.busy || updater.busy)}
                        if model.failed && model.preparationStep==4 {Button(model.text("Revisar e intentar de nuevo")){model.preparationStep=3}.disabled(model.running)}
                        if model.preparationStep==4 && model.activity.eta==nil {Text(model.text("Esta etapa todavía no informa cuánto falta. Mostramos el avance real y el tiempo transcurrido.")).font(.caption).foregroundStyle(.secondary)}
                        if let eta=model.activity.eta,model.running {Text(model.text("Tiempo restante de esta etapa")+": ~"+String(Int(eta))+" s").font(.callout).monospacedDigit()}
                    }.padding(22).background(Color.white.opacity(0.045),in:RoundedRectangle(cornerRadius:16))
                    if model.output != nil && !model.running && !model.failed && model.preparationStep==5 {
                        VStack(alignment:.leading,spacing:16) {
                            if model.isMac {
                                Label(model.text("Listo. Juega en tu Mac."),systemImage:"checkmark.circle.fill")
                                    .font(.system(size:20,weight:.semibold)).foregroundStyle(lime)
                                HStack {
                                    Button(model.text("Abrir juego")){model.openMacGame()}
                                        .buttonStyle(.borderedProminent).tint(lime).foregroundStyle(.black)
                                    Button(model.text("Mostrar app")){model.revealIPA()}
                                }
                                Text(model.text("Todo el juego va dentro de la app. No necesitas copiar carpetas."))
                                    .font(.system(size:12)).foregroundStyle(.secondary)
                                Text(model.text("Tus partidas se guardan en este Mac y se conservan al crear otra versión."))
                                    .font(.system(size:12)).foregroundStyle(.secondary)
                            } else {
                            Label(model.text("Listo. Instálalo en tu iPhone / iPad."),systemImage:"checkmark.circle.fill")
                                .font(.system(size:20,weight:.semibold)).foregroundStyle(lime)
                            Text(model.text("Instala y copia los datos desde aquí con tu cuenta personal, o usa Sideloadly como alternativa."))
                                .font(.system(size:13))
                            Button(model.text("Instalar en iPhone / iPad")){if let ipa=model.output,let folder=model.folder {sideload.configure(ipa:ipa,folder:folder,romfs:model.assets);model.installingInline=true}}
                                .disabled(updater.busy || sideload.busy).buttonStyle(.borderedProminent).tint(lime).foregroundStyle(.black)
                            DisclosureGroup(model.text("Alternativa: Sideloadly")) {
                                VStack(alignment:.leading,spacing:10) {
                                    HStack {
                                        Button(model.text("Usar Sideloadly")){model.openSideloadly()}
                                        Button(model.text("Mostrar IPA")){model.revealIPA()}
                                    }
                                    Text(model.text("2. Copia el nuevo romfs por Finder → iPhone → Archivos → tu juego. Reemplaza sólo romfs; conserva save y save_device.")).font(.system(size:12))
                                    Button(model.text("Mostrar datos del juego")){model.revealAssets()}
                                    Text(model.text("Para actualizar: misma cuenta e identificador de Sideloadly. Instala encima, sin desinstalar.")).font(.system(size:11)).foregroundStyle(.secondary)
                                }.padding(.top,8)
                            }.font(.system(size:12))
                            }
                            Button(model.text("Tus partidas")){model.showSaves=true}
                            Button(model.text(model.previous == nil ? "Preparar de nuevo" : "Preparar actualización")){model.preparationStep=3}.buttonStyle(.link).disabled(updater.busy || sideload.busy)
                        }.padding(22).frame(maxWidth:.infinity,alignment:.leading)
                            .background(lime.opacity(0.045),in:RoundedRectangle(cornerRadius:16))
                    }
                    if !model.activity.history.isEmpty && model.preparationStep>=4 {BuildTimeline(activity:model.activity,text:model.text)}
                    if model.failed && model.preparationStep<4 {Text(model.text(model.phase)).foregroundStyle(.orange)}
                    if (!model.transcript.isEmpty || model.running) && model.preparationStep>=4 {
                        DisclosureGroup(model.text(model.failed ? "Ver error" : "Ver compilación en vivo"),isExpanded:$model.showDetails) {
                            VStack(alignment:.leading,spacing:10) {
                                ScrollViewReader {proxy in
                                    ScrollView {Text(model.transcript).font(.system(size:10,design:.monospaced)).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading);Color.clear.frame(height:1).id("log-bottom")}
                                        .frame(height:150).onChange(of:model.transcript) {_,_ in if model.running {proxy.scrollTo("log-bottom",anchor:.bottom)}}
                                }
                                if model.logURL != nil {Button(model.text("Mostrar logs guardados")){model.revealLog()}}
                                Button(model.text("Mostrar logs del compilador")){model.revealCompilerLogs()}
                                Button(model.text("Copiar diagnóstico")){model.copyDiagnostics()}
                            }.padding(.top,8)
                        }.font(.system(size:12)).foregroundStyle(.secondary)
                    }
                }.padding(28)
            }
            }
        }.frame(minWidth:760,minHeight:530).preferredColorScheme(.dark)
        .dropDestination(for:URL.self) {items,_ in
            guard !model.installingInline,!model.running,!sideload.busy,!updater.busy else {return false}
            model.acceptDrop(items);return true
        }
        .onReceive(NotificationCenter.default.publisher(for:Notification.Name("nxnative.openAnalysis"))) {_ in if !model.running && !updater.busy {model.showAnalysis=true}}
        .onChange(of:model.target){_,target in if target=="mac" {sideload.cancelPendingUpdate()}}
        .sheet(isPresented:$model.showSaves) {SavesHelpView(folder:model.folder,isMac:model.isMac,text:model.text,language:model.language)}
        .onChange(of:model.installerReady) {_,ready in
            if ready,let ipa=model.output,let folder=model.folder {sideload.configure(ipa:ipa,folder:folder,romfs:model.assets);model.installingInline=true;model.installerReady=false}
        }
        .sheet(isPresented:$model.showSideload) {SideloadView(model:sideload,text:model.text)}
        .sheet(isPresented:$model.showAnalysis) {if let game=model.folder {GameAnalysisView(repo:model.repo,game:game,text:model.text)} else {Text(model.text("Primero selecciona la carpeta de un juego preparado.")).padding(24)}}
        .task {sideload.canRefresh={ !model.running && !updater.busy };await updater.check();sideload.checkRefresh()}
        .onReceive(Timer.publish(every:21600,on:.main,in:.common).autoconnect()) {_ in Task {await updater.check()}}
        .alert(model.text("Ya tienes la versión más reciente."),isPresented:$updater.showNotice) {Button(model.text("Aceptar"),role:.cancel) {}}
        .onReceive(NotificationCenter.default.publisher(for:NSApplication.willTerminateNotification)) {_ in model.cancel()}
    }
}

struct GameCatalogView: View {
    @ObservedObject var model: BuildModel
    @State private var query=""
    @FocusState private var searchFocused: Bool
    private let lime=EasyDesign.accent
    private var results: [CatalogGame] {GameCatalog.search(model.catalog,query:query)}
    var body: some View {
        VStack(alignment:.leading,spacing:18) {
            HStack {
                VStack(alignment:.leading,spacing:5) {
                    Text(model.text("Todos los juegos")).font(.system(size:26,weight:.bold,design:.rounded))
                    HStack(spacing:5) {
                        Text("\(results.count) / \(model.catalog.count)").monospacedDigit()
                        Text(model.text("juegos en la lista"))
                    }.font(.system(size:12)).foregroundStyle(.secondary)
                }
                Spacer()
            }
            Text(model.text("Juegos del repositorio. Consulta cada ficha para ver dispositivos probados y versiones."))
                .font(.system(size:12)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            HStack {
                Image(systemName:"magnifyingglass").foregroundStyle(lime)
                TextField(model.text("Buscar un juego"),text:$query)
                    .textFieldStyle(.plain).focused($searchFocused).accessibilityIdentifier("game-search")
                if !query.isEmpty {Button {query=""} label: {Image(systemName:"xmark.circle.fill")}.buttonStyle(.plain).accessibilityLabel(model.text("Limpiar búsqueda"))}
            }.padding(12).background(Color.white.opacity(0.06),in:RoundedRectangle(cornerRadius:10))
            if model.catalogFailed {
                Text(model.text("No pudimos leer los perfiles. Comprueba que el repositorio siga en su ubicación original."))
                    .foregroundStyle(.orange).frame(maxWidth:.infinity,maxHeight:.infinity)
            } else if results.isEmpty {
                VStack(spacing:8) {
                    Image(systemName:"magnifyingglass").font(.system(size:32)).foregroundStyle(.secondary)
                    Text(model.text("No encontramos juegos con esa búsqueda."))
                }.frame(maxWidth:.infinity,maxHeight:.infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing:8) {
                        ForEach(results) {game in
                            HStack(spacing:12) {
                                GameArtworkView(game:game).frame(width:80,height:45).clipShape(RoundedRectangle(cornerRadius:7))
                                VStack(alignment:.leading,spacing:5) {
                                    Text(game.name).font(.system(size:14,weight:.semibold)).fixedSize(horizontal:false,vertical:true)
                                    if !game.versions.isEmpty {
                                        Text(model.text("Versiones")+": "+game.versions.joined(separator:", "))
                                            .font(.system(size:11)).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Link(model.text("Ficha del juego"),destination:game.notesURL).font(.system(size:12))
                            }.padding(14).background(Color.white.opacity(0.04),in:RoundedRectangle(cornerRadius:12))
                        }
                    }
                }
            }
        }.padding(28).frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading).preferredColorScheme(.dark)
        .onAppear {searchFocused=true}
    }
}


@MainActor final class BuildCompletionNotice:NSObject,UNUserNotificationCenterDelegate {
    static let shared=BuildCompletionNotice()
    static func enabled(_ defaults:UserDefaults)->Bool {defaults.object(forKey:"buildNotifications") as? Bool ?? true}
    static func requestIfEnabled(defaults:UserDefaults) {
        guard enabled(defaults),Bundle.main.bundleIdentifier != nil else {return}
        let center=UNUserNotificationCenter.current();center.delegate=shared
        center.requestAuthorization(options:[.alert,.sound]){_,_ in}
    }
    static func post(success:Bool,game:String,target:String,text:(String)->String,defaults:UserDefaults) {
        guard enabled(defaults),!NSApp.isActive,Bundle.main.bundleIdentifier != nil else {return}
        let content=UNMutableNotificationContent();content.title=text(success ? "Tu juego está preparado" : "La preparación necesita atención")
        content.body=game+" · "+target;content.sound = .default;content.userInfo=["success":success]
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier:"build-"+UUID().uuidString,content:content,trigger:nil))
    }
    nonisolated func userNotificationCenter(_ center:UNUserNotificationCenter,didReceive response:UNNotificationResponse,withCompletionHandler completionHandler:@escaping()->Void) {
        let success=response.notification.request.content.userInfo["success"] as? Bool ?? false
        Task {@MainActor in NSApp.activate(ignoringOtherApps:true);NSApp.windows.first(where:{$0.isVisible})?.makeKeyAndOrderFront(nil);NotificationCenter.default.post(name:Notification.Name(success ? "nxnative.showLibrary" : "nxnative.showBuildActivity"),object:nil)}
        completionHandler()
    }
}

@main struct NxNativeEasyApp: App {
    @NSApplicationDelegateAdaptor(LauncherDelegate.self) private var delegate
    @StateObject private var updater=AppUpdater()
    @StateObject private var model=BuildModel()
    @StateObject private var library=GameLibrary()
    @StateObject private var sideload=SideloadModel()
    @AppStorage("interfaceLanguage") private var appLanguage="en"
    var body: some Scene {
        Window("nxnative Easy",id:"main") {
            LibraryWorkspace(model:model,library:library,updater:updater,sideload:sideload).onAppear {
                NSApplication.shared.applicationIconImage=AppArtwork.icon
                if Bundle.main.bundleIdentifier != nil {UNUserNotificationCenter.current().delegate=BuildCompletionNotice.shared}
            }
        }
            .defaultSize(width:1060,height:700)
            .commands {
                CommandGroup(replacing:.appSettings) {
                    Button(EasyStrings.text("Configuración",language:EasyLanguage(rawValue:appLanguage) ?? .english)) {
                        NotificationCenter.default.post(name:Notification.Name("nxnative.openSettings"),object:nil)
                    }.keyboardShortcut(",",modifiers:.command)
                }
                CommandMenu(EasyStrings.text("Herramientas de análisis",language:EasyLanguage(rawValue:appLanguage) ?? .english)) {
                    Button(EasyStrings.text("Analizar con REA",language:EasyLanguage(rawValue:appLanguage) ?? .english)) {
                        NotificationCenter.default.post(name:Notification.Name("nxnative.openAnalysis"),object:nil)
                    }
                }
                CommandGroup(after:.appInfo) {
                    Button(EasyStrings.text("Buscar actualizaciones…",language:EasyLanguage(rawValue:appLanguage) ?? .english)) {
                        Task {await updater.check(manual:true)}
                    }.disabled(updater.busy || sideload.busy)
                }
            }
    }
}
