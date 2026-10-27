import SwiftUI
import Combine
import AppKit
import Foundation
import Darwin
import UserNotifications

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
    @Published var folder: URL?
    @Published var keysFolder: URL?
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
            restoreOutput()
        }
    }
    var gameName: String { folder?.lastPathComponent ?? text("Ningún juego seleccionado") }
    private func refreshCatalog() {
        do {catalog=try GameCatalog.load(repo:repo);catalogFailed=false}
        catch {catalog=[];catalogFailed=true}
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
            failed=false;output=nil;assets=nil;transcript="";restoreOutput();return true
        } catch { phase="No pudimos leer esa carpeta.";detail=error.localizedDescription;failed=true;return false }
    }
    func chooseKeysFolder() {
        let panel=NSOpenPanel();panel.canChooseDirectories=true;panel.canChooseFiles=false
        panel.allowsMultipleSelection=false;panel.prompt=text("Usar mis llaves")
        panel.message=text("Elige tu carpeta con prod.keys. No copiamos las llaves ni las incluimos en la app.")
        guard panel.runModal() == .OK, let url=panel.url else {return}
        let resolved=url.resolvingSymlinksInPath().standardizedFileURL
        let root=repo.resolvingSymlinksInPath().standardizedFileURL
        let key=resolved.appendingPathComponent("prod.keys")
        guard resolved != root, !resolved.path.hasPrefix(root.path+"/"),
              FileManager.default.isReadableFile(atPath:key.path) else {
            failed=true;phase="Elige una carpeta externa con tu prod.keys.";detail="No se proporcionan llaves. Debes seleccionar las tuyas.";return
        }
        keysFolder=resolved;defaults.set(resolved.path,forKey:"keysDirectory")
        failed=false;phase="Tus llaves están seleccionadas.";detail="Sólo guardamos la ruta en este Mac, nunca su contenido."
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
        guard let folder, !running, !target.isEmpty else {return}
        let script=repo.appendingPathComponent("scripts/prepare_ios.sh")
        guard FileManager.default.fileExists(atPath:script.path) else {
            phase="No encontramos el código de nxnative.";detail="Vuelve a crear la app desde el repositorio con Abrir-interfaz.command.";failed=true;return
        }
        if keysFolder == nil || !FileManager.default.isReadableFile(atPath:keysFolder!.appendingPathComponent("prod.keys").path) {chooseKeysFolder()}
        guard let keysFolder else {return}
        let task=Process();let pipe=Pipe()
        task.executableURL=URL(fileURLWithPath:"/usr/bin/python3")
        var arguments=[repo.appendingPathComponent("desktop/NxNativeEasy/build_session.py").path,script.path,"--target",target,folder.path]
        arguments += ["--keys-folder",keysFolder.path]
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
        installerReady=false;running=true;cancelled=false;failed=false;showDetails=true;output=nil;assets=nil;transcript=""
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
        catch { running=false;process=nil;failed=true;phase="No pudimos iniciar la preparación.";detail=error.localizedDescription }
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
            let folder=item.deletingLastPathComponent().resolvingSymlinksInPath();let root=repo.resolvingSymlinksInPath()
            guard folder != root,!folder.path.hasPrefix(root.path+"/"),fm.isReadableFile(atPath:item.path) else {failed=true;phase="Elige una carpeta externa con tu prod.keys.";return}
            failed=false;keysFolder=folder;defaults.set(folder.path,forKey:"keysDirectory");preparationStep=target.isEmpty ? 0 : 2;return
        }
        var folders=Set<URL>()
        for file in files {
            var directory:ObjCBool=false
            guard fm.fileExists(atPath:file.path,isDirectory:&directory) else {continue}
            if directory.boolValue {folders.insert(file.resolvingSymlinksInPath())}
            else if ["nsp","xci","nsz","xcz"].contains(file.pathExtension.lowercased()) {folders.insert(file.deletingLastPathComponent().resolvingSymlinksInPath())}
        }
        guard folders.count==1,let folder=folders.first else {failed=true;phase="Arrastra los archivos de un solo juego desde la misma carpeta.";return}
        if acceptFolder(folder) {if !target.isEmpty {preparationStep=2}}
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
    @StateObject private var controllerMonitor=ControllerMonitor()
    @State private var showControllerTest=false
    private let ink=Color(red:0.93,green:0.94,blue:0.90)
    private let lime=Color(red:0.79,green:0.95,blue:0.37)
    var body: some View {
        ZStack {
            Color(red:0.065,green:0.075,blue:0.07).ignoresSafeArea()
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
                        if model.isMac {
                        HStack(alignment:.top,spacing:10) {
                            Image(systemName:controllerMonitor.controllers.contains(where:{$0.supported}) ? "checkmark.circle.fill" : "gamecontroller")
                                .foregroundStyle(controllerMonitor.controllers.contains(where:{$0.supported}) ? lime : .gray)
                            VStack(alignment:.leading,spacing:4) {
                                if controllerMonitor.controllers.isEmpty {
                                    Text(model.text("Sin control conectado en este Mac")).font(.system(size:13,weight:.medium))
                                    Text(model.text("Conéctalo por Bluetooth y aparecerá aquí.")).font(.system(size:12)).foregroundStyle(.secondary)
                                } else {
                                    ForEach(controllerMonitor.controllers) { controller in
                                        Text((controller.name.isEmpty ? model.text("Control") : controller.name)+" · "+model.text(controller.supported ? "Listo en este Mac" : "Sin perfil compatible"))
                                            .font(.system(size:13,weight:.medium))
                                    }
                                }
                            }
                            Spacer()
                            Button(model.text("Probar control")){showControllerTest=true}
                                .disabled(model.running || updater.busy || sideload.busy).accessibilityIdentifier("test-controller")
                        }.accessibilityIdentifier("controller-status")
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
                        Text(model.text("También puedes arrastrar NSP, XCI, NSZ o XCZ de una misma carpeta. No copiamos ni modificamos esos archivos.")).font(.callout).foregroundStyle(.secondary)
                        Button(model.text("Continuar")){model.preparationStep=2}.buttonStyle(LibraryPrimaryButtonStyle()).disabled(model.folder==nil || model.running || sideload.busy || updater.busy)
                        }
                        if model.preparationStep==2 {
                        HStack(spacing:12) {
                            Image(systemName:"key.horizontal").font(.system(size:19)).foregroundStyle(lime).frame(width:24)
                            VStack(alignment:.leading,spacing:4) {
                                Text(model.text("Carpeta de llaves")).font(.system(size:14,weight:.medium))
                                Text(model.keysFolder?.lastPathComponent ?? model.text("Selecciona tus propias prod.keys."))
                                    .font(.system(size:12)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(model.keysFolder == nil ? model.text("Elegir") : model.text("Cambiar")) {model.chooseKeysFolder()}.disabled(model.running || updater.busy || sideload.busy).accessibilityLabel(model.text("Carpeta de llaves"))
                        }
                        Button(model.text("Continuar")){model.preparationStep=3}.buttonStyle(LibraryPrimaryButtonStyle()).disabled(model.keysFolder==nil || model.running || sideload.busy || updater.busy)
                        }
                        if model.preparationStep==3 {
                            Label(model.isMac ? "Mac" : "iPhone / iPad",systemImage:model.isMac ? "desktopcomputer" : "ipad.and.iphone").font(.title2.bold())
                            Text(model.gameName).font(.headline)
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
                            Button(model.text("Instalar en iPhone / iPad")){if let ipa=model.output,let folder=model.folder {sideload.configure(ipa:ipa,folder:folder,romfs:model.assets);model.showSideload=true}}
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
        }.frame(minWidth:760,minHeight:530).preferredColorScheme(.dark)
        .dropDestination(for:URL.self) {items,_ in
            guard !model.running,!sideload.busy,!updater.busy else {return false}
            model.acceptDrop(items);return true
        }
        .onReceive(NotificationCenter.default.publisher(for:Notification.Name("nxnative.openAnalysis"))) {_ in if !model.running && !updater.busy {model.showAnalysis=true}}
        .onChange(of:model.target){_,target in if target=="mac" {sideload.cancelPendingUpdate()}}
        .sheet(isPresented:$model.showSaves) {SavesHelpView(folder:model.folder,isMac:model.isMac,text:model.text,language:model.language)}
        .onChange(of:model.installerReady) {_,ready in
            if ready,let ipa=model.output,let folder=model.folder {sideload.configure(ipa:ipa,folder:folder,romfs:model.assets);model.showSideload=true;model.installerReady=false}
        }
        .sheet(isPresented:$model.showSideload) {SideloadView(model:sideload,text:model.text)}
        .sheet(isPresented:$model.showAnalysis) {if let game=model.folder {GameAnalysisView(repo:model.repo,game:game,text:model.text)} else {Text(model.text("Primero selecciona la carpeta de un juego preparado.")).padding(24)}}
        .sheet(isPresented:$model.showCatalog) {GameCatalogView(model:model)}
        .sheet(isPresented:$showControllerTest) {ControllerTestView(text:model.text)}
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
    private let lime=Color(red:0.79,green:0.95,blue:0.37)
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
                Button(model.text("Cerrar")) {model.showCatalog=false}.keyboardShortcut(.cancelAction)
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
        }.padding(26).frame(width:760,height:620).preferredColorScheme(.dark)
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
