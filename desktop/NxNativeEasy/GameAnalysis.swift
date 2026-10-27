import SwiftUI
import AppKit
import Darwin

@MainActor final class GameAnalysisModel:ObservableObject {
    @Published var running=false
    @Published var transcript=""
    @Published var failed=false
    @Published var started:Date?
    private var task:Process?
    private var activity=BuildActivity()
    private var logURL:URL?
    private(set) var workspace:URL?
    func start(repo:URL,game:URL,run:Bool,ghidra:String="") {
        guard !running else {return}
        let out=game.appendingPathComponent("nxnative-tools/analysis/"+UUID().uuidString)
        workspace=out;failed=false;transcript="";activity=BuildActivity();started=Date()
        let worker=Process(),pipe=Pipe()
        worker.executableURL=URL(fileURLWithPath:"/usr/bin/python3")
        worker.arguments=[repo.appendingPathComponent("desktop/NxNativeEasy/build_session.py").path,repo.appendingPathComponent("scripts/analyze_game.py").path,game.path,"--output",out.path]+(run ? ["--run"] : [])
        worker.standardOutput=pipe;worker.standardError=pipe
        var env=ProcessInfo.processInfo.environment;env["PYTHONUNBUFFERED"]="1"
        logURL=game.appendingPathComponent("nxnative-tools/logs/analysis-"+UUID().uuidString+".log")
        env["NXE_BUILD_LOG"]=logURL?.path
        if !ghidra.isEmpty {env["GHIDRA_INSTALL_DIR"]=ghidra}
        worker.environment=env
        pipe.fileHandleForReading.readabilityHandler={ [weak self] handle in
            let data=handle.availableData
            if data.isEmpty {handle.readabilityHandler=nil;return}
            Task {@MainActor in guard let self,self.running else {return};self.activity.receive(data);self.transcript=self.activity.transcript}
        }
        worker.terminationHandler={ [weak self] worker in
            Task {@MainActor in guard let self else {return};self.activity.finish(logURL:self.logURL);self.transcript=self.activity.transcript;self.failed=worker.terminationStatus != 0;self.running=false;self.task=nil}
        }
        do {task=worker;running=true;try worker.run()}
        catch {transcript=error.localizedDescription;running=false;failed=true;task=nil}
    }
    func cancel() {if let task,task.isRunning {if kill(-task.processIdentifier,SIGTERM) != 0 {task.terminate()}}}
    func reveal() {if let workspace,FileManager.default.fileExists(atPath:workspace.path) {NSWorkspace.shared.open(workspace)}}
}

struct GameAnalysisView:View {
    let repo:URL
    let game:URL
    let text:(String)->String
    @StateObject private var model=GameAnalysisModel()
    @AppStorage("analysisGhidraDirectory") private var ghidra=""
    @Environment(\.dismiss) private var dismiss
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            HStack {Text(text("Analizar con REA")).font(.title2.bold());Spacer();Button(text("Cerrar")){dismiss()}.disabled(model.running)}
            Text(text("Análisis opcional del código original extraído. No modifica ni recompila el juego y no lo convierte automáticamente en un juego compatible."))
            Text(text("REA necesita Node/npm y un motor local compatible: Ghidra, Hopper o IDA. Su licencia e instalación son independientes. El análisis usa versiones fijas en una caché de este juego; no cambia la configuración de tu agente."))
                .font(.callout).foregroundStyle(.secondary)
            HStack {
                Button(text("Exportar para analizar")){model.start(repo:repo,game:game,run:false)}.disabled(model.running)
                Button(text("Exportar y ejecutar REA")){model.start(repo:repo,game:game,run:true,ghidra:ghidra)}.disabled(model.running)
                Link(text("Configurar motor"),destination:URL(string:"https://github.com/morluto/rea/blob/main/docs/installation.md")!)
            }
            HStack {
                Button(text("Seleccionar Ghidra…")) {
                    let panel=NSOpenPanel();panel.canChooseDirectories=true;panel.canChooseFiles=false;panel.allowsMultipleSelection=false
                    if panel.runModal() == .OK,let path=panel.url,FileManager.default.fileExists(atPath:path.appendingPathComponent("support/analyzeHeadless").path) {ghidra=path.path}
                }.disabled(model.running)
                Text(ghidra.isEmpty ? text("Opcional: usa tu instalación local de Ghidra.") : URL(fileURLWithPath:ghidra).lastPathComponent).font(.caption).foregroundStyle(.secondary)
            }
            if model.running {
                ProgressView().progressViewStyle(.linear)
                TimelineView(.periodic(from:.now,by:1)) {context in Text(text("Tiempo transcurrido")+" "+String(Int(context.date.timeIntervalSince(model.started ?? context.date)))+" s").font(.caption)}
                Button(text("Cancelar")){model.cancel()}
            }
            ScrollView {Text(model.transcript).font(.system(size:11,design:.monospaced)).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading)}.frame(minHeight:180)
            if model.failed {Text(text("El análisis no terminó. Revisa los logs; tus archivos originales se conservaron.")).foregroundStyle(.orange)}
            if model.workspace != nil && !model.running {Button(text("Mostrar análisis y logs")){model.reveal()}}
        }.padding(24).frame(width:720).interactiveDismissDisabled(model.running)
    }
}
