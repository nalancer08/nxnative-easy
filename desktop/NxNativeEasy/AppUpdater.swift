import AppKit
import Combine
import Foundation

@MainActor final class AppUpdater: ObservableObject {
    @Published private(set) var available: UpdateRelease?
    @Published private(set) var busy=false
    @Published private(set) var phase=""
    @Published private(set) var progress: Double?
    @Published private(set) var error: String?
    @Published var showNotice=false
    private var revision: String?
    private var process: Process?
    private var buffered=""
    var visible: Bool {available != nil || busy || error != nil}
    var phaseText: String {
        switch phase {
        case "download":return "Descargando actualización…"
        case "extract":return "Preparando el código nuevo…"
        case "build":return "Compilando la actualización…"
        case "verify":return "Verificando la app…"
        case "restart":return "Reiniciando con la versión nueva…"
        default:return "Preparando actualización…"
        }
    }
    private var checking=false
    private struct Commit: Decodable {let sha:String}
    private struct Event: Decodable {let phase:String;let progress:Double?;let message:String?}
    init() {
        let failure=FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/nxnative Easy/Updates/last-error.json")
        if FileManager.default.fileExists(atPath:failure.path) {
            error="No pudimos actualizar. Tu versión anterior se conservó."
            try? FileManager.default.removeItem(at:failure)
        }
    }
    private var binaryAvailable=false
    private func fetch(_ url:String) async throws -> Data {
        var request=URLRequest(url:URL(string:url)!,timeoutInterval:20)
        request.setValue("nxnative-Easy-Updater",forHTTPHeaderField:"User-Agent")
        let (data,response)=try await URLSession.shared.data(for:request)
        guard let http=response as? HTTPURLResponse,http.statusCode==200 else {throw URLError(.badServerResponse)}
        guard data.count<128*1024 else {throw URLError(.dataLengthExceedsMaximum)}
        return data
    }
    func check(manual:Bool=false) async {
        guard !busy,!checking else {return}
        checking=true;defer {checking=false}
        do {
            let commit=try JSONDecoder().decode(Commit.self,from:await fetch("https://api.github.com/repos/nalancer08/nxnative-easy/commits/main"))
            guard commit.sha.range(of:"^[0-9a-f]{40}$",options:.regularExpression) != nil else {throw URLError(.cannotParseResponse)}
            let release=try JSONDecoder().decode(UpdateRelease.self,from:await fetch("https://raw.githubusercontent.com/nalancer08/nxnative-easy/\(commit.sha)/desktop/release.json"))
            try release.validate()
            let current=Int(Bundle.main.object(forInfoDictionaryKey:"CFBundleVersion") as? String ?? "0") ?? 0
            if release.isNewer(than:current) {
                binaryAvailable=false
                if let data=try? await fetch("https://api.github.com/repos/nalancer08/nxnative-easy/releases/tags/v\(release.version)"),let listing=try? JSONSerialization.jsonObject(with:data) as? [String:Any] {
                    let names=(listing["assets"] as? [[String:Any]] ?? []).compactMap {$0["name"] as? String}
                    binaryAvailable=names.contains("nxnative-Easy-macOS-arm64.zip") && names.contains("SHA256SUMS")
                }
                if PortableRuntime.tools != nil && !binaryAvailable {throw URLError(.resourceUnavailable)}
                available=release;revision=commit.sha;error=nil
            } else if manual {showNotice=true}
        } catch {if manual {self.error="No pudimos buscar actualizaciones. Intenta de nuevo más tarde."}}
    }
    func start() {
        guard !busy,let release=available,let revision else {return}
        guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion>=release.minimumMacOSMajor else {
            error="Primero actualiza macOS para instalar esta versión.";return
        }
        guard let helper=Bundle.main.url(forResource:"update_app",withExtension:"py") else {
            error="Vuelve a ejecutar el comando de instalación para activar las actualizaciones.";return
        }
        error=nil;busy=true;phase="download";progress=nil;buffered=""
        let task=Process();let pipe=Pipe()
        task.executableURL=PortableRuntime.python
        task.arguments=[helper.path,"--revision",revision,"--build",String(release.build),
                        "--target",Bundle.main.bundleURL.path,"--parent-pid",String(ProcessInfo.processInfo.processIdentifier)]
        // Optional local validation cache; ordinary installs use the helper's Application Support default.
        if let cache=Bundle.main.object(forInfoDictionaryKey:"NxNativeUpdateCache") as? String {
            task.arguments! += ["--cache",cache]
        }
        task.standardOutput=pipe;task.standardError=pipe
        var environment=PortableRuntime.environment();environment["PYTHONUNBUFFERED"]="1";if binaryAvailable {environment["NXE_PREFER_PORTABLE"]="1"}else{environment.removeValue(forKey:"NXE_PREFER_PORTABLE")};task.environment=environment
        pipe.fileHandleForReading.readabilityHandler={ [weak self] handle in
            let bytes=handle.availableData
            if bytes.isEmpty {handle.readabilityHandler=nil;return}
            let chunk=String(decoding:bytes,as:UTF8.self)
            Task { @MainActor in self?.receive(chunk) }
        }
        task.terminationHandler={ [weak self] _ in
            Task { @MainActor in
                guard let self,self.busy,self.phase != "restart" else {return}
                self.busy=false;self.process=nil
                if self.error==nil {self.error="No pudimos actualizar. Tu versión anterior se conservó."}
            }
        }
        do {process=task;try task.run()}
        catch {busy=false;self.error="No pudimos iniciar la actualización."}
    }
    private func receive(_ chunk:String) {
        buffered+=chunk
        while let newline=buffered.firstIndex(of:"\n") {
            let line=String(buffered[..<newline]);buffered.removeSubrange(...newline)
            guard let data=line.data(using:.utf8),let event=try? JSONDecoder().decode(Event.self,from:data) else {continue}
            phase=event.phase;progress=event.progress
            if phase=="error" {error="No pudimos actualizar. Tu versión anterior se conservó.";busy=false}
            if phase=="restart" {NSApplication.shared.terminate(nil)}
        }
    }
    func dismissError() {error=nil}
}
