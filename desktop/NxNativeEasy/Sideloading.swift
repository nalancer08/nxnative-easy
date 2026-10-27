import SwiftUI
import AppKit
import Combine
import CryptoKit
import ServiceManagement
import Darwin

struct SideloadDevice:Identifiable {
    let id:String;let name:String
    var model:String="";var os:String="";var kind:String="";var ready:Bool=true;var connections:[String]=[]
    var detail:String {[model,os.isEmpty ? "" : (kind=="iPad" ? "iPadOS " : "iOS ")+os,connections.joined(separator:" + ")].filter{!$0.isEmpty}.joined(separator:" · ")}
    static func decode(_ items:[[String:Any]])->[SideloadDevice] {
        var result:[String:SideloadDevice]=[:]
        for item in items {
            guard let id=item["udid"] as? String,!id.isEmpty,let name=item["name"] as? String else {continue}
            let value=SideloadDevice(id:id,name:name,model:item["model"] as? String ?? "",os:item["os"] as? String ?? "",kind:item["kind"] as? String ?? "",ready:item["ready"] as? Bool ?? true,connections:item["connections"] as? [String] ?? [])
            if result[id]==nil || value.connections.contains("USB") {result[id]=value}
        }
        return result.values.sorted {$0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending}
    }
}
struct AccountDevice:Identifiable {let id:String;let name:String;let status:String}
struct InstallLog:Identifiable {let id=UUID();let date=Date();let message:String;var progress:Double?=nil}
struct TrustedSMS:Identifiable {let id:Int;let digits:String}
struct SideloadTeam:Identifiable {let id:String;let name:String;var kind:String=""}
struct InstalledGame:Identifiable {let id:String;let name:String;var version:String=""}

struct GameAppScope {
    var originals:Set<String>=[]
    var known:Set<String>=[]
    var isEmpty:Bool {originals.isEmpty && known.isEmpty}
    func permits(_ id:String)->Bool {
        guard id.range(of:"^[A-Za-z0-9.-]{1,255}$",options:.regularExpression) != nil else {return false}
        if known.contains(id) || originals.contains(id) {return true}
        return originals.contains {base in
            guard base.range(of:"^org\\.nxnative\\.[0-9a-f]{16}$",options:[.regularExpression,.caseInsensitive]) != nil else {return false}
            let prefix=base.lowercased()+"."
            guard id.lowercased().hasPrefix(prefix) else {return false}
            let suffix=id.dropFirst(prefix.count)
            return suffix.count==10 && suffix.allSatisfy {$0.isASCII && ($0.isLetter || $0.isNumber)}
        }
    }
}

struct RefreshJob:Codable,Identifiable {
    var id:String
    var ipa:String
    var gameFolder:String
    var originalID:String
    var effectiveID:String
    var team:String
    var udid:String
    var account:String
    var sha256:String
    var expires:Date
    var enabled:Bool
    var retryAfter:Date?
    var needsLogin:Bool=false
}
enum RefreshPolicy {
    static func account(_ email:String)->String {SHA256.hash(data:Data(email.trimmingCharacters(in:.whitespacesAndNewlines).lowercased().utf8)).map {String(format:"%02x",$0)}.joined()}
    static func due(_ job:RefreshJob,now:Date,account:String)->Bool {job.enabled && !job.needsLogin && job.account==account && job.expires.timeIntervalSince(now)<=48*3600 && (job.retryAfter==nil || job.retryAfter!<=now)}
    static func identity(original:String,team:String,existing:String)->String? {
        guard team.count==10,team.allSatisfy({$0.isASCII && ($0.isLetter || $0.isNumber)}) else {return nil}
        if existing.isEmpty {return original+"."+team}
        return existing.count<=255 && existing.allSatisfy({$0.isASCII && ($0.isLetter || $0.isNumber || $0=="." || $0=="-")}) ? existing : nil
    }
}

@MainActor final class SideloadModel:ObservableObject {
    @Published var devices:[SideloadDevice]=[]
    @Published var teams:[SideloadTeam]=[]
    @Published var apps:[InstalledGame]=[]
    var preparedIdentifiers:[String]=[]
    var preparedFolders:[String:URL]=[:]
    @Published var exportedSaves:URL?
    private var helperCapabilities:Set<String>=[]
    private var pendingExport:URL?
    private var pendingContentID:String?
    private var appQueryScope=GameAppScope()
    private var scopedDiscovery=false
    @Published var accountDevices:[AccountDevice]=[]
    @Published var accountDeviceTeam=""
    @Published var logs:[InstallLog]=[]
    @Published var logURL:URL?
    private var pendingUpdate:(device:String,id:String)?
    private var loggedPhase=""
    private var loggedBucket = -1
    @Published var device=""
    @Published var team=""
    @Published var existing=""
    @Published var email=""
    @Published var anisette="https://ani.iloader.app"
    @Published var authenticated=false
    @Published var busy=false
    @Published var codeRequired=false
    @Published var smsNumbers:[TrustedSMS]=[]
    @Published var error:String?
    @Published var phase="Conecta y desbloquea tu iPhone/iPad."
    @Published var fraction:Double?
    @Published var startedAt:Date?
    @Published var jobs:[RefreshJob]=[]
    var canRefresh:()->Bool={true}
    var ipa:URL?
    var gameFolder:URL?
    var romfs:URL?
    var originalID=""
    private var process:Process?
    private var input:FileHandle?
    private var pending=Data()
    private var timer:AnyCancellable?
    private var terminationObserver:NSObjectProtocol?
    private var installIntent:RefreshJob?
    private var activeRefresh:RefreshJob?
    private var refreshAuthenticated=false
    private var manualRefresh=false
    private var pendingRemember:Bool?
    var showsRefreshNotice:Bool {jobs.contains(where:{$0.enabled}) && (busy || error != nil)}
    private let stateURL:URL
    private let defaults:UserDefaults
    private let helperURL:URL?
    init(stateURL:URL?=nil,defaults:UserDefaults = .standard,helperURL:URL?=nil) {
        self.defaults=defaults;self.helperURL=helperURL
        email=defaults.string(forKey:"sideloadEmail") ?? "";anisette=defaults.string(forKey:"sideloadAnisette") ?? "https://ani.iloader.app"
        self.stateURL=stateURL ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/nxnative Easy/refresh-jobs.json")
        if let data=try? Data(contentsOf:self.stateURL),let saved=try? JSONDecoder().decode([RefreshJob].self,from:data) {jobs=saved}
        terminationObserver=NotificationCenter.default.addObserver(forName:NSApplication.willTerminateNotification,object:nil,queue:.main) { [weak self] _ in MainActor.assumeIsolated {self?.cancel()} }
        timer=Timer.publish(every:1800,on:.main,in:.common).autoconnect().sink { [weak self] _ in Task {@MainActor in self?.checkRefresh()}}
    }
    func configure(ipa:URL,folder:URL,romfs:URL?) {
        self.ipa=ipa;gameFolder=folder;self.romfs=romfs
        originalID=PreviousPreparation.load(folder:folder,target:"ios")?.bundleID ?? ""
        existing=pendingUpdate?.id ?? ""
        if let pendingUpdate {device=pendingUpdate.device;self.pendingUpdate=nil}
        if existing.isEmpty,let known=jobs.first(where:{$0.originalID==originalID && $0.gameFolder==folder.path && $0.account==RefreshPolicy.account(email)}) {
            if device.isEmpty {device=known.udid};if team.isEmpty {team=known.team}
            if device==known.udid {existing=known.effectiveID}
        }
        connect();listDevices()
    }
    func titleID(for app:InstalledGame)->String? {
        let parts=app.id.split(separator:".")
        if parts.count>=3,parts[0].lowercased()=="org",parts[1].lowercased()=="nxnative",parts[2].count==16,parts[2].allSatisfy({$0.isHexDigit}) {return parts[2].uppercased()}
        if let job=jobs.first(where:{$0.udid==device && $0.effectiveID==app.id}) {return SaveLocations.titleID(folder:URL(fileURLWithPath:job.gameFolder))}
        if let folder=gameFolder,app.id==existing {return SaveLocations.titleID(folder:folder)}
        return nil
    }
    func dataFolder(for app:InstalledGame)->URL? {
        guard let id=titleID(for:app),let folder=preparedFolders[id],
              let data=try? Data(contentsOf:folder.appendingPathComponent("nxnative-ios.json")),
              let info=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],
              let path=info["light_dir"] as? String else {return nil}
        let romfs=URL(fileURLWithPath:path).appendingPathComponent("romfs")
        return FileManager.default.fileExists(atPath:romfs.path) ? romfs : nil
    }
    var supportsSaveExport:Bool {helperCapabilities.contains("save-export-v1")}
    var supportsContentCopy:Bool {helperCapabilities.contains("romfs-copy-v1")}
    func exportSaves(_ app:InstalledGame,destination:URL,confirmedClosed:Bool) {
        guard !busy,!device.isEmpty,appQueryScope.permits(app.id),helperCapabilities.contains("save-export-v1") else {return}
        guard !destination.deletingLastPathComponent().pathComponents.contains(".git") else {return}
        if let id=titleID(for:app),let folder=preparedFolders[id] {gameFolder=folder};logURL=nil
        pendingExport=destination;exportedSaves=nil;busy=true;error=nil;fraction=nil;startedAt=Date();phase="Exportando partidas…";record(phase)
        send(["op":"export_saves","udid":device,"effective_id":app.id,"destination":destination.path,"confirmed_closed":confirmedClosed,"original_ids":appQueryScope.originals.sorted(),"known_ids":appQueryScope.known.sorted()])
    }
    func chooseSaveDestination(_ app:InstalledGame,text:(String)->String={ $0 }) {
        guard !busy else {return}
        let panel=NSSavePanel();panel.title=app.name;panel.canCreateDirectories=true;panel.prompt=text("Exportar partidas")
        let formatter=DateFormatter();formatter.locale=Locale(identifier:"en_US_POSIX");formatter.dateFormat="yyyyMMdd-HHmmss"
        panel.nameFieldStringValue="partidas-"+(titleID(for:app) ?? "juego")+"-"+formatter.string(from:Date())+".zip"
        if let id=titleID(for:app),let folder=preparedFolders[id] {panel.directoryURL=folder}
        guard panel.runModal() == .OK,let url=panel.url else {return}
        exportSaves(app,destination:url,confirmedClosed:true)
    }
    func copyData(_ app:InstalledGame,confirmedClosed:Bool) {
        guard !busy,!device.isEmpty,appQueryScope.permits(app.id),let source=dataFolder(for:app),helperCapabilities.contains("romfs-copy-v1") else {return}
        guard let id=titleID(for:app),let folder=preparedFolders[id],let version=PreviousPreparation.load(folder:folder,target:"ios")?.version,version==app.version else {error="Actualiza primero la app con la misma versión que los datos preparados.";return}
        gameFolder=folder;logURL=nil
        pendingContentID=app.id;busy=true;error=nil;fraction=nil;startedAt=Date();phase="Copiando datos del juego…";record(phase)
        send(["op":"copy_romfs","udid":device,"effective_id":app.id,"romfs":source.path,"confirmed_closed":confirmedClosed,"game_version":app.version,"original_ids":appQueryScope.originals.sorted(),"known_ids":appQueryScope.known.sorted()])
    }
    func cancelPendingUpdate() {pendingUpdate=nil}
    func prepareUpdate(_ app:InstalledGame) {guard !busy,!device.isEmpty else {return};pendingUpdate=(device,app.id)}
    func openDevice(_ id:String) {
        guard !busy else {return}
        device=id;existing="";apps=[];inspectApps()
    }
    func inspectAccountDevices() {
        guard !busy,authenticated,!team.isEmpty else {return}
        busy=true;error=nil;startedAt=Date();fraction=nil;phase="Consultando dispositivos registrados en Apple…";accountDevices=[];accountDeviceTeam="";record(phase)
        send(["op":"account_devices","team":team])
    }
    func copyLogs(text:(String)->String) {
        let output=logs.map {$0.date.formatted(date:.omitted,time:.standard)+" · "+text($0.message)+($0.progress.map{" · "+String(Int($0*100))+" %"} ?? "")}.joined(separator:"\n")
        NSPasteboard.general.clearContents();NSPasteboard.general.setString(output,forType:.string)
    }
    private func record(_ message:String,progress:Double?=nil) {
        // Only local fixed messages enter this log. Never serialize helper events,
        // Apple responses, identifiers, account names, passwords or tokens.
        if logs.count>=400 {logs.removeFirst(logs.count-399)}
        logs.append(InstallLog(message:message,progress:progress))
        if logURL==nil,let folder=gameFolder {
            let root=folder.appendingPathComponent("nxnative-tools/logs")
            do {try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700]);logURL=root.appendingPathComponent("install-"+UUID().uuidString+".log")}catch{}
        }
        if let logURL {
            let output=logs.map {$0.date.ISO8601Format()+" · "+$0.message+($0.progress.map{" · "+String(Int($0*100))+" %"} ?? "")}.joined(separator:"\n")+"\n"
            do {try Data(output.utf8).write(to:logURL,options:.atomic);try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:logURL.path)}catch{}
        }
    }
    func connect() {
        if let process,process.isRunning {return}
        process=nil;input=nil;scopedDiscovery=false
        guard let root=Bundle.main.executableURL?.deletingLastPathComponent() else {return}
        let helper=helperURL ?? root.appendingPathComponent("nxnative-sideload")
        guard FileManager.default.isExecutableFile(atPath:helper.path) else {error="Falta el instalador nativo. Actualiza nxnative Easy.";return}
        let task=Process(),pipe=Pipe(),requests=Pipe();task.executableURL=helper
        task.standardOutput=pipe;task.standardError=FileHandle.nullDevice;task.standardInput=requests
        var environment=ProcessInfo.processInfo.environment;environment.removeValue(forKey:"RUST_LOG");environment.removeValue(forKey:"RUST_BACKTRACE");task.environment=environment
        input=requests.fileHandleForWriting;pending=Data()
        pipe.fileHandleForReading.readabilityHandler={ [weak self] handle in
            let data=handle.availableData;if data.isEmpty {handle.readabilityHandler=nil;return}
            Task {@MainActor in self?.receive(data)}
        }
        task.terminationHandler={ [weak self] finished in Task {@MainActor in guard let self,self.process === finished else {return};self.process=nil;self.input=nil;self.scopedDiscovery=false;self.authenticated=false;self.codeRequired=false;if self.busy {self.error="Instalación detenida. Vuelve a intentar; las partidas no se tocaron."};self.busy=false;self.activeRefresh=nil;self.installIntent=nil;self.refreshAuthenticated=false}}
        do {process=task;try task.run()}
        catch {process=nil;input=nil;self.error="No pudimos iniciar el instalador nativo."}
    }
    private func send(_ value:[String:Any]) {
        connect();guard let input,let process,process.isRunning else {busy=false;return}
        do {var data=try JSONSerialization.data(withJSONObject:value);data.append(10);try input.write(contentsOf:data)}
        catch {self.error="No pudimos comunicarnos con el instalador.";busy=false}
    }
    func listDevices() {guard !busy else {return};error=nil;busy=true;startedAt=Date();fraction=nil;phase="Buscando dispositivos conectados…";record(phase);send(["op":"devices"])}
    func inspectApps() {
        guard !busy,!device.isEmpty else {return}
        var originals=Set(preparedIdentifiers)
        if !originalID.isEmpty {originals.insert(originalID)}
        let scope=GameAppScope(originals:originals,known:Set(jobs.filter{$0.udid==device}.map(\.effectiveID)))
        apps=[];appQueryScope=scope
        guard !scope.isEmpty else {phase="Añade la carpeta preparada del juego para reconocer instalaciones anteriores.";return}
        guard scopedDiscovery else {error="Actualiza la app para buscar juegos sin consultar otras aplicaciones.";return}
        busy=true;startedAt=Date();fraction=nil;phase="Buscando tus juegos instalados…";record(phase)
        send(["op":"installed_apps","udid":device,"original_ids":scope.originals.sorted(),"known_ids":scope.known.sorted()])
    }

    func signIn(password:String,remember:Bool) {
        guard !busy,!email.isEmpty,!password.isEmpty else {return}
        email=email.trimmingCharacters(in:.whitespacesAndNewlines).lowercased()
        busy=true;error=nil;startedAt=Date();fraction=nil;phase="Iniciando sesión con Apple…"
        record("Iniciando sesión con Apple…")
        pendingRemember=remember
        send(["op":"login","email":email,"password":password,"remember":remember,"anisette_url":anisette])
    }
    func submitCode(_ code:String) {codeRequired=false;send(["op":"code","code":code])}
    func sendToDevices() {codeRequired=false;send(["op":"send_to_devices"])}
    func sendSMS(_ number:Int) {codeRequired=false;send(["op":"sms","number":number])}
    func resend() {codeRequired=false;send(["op":"resend"])}
    func signOut() {guard !busy else {return};send(["op":"logout","email":email]);defaults.removeObject(forKey:"sideloadEmail");for index in jobs.indices {jobs[index].enabled=false};saveJobs()}
    func cancel() {record("Operación cancelada; puedes volver a intentar.");if let refresh=activeRefresh,let index=jobs.firstIndex(where:{$0.id==refresh.id}) {jobs[index].retryAfter=Date().addingTimeInterval(6*3600);saveJobs()};if let process,process.isRunning {if kill(-process.processIdentifier,SIGTERM) != 0 {process.terminate()}}}
    var canUpdateAppOnly:Bool {
        guard let folder=gameFolder,let version=PreviousPreparation.load(folder:folder,target:"ios")?.version,!version.isEmpty,
              let app=apps.first(where:{$0.id==existing}) else {return false}
        return app.version==version && romfs != nil
    }
    func install(autoRefresh:Bool,includeContent:Bool=true) {
        guard !busy,authenticated,let ipa,let gameFolder,!originalID.isEmpty,!device.isEmpty,!team.isEmpty else {return}
        if !includeContent && !canUpdateAppOnly {error="La versión del juego cambió o no está verificada. Instala la app con sus datos nuevos.";return}
        if autoRefresh && defaults.string(forKey:"sideloadEmail") != email {error="Para renovar al reiniciar, inicia sesión recordándola en el Llavero, o desactiva la renovación.";return}
        guard let effective=RefreshPolicy.identity(original:originalID,team:team,existing:existing) else {error="Ese identificador no corresponde al equipo elegido. Detenido para conservar la app anterior.";return}
        let job=RefreshJob(id:device+":"+effective,ipa:ipa.path,gameFolder:gameFolder.path,originalID:originalID,effectiveID:effective,team:team,udid:device,account:RefreshPolicy.account(email),sha256:"",expires:Date(),enabled:autoRefresh)
        startInstall(job,updating:!existing.isEmpty,content:includeContent ? romfs : nil,appOnly:!includeContent)
    }
    private func startInstall(_ job:RefreshJob,updating:Bool,content:URL?,appOnly:Bool=false) {
        guard FileManager.default.isReadableFile(atPath:job.ipa) else {error="No encontramos la IPA original. Conserva los archivos de preparación para renovarla.";activeRefresh=nil;return}
        if let content,!FileManager.default.fileExists(atPath:content.path) {error="Faltan los datos romfs. Prepara el juego de nuevo antes de instalarlo.";activeRefresh=nil;return}
        installIntent=job;loggedPhase="";loggedBucket = -1;logURL=nil;record("Firmando e instalando…");busy=true;error=nil;startedAt=Date();phase="Firmando e instalando…";fraction=nil
        var value:[String:Any]=["op":"install","ipa":job.ipa,"original_id":job.originalID,"team":job.team,"udid":job.udid,"work":URL(fileURLWithPath:job.gameFolder).appendingPathComponent("nxnative-tools/sideloading").path,"update":updating,"automatic":activeRefresh != nil && !manualRefresh]
        if appOnly {value["app_only"]=true}
        if updating {value["expected_id"]=job.effectiveID}
        if !job.sha256.isEmpty {value["sha256"]=job.sha256}
        if let content {value["romfs"]=content.path}
        send(value)
    }
    private func receive(_ data:Data) {
        pending.append(data);guard pending.count<=2*1024*1024 else {cancel();return}
        while let index=pending.firstIndex(of:10) {
            let line=Data(pending[..<index]);pending.removeSubrange(...index)
            if let event=(try? JSONSerialization.jsonObject(with:line)) as? [String:Any] {handle(event)}
        }
    }
    private func handle(_ event:[String:Any]) {
        switch event["event"] as? String {
        case "hello":helperCapabilities=Set(event["capabilities"] as? [String] ?? []);scopedDiscovery=(event["capabilities"] as? [String] ?? []).contains("scoped-games-v1");if (event["protocol"] as? Int) != 1 || event["architecture"] as? String != "aarch64" {error="El instalador debe compilarse para Apple silicon.";cancel()}
        case "devices":
            devices=SideloadDevice.decode((event["items"] as? [[String:Any]]) ?? []);record("Búsqueda de dispositivos terminada.")
            busy=false
            if let refresh=activeRefresh {continueRefresh(refresh)}
            else {
                if !devices.contains(where:{$0.id==device}) {device="";apps=[];existing=""}
                if device.isEmpty,devices.count==1 {device=devices[0].id}
                if !device.isEmpty {inspectApps()}
            }
        case "installed_apps":
            apps=((event["items"] as? [[String:Any]]) ?? []).compactMap {item in guard let id=item["id"] as? String,appQueryScope.permits(id),let name=item["name"] as? String else {return nil};return InstalledGame(id:id,name:name,version:item["version"] as? String ?? "")}.sorted {$0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending}
            record("Lista de tus juegos actualizada.")
            let matches=apps.filter {$0.id.hasPrefix(originalID)};if existing.isEmpty,matches.count==1 {existing=matches[0].id}
            busy=false
        case "account_devices":
            accountDeviceTeam=event["team"] as? String ?? ""
            accountDevices=((event["items"] as? [[String:Any]]) ?? []).compactMap {item in guard let id=item["udid"] as? String else {return nil};return AccountDevice(id:id,name:item["name"] as? String ?? String(id.suffix(8)),status:item["status"] as? String ?? "")}
            busy=false;record("Dispositivos registrados consultados.")
        case "two_factor":record("Introduce el código de Apple.");codeRequired=true;phase="Introduce el código de Apple.";smsNumbers=((event["numbers"] as? [[String:Any]]) ?? []).compactMap {number in guard let id=number["id"] as? Int,let digits=number["last_digits"] as? String else {return nil};return TrustedSMS(id:id,digits:digits)}
        case "signed_in":
            record("Sesión iniciada. Elige tu equipo personal.");authenticated=true;busy=false;codeRequired=false;error=nil;phase="Sesión iniciada. Elige tu equipo personal."
            if let remember=pendingRemember {if remember {defaults.set(email,forKey:"sideloadEmail");defaults.set(anisette,forKey:"sideloadAnisette")}else{defaults.removeObject(forKey:"sideloadEmail")};pendingRemember=nil}
            teams=((event["teams"] as? [[String:Any]]) ?? []).compactMap {item in guard let id=item["id"] as? String else {return nil};return SideloadTeam(id:id,name:item["name"] as? String ?? id,kind:item["kind"] as? String ?? "")}
            if !teams.contains(where:{$0.id==team}) {team=""}
            for index in jobs.indices where jobs[index].account==RefreshPolicy.account(email) {jobs[index].needsLogin=false};saveJobs()
            if let refresh=activeRefresh {refreshAuthenticated=true;continueRefresh(refresh)}
        case "signed_out":authenticated=false;accountDevices=[];accountDeviceTeam="";teams=[];team="";busy=false
        case "progress":
            let phases=["Exporting saves":"Exportando partidas…","Verifying saves":"Verificando el respaldo…","Registering device":"Registrando el dispositivo con Apple…","Verifying signature":"Verificando firma y vencimiento…","Preparing IPA":"Preparando IPA…","Signing app":"Firmando la app…","Installing app":"Instalando la app…","Copying game data":"Copiando datos del juego…","Game data ready":"Datos del juego listos."]
            phase=phases[event["phase"] as? String ?? ""] ?? phase;if let value=event["fraction"] as? Double,value.isFinite,value>=0,value<=1 {fraction=value}else{fraction=nil}
            let bucket=Int((fraction ?? 0)*10)
            if loggedPhase != phase || loggedBucket != bucket {record(phase,progress:fraction);loggedPhase=phase;loggedBucket=bucket}
        case "saves_exported":
            guard let requested=pendingExport,event["path"] as? String==requested.path,(event["files"] as? Int ?? 0)>0,FileManager.default.isReadableFile(atPath:requested.path) else {error="No pudimos verificar el ZIP exportado.";busy=false;pendingExport=nil;return}
            exportedSaves=requested;pendingExport=nil;busy=false;fraction=1;phase="Partidas exportadas. El juego no se modificó.";record(phase)
        case "content_copied":
            guard let expected=pendingContentID,event["effective_id"] as? String==expected else {error="No pudimos verificar la copia de datos.";busy=false;return}
            pendingContentID=nil;busy=false;fraction=1;phase="Datos del juego copiados. Tus partidas siguen intactas.";record(phase)
        case "installed":
            guard var job=installIntent,let actual=event["effective_id"] as? String,actual==job.effectiveID,let expiry=event["expires"] as? Double,expiry>Date().timeIntervalSince1970,let hash=event["sha256"] as? String,hash.count==64 else {
                error="No pudimos verificar el resultado de la instalación. Revisa el dispositivo antes de continuar.";busy=false;activeRefresh=nil;installIntent=nil;return
            }
            job.expires=Date(timeIntervalSince1970:expiry);job.sha256=hash;job.retryAfter=nil;job.needsLogin=false;jobs.removeAll {$0.id==job.id};jobs.append(job);error=nil;saveJobs();existing=actual
            installIntent=nil;activeRefresh=nil;refreshAuthenticated=false;busy=false;fraction=1;phase="Instalado. Tus partidas se conservan en el dispositivo.";record(phase)
        case "error":
            record("La operación se detuvo. Revisa el mensaje de error.")
            let op=event["operation"] as? String
            let codes=["version_changed":"La versión del juego cambió o no está verificada. Instala la app con sus datos nuevos.","game_running":"El juego sigue abierto. La renovación espera para no interrumpir tu partida.","idle_unknown":"No pudimos comprobar si el juego está abierto. Guarda, ciérralo y renueva manualmente.","identity_mismatch":"Ese identificador no corresponde al equipo elegido. Detenido para conservar la app anterior.","not_installed":"No encontramos esa app instalada. Revisa el identificador antes de actualizar.","wrong_app":"La app elegida no corresponde a este juego. No se instaló encima.","storage":"No hay espacio suficiente para preparar los datos nuevos sin borrar los anteriores.","ipa_changed":"La IPA cambió. Prepara y aprueba la actualización antes de renovarla."]
            error=codes[event["code"] as? String ?? ""] ?? ((op=="login" || op=="restore") ? "No pudimos iniciar sesión o la sesión guardada caducó. Vuelve a iniciar sesión." : "No pudimos completar la instalación. Revisa el dispositivo, equipo y permisos. No se revocaron certificados automáticamente.")
            if op=="export_saves" || op=="copy_romfs" {
                let failures=["game_running":"Guarda y cierra el juego desde el selector de apps antes de continuar.","idle_unknown":"No pudimos verificar que el juego esté cerrado. Guárdalo y ciérralo antes de continuar.","no_saves":"Todavía no encontramos archivos de partida guardados en este juego.","save_changed":"La partida cambió durante la exportación. Cierra el juego y vuelve a intentar.","save_metadata":"Este guardado usa metadatos que la exportación no puede conservar. Usa un respaldo completo del dispositivo.","save_destination":"Elige un ZIP nuevo; no sobrescribimos respaldos.","version_changed":"Actualiza primero la app con la misma versión que los datos preparados.","save_limits":"El guardado supera el límite de exportación de 512 MB u 8192 entradas."]
                error=failures[event["code"] as? String ?? ""] ?? "No pudimos completar la operación. Revisa la conexión y el espacio disponible. Las partidas no se modificaron."
                pendingExport=nil;pendingContentID=nil
            }
            if op=="installed_apps" {apps=[];error=(event["code"] as? String)=="scope_unavailable" ? "No pudimos limitar la consulta a tus juegos. No mostramos otras aplicaciones." : "No pudimos leer tus juegos. Desbloquea el dispositivo, confía en este Mac y vuelve a buscar."}
            if op=="devices" {error="No pudimos buscar dispositivos. Revisa la conexión y vuelve a intentar."}
            if op=="account_devices" {accountDevices=[];accountDeviceTeam="";error="Apple no devolvió los dispositivos de este equipo. Revisa tu sesión y vuelve a consultar."}
            if let code=event["apple_code"] as? Int {error=(error ?? "")+" · Apple: \(code)"}
            if op=="login" || op=="restore" {authenticated=false;pendingRemember=nil}
            if let refresh=activeRefresh,let index=jobs.firstIndex(where:{$0.id==refresh.id}) {jobs[index].retryAfter=Date().addingTimeInterval((event["code"] as? String)=="game_running" ? 600 : 6*3600);jobs[index].needsLogin=(op=="restore");saveJobs()}
            if let error {record(error)}
            activeRefresh=nil;installIntent=nil;refreshAuthenticated=false;codeRequired=false;busy=false
        default:break
        }
    }
    private func saveJobs() {
        do {
            let parent=stateURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at:parent,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
            try FileManager.default.setAttributes([.posixPermissions:0o700],ofItemAtPath:parent.path)
            try JSONEncoder().encode(jobs).write(to:stateURL,options:.atomic)
            try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:stateURL.path)
        } catch {self.error="La instalación terminó, pero no pudimos guardar su renovación automática."}
    }
    func restoreSession() {
        guard !busy,!email.isEmpty,defaults.string(forKey:"sideloadEmail")==email else {return}
        busy=true;error=nil;startedAt=Date();fraction=nil;phase="Renovando sesión guardada…";record(phase)
        send(["op":"restore","email":email,"anisette_url":anisette])
    }
    var hasRememberedSession:Bool {defaults.string(forKey:"sideloadEmail")==email && !email.isEmpty}
    func select(_ job:RefreshJob) {
        guard !busy else {return}
        ipa=URL(fileURLWithPath:job.ipa);gameFolder=URL(fileURLWithPath:job.gameFolder);romfs=nil
        originalID=job.originalID;device=job.udid;team=job.team;existing=job.effectiveID
    }
    func setRefresh(_ job:RefreshJob,enabled:Bool) {
        guard !busy,let index=jobs.firstIndex(where:{$0.id==job.id}) else {return}
        jobs[index].enabled=enabled;saveJobs()
    }
    func forget(_ job:RefreshJob) {
        guard !busy else {return}
        jobs.removeAll {$0.id==job.id};saveJobs()
    }
    func renew(_ job:RefreshJob) {
        guard !busy,canRefresh() else {return}
        guard job.account==RefreshPolicy.account(email) else {error="Inicia sesión con la cuenta que instaló este juego para renovarlo.";return}
        guard hasRememberedSession || authenticated else {error="Inicia sesión para renovar este juego.";return}
        guard job.sha256.count==64 else {error="Falta el registro de la IPA. Prepara y aprueba la actualización antes de renovarla.";return}
        select(job);activeRefresh=job;manualRefresh=true;refreshAuthenticated=authenticated
        error=nil;startedAt=Date();listDevices()
    }
    func reviewRefresh() {
        guard !busy,let job=jobs.first(where:{$0.enabled}) else {return}
        ipa=URL(fileURLWithPath:job.ipa);gameFolder=URL(fileURLWithPath:job.gameFolder);romfs=nil;originalID=job.originalID;device=job.udid;team=job.team;existing=job.effectiveID
        listDevices()
    }
    func checkRefresh() {
        guard !busy,activeRefresh==nil,canRefresh(),!email.isEmpty,defaults.string(forKey:"sideloadEmail") != nil else {return}
        guard let job=jobs.first(where:{RefreshPolicy.due($0,now:Date(),account:RefreshPolicy.account(email))}) else {return}
        activeRefresh=job;manualRefresh=false;refreshAuthenticated=false;listDevices()
    }
    private func continueRefresh(_ job:RefreshJob) {
        guard devices.contains(where:{$0.id==job.udid}) else {if manualRefresh {error="Conecta y desbloquea el dispositivo donde instalaste este juego."};activeRefresh=nil;return}
        guard teams.contains(where:{$0.id==job.team}) || !refreshAuthenticated else {error="La cuenta actual no tiene el equipo original de este juego. No cambiamos su identidad.";activeRefresh=nil;return}
        if !refreshAuthenticated {busy=true;phase="Renovando sesión guardada…";send(["op":"restore","email":email,"anisette_url":anisette])}
        else {startInstall(job,updating:true,content:nil)}
    }
    func setLoginItem(_ enabled:Bool) {
        do {if enabled {try SMAppService.mainApp.register();if SMAppService.mainApp.status == .requiresApproval {SMAppService.openSystemSettingsLoginItems()}}else{try SMAppService.mainApp.unregister()}}
        catch {self.error="Revisa Elementos de inicio en Ajustes del Sistema para permitir la renovación al iniciar sesión."}
    }
}

struct SideloadView:View {
    @ObservedObject var model:SideloadModel
    let text:(String)->String
    var accountOnly=false
    var embedded=false
    @Environment(\.dismiss) private var dismiss
    @State private var password=""
    @State private var code=""
    @State private var remember=true
    @State private var autoRefresh=true
    @State private var loginItem=SMAppService.mainApp.status == .enabled
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:16) {
                HStack {Text(text(accountOnly || model.ipa==nil ? "Tu cuenta Apple" : "Instalar en iPhone / iPad")).font(.title2.bold());Spacer();if !embedded {Button(text("Cerrar")){dismiss()}.disabled(model.busy)}}
                if !accountOnly {
                HStack(spacing:18) {
                    Label(text("1 · Dispositivo"),systemImage:model.device.isEmpty ? "circle" : "checkmark.circle.fill")
                    Label(text("2 · Cuenta Apple"),systemImage:model.authenticated ? "checkmark.circle.fill" : "circle")
                    Label(text("3 · Instalar"),systemImage:"arrow.down.app")
                }.font(.caption).foregroundStyle(.secondary)
                if let folder=model.gameFolder {Text(folder.lastPathComponent).font(.headline)}
                Text(text("Conecta tu dispositivo e inicia sesión. Firmar e instalar requiere tu confirmación.")).foregroundStyle(.secondary)
                Picker(text("Dispositivo"),selection:$model.device) {Text(text("Elige tu iPhone/iPad")).tag("");ForEach(model.devices){Text($0.name).tag($0.id)}}.disabled(model.busy)
                    .onChange(of:model.device) {_,_ in model.existing="";model.inspectApps()}
                if let selected=model.devices.first(where:{$0.id==model.device}),!selected.detail.isEmpty {Text(selected.detail).font(.caption).foregroundStyle(.secondary)}
                Button(text("Buscar dispositivos")){model.listDevices()}.disabled(model.busy)
                Text(text("Desbloquea el dispositivo, confía en este Mac y activa Modo de desarrollador si iOS lo pide.")) .font(.caption).foregroundStyle(.secondary)
                }
                if accountOnly {Text(text("Una cuenta para todos tus dispositivos en este Mac. Sólo se necesita para firmar, instalar y renovar apps.")).foregroundStyle(.secondary)}
                if !model.authenticated {
                    LabeledContent(text("Cuenta Apple personal")){TextField("name@example.com",text:$model.email).textFieldStyle(.roundedBorder).disabled(model.busy)}
                    LabeledContent(text("Contraseña de Apple")){SecureField(text("Contraseña de Apple"),text:$password).textFieldStyle(.roundedBorder).disabled(model.busy)}
                    Toggle(text("Recordar sesión en el Llavero; no guardar la contraseña"),isOn:$remember).disabled(model.busy).onChange(of:remember){_,value in if !value {autoRefresh=false}}
                    DisclosureGroup(text("Servicio de autenticación")) {
                        Text(text("La contraseña y el código se envían a Apple. El servicio anisette recibe los datos técnicos que requiere la autenticación, no tu contraseña.")) .font(.caption)
                        TextField("Anisette HTTPS",text:$model.anisette).disabled(model.busy)
                    }
                    if model.hasRememberedSession {Button(text("Usar sesión del Llavero")){model.restoreSession()}.disabled(model.busy)}
                    Button(text("Iniciar sesión")){model.signIn(password:password,remember:remember);password=""}.buttonStyle(.borderedProminent).disabled(model.busy || model.email.isEmpty || password.isEmpty)
                } else {
                    Label(text("Sesión iniciada"),systemImage:"person.crop.circle.badge.checkmark")
                    Text(model.email).font(.caption).textSelection(.enabled)
                    Picker(text("Tu equipo personal"),selection:$model.team) {Text(text("Selecciona tu equipo")).tag("");ForEach(model.teams){Text($0.name+" · "+$0.id).tag($0.id)}}.disabled(model.busy)
                    if let selected=model.teams.first(where:{$0.id==model.team}),!selected.kind.isEmpty {Text(text("Tipo de equipo según Apple")+": "+selected.kind).font(.caption).foregroundStyle(.secondary)}
                    Button(text("Leer dispositivos de mi cuenta Apple")){model.inspectAccountDevices()}.disabled(model.busy || model.team.isEmpty)
                    if model.accountDeviceTeam==model.team {
                        Text(text("Dispositivos registrados en el equipo")+": "+String(model.accountDevices.count)).font(.headline)
                        ForEach(model.accountDevices) {item in Text(item.name+" · …"+String(item.id.suffix(8))+" · "+item.status).font(.caption)}
                    }
                    Text(text("Cuenta gratuita: Apple indica hasta 3 dispositivos y perfiles de 7 días. Esta lista muestra registros reales; no calcula cupos libres ni elimina dispositivos.")).font(.caption).foregroundStyle(.secondary)
                    if !accountOnly && model.ipa != nil {
                    Picker(text("App existente que actualizarás"),selection:$model.existing) {Text(text("Primera instalación")).tag("");ForEach(model.apps){Text($0.name+" · "+$0.id).tag($0.id)}}.disabled(model.busy)
                    Text(text("Se conserva el identificador efectivo. Si no corresponde al juego y equipo, la instalación se detiene; no se desinstala la app anterior.")) .font(.caption).foregroundStyle(.secondary)
                    Toggle(text("Renovar automáticamente antes de que caduque"),isOn:$autoRefresh).disabled(model.busy || !remember)
                    Toggle(text("Abrir nxnative Easy al iniciar sesión"),isOn:$loginItem).onChange(of:loginItem){_,value in model.setLoginItem(value)}.disabled(model.busy)
                    Text(text("La renovación necesita este Mac encendido, nxnative Easy abierto, conexión a Internet y el dispositivo accesible. Conserva la IPA original.")) .font(.caption).foregroundStyle(.secondary)
                    Button(text(model.existing.isEmpty ? "Firmar e instalar" : "Firmar y actualizar")){model.install(autoRefresh:autoRefresh)}.buttonStyle(.borderedProminent).disabled(model.busy || model.device.isEmpty || model.team.isEmpty || model.originalID.isEmpty)
                    }
                    if !accountOnly && model.canUpdateAppOnly {
                        Button(text("Actualizar sólo la app; conservar romfs")){model.install(autoRefresh:autoRefresh,includeContent:false)}.disabled(model.busy)
                        Text(text("Para cambios de controles o de la app con la misma versión del juego. Si cambió el juego o DLC, usa la instalación con datos nuevos.")).font(.caption).foregroundStyle(.secondary)
                    }
                    Button(text("Cerrar sesión")){model.signOut()}.disabled(model.busy)
                }
                if model.codeRequired {
                    TextField(text("Código de verificación"),text:$code)
                    HStack {Button(text("Confirmar código")){model.submitCode(code);code=""};Button(text("Reenviar código")){model.resend()}}
                    Button(text("Enviar a mis dispositivos")){model.sendToDevices()}
                    ForEach(model.smsNumbers) {number in Button("SMS · …"+number.digits){model.sendSMS(number.id)}}
                }
                if !accountOnly {Text(text("Guarda y cierra el juego antes de instalar. Firma, copia y renovación nativas aún requieren validación completa con una cuenta y dispositivo reales.")).font(.caption).foregroundStyle(.secondary)}
                InstallActivityView(model:model,text:text)
                if !model.busy {Text(text(model.phase)).font(.callout)}
            }.padding(24)
        }.frame(maxWidth:.infinity,maxHeight:.infinity).frame(width:embedded ? nil : 760,height:embedded ? nil : 720).tint(Color(red:0.79,green:0.95,blue:0.37)).preferredColorScheme(.dark).interactiveDismissDisabled(model.busy)
    }
}


struct SideloadLibraryView:View {
    @ObservedObject var model:SideloadModel
    let text:(String)->String
    let canInstall:Bool
    var prepareGame:()->Void={}
    var embedded=false
    var artwork:(InstalledGame)->NSImage?={_ in nil}
    @Environment(\.dismiss) private var dismiss
    @State private var showInstaller=false
    @State private var accountOnly=false
    private enum Confirmation {case export(InstalledGame),copy(InstalledGame),forget(RefreshJob)}
    @State private var confirmation:Confirmation?
    @State private var search=""
    @State private var appLimit=8
    private var matchingApps:[InstalledGame] {model.apps.filter {search.isEmpty || ($0.name+" "+$0.id).localizedCaseInsensitiveContains(search)}}
    private let accent=Color(red:0.79,green:0.95,blue:0.37)
    private var confirmationTitle:String {
        switch confirmation {case .export:return "Exportar partidas";case .copy:return "Copiar datos del juego";case .forget:return "¿Quitar este registro?";case nil:return ""}
    }
    private func confirmationMessage(_ action:Confirmation)->String {
        switch action {
        case .export:return "Guarda tu progreso y cierra el juego desde el selector de apps. Copiaremos save y save_device a un ZIP local, sin modificar el dispositivo."
        case .copy:return "Copiaremos el romfs preparado en este Mac al juego seleccionado. Conservamos tus partidas y no reinstalamos la app. Mantén el juego cerrado hasta terminar."
        case .forget:return "Sólo detiene la renovación y quita el registro de este Mac. El juego, sus archivos y sus partidas siguen en tu dispositivo."
        }
    }
    private func prepare() {prepareGame();if !embedded {dismiss()}}
    var body:some View {
        VStack(spacing:0) {
            HStack(alignment:.top) {
                VStack(alignment:.leading,spacing:6) {
                    Label(text("Mis iPhones y iPads"),systemImage:"ipad.and.iphone").font(.title2.bold())
                    Text(text("Conecta. Elige tu juego. Instala o actualiza.")).foregroundStyle(.secondary)
                }
                Spacer();if !embedded {Button(text("Cerrar")){dismiss()}.disabled(model.busy)}
            }.padding(24)
            Divider()
            ScrollView {
                VStack(alignment:.leading,spacing:20) {
                    Text(text("Exportar partidas y copiar romfs no requieren iniciar sesión con Apple. Sólo conecta y autoriza tu dispositivo.")).font(.callout).foregroundStyle(.secondary)
                    HStack {
                        Label(text("Dispositivos conectados"),systemImage:"cable.connector").font(.headline)
                        Spacer();Button(text("Buscar dispositivos")){model.listDevices()}.disabled(model.busy || !canInstall)
                    }
                    if model.devices.isEmpty && !model.busy {
                        VStack(alignment:.leading,spacing:10) {
                            Text(text("Conecta tu iPhone o iPad")).font(.headline)
                            Text(text("Desbloquea el dispositivo, confía en este Mac y activa Modo de desarrollador si iOS lo pide.")).foregroundStyle(.secondary)
                            Button(text("Buscar dispositivos")){model.listDevices()}
                        }.padding(18).frame(maxWidth:.infinity,minHeight:136,alignment:.topLeading).background(.white.opacity(0.04),in:RoundedRectangle(cornerRadius:14))
                    }
                    ForEach(model.devices) {device in
                        Button {model.openDevice(device.id)} label:{
                            HStack(spacing:14) {
                                Image(systemName:device.kind=="iPad" ? "ipad" : "iphone").font(.system(size:30)).foregroundStyle(accent).frame(width:42)
                                VStack(alignment:.leading,spacing:5) {Text(device.name).font(.headline);Text(device.detail.isEmpty ? text("Información del dispositivo no disponible") : device.detail).font(.caption).foregroundStyle(.secondary);if !device.ready {Text(text("Desbloquea y confía en este Mac para leer las apps.")).font(.caption).foregroundStyle(.orange)}}
                                Spacer();Image(systemName:model.device==device.id ? "checkmark.circle.fill" : "circle").foregroundStyle(model.device==device.id ? accent : .secondary)
                            }.padding(16).background(model.device==device.id ? accent.opacity(0.08) : .white.opacity(0.035),in:RoundedRectangle(cornerRadius:14))
                        }.buttonStyle(.plain).disabled(model.busy || !canInstall)
                    }
                        VStack(alignment:.leading,spacing:10) {
                            Label(text("Instalar otro juego"),systemImage:"plus.app").font(.headline)
                            Text(text("Elige tus archivos; prepararemos el juego y abriremos el instalador al terminar.")).foregroundStyle(.secondary)
                            Button(text("Elegir carpeta de juego")){model.cancelPendingUpdate();prepare()}.disabled(model.busy || !canInstall)
                        }.padding(18).frame(maxWidth:.infinity,minHeight:136,alignment:.topLeading).background(.white.opacity(0.04),in:RoundedRectangle(cornerRadius:14))
                    if !model.device.isEmpty {
                        HStack {Label(text("Tus juegos instalados"),systemImage:"square.grid.2x2").font(.headline);Spacer();Text(String(model.apps.count)).foregroundStyle(.secondary)}
                        TextField(text("Buscar por nombre o identificador"),text:$search).textFieldStyle(.roundedBorder)
                        if model.apps.isEmpty && !model.busy {Text(text("No encontramos juegos vinculados. Añade su carpeta preparada a la biblioteca y vuelve a buscar.")).foregroundStyle(.secondary)}
                        ForEach(Array(matchingApps.prefix(appLimit))) {app in
                            HStack(spacing:12) {
                                if let image=artwork(app) {Image(nsImage:image).resizable().scaledToFill().frame(width:76,height:50).clipped().clipShape(RoundedRectangle(cornerRadius:8))}
                                else {Image(systemName:"gamecontroller").font(.title2).frame(width:76,height:50).background(.white.opacity(0.04),in:RoundedRectangle(cornerRadius:8))}
                                VStack(alignment:.leading,spacing:4) {Text(app.name).font(.headline);Text(app.id+(app.version.isEmpty ? "" : " · "+app.version)).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)}
                                Spacer()
                                VStack(alignment:.trailing,spacing:7) {
                                    Button(text("Actualizar con mis archivos")){model.prepareUpdate(app);prepare()}
                                    HStack {
                                        Button(text("Exportar partidas")){confirmation = .export(app)}.disabled(!model.supportsSaveExport)
                                        if model.dataFolder(for:app) != nil {Button(text("Copiar datos del juego")){confirmation = .copy(app)}.disabled(!model.supportsContentCopy)}
                                    }.font(.caption)
                                }.disabled(model.busy || !canInstall)
                            }.padding(.vertical,6)
                            Divider()
                        }
                        if matchingApps.count>appLimit {Button(text("Mostrar más juegos")+" · "+String(min(appLimit,matchingApps.count))+" / "+String(matchingApps.count)){appLimit+=8}}
                        Text(text("Actualizar requiere tus archivos del mismo juego y la cuenta/equipo originales. No desinstalamos la app existente.")).font(.caption).foregroundStyle(.secondary)
                    }
                    if !model.jobs.isEmpty {
                        Label(text("Firmas y renovación"),systemImage:"arrow.clockwise.circle").font(.headline)
                        ForEach(model.jobs.filter {model.device.isEmpty || $0.udid==model.device}.sorted {$0.expires<$1.expires}) {job in
                            VStack(alignment:.leading,spacing:10) {
                                Text(URL(fileURLWithPath:job.ipa).deletingPathExtension().lastPathComponent).font(.headline)
                                Text(job.effectiveID).font(.caption).textSelection(.enabled)
                                Text(text(job.expires<=Date() ? "Firma vencida" : "La firma vence")+" "+job.expires.formatted(date:.abbreviated,time:.shortened)).font(.caption)
                                if job.needsLogin {Text(text("Inicia sesión para renovar este juego.")).foregroundStyle(.orange)}
                                Toggle(text("Renovar automáticamente antes de que caduque"),isOn:Binding(get:{model.jobs.first(where:{$0.id==job.id})?.enabled ?? false},set:{model.setRefresh(job,enabled:$0)}))
                                HStack {Button(text("Renovar ahora")){model.renew(job)};Button(text("Revisar cuenta e instalación")){model.select(job);accountOnly=false;showInstaller=true};Spacer();Button(text("Quitar de esta lista")){confirmation = .forget(job)}}
                            }.padding(16).background(.white.opacity(0.04),in:RoundedRectangle(cornerRadius:14)).disabled(model.busy || !canInstall)
                        }
                    }
                    InstallActivityView(model:model,text:text)
                }.padding(24)
            }
        }.frame(width:embedded ? nil : 850,height:embedded ? nil : 730).frame(maxWidth:.infinity,maxHeight:.infinity).background(Color(red:0.065,green:0.075,blue:0.07)).preferredColorScheme(.dark).interactiveDismissDisabled(model.busy)
        .onChange(of:search){_,_ in appLimit=8}
        .onChange(of:model.device){_,_ in appLimit=8}
        .task {if canInstall && !model.busy {model.listDevices()}}
        .sheet(isPresented:$showInstaller){SideloadView(model:model,text:text,accountOnly:accountOnly)}
        .alert(text(confirmationTitle),isPresented:Binding(get:{confirmation != nil},set:{if !$0 {confirmation=nil}}),presenting:confirmation) {action in
            Button(text("Cancelar"),role:.cancel){confirmation=nil}
            switch action {
            case .export(let app):
                Button(text("Ya guardé y cerré el juego")){confirmation=nil;DispatchQueue.main.async {model.chooseSaveDestination(app,text:text)}}
            case .copy(let app):
                Button(text("Ya guardé y cerré el juego")){confirmation=nil;model.copyData(app,confirmedClosed:true)}
            case .forget(let job):
                Button(text("Quitar de esta lista"),role:.destructive){model.forget(job);confirmation=nil}
            }
        } message:{action in Text(text(confirmationMessage(action)))}

    }
}

struct InstallActivityView:View {
    @ObservedObject var model:SideloadModel
    let text:(String)->String
    @State private var expanded=true
    var body:some View {
        VStack(alignment:.leading,spacing:10) {
            if model.busy {
                HStack {Text(text(model.phase)).font(.headline);Spacer();Button(text("Cancelar")){model.cancel()}}
                if let fraction=model.fraction {ProgressView(value:fraction);Text(String(Int(fraction*100))+" %").font(.caption.monospacedDigit())}else{ProgressView().progressViewStyle(.linear)}
                TimelineView(.periodic(from:.now,by:1)){context in Text(text("Tiempo transcurrido")+" "+String(Int(context.date.timeIntervalSince(model.startedAt ?? context.date)))+" s").font(.caption).foregroundStyle(.secondary)}
            }
            if let error=model.error {Label(text(error),systemImage:"exclamationmark.triangle").foregroundStyle(.orange).textSelection(.enabled)}
            if let export=model.exportedSaves {Button(text("Mostrar ZIP de partidas")){NSWorkspace.shared.activateFileViewerSelecting([export])}}
            if !model.logs.isEmpty {
                DisclosureGroup(text("Actividad de instalación"),isExpanded:$expanded) {
                    HStack {Button(text("Copiar registro")){model.copyLogs(text:text)};if let url=model.logURL {Button(text("Mostrar registro guardado")){NSWorkspace.shared.activateFileViewerSelecting([url])}};Spacer()}
                    ScrollView {LazyVStack(alignment:.leading,spacing:5) {ForEach(model.logs) {entry in Text(entry.date.formatted(date:.omitted,time:.standard)+" · "+text(entry.message)+(entry.progress.map{" · "+String(Int($0*100))+" %"} ?? "")).font(.system(size:11,design:.monospaced)).textSelection(.enabled)}}.frame(maxWidth:.infinity,alignment:.leading)}.frame(height:160)
                }
            }
        }
    }
}
