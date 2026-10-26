import SwiftUI
import AppKit
import Foundation
import Darwin

struct GameCard: Identifiable {
    let id: String
    let name: String
    let symbol: String
    let tint: Color
}

@MainActor final class BuildModel: ObservableObject {
    @Published var language: EasyLanguage = EasyLanguage.load() {
        didSet {language.save()}
    }
    func text(_ source: String) -> String {EasyStrings.text(source, language:language)}
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
    let cards: [GameCard] = [
        .init(id:"dread",name:"Metroid Dread",symbol:"scope",tint:.orange),
        .init(id:"wonder",name:"Super Mario Bros. Wonder",symbol:"sparkles",tint:.mint),
        .init(id:"zelda",name:"Zelda: Breath of the Wild",symbol:"mountain.2",tint:.cyan)
    ]
    init() {
        let configured = Bundle.main.object(forInfoDictionaryKey:"NxNativeSource") as? String ?? ""
        repo = URL(fileURLWithPath:configured)
        if let path=UserDefaults.standard.string(forKey:"keysDirectory"), FileManager.default.fileExists(atPath:path+"/prod.keys") {
            keysFolder=URL(fileURLWithPath:path)
        }
        if let path = UserDefaults.standard.string(forKey:"lastGameFolder"), FileManager.default.fileExists(atPath:path) {
            folder=URL(fileURLWithPath:path)
            restoreOutput()
        }
    }
    var gameName: String { folder?.lastPathComponent ?? text("Ningún juego seleccionado") }
    func openCatalog() {
        do {catalog=try GameCatalog.load(repo:repo);catalogFailed=false}
        catch {catalog=[];catalogFailed=true}
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
                phase="No encontramos el juego en esa carpeta."
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
        guard let folder,
              let data=try? Data(contentsOf:folder.appendingPathComponent("nxnative-ios.json")),
              let record=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],
              let path=record["light_dir"] as? String else {return}
        let directory=URL(fileURLWithPath:path)
        if let files=try? FileManager.default.contentsOfDirectory(at:directory,includingPropertiesForKeys:nil),
           let ipa=files.first(where:{$0.pathExtension=="ipa"}) { output=ipa;assets=directory.appendingPathComponent("romfs") }
    }
    func build() {
        guard let folder, !running else {return}
        let script=repo.appendingPathComponent("scripts/prepare_ios.sh")
        guard FileManager.default.fileExists(atPath:script.path) else {
            phase="No encontramos el código de nxnative.";detail="Vuelve a crear la app desde el repositorio con Abrir-interfaz.command.";failed=true;return
        }
        if keysFolder == nil {chooseKeysFolder()}
        guard let keysFolder else {return}
        let task=Process();let pipe=Pipe()
        task.executableURL=URL(fileURLWithPath:"/usr/bin/python3")
        var arguments=[repo.appendingPathComponent("desktop/NxNativeEasy/build_session.py").path,script.path,folder.path]
        arguments += ["--keys-folder",keysFolder.path]
        task.arguments=arguments;task.currentDirectoryURL=repo
        task.standardOutput=pipe;task.standardError=pipe
        var environment=ProcessInfo.processInfo.environment
        environment["PYTHONUNBUFFERED"]="1"
        task.environment=environment
        running=true;cancelled=false;failed=false;output=nil;assets=nil;transcript=""
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
                    self.phase=self.output == nil ? "Terminó, pero no encontramos la IPA." : "Tu juego está listo para Sideloadly."
                    self.detail=self.output == nil ? "Abre los detalles para revisar las rutas de salida." : "Abre la IPA y arrástrala a Sideloadly. La firma se hace con tu cuenta personal."
                } else {
                    self.failed=true;self.phase="Necesitamos revisar un paso."
                    self.detail="No borramos tus archivos. Abre los detalles para ver el error y vuelve a intentar."
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
        else if lower.contains("xcodebuild") || lower.contains("building the ipa") {phase="Compilando la app para iPhone…"}
        else if lower.contains("shader") {phase="Preparando los gráficos del juego…"}
        else if lower.contains("extract") {phase="Preparando los archivos del juego…"}
    }
    func cancel() {
        guard let process,process.isRunning else{return}
        cancelled=true
        if kill(-process.processIdentifier,SIGTERM) != 0 {process.terminate()}
        phase="Cancelando…"
    }
    func revealIPA() {if let output {NSWorkspace.shared.activateFileViewerSelecting([output])}}
    func revealAssets() {if let assets {NSWorkspace.shared.activateFileViewerSelecting([assets])}}
    func openSideloadly() {
        if let app=NSWorkspace.shared.urlForApplication(withBundleIdentifier:"io.sideloadly.sideloadly") {
            NSWorkspace.shared.openApplication(at:app,configuration:.init())
        } else {NSWorkspace.shared.open(URL(string:"https://sideloadly.io")!)}
    }
}

struct ContentView: View {
    @StateObject private var model=BuildModel()
    private let ink=Color(red:0.93,green:0.94,blue:0.90)
    private let lime=Color(red:0.79,green:0.95,blue:0.37)
    var body: some View {
        ZStack {
            Color(red:0.065,green:0.075,blue:0.07).ignoresSafeArea()
            ScrollView {
                VStack(alignment:.leading,spacing:24) {
                    HStack {
                        Label("nxnative / easy",systemImage:"gamecontroller.fill").font(.system(size:15,weight:.semibold,design:.monospaced)).foregroundStyle(lime)
                        Spacer()
                        Picker(model.text("Idioma de la interfaz"),selection:$model.language) {
                            Text("English").tag(EasyLanguage.english)
                            Text("Español").tag(EasyLanguage.spanish)
                        }.labelsHidden().frame(width:130).accessibilityIdentifier("interface-language")
                    }
                    VStack(alignment:.leading,spacing:8) {
                        Text(model.text("Del juego a tu iPhone.")).font(.system(size:42,weight:.bold,design:.rounded)).foregroundStyle(ink)
                        Text(model.text("Elige una carpeta. Prepara tu juego. A jugar.")).font(.system(size:17)).foregroundStyle(.gray)
                    }
                    HStack(spacing:12) {
                        ForEach(model.cards) {card in
                            VStack(alignment:.leading,spacing:8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius:12).fill(card.tint.opacity(0.12))
                                    Image(systemName:card.symbol).font(.system(size:38,weight:.light)).foregroundStyle(card.tint)
                                }.frame(height:106)
                                Text(card.name).font(.system(size:11,weight:.medium)).foregroundStyle(ink).lineLimit(1)
                            }.frame(maxWidth:.infinity)
                        }
                        Button {model.openCatalog()} label: {
                            VStack(alignment:.leading,spacing:8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius:12).fill(lime.opacity(0.12))
                                    Image(systemName:"square.grid.2x2").font(.system(size:34,weight:.light)).foregroundStyle(lime)
                                }.frame(height:106)
                                HStack {
                                    Text(model.text("Ver todos")).font(.system(size:11,weight:.semibold))
                                    Spacer()
                                    Image(systemName:"arrow.up.right").font(.system(size:10))
                                }.foregroundStyle(ink)
                            }.frame(maxWidth:.infinity)
                        }.buttonStyle(.plain).accessibilityIdentifier("view-all-games")
                    }
                    VStack(alignment:.leading,spacing:18) {
                        HStack(alignment:.center,spacing:14) {
                            Image(systemName:"folder.fill").font(.system(size:28)).foregroundStyle(lime)
                            VStack(alignment:.leading,spacing:4) {
                                Text(model.gameName).font(.system(size:18,weight:.semibold)).foregroundStyle(ink)
                                Text(model.folder == nil ? model.text("Una carpeta por juego, con su base y actualizaciones.") : model.folder!.path)
                                    .font(.system(size:11)).foregroundStyle(.gray).lineLimit(1).truncationMode(.middle)
                            }
                            Spacer()
                            Button(model.folder == nil ? model.text("1. Elegir juego") : model.text("Cambiar")) {model.chooseFolder()}.disabled(model.running)
                        }
                        HStack {
                            Image(systemName:"key.horizontal").foregroundStyle(lime)
                            Text(model.keysFolder == nil ? model.text("Tus llaves: selecciona su carpeta") : model.text("Tus llaves: carpeta seleccionada"))
                                .font(.system(size:12)).foregroundStyle(ink)
                            Spacer()
                            Button(model.keysFolder == nil ? model.text("Elegir carpeta de llaves") : model.text("Cambiar llaves")) {model.chooseKeysFolder()}.disabled(model.running)
                        }
                        Divider().overlay(Color.white.opacity(0.08))
                        HStack {
                            VStack(alignment:.leading,spacing:5) {
                                Text(model.text(model.phase)).font(.system(size:16,weight:.semibold)).foregroundStyle(model.failed ? .orange : ink)
                                Text(model.text(model.detail)).font(.system(size:12)).foregroundStyle(.gray).fixedSize(horizontal:false,vertical:true)
                            }
                            Spacer()
                            if model.running {ProgressView().controlSize(.small);Button(model.text("Cancelar")){model.cancel()}}
                        }
                        if !model.running {
                            Button {model.build()} label: {
                                HStack {Image(systemName:"iphone.gen3");Text(model.text("2. Preparar para iPhone"));Spacer();Image(systemName:"arrow.right")}
                                    .font(.system(size:16,weight:.bold)).padding(16).foregroundStyle(Color.black)
                                    .background(model.folder == nil ? Color.gray : lime,in:RoundedRectangle(cornerRadius:12))
                            }.buttonStyle(.plain).disabled(model.folder == nil)
                        }
                        if model.running {ProgressView().progressViewStyle(.linear).tint(lime)}
                        if model.output != nil && !model.running {
                            HStack {
                                Button(model.text("Mostrar IPA")){model.revealIPA()}
                                Button(model.text("Mostrar datos romfs")){model.revealAssets()}
                                Button(model.text("Abrir Sideloadly")){model.openSideloadly()}
                            }
                            Text(model.text("Primera instalación: instala la IPA ligera y copia romfs por Finder. Para actualizar, conserva la misma cuenta y bundle ID; no desinstales la app."))
                                .font(.system(size:12)).foregroundStyle(ink.opacity(0.8))
                        }
                    }.padding(24).background(Color.white.opacity(0.045),in:RoundedRectangle(cornerRadius:20))
                    DisclosureGroup(model.text("Detalles"),isExpanded:$model.showDetails) {
                        VStack(alignment:.leading,spacing:12) {
                            if !model.transcript.isEmpty {
                                Text(model.text("Los detalles de compilación se muestran en su idioma original.")).font(.system(size:11)).foregroundStyle(.gray)
                                ScrollView {Text(model.transcript).font(.system(size:10,design:.monospaced)).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading)}.frame(height:180)
                            }
                            HStack {
                                Link(model.text("Guía de instalación"),destination:URL(string:"https://github.com/nalancer08/nxnative-easy#readme")!)
                                if !model.transcript.isEmpty {Button(model.text("Copiar diagnóstico")){NSPasteboard.general.clearContents();NSPasteboard.general.setString(model.transcript,forType:.string)}}
                            }
                        }.padding(.top,10)
                    }.font(.system(size:12)).foregroundStyle(.gray)
                    Text(model.text("Preparación local. No se incluyen juegos ni llaves. La firma e instalación se hacen por separado en Sideloadly.")+"\n"+model.text("Compatibilidad según perfil, versión y dispositivo. Esta app no verifica que un juego funcione en tu iPhone."))
                        .font(.system(size:11)).foregroundStyle(.gray).lineSpacing(4)
                }.padding(32)
            }
        }.frame(minWidth:820,minHeight:680).preferredColorScheme(.dark)
        .sheet(isPresented:$model.showCatalog) {GameCatalogView(model:model)}
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
                        Text(model.text("perfiles incluidos en esta copia"))
                    }.font(.system(size:12)).foregroundStyle(.secondary)
                }
                Spacer()
                Button(model.text("Cerrar")) {model.showCatalog=false}.keyboardShortcut(.cancelAction)
            }
            Text(model.text("Son perfiles del repositorio, no una prueba de funcionamiento en tu dispositivo. Consulta la ficha para ver plataformas, versiones y límites."))
                .font(.system(size:12)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            HStack {
                Image(systemName:"magnifyingglass").foregroundStyle(lime)
                TextField(model.text("Buscar por nombre, versión o Title ID"),text:$query)
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
                                Image(systemName:"gamecontroller").font(.system(size:20)).foregroundStyle(lime).frame(width:36)
                                VStack(alignment:.leading,spacing:5) {
                                    Text(game.name).font(.system(size:14,weight:.semibold)).fixedSize(horizontal:false,vertical:true)
                                    Text(game.id).font(.system(size:10,design:.monospaced)).foregroundStyle(.secondary).textSelection(.enabled)
                                    if !game.versions.isEmpty {
                                        Text(model.text("Versiones del perfil")+": "+game.versions.joined(separator:", "))
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
    var body: some Scene {
        WindowGroup("nxnative Easy") {ContentView()}
            .defaultSize(width:920,height:780)
    }
}
