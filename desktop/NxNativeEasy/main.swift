import SwiftUI
import AppKit
import Foundation
import Darwin

struct GameCard: Identifiable {
    let id: String
    let name: String
    let image: String
}

@MainActor final class BuildModel: ObservableObject {
    @Published var folder: URL?
    @Published var running = false
    @Published var phase = "Tu próximo juego empieza aquí."
    @Published var detail = "Elige su carpeta. Nosotros preparamos la IPA ligera."
    @Published var transcript = ""
    @Published var output: URL?
    @Published var assets: URL?
    @Published var failed = false
    @Published var appOnly = false
    @Published var showDetails = false
    private var process: Process?
    private var cancelled = false
    let repo: URL
    let cards: [GameCard] = [
        .init(id:"dread",name:"Metroid Dread",image:"metroid-dread.jpg"),
        .init(id:"wonder",name:"Super Mario Bros. Wonder",image:"super-mario-bros-wonder.jpg"),
        .init(id:"zelda",name:"Zelda: Breath of the Wild",image:"zelda-breath-of-the-wild.jpg"),
        .init(id:"odyssey",name:"Super Mario Odyssey",image:"super-mario-odyssey.jpg"),
        .init(id:"cuphead",name:"Cuphead",image:"cuphead.jpg"),
        .init(id:"hades",name:"Hades",image:"hades.jpg")
    ]
    init() {
        let configured = Bundle.main.object(forInfoDictionaryKey:"NxNativeSource") as? String ?? ""
        repo = URL(fileURLWithPath:configured)
        if let path = UserDefaults.standard.string(forKey:"lastGameFolder"), FileManager.default.fileExists(atPath:path) {
            folder=URL(fileURLWithPath:path)
            restoreOutput()
        }
    }
    var gameName: String { folder?.lastPathComponent ?? "Ningún juego seleccionado" }
    func chooseFolder() {
        let panel=NSOpenPanel();panel.canChooseDirectories=true;panel.canChooseFiles=false
        panel.allowsMultipleSelection=false;panel.prompt="Elegir juego"
        panel.message="Selecciona la carpeta con el juego base y sus actualizaciones NSP/XCI."
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
            phase="Listo para preparar \(gameName).";detail="Un clic más. Los archivos anteriores se conservan."
            failed=false;output=nil;assets=nil;transcript="";restoreOutput()
        } catch { phase="No pudimos leer esa carpeta.";detail=error.localizedDescription;failed=true }
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
        var keys: URL?
        if !appOnly && !FileManager.default.fileExists(atPath:folder.appendingPathComponent("prod.keys").path) {
            let panel=NSOpenPanel();panel.prompt="Elegir prod.keys";panel.message="Sólo la primera vez: selecciona tus llaves. Se quedan en tu Mac."
            guard panel.runModal() == .OK else {return};keys=panel.url
        }
        let task=Process();let pipe=Pipe()
        task.executableURL=URL(fileURLWithPath:"/usr/bin/python3")
        var arguments=[repo.appendingPathComponent("desktop/NxNativeEasy/build_session.py").path,script.path,folder.path]
        if appOnly { arguments.append("--app-only") }
        if let keys {arguments += ["--keys",keys.path]}
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
                        Label("nxnative / personal",systemImage:"gamecontroller.fill").font(.system(size:15,weight:.semibold,design:.monospaced)).foregroundStyle(lime)
                        Spacer()
                        Text("HECHO PARA TU IPHONE").font(.system(size:10,weight:.medium,design:.monospaced)).tracking(2).foregroundStyle(.gray)
                    }
                    VStack(alignment:.leading,spacing:8) {
                        Text("Del juego a tu iPhone.").font(.system(size:42,weight:.bold,design:.rounded)).foregroundStyle(ink)
                        Text("Elige una carpeta. Prepara tu juego. A jugar.").font(.system(size:17)).foregroundStyle(.gray)
                    }
                    HStack(spacing:12) {
                        ForEach(model.cards.prefix(4)) {card in
                            VStack(alignment:.leading,spacing:8) {
                                if let image=NSImage(contentsOf:model.repo.appendingPathComponent("docs/images/"+card.image)) {
                                    Image(nsImage:image).resizable().scaledToFill().frame(height:106).clipped().clipShape(RoundedRectangle(cornerRadius:12))
                                }
                                Text(card.name).font(.system(size:11,weight:.medium)).foregroundStyle(ink).lineLimit(1)
                            }.frame(maxWidth:.infinity)
                        }
                    }.accessibilityLabel("Juegos con perfiles incluidos; consulta la ficha de cada juego para compatibilidad")
                    VStack(alignment:.leading,spacing:18) {
                        HStack(alignment:.center,spacing:14) {
                            Image(systemName:"folder.fill").font(.system(size:28)).foregroundStyle(lime)
                            VStack(alignment:.leading,spacing:4) {
                                Text(model.gameName).font(.system(size:18,weight:.semibold)).foregroundStyle(ink)
                                Text(model.folder == nil ? "Una carpeta por juego, con su base y actualizaciones." : model.folder!.path)
                                    .font(.system(size:11)).foregroundStyle(.gray).lineLimit(1).truncationMode(.middle)
                            }
                            Spacer()
                            Button(model.folder == nil ? "1. Elegir juego" : "Cambiar") {model.chooseFolder()}.disabled(model.running)
                        }
                        Divider().overlay(Color.white.opacity(0.08))
                        HStack {
                            VStack(alignment:.leading,spacing:5) {
                                Text(model.phase).font(.system(size:16,weight:.semibold)).foregroundStyle(model.failed ? .orange : ink)
                                Text(model.detail).font(.system(size:12)).foregroundStyle(.gray).fixedSize(horizontal:false,vertical:true)
                            }
                            Spacer()
                            if model.running {ProgressView().controlSize(.small);Button("Cancelar"){model.cancel()}}
                        }
                        if !model.running {
                            Button {model.build()} label: {
                                HStack {Image(systemName:"iphone.gen3");Text("2. Preparar para iPhone");Spacer();Image(systemName:"arrow.right")}
                                    .font(.system(size:16,weight:.bold)).padding(16).foregroundStyle(Color.black)
                                    .background(model.folder == nil ? Color.gray : lime,in:RoundedRectangle(cornerRadius:12))
                            }.buttonStyle(.plain).disabled(model.folder == nil)
                        }
                        if model.running {ProgressView().progressViewStyle(.linear).tint(lime)}
                        if model.output != nil && !model.running {
                            HStack {
                                Button("Mostrar IPA"){model.revealIPA()}
                                Button("Mostrar datos romfs"){model.revealAssets()}
                                Button("Abrir Sideloadly"){model.openSideloadly()}
                            }
                            Text("Primera instalación: instala la IPA ligera y copia romfs por Finder. Para actualizar, conserva la misma cuenta y bundle ID; no desinstales la app.")
                                .font(.system(size:12)).foregroundStyle(ink.opacity(0.8))
                        }
                    }.padding(24).background(Color.white.opacity(0.045),in:RoundedRectangle(cornerRadius:20))
                    DisclosureGroup("Opciones y detalles",isExpanded:$model.showDetails) {
                        VStack(alignment:.leading,spacing:12) {
                            Toggle("Recrear sólo la app con las cachés existentes",isOn:$model.appOnly).disabled(model.running)
                            Text("Úsalo para actualizar el editor. Para una versión nueva del juego, déjalo desactivado. La primera preparación necesita Xcode y Homebrew instalados.").font(.system(size:12)).foregroundStyle(.gray)
                            if !model.transcript.isEmpty {
                                ScrollView {Text(model.transcript).font(.system(size:10,design:.monospaced)).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading)}.frame(height:180)
                            }
                            HStack {
                                Link("Guía de instalación",destination:URL(string:"https://github.com/nalancer08/nxnative-personal#readme")!)
                                if !model.transcript.isEmpty {Button("Copiar diagnóstico"){NSPasteboard.general.clearContents();NSPasteboard.general.setString(model.transcript,forType:.string)}}
                            }
                        }.padding(.top,10)
                    }.font(.system(size:12)).foregroundStyle(.gray)
                    Text("Tus juegos y llaves se quedan en tu Mac. IPA sin firmar · Sideloadly usa tu cuenta personal.\nMetroid Dread confirmado en nuestro iPhone. Los demás dependen del perfil, versión y dispositivo.")
                        .font(.system(size:11)).foregroundStyle(.gray).lineSpacing(4)
                }.padding(32)
            }
        }.frame(minWidth:820,minHeight:680).preferredColorScheme(.dark)
        .onReceive(NotificationCenter.default.publisher(for:NSApplication.willTerminateNotification)) {_ in model.cancel()}
    }
}

@main struct NxNativeEasyApp: App {
    var body: some Scene {
        WindowGroup("nxnative · Preparar para iPhone") {ContentView()}
            .defaultSize(width:920,height:780)
    }
}
