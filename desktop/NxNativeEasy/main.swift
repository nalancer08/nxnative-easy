import SwiftUI
import Combine
import AppKit
import Foundation
import Darwin

@MainActor final class BuildModel: ObservableObject {
    @Published var language: EasyLanguage = EasyLanguage.load() {
        didSet {language.save()}
    }
    func text(_ source: String) -> String {EasyStrings.text(source, language:language)}
    @Published var target = "" {
        didSet { output=nil;assets=nil;failed=false;restoreOutput() }
    }
    var isMac: Bool {target == "mac"}
    @Published var folder: URL?
    @Published var keysFolder: URL?
    @Published var running = false
    @Published var phase = "Tu próximo juego empieza aquí."
    @Published var detail = "Elige su carpeta. Nosotros preparamos la IPA ligera."
    @Published var transcript = ""
    @Published var output: URL?
    @Published var assets: URL?
    @Published var failed = false
    @Published var showDetails = false
    @Published var showCatalog = false
    @Published var catalog: [CatalogGame] = []
    @Published var catalogFailed = false
    private var process: Process?
    private var cancelled = false
    let repo: URL
    init() {
        let configured=Bundle.main.object(forInfoDictionaryKey:"NxNativeSource") as? String ?? ""
        repo=URL(fileURLWithPath:configured)
        refreshCatalog()
        if let path=UserDefaults.standard.string(forKey:"keysDirectory"), FileManager.default.fileExists(atPath:path+"/prod.keys") {
            keysFolder=URL(fileURLWithPath:path)
        }
        if let path = UserDefaults.standard.string(forKey:"lastGameFolder"), FileManager.default.fileExists(atPath:path) {
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
    func chooseFolder() {
        let panel=NSOpenPanel();panel.canChooseDirectories=true;panel.canChooseFiles=false
        panel.allowsMultipleSelection=false;panel.prompt=text("Elegir juego")
        panel.message=text("Selecciona la carpeta con el juego base y sus actualizaciones NSP/XCI.")
        guard panel.runModal() == .OK, let url=panel.url else { return }
        do {
            let files=try FileManager.default.contentsOfDirectory(at:url,includingPropertiesForKeys:nil)
            guard files.contains(where:{["nsp","xci","nsz","xcz"].contains($0.pathExtension.lowercased())}) else {
                output=nil;assets=nil;phase="No encontramos el juego en esa carpeta."
                detail="Elige la carpeta que contiene los archivos NSP o XCI directamente."
                failed=true;return
            }
            guard !url.standardizedFileURL.path.hasPrefix(repo.standardizedFileURL.path+"/"), url.standardizedFileURL != repo.standardizedFileURL else {
                phase="Guarda el juego fuera del repositorio.";detail="Así tus juegos y llaves se quedan fuera de GitHub.";failed=true;return
            }
            folder=url;UserDefaults.standard.set(url.path,forKey:"lastGameFolder")
            phase="Listo para preparar el juego.";detail="Un clic más. Los archivos anteriores se conservan."
            failed=false;output=nil;assets=nil;transcript="";restoreOutput()
        } catch { phase="No pudimos leer esa carpeta.";detail=error.localizedDescription;failed=true }
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
        keysFolder=resolved;UserDefaults.standard.set(resolved.path,forKey:"keysDirectory")
        failed=false;phase="Tus llaves están seleccionadas.";detail="Sólo guardamos la ruta en este Mac, nunca su contenido."
    }
    func restoreOutput() {
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
              let path=record["light_dir"] as? String else {return}
        let directory=URL(fileURLWithPath:path)
        if let files=try? FileManager.default.contentsOfDirectory(at:directory,includingPropertiesForKeys:nil),
           let ipa=files.first(where:{$0.pathExtension=="ipa"}) { output=ipa;assets=directory.appendingPathComponent("romfs") }
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
        task.arguments=arguments;task.currentDirectoryURL=repo
        task.standardOutput=pipe;task.standardError=pipe
        var environment=ProcessInfo.processInfo.environment
        environment["PYTHONUNBUFFERED"]="1"
        task.environment=environment
        running=true;cancelled=false;failed=false;showDetails=false;output=nil;assets=nil;transcript=""
        phase="Preparando herramientas…";detail="Puedes dejar esta ventana abierta. No necesitas usar Terminal."
        pipe.fileHandleForReading.readabilityHandler={ [weak self] handle in
            let data=handle.availableData
            guard !data.isEmpty else { handle.readabilityHandler=nil;return }
            let text=String(decoding:data,as:UTF8.self)
            Task { @MainActor in self?.append(text) }
        }
        task.terminationHandler={ [weak self] task in
            let status=task.terminationStatus
            Task { @MainActor in
                guard let self else{return}
                self.running=false;self.process=nil
                if self.cancelled {
                    self.phase="Preparación cancelada.";self.detail="Tus archivos y partidas anteriores se conservaron."
                } else if status==0 {
                    self.restoreOutput()
                    self.failed=self.output==nil
                    self.phase=self.output == nil ? "Terminó, pero no encontramos la app." : (self.isMac ? "Tu juego está listo para Mac." : "Tu juego está listo para Sideloadly.")
                    self.detail=self.output == nil ? "Usa Ver error para revisar lo que ocurrió." : "Abre la IPA y arrástrala a Sideloadly. La firma se hace con tu cuenta personal."
                } else {
                    self.failed=true;self.phase="No pudimos preparar el juego."
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
            }
        }
        do { process=task;try task.run() }
        catch { running=false;process=nil;failed=true;phase="No pudimos iniciar la preparación.";detail=error.localizedDescription }
    }
    func append(_ text:String) {
        transcript += text
        if transcript.count>120000 {transcript=String(transcript.suffix(100000))}
        guard running else {return}
        let lower=text.lowercased()
        if lower.contains("pack ipa") || lower.contains("source ipa:") || lower.contains("procesados") || lower.contains("processed ") {phase="Creando tu IPA ligera…"}
        else if lower.contains("xcodebuild") || lower.contains("building the ipa") {phase=isMac ? "Compilando la app para Mac…" : "Compilando la app para iPhone…"}
        else if lower.contains("shader") {phase="Preparando los gráficos del juego…"}
        else if lower.contains("extract") {phase="Preparando los archivos del juego…"}
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
    @StateObject private var model=BuildModel()
    @StateObject private var controllerMonitor=ControllerMonitor()
    @State private var showControllerTest=false
    private let ink=Color(red:0.93,green:0.94,blue:0.90)
    private let lime=Color(red:0.79,green:0.95,blue:0.37)
    var body: some View {
        ZStack {
            Color(red:0.065,green:0.075,blue:0.07).ignoresSafeArea()
            ScrollView {
                VStack(alignment:.leading,spacing:22) {
                    HStack {
                        HStack(spacing:9) {
                            Image(nsImage:AppArtwork.icon).resizable().interpolation(.high)
                                .frame(width:34,height:34).accessibilityHidden(true)
                            Text("nxnative easy").font(.system(size:15,weight:.semibold)).foregroundStyle(lime)
                        }
                        Spacer()
                        Picker(model.text("Idioma de la interfaz"),selection:$model.language) {
                            Text("English").tag(EasyLanguage.english)
                            Text("Español").tag(EasyLanguage.spanish)
                        }.labelsHidden().frame(width:120).accessibilityIdentifier("interface-language")
                    }
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
                                            .disabled(model.running || updater.busy).accessibilityIdentifier("install-update")
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
                    VStack(alignment:.leading,spacing:6) {
                        Text(model.text("Prepara tu juego.")).font(.system(size:32,weight:.bold,design:.rounded)).foregroundStyle(ink)
                        Text(model.text(model.isMac ? "Creamos una app completa para jugar en tu Mac." : "Elige dónde quieres jugar y añade tus archivos."))
                            .font(.system(size:14)).foregroundStyle(.secondary)
                    }
                    VStack(alignment:.leading,spacing:10) {
                        HStack {
                            Text(model.text("Juegos con soporte en la herramienta"))
                                .font(.system(size:14,weight:.semibold)).foregroundStyle(ink)
                            Spacer()
                            Button {model.openCatalog()} label: {
                                Label(model.text("Ver todos"),systemImage:"magnifyingglass")
                                    .font(.system(size:12,weight:.semibold))
                            }.buttonStyle(.plain).foregroundStyle(lime).accessibilityIdentifier("view-all-games")
                        }
                        Text(model.text("No incluye ni descarga juegos. Debes añadir tus propios archivos."))
                            .font(.system(size:12)).foregroundStyle(.secondary)
                        SupportCarousel(games:model.catalog)
                    }
                    VStack(alignment:.leading,spacing:18) {
                        HStack {
                            Text(model.text("¿Dónde quieres jugar?")).font(.system(size:13,weight:.medium))
                            Spacer()
                            ForEach(["ios","mac"],id:\.self) { target in
                                Button {model.target=target} label: {
                                    Text(target == "ios" ? "iPhone / iPad" : "Mac")
                                        .font(.system(size:13,weight:.semibold)).padding(.horizontal,16).padding(.vertical,9)
                                        .foregroundStyle(model.target == target ? Color.black : ink)
                                        .background(model.target == target ? lime : Color.white.opacity(0.06),in:RoundedRectangle(cornerRadius:9))
                                }.buttonStyle(.plain).disabled(model.running || updater.busy).accessibilityIdentifier("target-"+target)
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
                                .disabled(model.running || updater.busy).accessibilityIdentifier("test-controller")
                        }.accessibilityIdentifier("controller-status")
                        }
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
                            Button(model.folder == nil ? model.text("Elegir") : model.text("Cambiar")) {model.chooseFolder()}.disabled(model.running || updater.busy).accessibilityLabel(model.text("Carpeta de tu juego"))
                        }
                        HStack(spacing:12) {
                            Image(systemName:"key.horizontal").font(.system(size:19)).foregroundStyle(lime).frame(width:24)
                            VStack(alignment:.leading,spacing:4) {
                                Text(model.text("Carpeta de llaves")).font(.system(size:14,weight:.medium))
                                Text(model.keysFolder?.lastPathComponent ?? model.text("Selecciona tus propias prod.keys."))
                                    .font(.system(size:12)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(model.keysFolder == nil ? model.text("Elegir") : model.text("Cambiar")) {model.chooseKeysFolder()}.disabled(model.running || updater.busy).accessibilityLabel(model.text("Carpeta de llaves"))
                        }
                        if model.running {
                            Divider().overlay(Color.white.opacity(0.08))
                            HStack {
                                Text(model.text(model.phase)).font(.system(size:14,weight:.medium))
                                Spacer()
                                Button(model.text("Cancelar")){model.cancel()}
                            }
                            ProgressView().progressViewStyle(.linear).tint(lime)
                        } else if model.failed {
                            Text(model.text(model.phase)).font(.system(size:14,weight:.semibold)).foregroundStyle(.orange)
                            Text(model.text(model.detail)).font(.system(size:12)).foregroundStyle(.secondary)
                        }
                        if !model.running && (model.output == nil || model.failed) {
                            Button {model.build()} label: {
                                HStack {
                                    Text(model.text(model.failed ? "Intentar de nuevo" : "Preparar juego"))
                                    Spacer()
                                    Image(systemName:"arrow.right")
                                }.font(.system(size:15,weight:.bold)).padding(15).foregroundStyle(Color.black)
                                    .background(model.folder == nil || model.target.isEmpty ? Color.gray : lime,in:RoundedRectangle(cornerRadius:10))
                            }.buttonStyle(.plain).disabled(model.folder == nil || model.target.isEmpty || updater.busy)
                        }
                    }.padding(22).background(Color.white.opacity(0.045),in:RoundedRectangle(cornerRadius:16))
                    if model.output != nil && !model.running && !model.failed {
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
                            Text(model.text("1. Envía la IPA a Sideloadly y pulsa Start con tu cuenta personal."))
                                .font(.system(size:13))
                            HStack {
                                Button(model.text(model.sideloadlyURL == nil ? "Descargar Sideloadly" : "Enviar a Sideloadly")){model.openSideloadly()}.buttonStyle(.borderedProminent).tint(lime).foregroundStyle(.black)
                                Button(model.text("Mostrar IPA")){model.revealIPA()}
                            }
                            Text(model.text("2. La primera vez, copia romfs por Finder → iPhone → Archivos → tu juego."))
                                .font(.system(size:13))
                            Button(model.text("Mostrar datos del juego")){model.revealAssets()}
                            Text(model.text("Para actualizar: misma cuenta e identificador de Sideloadly. Instala encima, sin desinstalar."))
                                .font(.system(size:11)).foregroundStyle(.secondary)
                            }
                            Button(model.text("Preparar de nuevo")){model.build()}.buttonStyle(.link).disabled(updater.busy)
                        }.padding(22).frame(maxWidth:.infinity,alignment:.leading)
                            .background(lime.opacity(0.045),in:RoundedRectangle(cornerRadius:16))
                    }
                    if model.failed && !model.transcript.isEmpty {
                        DisclosureGroup(model.text("Ver error"),isExpanded:$model.showDetails) {
                            VStack(alignment:.leading,spacing:10) {
                                ScrollView {Text(model.transcript).font(.system(size:10,design:.monospaced)).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading)}.frame(height:150)
                                Button(model.text("Copiar diagnóstico")){NSPasteboard.general.clearContents();NSPasteboard.general.setString(model.transcript,forType:.string)}
                            }.padding(.top,8)
                        }.font(.system(size:12)).foregroundStyle(.secondary)
                    }
                }.padding(28)
            }
        }.frame(minWidth:760,minHeight:530).background(CompactWindow(height:(model.isMac ? 740 : 680)+(updater.visible ? 95 : 0))).preferredColorScheme(.dark)
        .sheet(isPresented:$model.showCatalog) {GameCatalogView(model:model)}
        .sheet(isPresented:$showControllerTest) {ControllerTestView(text:model.text)}
        .task {await updater.check()}
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

@main struct NxNativeEasyApp: App {
    @NSApplicationDelegateAdaptor(LauncherDelegate.self) private var delegate
    @StateObject private var updater=AppUpdater()
    @AppStorage("interfaceLanguage") private var appLanguage="en"
    var body: some Scene {
        Window("nxnative Easy",id:"main") {
            ContentView(updater:updater).onAppear {
                NSApplication.shared.applicationIconImage=AppArtwork.icon
            }
        }
            .defaultSize(width:820,height:740)
            .commands {
                CommandGroup(after:.appInfo) {
                    Button(EasyStrings.text("Buscar actualizaciones…",language:EasyLanguage(rawValue:appLanguage) ?? .english)) {
                        Task {await updater.check(manual:true)}
                    }.disabled(updater.busy)
                }
            }
    }
}
