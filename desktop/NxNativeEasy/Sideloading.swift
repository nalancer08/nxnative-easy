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
struct SideloadTeam:Identifiable {let id:String;let name:String;var kind:String="";var freeDeviceLimit:Int?}
enum DeviceRegistrationState {case unknown,registered,new}
enum AccountRegistrationPolicy {
    static func remaining(limit:Int?,devices:[AccountDevice])->Int? {
        guard limit==3 else {return nil}
        return max(0,3-Set(devices.map{$0.id.lowercased()}).count)
    }
    static func state(team:String,loadedTeam:String,checkedAt:Date?,device:String,devices:[AccountDevice],now:Date=Date())->DeviceRegistrationState {
        guard !team.isEmpty,team==loadedTeam,!device.isEmpty,let checkedAt,now.timeIntervalSince(checkedAt)>=0,now.timeIntervalSince(checkedAt)<=300 else {return .unknown}
        return devices.contains(where:{$0.id.caseInsensitiveCompare(device) == .orderedSame}) ? .registered : .new
    }
}
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

struct DeviceGameObservation:Codable,Identifiable {
    var id:String {device+":"+bundleID}
    let device:String
    let deviceName:String
    let bundleID:String
    let titleID:String?
    let version:String
    let checkedAt:Date?
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
    @Published private(set) var deviceGames:[DeviceGameObservation]=[]
    private var presenceWritable=true
    private var verifiedDevices:Set<String>=[]
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
    @Published var accountDeviceLimit:Int?
    @Published var accountDevicesCheckedAt:Date?
    @Published var logs:[InstallLog]=[]
    @Published var logURL:URL?
    private var pendingUpdate:(device:String,id:String)?
    private var loggedPhase=""
    private var loggedBucket = -1
    @Published var device="" {didSet {if device != oldValue {completedInstallation=false}}}
    @Published var team="" {
        didSet {
            if team != oldValue {completedInstallation=false}
            if authenticated,hasRememberedSession,teams.contains(where:{$0.id==team}) {defaults.set(team,forKey:"sideloadTeam."+RefreshPolicy.account(email))}
        }
    }
    @Published var existing=""
    @Published var email=""
    @Published var anisette="https://ani.iloader.app"
    @Published var authenticated=false
    @Published private(set) var completedInstallation=false
    @Published private(set) var increasedMemoryLimit:Bool?
    @Published private(set) var recoveringSession=false
    private var recoveryRequested=false
    private var automaticRecoveryAttempted=false
    @Published var busy=false {
        didSet {if !busy && recoveryRequested {Task {@MainActor [weak self] in self?.recoverRememberedSessionIfNeeded()}}}
    }
    @Published var codeRequired=false
    @Published var smsNumbers:[TrustedSMS]=[]
    @Published var error:String?
    @Published var phase="Conecta y desbloquea tu iPhone/iPad."
    @Published var connectionSummary=""
    @Published var fraction:Double?
    @Published var startedAt:Date?
    @Published var jobs:[RefreshJob]=[]
    var canRefresh:()->Bool={true}
    var ipa:URL?
    var gameFolder:URL?
    var romfs:URL?
    var originalID=""
    private var installerLease:Int32 = -1
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
        let presence=self.stateURL.deletingLastPathComponent().appendingPathComponent("device-games.json")
        if FileManager.default.fileExists(atPath:presence.path) {
            if let data=try? Data(contentsOf:presence),data.count<=1048576,let saved=try? JSONDecoder().decode([DeviceGameObservation].self,from:data),saved.count<=2000 {deviceGames=saved}else{presenceWritable=false}
        }
        if let data=try? Data(contentsOf:self.stateURL),let saved=try? JSONDecoder().decode([RefreshJob].self,from:data) {jobs=saved}
        terminationObserver=NotificationCenter.default.addObserver(forName:NSApplication.willTerminateNotification,object:nil,queue:.main) { [weak self] _ in MainActor.assumeIsolated {self?.cancel()} }
        timer=Timer.publish(every:1800,on:.main,in:.common).autoconnect().sink { [weak self] _ in Task {@MainActor in self?.checkRefresh()}}
    }
    func configure(ipa:URL,folder:URL,romfs:URL?) {
        completedInstallation=false;increasedMemoryLimit=nil
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
    func observations(titleID:String?,originalID:String?)->[DeviceGameObservation] {
        let related=jobs.filter {job in
            (originalID != nil && job.originalID==originalID) || (titleID != nil && SaveLocations.titleID(folder:URL(fileURLWithPath:job.gameFolder))==titleID)
        }
        let known=Set(related.map {$0.effectiveID})
        var result=deviceGames.filter {item in (titleID != nil && item.titleID==titleID) || (originalID != nil && item.bundleID==originalID) || known.contains(item.bundleID)}
        // Older releases persisted receipts but not presence. Keep these historical,
        // without inventing an installation date/version or overriding a fresh negative query.
        for job in related where job.sha256.count==64 && !verifiedDevices.contains(job.udid) {
            guard !result.contains(where:{$0.device==job.udid && $0.bundleID==job.effectiveID}) else {continue}
            let name=devices.first(where:{$0.id==job.udid})?.name ?? deviceGames.first(where:{$0.device==job.udid})?.deviceName ?? "iPhone / iPad"
            result.append(DeviceGameObservation(device:job.udid,deviceName:name,bundleID:job.effectiveID,titleID:titleID,version:"",checkedAt:nil))
        }
        return result.sorted {($0.checkedAt ?? .distantPast)>($1.checkedAt ?? .distantPast)}
    }
    func isVerified(_ item:DeviceGameObservation)->Bool {item.checkedAt != nil && verifiedDevices.contains(item.device) && devices.contains(where:{$0.id==item.device})}
    private func savePresence() {
        guard presenceWritable else {return}
        let file=stateURL.deletingLastPathComponent().appendingPathComponent("device-games.json")
        do {
            try FileManager.default.createDirectory(at:file.deletingLastPathComponent(),withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
            try JSONEncoder().encode(deviceGames).write(to:file,options:.atomic)
            try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:file.path)
        }catch{}
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
    var hasPendingUpdate:Bool {pendingUpdate != nil}
    func cancelPendingUpdate() {pendingUpdate=nil}
    func prepareUpdate(_ app:InstalledGame) {guard !busy,!device.isEmpty else {return};pendingUpdate=(device,app.id);gameFolder=titleID(for:app).flatMap {preparedFolders[$0]}}
    func openDevice(_ id:String) {
        guard !busy else {return}
        device=id;existing="";apps=[];inspectApps()
    }
    var estimatedDeviceSlots:Int? {accountDeviceTeam==team ? AccountRegistrationPolicy.remaining(limit:accountDeviceLimit,devices:accountDevices) : nil}
    var registrationState:DeviceRegistrationState {AccountRegistrationPolicy.state(team:team,loadedTeam:accountDeviceTeam,checkedAt:accountDevicesCheckedAt,device:device,devices:accountDevices)}
    func accountDeviceName(_ item:AccountDevice)->String {
        if let known=devices.first(where:{$0.id.caseInsensitiveCompare(item.id) == .orderedSame}) {return known.name}
        if item.name.hasPrefix("device-") || item.name==item.id {return "iPhone / iPad · …"+String(item.id.suffix(6))}
        return item.name
    }
    func inspectAccountDevices() {
        guard !busy,authenticated,!team.isEmpty else {return}
        busy=true;error=nil;startedAt=Date();fraction=nil;phase="Consultando dispositivos registrados en Apple…";accountDevices=[];accountDeviceTeam="";accountDeviceLimit=nil;accountDevicesCheckedAt=nil;record(phase)
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
        if installerLease>=0 {Darwin.close(installerLease);installerLease = -1}
        guard let acquired=InstallerLease.acquire(at:stateURL.appendingPathExtension("lock")) else {error="Hay una instalación o renovación en curso. Intenta de nuevo en un momento.";busy=false;return}
        installerLease=acquired
        guard let root=Bundle.main.executableURL?.deletingLastPathComponent() else {return}
        let helper=helperURL ?? root.appendingPathComponent("nxnative-sideload")
        guard FileManager.default.isExecutableFile(atPath:helper.path) else {Darwin.close(installerLease);installerLease = -1;error="Falta el instalador nativo. Actualiza nxnative Easy.";return}
        let task=Process(),pipe=Pipe(),requests=Pipe();task.executableURL=helper
        task.standardOutput=pipe;task.standardError=FileHandle.nullDevice;task.standardInput=requests
        var environment=ProcessInfo.processInfo.environment;environment.removeValue(forKey:"RUST_LOG");environment.removeValue(forKey:"RUST_BACKTRACE");task.environment=environment
        input=requests.fileHandleForWriting;pending=Data()
        pipe.fileHandleForReading.readabilityHandler={ [weak self] handle in
            let data=handle.availableData;if data.isEmpty {handle.readabilityHandler=nil;return}
            Task {@MainActor in self?.receive(data)}
        }
        task.terminationHandler={ [weak self] finished in Task {@MainActor in
            guard let self,self.process === finished else {return}
            let recovering=self.recoveringSession
            if self.installerLease>=0 {Darwin.close(self.installerLease);self.installerLease = -1}
            self.process=nil;self.input=nil;self.scopedDiscovery=false;self.authenticated=false;self.codeRequired=false;self.recoveringSession=false;self.pendingRemember=nil
            if self.busy {self.error=recovering ? "No pudimos recuperar la sesión guardada. Revisa Internet y el acceso al Llavero, o vuelve a iniciar sesión." : "Instalación detenida. Vuelve a intentar; las partidas no se tocaron."}
            self.busy=false;self.activeRefresh=nil;self.installIntent=nil;self.refreshAuthenticated=false
        }}
        do {process=task;try task.run()}
        catch {Darwin.close(installerLease);installerLease = -1;process=nil;input=nil;self.error="No pudimos iniciar el instalador nativo."}
    }
    private func send(_ value:[String:Any]) {
        connect();guard let input,let process,process.isRunning else {recoveringSession=false;busy=false;return}
        do {var data=try JSONSerialization.data(withJSONObject:value);data.append(10);try input.write(contentsOf:data)}
        catch {self.error="No pudimos comunicarnos con el instalador.";recoveringSession=false;busy=false}
    }
    private func textConnection(_ reachable:Bool?)->String {reachable==true ? "✓" : reachable==false ? "✗" : "—"}
    func checkConnections() {
        guard !busy,!device.isEmpty else{return}
        busy=true;connectionSummary="";startedAt=Date();phase="Comprobando USB y Wi-Fi…"
        send(["op":"connection_diagnostics","udid":device])
    }
    func listDevices() {guard !busy else {return};error=nil;busy=true;startedAt=Date();fraction=nil;phase="Buscando dispositivos conectados…";record(phase);send(["op":"devices"])}
    func inspectApps() {
        guard !busy,!device.isEmpty else {return}
        var originals=Set(preparedIdentifiers)
        if !originalID.isEmpty {originals.insert(originalID)}
        let scope=GameAppScope(originals:originals,known:Set(jobs.filter{$0.udid==device}.map(\.effectiveID)))
        verifiedDevices.remove(device)
        apps=[];appQueryScope=scope
        guard !scope.isEmpty else {phase="Añade la carpeta preparada del juego para reconocer instalaciones anteriores.";return}
        guard scopedDiscovery else {error="Actualiza la app para buscar juegos sin consultar otras aplicaciones.";return}
        busy=true;startedAt=Date();fraction=nil;phase="Buscando tus juegos instalados…";record(phase)
        send(["op":"installed_apps","udid":device,"original_ids":scope.originals.sorted(),"known_ids":scope.known.sorted()])
    }

    func signIn(password:String,remember:Bool) {
        guard !busy,!email.isEmpty,!password.isEmpty else {return}
        recoveryRequested=false;automaticRecoveryAttempted=true;recoveringSession=false
        email=email.trimmingCharacters(in:.whitespacesAndNewlines).lowercased()
        busy=true;error=nil;startedAt=Date();fraction=nil;phase="Iniciando sesión con Apple…"
        record("Iniciando sesión con Apple…")
        pendingRemember=remember
        send(["op":"login","email":email,"password":password,"remember":remember,"anisette_url":anisette])
    }
    func submitCode(_ code:String) {phase="Verificando código…";codeRequired=false;send(["op":"code","code":code])}
    func sendToDevices() {phase="Solicitando un nuevo código…";codeRequired=false;send(["op":"send_to_devices"])}
    func sendSMS(_ number:Int) {phase="Solicitando un nuevo código…";codeRequired=false;send(["op":"sms","number":number])}
    func resend() {phase="Solicitando un nuevo código…";codeRequired=false;send(["op":"resend"])}
    func signOut() {guard !busy else {return};connect();guard process?.isRunning==true else{return};recoveryRequested=false;automaticRecoveryAttempted=true;defaults.removeObject(forKey:"sideloadTeam."+RefreshPolicy.account(email));send(["op":"logout","email":email]);defaults.removeObject(forKey:"sideloadEmail");for index in jobs.indices {jobs[index].enabled=false};saveJobs()}
    func cancel() {recoveryRequested=false;automaticRecoveryAttempted=true;pendingRemember=nil;record("Operación cancelada; puedes volver a intentar.");if let refresh=activeRefresh,let index=jobs.firstIndex(where:{$0.id==refresh.id}) {jobs[index].retryAfter=Date().addingTimeInterval(6*3600);saveJobs()};if let process,process.isRunning {if kill(-process.processIdentifier,SIGTERM) != 0 {process.terminate()}}}
    var canUpdateAppOnly:Bool {
        guard let folder=gameFolder,let version=PreviousPreparation.load(folder:folder,target:"ios")?.version,!version.isEmpty,
              let app=apps.first(where:{$0.id==existing}) else {return false}
        return app.version==version && romfs != nil
    }
    func install(autoRefresh:Bool,includeContent:Bool=true,approveRegistration:Bool=false) {
        guard !busy,authenticated,let ipa,let gameFolder,!originalID.isEmpty,!device.isEmpty,!team.isEmpty else {return}
        if !includeContent && !canUpdateAppOnly {error="La versión del juego cambió o no está verificada. Instala la app con sus datos nuevos.";return}
        if autoRefresh && defaults.string(forKey:"sideloadEmail") != email {error="Para renovar al reiniciar, inicia sesión recordándola en el Llavero, o desactiva la renovación.";return}
        guard let effective=RefreshPolicy.identity(original:originalID,team:team,existing:existing) else {error="Ese identificador no corresponde al equipo elegido. Detenido para conservar la app anterior.";return}
        let job=RefreshJob(id:device+":"+effective,ipa:ipa.path,gameFolder:gameFolder.path,originalID:originalID,effectiveID:effective,team:team,udid:device,account:RefreshPolicy.account(email),sha256:"",expires:Date(),enabled:autoRefresh)
        startInstall(job,updating:!existing.isEmpty,content:includeContent ? romfs : nil,appOnly:!includeContent,approveRegistration:approveRegistration)
    }
    private func startInstall(_ job:RefreshJob,updating:Bool,content:URL?,appOnly:Bool=false,approveRegistration:Bool=false) {
        guard helperCapabilities.contains("registration-consent-v1") else {error="Actualiza el instalador para comprobar el registro del dispositivo.";activeRefresh=nil;return}
        guard FileManager.default.isReadableFile(atPath:job.ipa) else {error="No encontramos la IPA original. Conserva los archivos de preparación para renovarla.";activeRefresh=nil;return}
        if let content,!FileManager.default.fileExists(atPath:content.path) {error="Faltan los datos romfs. Prepara el juego de nuevo antes de instalarlo.";activeRefresh=nil;return}
        completedInstallation=false
        installIntent=job;loggedPhase="";loggedBucket = -1;logURL=nil;record("Firmando e instalando…");busy=true;error=nil;startedAt=Date();phase="Firmando e instalando…";fraction=nil
        var value:[String:Any]=["op":"install","ipa":job.ipa,"original_id":job.originalID,"team":job.team,"udid":job.udid,"work":URL(fileURLWithPath:job.gameFolder).appendingPathComponent("nxnative-tools/sideloading").path,"update":updating,"automatic":activeRefresh != nil && !manualRefresh]
        value["approve_registration"]=approveRegistration && activeRefresh==nil
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
        case "connection_diagnostics":
            guard event["udid"] as? String==device else{return}
            let results=(event["items"] as? [[String:Any]]) ?? []
            connectionSummary=["USB","Wi-Fi"].map {kind in kind+": "+textConnection(results.first {$0["connection"] as? String==kind}?["reachable"] as? Bool)}.joined(separator:" · ")
            busy=false;phase="Comprobación de conexión terminada.";record(phase)
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
            deviceGames.removeAll {$0.device==device && appQueryScope.permits($0.bundleID)}
            let checked=Date(),deviceName=devices.first(where:{$0.id==device})?.name ?? "iPhone / iPad"
            deviceGames += apps.map {DeviceGameObservation(device:device,deviceName:deviceName,bundleID:$0.id,titleID:titleID(for:$0),version:$0.version,checkedAt:checked)}
            verifiedDevices.insert(device);savePresence()
            record("Lista de tus juegos actualizada.")
            let matches=apps.filter {$0.id.hasPrefix(originalID)};if existing.isEmpty,matches.count==1 {existing=matches[0].id}
            busy=false
        case "device_registered":
            guard event["team"] as? String==team,event["udid"] as? String==device else {return}
            if accountDeviceTeam==team,!accountDevices.contains(where:{$0.id.caseInsensitiveCompare(device) == .orderedSame}) {
                accountDevices.append(AccountDevice(id:device,name:devices.first(where:{$0.id==device})?.name ?? "iPhone / iPad",status:"registered"));accountDevicesCheckedAt=Date()
            }
        case "account_devices":
            accountDeviceTeam=event["team"] as? String ?? ""
            accountDeviceLimit=(event["free_device_limit"] as? Int)==3 ? 3 : nil;accountDevicesCheckedAt=Date()
            accountDevices=((event["items"] as? [[String:Any]]) ?? []).compactMap {item in guard let id=item["udid"] as? String else {return nil};return AccountDevice(id:id,name:item["name"] as? String ?? String(id.suffix(8)),status:item["status"] as? String ?? "")}
            busy=false;record("Dispositivos registrados consultados.")
        case "two_factor":
            if let refresh=activeRefresh,!manualRefresh,let index=jobs.firstIndex(where:{$0.id==refresh.id}) {jobs[index].needsLogin=true;saveJobs()}
            record("Introduce el código de Apple.");codeRequired=true;phase="Introduce el código de Apple.";smsNumbers=((event["numbers"] as? [[String:Any]]) ?? []).compactMap {number in guard let id=number["id"] as? Int,let digits=number["last_digits"] as? String else {return nil};return TrustedSMS(id:id,digits:digits)}
        case "signed_in":
            recoveringSession=false;recoveryRequested=false;automaticRecoveryAttempted=true
            record("Sesión iniciada. Elige tu equipo personal.");authenticated=true;busy=false;codeRequired=false;error=nil;phase="Sesión iniciada. Elige tu equipo personal."
            if let remember=pendingRemember {if remember {defaults.set(email,forKey:"sideloadEmail");defaults.set(anisette,forKey:"sideloadAnisette")}else{defaults.removeObject(forKey:"sideloadEmail")};pendingRemember=nil}
            teams=((event["teams"] as? [[String:Any]]) ?? []).compactMap {item in guard let id=item["id"] as? String else {return nil};return SideloadTeam(id:id,name:item["name"] as? String ?? id,kind:item["kind"] as? String ?? "",freeDeviceLimit:(item["free_device_limit"] as? Int)==3 ? 3 : nil)}
            if !teams.contains(where:{$0.id==team}) {team=""}
            if activeRefresh==nil,team.isEmpty,hasRememberedSession,let saved=defaults.string(forKey:"sideloadTeam."+RefreshPolicy.account(email)),teams.contains(where:{$0.id==saved}) {team=saved}
            for index in jobs.indices where jobs[index].account==RefreshPolicy.account(email) {jobs[index].needsLogin=false};saveJobs()
            if let refresh=activeRefresh {refreshAuthenticated=true;continueRefresh(refresh)}
        case "signed_out":recoveringSession=false;recoveryRequested=false;automaticRecoveryAttempted=true;authenticated=false;accountDevices=[];accountDeviceTeam="";accountDeviceLimit=nil;accountDevicesCheckedAt=nil;teams=[];team="";busy=false
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
            // A validated install receipt is presence evidence immediately, before any later refresh.
            let installedFolder=URL(fileURLWithPath:job.gameFolder)
            let installedVersion=PreviousPreparation.load(folder:installedFolder,target:"ios")?.version ?? ""
            let installedTitle=SaveLocations.titleID(folder:installedFolder)
            let installedName=devices.first(where:{$0.id==job.udid})?.name ?? "iPhone / iPad"
            deviceGames.removeAll {$0.device==job.udid && $0.bundleID==actual}
            deviceGames.append(DeviceGameObservation(device:job.udid,deviceName:installedName,bundleID:actual,titleID:installedTitle,version:installedVersion,checkedAt:Date()))
            verifiedDevices.insert(job.udid);savePresence()
            if device==job.udid {
                apps.removeAll {$0.id==actual}
                apps.append(InstalledGame(id:actual,name:installedFolder.lastPathComponent,version:installedVersion))
            }
            let confirmsCurrentInstall=activeRefresh==nil && job.ipa==ipa?.path && job.gameFolder==gameFolder?.path && job.originalID==originalID && job.udid==device && job.team==team
            installIntent=nil;activeRefresh=nil;refreshAuthenticated=false;busy=false;fraction=1;completedInstallation=confirmsCurrentInstall;increasedMemoryLimit=event["increased_memory_limit"] as? Bool;phase="Instalado. Tus partidas se conservan en el dispositivo.";record(phase)
        case "error":
            record("La operación se detuvo. Revisa el mensaje de error.")
            let op=event["operation"] as? String
            let codes=["registration_consent":"Este dispositivo necesita registro. Revisa el consumo de un cupo y confirma antes de instalar.","version_changed":"La versión del juego cambió o no está verificada. Instala la app con sus datos nuevos.","game_running":"El juego sigue abierto. La renovación espera para no interrumpir tu partida.","idle_unknown":"No pudimos comprobar si el juego está abierto. Guarda, ciérralo y renueva manualmente.","identity_mismatch":"Ese identificador no corresponde al equipo elegido. Detenido para conservar la app anterior.","not_installed":"No encontramos esa app instalada. Revisa el identificador antes de actualizar.","wrong_app":"La app elegida no corresponde a este juego. No se instaló encima.","storage":"No hay espacio suficiente para preparar los datos nuevos sin borrar los anteriores.","ipa_changed":"La IPA cambió. Prepara y aprueba la actualización antes de renovarla."]
            error=codes[event["code"] as? String ?? ""] ?? ((op=="login" || op=="restore") ? "No pudimos iniciar sesión o la sesión guardada caducó. Vuelve a iniciar sesión." : "No pudimos completar la instalación. Revisa el dispositivo, equipo y permisos. No se revocaron certificados automáticamente.")
            if op=="export_saves" || op=="copy_romfs" {
                let failures=["game_running":"Guarda y cierra el juego desde el selector de apps antes de continuar.","idle_unknown":"No pudimos verificar que el juego esté cerrado. Guárdalo y ciérralo antes de continuar.","no_saves":"Todavía no encontramos archivos de partida guardados en este juego.","save_changed":"La partida cambió durante la exportación. Cierra el juego y vuelve a intentar.","save_metadata":"Este guardado usa metadatos que la exportación no puede conservar. Usa un respaldo completo del dispositivo.","save_destination":"Elige un ZIP nuevo; no sobrescribimos respaldos.","version_changed":"Actualiza primero la app con la misma versión que los datos preparados.","save_limits":"El guardado supera el límite de exportación de 512 MB u 8192 entradas."]
                error=failures[event["code"] as? String ?? ""] ?? "No pudimos completar la operación. Revisa la conexión y el espacio disponible. Las partidas no se modificaron."
                pendingExport=nil;pendingContentID=nil
            }
            if op=="installed_apps" {apps=[];error=(event["code"] as? String)=="scope_unavailable" ? "No pudimos limitar la consulta a tus juegos. No mostramos otras aplicaciones." : "No pudimos leer tus juegos. Desbloquea el dispositivo, confía en este Mac y vuelve a buscar."}
            if op=="devices" {error="No pudimos buscar dispositivos. Revisa la conexión y vuelve a intentar."}
            if op=="account_devices" {accountDevices=[];accountDeviceTeam="";error="Apple no devolvió los dispositivos de este equipo. Revisa tu sesión y vuelve a consultar."}
            if op=="restore" {error="No pudimos recuperar la sesión guardada. Revisa Internet y el acceso al Llavero, o vuelve a iniciar sesión."}
            if let code=event["apple_code"] as? Int {error=(error ?? "")+" · Apple: \(code)"}
            if op=="login" || op=="restore" {authenticated=false;pendingRemember=nil;recoveringSession=false}
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
    // Restore authentication only. Never starts registration, signing or installation.
    func recoverRememberedSessionIfNeeded() {
        guard !automaticRecoveryAttempted,!authenticated,hasRememberedSession else {recoveryRequested=false;return}
        recoveryRequested=true
        guard !busy,activeRefresh==nil else {return}
        restoreSession()
    }
    func restoreSession() {
        guard !busy,!email.isEmpty,defaults.string(forKey:"sideloadEmail")==email else {return}
        recoveryRequested=false;automaticRecoveryAttempted=true;recoveringSession=true;pendingRemember=nil
        busy=true;error=nil;startedAt=Date();fraction=nil;phase="Recuperando tu sesión del Llavero…";record(phase)
        send(["op":"restore","email":email,"anisette_url":anisette])
    }
    // This is an opt-in marker, not proof that Keychain or Apple will accept the saved session.
    var hasRememberedSession:Bool {defaults.string(forKey:"sideloadEmail")==email && !email.isEmpty}
    func select(_ job:RefreshJob) {
        completedInstallation=false
        guard !busy else {return}
        ipa=URL(fileURLWithPath:job.ipa);gameFolder=URL(fileURLWithPath:job.gameFolder);romfs=nil
        originalID=job.originalID;device=job.udid;team=job.team;existing=job.effectiveID
    }
    private func metadataLease()->Int32? {
        installerLease>=0 ? Darwin.dup(installerLease) : InstallerLease.acquire(at:stateURL.appendingPathExtension("lock"))
    }
    private func reloadJobsForEdit()->Bool {
        guard FileManager.default.fileExists(atPath:stateURL.path) else{return true}
        guard let data=try? Data(contentsOf:stateURL),let saved=try? JSONDecoder().decode([RefreshJob].self,from:data) else {error="No pudimos leer el registro de renovaciones. Se conservó sin cambios.";return false}
        jobs=saved;return true
    }
    func setRefresh(_ job:RefreshJob,enabled:Bool) {
        guard !busy else{return}
        guard let lease=metadataLease() else {error="Hay una instalación o renovación en curso. Intenta de nuevo en un momento.";return}
        defer {Darwin.close(lease)}
        guard reloadJobsForEdit(),let index=jobs.firstIndex(where:{$0.id==job.id}) else{return}
        jobs[index].enabled=enabled;saveJobs()
    }
    func forget(_ job:RefreshJob) {
        guard !busy else {return}
        guard let lease=metadataLease() else {error="Hay una instalación o renovación en curso. Intenta de nuevo en un momento.";return}
        defer {Darwin.close(lease)}
        guard reloadJobsForEdit() else{return}
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
        if !manualRefresh {
            guard let data=try? Data(contentsOf:stateURL),let saved=try? JSONDecoder().decode([RefreshJob].self,from:data),saved.contains(where:{$0.id==job.id && $0.enabled && $0.sha256==job.sha256 && $0.ipa==job.ipa && $0.account==job.account && $0.team==job.team}) else {activeRefresh=nil;return}
        }
        guard devices.contains(where:{$0.id==job.udid}) else {if manualRefresh {error="Conecta y desbloquea el dispositivo donde instalaste este juego."};activeRefresh=nil;return}
        guard teams.contains(where:{$0.id==job.team}) || !refreshAuthenticated else {error="La cuenta actual no tiene el equipo original de este juego. No cambiamos su identidad.";activeRefresh=nil;return}
        if !refreshAuthenticated {recoveryRequested=false;automaticRecoveryAttempted=true;recoveringSession=true;busy=true;phase="Recuperando tu sesión del Llavero…";send(["op":"restore","email":email,"anisette_url":anisette])}
        else {startInstall(job,updating:true,content:nil)}
    }
    static var backgroundEnabled:Bool {SMAppService.agent(plistName:"com.nalancer08.nxnative.refresh.plist").status == .enabled}
    func setLoginItem(_ enabled:Bool) {
        do {if enabled {try SMAppService.agent(plistName:"com.nalancer08.nxnative.refresh.plist").register();if SMAppService.agent(plistName:"com.nalancer08.nxnative.refresh.plist").status == .requiresApproval {SMAppService.openSystemSettingsLoginItems()}}else{try SMAppService.agent(plistName:"com.nalancer08.nxnative.refresh.plist").unregister()}}
        catch {self.error="Revisa Elementos de inicio en Ajustes del Sistema para permitir la renovación al iniciar sesión."}
    }
}

struct SideloadView:View {
    @ObservedObject var model:SideloadModel
    let text:(String)->String
    var accountOnly=false
    var embedded=false
    var guided=false
    var gameName:String?
    var onReturn:()->Void={}
    @Environment(\.dismiss) private var dismiss
    @State private var approveRegistration=false
    @State private var installStep=0
    @State private var usePassword=false
    @State private var password=""
    @State private var remember=true
    @State private var autoRefresh=true
    @State private var includeGameData=true
    @State private var loginItem=SMAppService.agent(plistName:"com.nalancer08.nxnative.refresh.plist").status == .enabled
    init(model:SideloadModel,text:@escaping (String)->String,accountOnly:Bool=false,embedded:Bool=false,guided:Bool=false,gameName:String?=nil,onReturn:@escaping ()->Void={},initialStep:Int=0) {
        self.model=model;self.text=text;self.accountOnly=accountOnly;self.embedded=embedded;self.guided=guided;self.gameName=gameName;self.onReturn=onReturn
        _installStep=State(initialValue:max(0,min(3,initialStep)))
    }
    private var selectedDevice:SideloadDevice? {model.devices.first {$0.id==model.device}}
    private var displayedGame:String {gameName ?? model.gameFolder?.lastPathComponent ?? text("Tu juego")}
    private var title:String {
        if accountOnly {return model.codeRequired ? "Verifica tu cuenta" : model.authenticated ? "Tu cuenta, lista para instalar" : "Conecta tu cuenta Apple"}
        return ["Elige dónde instalar","Conecta tu cuenta Apple","Todo listo para instalar",model.completedInstallation ? "Ya está en tu dispositivo" : model.busy ? "Instalando tu juego" : "Revisa la instalación"][min(3,installStep)]
    }
    private var subtitle:String {
        if accountOnly {return "Una cuenta para firmar e instalar en todos tus dispositivos."}
        return ["Tu juego ya está preparado. Ahora elige tu iPhone o iPad.","Inicia sesión para firmar tu app. Tus partidas y archivos siguen en su lugar.","Revisa el destino y confirma. La instalación empieza sólo cuando tú lo indiques.",model.completedInstallation ? "Abre el juego en tu iPhone o iPad. Tus partidas se conservan." : model.busy ? "Sigue la firma, la instalación y la copia de datos desde aquí." : "La instalación no terminó. Revisa lo ocurrido antes de volver a intentarlo."][min(3,installStep)]
    }
    private var kind:EasyMilestoneKind {accountOnly || installStep==1 ? .account : installStep==0 ? .device : installStep==2 ? .review : model.completedInstallation ? .complete : model.busy ? .transfer : .review}
    private var canInstall:Bool {!model.busy && model.authenticated && !model.device.isEmpty && !model.team.isEmpty && !model.originalID.isEmpty && model.ipa != nil && model.registrationState != .unknown && (model.registrationState != .new || approveRegistration)}
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:EasyDesign.spacing) {
                HStack(alignment:.center) {
                    VStack(alignment:.leading,spacing:5) {
                        Text(text(accountOnly ? "Tu cuenta Apple" : guided ? "Del juego a tu dispositivo" : "Instalar en iPhone / iPad")).font(.system(size:30,weight:.bold,design:.rounded))
                        if !accountOnly {Label(displayedGame,systemImage:"checkmark.circle.fill").font(.callout).foregroundStyle(.secondary)}
                    }
                    Spacer()
                    if !embedded {Button(text("Cerrar")){dismiss()}.disabled(model.busy)}
                    else if guided {Button(text("Ver preparación"),action:onReturn).disabled(model.busy)}
                }
                if !accountOnly {
                    if guided {Label(text("Preparación completada · Ahora vamos a instalar"),systemImage:"checkmark.seal.fill").font(.caption.weight(.semibold)).foregroundStyle(EasyDesign.accent)}
                    EasyStepRail(titles:["Dispositivo","Cuenta Apple","Revisar","Instalar"].map(text),current:installStep)
                }
                EasyMilestone(kind:kind,title:text(title),subtitle:text(subtitle))
                if accountOnly || installStep==1 {accountContent}
                else if installStep==0 {deviceContent}
                else if installStep==2 {reviewContent}
                else {installationContent}
                if !accountOnly && installStep>0 && installStep<3 {
                    Button {installStep-=1} label:{Label(text("Atrás"),systemImage:"arrow.left")}.buttonStyle(EasyLinkStyle()).disabled(model.busy)
                }
                InstallActivityView(model:model,text:text)
            }.frame(maxWidth:860,alignment:.leading).frame(maxWidth:.infinity,alignment:.top).padding(EasyDesign.pagePadding)
        }
        .safeAreaInset(edge:.bottom,spacing:0) {if !accountOnly && installStep==2 {installFooter}}
        .background(EasyDesign.background)
        .buttonStyle(EasySecondaryStyle())
        .task {model.recoverRememberedSessionIfNeeded();if model.authenticated && !model.hasRememberedSession {autoRefresh=false}}
        .onDisappear {password=""}
        .onChange(of:model.authenticated){_,authenticated in if authenticated {password="";autoRefresh=model.hasRememberedSession}}
        .onChange(of:model.device){_,_ in approveRegistration=false;includeGameData=true}
        .onChange(of:installStep){_,step in if step==2 {approveRegistration=false;if !model.busy {model.inspectAccountDevices()}}}
        .onChange(of:model.existing){_,_ in includeGameData=true}
        .onChange(of:model.team){_,value in approveRegistration=false;if !value.isEmpty && model.authenticated && !model.busy {model.inspectAccountDevices()}}
        .frame(maxWidth:.infinity,maxHeight:.infinity).frame(width:embedded ? nil : 820,height:embedded ? nil : 760)
        .tint(EasyDesign.accent).preferredColorScheme(.dark).interactiveDismissDisabled(model.busy)
    }
    private var deviceContent:some View {
        EasyCard {
            VStack(alignment:.leading,spacing:18) {
                HStack {
                    Label(text(model.devices.isEmpty ? "Conecta tu iPhone o iPad" : "Dispositivos disponibles"),systemImage:"cable.connector").font(.headline)
                    Spacer();Button(text("Buscar dispositivos")){model.listDevices()}.disabled(model.busy)
                }
                if model.devices.isEmpty {
                    Text(text("Conecta por USB, desbloquea y pulsa Confiar si tu dispositivo lo pide.")).font(.callout).foregroundStyle(.secondary)
                } else {
                    ForEach(model.devices) {device in
                        Button {model.device=device.id;model.existing="";model.inspectApps()} label:{
                            HStack(spacing:14) {
                                Image(systemName:device.kind=="iPad" ? "ipad" : "iphone").font(.system(size:30,weight:.light)).foregroundStyle(EasyDesign.accent).frame(width:40)
                                VStack(alignment:.leading,spacing:6) {Text(device.name).font(.headline);if !device.detail.isEmpty {Text(device.detail).font(.caption).foregroundStyle(.secondary)}}
                                Spacer();Image(systemName:model.device==device.id ? "checkmark.circle.fill" : "circle").foregroundStyle(model.device==device.id ? EasyDesign.accent : .secondary)
                            }.padding(16).background(model.device==device.id ? EasyDesign.accent.opacity(0.08) : .white.opacity(0.025),in:RoundedRectangle(cornerRadius:12))
                        }.buttonStyle(.plain).disabled(model.busy).accessibilityLabel(device.name).accessibilityAddTraits(model.device==device.id ? .isSelected : [])
                    }
                }
                Text(text("Desbloquea el dispositivo, confía en este Mac y activa Modo de desarrollador si iOS lo pide.")).font(.caption).foregroundStyle(.secondary)
                Button {installStep=1} label:{Label(text("Continuar con este dispositivo"),systemImage:"arrow.right")}.buttonStyle(EasyPrimaryStyle()).disabled(model.busy || model.device.isEmpty)
            }
        }
    }
    private var accountContent:some View {
        VStack(alignment:.leading,spacing:20) {
            if model.codeRequired {AppleVerificationView(model:model,text:text)}
            else if model.authenticated {signedInContent}
            else if model.busy {
                Label(model.email,systemImage:"person.crop.circle").font(.callout).foregroundStyle(.secondary)
            } else if model.hasRememberedSession && !usePassword {
                EasyCard {
                    VStack(alignment:.leading,spacing:16) {
                        Label(text("Tu cuenta está guardada en este Mac"),systemImage:"key.horizontal").font(.headline)
                        Text(model.email).font(.callout).textSelection(.enabled)
                        Text(text("Recupera la sesión del Llavero. Si Apple vuelve a pedir acceso, inicia sesión con tu contraseña.")).font(.callout).foregroundStyle(.secondary)
                        Button(text("Reintentar sesión guardada")){model.restoreSession()}.buttonStyle(EasyPrimaryStyle())
                        Button(text("Entrar con contraseña")){usePassword=true}.buttonStyle(EasyLinkStyle())
                    }
                }
            } else {loginContent}
            if !accountOnly && model.authenticated && !model.codeRequired {
                Button {installStep=2} label:{Label(text("Continuar a la revisión"),systemImage:"arrow.right")}.buttonStyle(EasyPrimaryStyle()).disabled(model.busy || model.team.isEmpty)
            }
        }
    }
    private var loginContent:some View {
        EasyCard {
            VStack(alignment:.leading,spacing:20) {
                VStack(alignment:.leading,spacing:6) {Text(text("Inicia sesión en Apple")).font(.title3.bold());Text(text("Sólo hace falta para firmar, instalar y renovar apps. Exportar partidas y copiar romfs no necesitan sesión.")).font(.callout).foregroundStyle(.secondary)}
                VStack(alignment:.leading,spacing:16) {
                    EasyField(text("Cuenta Apple personal")){TextField("name@example.com",text:$model.email).accessibilityLabel(text("Cuenta Apple personal"))}
                    EasyField(text("Contraseña de Apple")){SecureField(text("Contraseña de Apple"),text:$password).accessibilityLabel(text("Contraseña de Apple")).onSubmit {signIn()}}
                    Toggle(text("Recordar sesión en este Mac"),isOn:$remember).onChange(of:remember){_,value in if !value {autoRefresh=false}}
                    Text(text("Guardamos la sesión en el Llavero, nunca tu contraseña.")).font(.caption).foregroundStyle(.secondary)
                    Button {signIn()} label:{Label(text("Iniciar sesión"),systemImage:"arrow.right")}.buttonStyle(EasyPrimaryStyle()).disabled(model.email.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || password.isEmpty)
                    if model.hasRememberedSession {Button(text("Usar sesión del Llavero")){usePassword=false;password="";model.restoreSession()}.buttonStyle(EasyLinkStyle())}
                }.frame(maxWidth:500,alignment:.leading)
                DisclosureGroup(text("Privacidad y conexión")) {
                    VStack(alignment:.leading,spacing:12) {
                        Text(text("La contraseña y el código se envían a Apple. El servicio anisette recibe los datos técnicos que requiere la autenticación, no tu contraseña.")).font(.caption).foregroundStyle(.secondary)
                        EasyField(text("Servicio de autenticación")){TextField("Anisette HTTPS",text:$model.anisette)}
                    }.padding(.top,12)
                }.font(.caption)
            }
        }.disabled(model.busy)
    }
    private func signIn() {guard !model.busy,!password.isEmpty,!model.email.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else {return};let value=password;password="";model.signIn(password:value,remember:remember)}
    private var signedInContent:some View {
        EasyCard {
            VStack(alignment:.leading,spacing:18) {
                HStack(spacing:14) {
                    Image(systemName:"person.crop.circle.badge.checkmark").font(.system(size:34,weight:.light)).foregroundStyle(EasyDesign.accent)
                    VStack(alignment:.leading,spacing:5) {Text(text("Sesión iniciada")).font(.headline);Text(model.email).font(.callout).textSelection(.enabled)}
                    Spacer();Button(text("Cerrar sesión")){model.signOut()}.buttonStyle(EasyLinkStyle()).disabled(model.busy)
                }
                Divider()
                VStack(alignment:.leading,spacing:8) {
                    Text(text("Equipo para firmar tus apps")).font(.callout.bold())
                    Picker(text("Tu equipo personal"),selection:$model.team) {Text(text("Selecciona tu equipo")).tag("");ForEach(model.teams){Text($0.name+" · "+$0.id).tag($0.id)}}.labelsHidden().frame(maxWidth:520).disabled(model.busy)
                    if let selected=model.teams.first(where:{$0.id==model.team}),!selected.kind.isEmpty {Text(selected.freeDeviceLimit==3 ? text("Cuenta gratuita") : selected.kind).font(.caption).foregroundStyle(.secondary)}
                }
                if model.accountDeviceTeam==model.team && !model.team.isEmpty {
                    HStack(spacing:20) {
                        VStack(alignment:.leading,spacing:4) {Text(String(model.accountDevices.count)).font(.system(size:28,weight:.bold,design:.rounded));Text(text("Dispositivos registrados")).font(.caption).foregroundStyle(.secondary)}
                        if let remaining=model.estimatedDeviceSlots {Divider().frame(height:44);VStack(alignment:.leading,spacing:4) {Text("\(remaining) / 3").font(.system(size:28,weight:.bold,design:.rounded)).foregroundStyle(EasyDesign.accent);Text(text("Cupos disponibles estimados")).font(.caption).foregroundStyle(.secondary)}}
                    }
                    if model.estimatedDeviceSlots==nil {Text(text("Apple aún no confirmó cuántos dispositivos puedes registrar.")).font(.caption).foregroundStyle(.secondary)}
                    else {Text(text("Estimación según los registros devueltos. Apple confirma el cupo al registrar un dispositivo nuevo.")).font(.caption).foregroundStyle(.secondary)}
                    DisclosureGroup(text("Ver dispositivos registrados")) {VStack(alignment:.leading,spacing:10) {ForEach(model.accountDevices) {item in Label(model.accountDeviceName(item),systemImage:"iphone")}}.padding(.top,12)}.font(.callout)
                }
                Button(text("Actualizar dispositivos de mi cuenta")){model.inspectAccountDevices()}.disabled(model.busy || model.team.isEmpty)
                Text(text("El cupo corresponde al dispositivo, no a cada juego. Actualizar en un dispositivo ya registrado no consume otro cupo de dispositivo.")).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private var reviewContent:some View {
        VStack(alignment:.leading,spacing:20) {
            EasyCard {
                VStack(alignment:.leading,spacing:16) {
                    Text(displayedGame).font(.title3.bold())
                    Label(selectedDevice?.name ?? "iPhone / iPad",systemImage:"iphone").font(.headline)
                    Label(model.email,systemImage:"person.crop.circle").font(.callout).foregroundStyle(.secondary)
                    Label(text(model.romfs == nil ? "IPA completa: el juego va dentro de la app." : "IPA ligera: instalaremos la app y copiaremos romfs por separado."),systemImage:"shippingbox").font(.callout).foregroundStyle(.secondary)
                    VStack(alignment:.leading,spacing:8) {
                        Text(text("App existente que actualizarás")).font(.callout.bold())
                        Picker(text("App existente que actualizarás"),selection:$model.existing) {Text(text("Primera instalación")).tag("");ForEach(model.apps){Text($0.name+" · "+$0.id).tag($0.id)}}.labelsHidden().frame(maxWidth:.infinity).disabled(model.busy)
                    }
                    Text(text("Se conserva el identificador efectivo. Si no corresponde al juego y equipo, la instalación se detiene; no se desinstala la app anterior.")).font(.caption).foregroundStyle(.secondary)
                }
            }
            RegistrationReviewView(model:model,text:text,approved:$approveRegistration)
            EasyCard {
                VStack(alignment:.leading,spacing:16) {
                    Toggle(text("Renovar automáticamente antes de que caduque"),isOn:$autoRefresh).disabled(model.busy || !model.hasRememberedSession)
                    if !model.hasRememberedSession {Text(text("Para renovar automáticamente, inicia sesión recordándola en el Llavero.")).font(.caption).foregroundStyle(.secondary)}
                    Text(text("La renovación necesita este Mac encendido, nxnative Easy abierto, conexión a Internet y el dispositivo accesible. Conserva la IPA original.")).font(.caption).foregroundStyle(.secondary)
                    DisclosureGroup(text("Más opciones")) {
                        VStack(alignment:.leading,spacing:14) {
                            Toggle(text("Renovar aunque la ventana esté cerrada"),isOn:$loginItem).onChange(of:loginItem){_,value in model.setLoginItem(value)}
                            if model.canUpdateAppOnly {Toggle(text("Copiar también los datos del juego"),isOn:$includeGameData);Text(text("Para cambios de controles o de la app con la misma versión del juego. Si cambió el juego o DLC, usa la instalación con datos nuevos.")).font(.caption).foregroundStyle(.secondary)}
                        }.padding(.top,12)
                    }.font(.callout)
                    Label(text("Guarda y cierra el juego antes de instalar. No desinstales la app anterior."),systemImage:"info.circle").font(.callout)

                    if model.originalID.isEmpty || model.ipa==nil {Text(text("Falta una IPA preparada con su identidad. Vuelve a preparar el juego antes de instalar.")).font(.caption).foregroundStyle(.orange)}
                }
            }.disabled(model.busy)
        }
    }
    private var readinessMessage:String {
        if model.busy {return "Esperando la operación actual…"}
        if !model.authenticated {return "Vuelve a iniciar sesión para continuar."}
        if model.device.isEmpty {return "Elige un dispositivo conectado."}
        if model.team.isEmpty {return "Selecciona tu equipo Apple."}
        if model.ipa==nil || model.originalID.isEmpty {return "Falta una IPA preparada con su identidad. Vuelve a preparar el juego antes de instalar."}
        if model.registrationState == .unknown {return "Consulta tu cuenta para comprobar el registro."}
        if model.registrationState == .new && !approveRegistration {return "Confirma arriba el uso de un cupo para este dispositivo."}
        return "La firma y la instalación empiezan al pulsar el botón."
    }
    private var installFooter:some View {
        HStack(spacing:18) {
            VStack(alignment:.leading,spacing:5) {
                Text(text(canInstall ? "Listo para instalar" : "Antes de instalar")).font(.headline)
                Text(text(readinessMessage)).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            }.frame(maxWidth:.infinity,alignment:.leading)
            Button {installStep=3;model.install(autoRefresh:autoRefresh,includeContent:includeGameData,approveRegistration:approveRegistration)} label:{Label(text(model.existing.isEmpty ? "Firmar e instalar" : "Firmar y actualizar"),systemImage:"arrow.down.app")}.buttonStyle(EasyPrimaryStyle()).disabled(!canInstall)
        }.padding(20).frame(maxWidth:860).frame(maxWidth:.infinity).background(EasyDesign.background).overlay(alignment:.top){Divider()}
    }
    private var installationContent:some View {
        EasyCard {
            VStack(alignment:.leading,spacing:16) {
                Label(displayedGame,systemImage:model.completedInstallation ? "checkmark.seal.fill" : "shippingbox").font(.title3.bold())
                Text(selectedDevice?.name ?? "iPhone / iPad").font(.callout).foregroundStyle(.secondary)
                if model.completedInstallation {
                    Text(text("Instalación confirmada. Ya puedes abrir el juego en tu dispositivo.")).font(.callout)
                    if guided {Button(text("Volver a la preparación"),action:onReturn).buttonStyle(EasyPrimaryStyle())}
                    else if !embedded {Button(text("Listo")){dismiss()}.buttonStyle(EasyPrimaryStyle())}
                } else if !model.busy {
                    Text(text("La instalación no ha terminado. Revisa el mensaje y vuelve a intentarlo.")).font(.callout).foregroundStyle(.secondary)
                    Button(text("Revisar e intentar de nuevo")){installStep=2}.buttonStyle(EasyPrimaryStyle())
                } else {Text(text("Mantén el dispositivo conectado y la app abierta hasta que terminemos.")).font(.callout).foregroundStyle(.secondary)}
            }
        }
    }
}


struct RegistrationReviewView:View {
    @ObservedObject var model:SideloadModel
    let text:(String)->String
    @Binding var approved:Bool
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            switch model.registrationState {
            case .registered:
                Label(text("Este dispositivo ya está registrado"),systemImage:"checkmark.seal.fill").font(.headline).foregroundStyle(.green)
                Text(text("Instalar o actualizar aquí no consume otro cupo de dispositivo.")).font(.callout)
            case .new:
                Label(text("Este dispositivo usará un cupo nuevo"),systemImage:"plus.circle.fill").font(.headline).foregroundStyle(.orange)
                Text(text("Al confirmar la instalación, registraremos este dispositivo con tu equipo Apple y consumirá un cupo.")).font(.callout)
                if let remaining=model.estimatedDeviceSlots {Text(text("Disponibles estimados antes de instalar")+": "+String(remaining)+" · "+text("Después")+": "+String(max(0,remaining-1))).font(.callout.bold())}
                Text(text("El registro puede consumir el cupo aunque la instalación falle después.")).font(.caption).foregroundStyle(.secondary)
                Toggle(text("Acepto registrar este dispositivo y usar un cupo"),isOn:$approved).disabled(model.busy)
            case .unknown:
                Label(text("Comprueba el registro antes de instalar"),systemImage:"questionmark.circle").font(.headline)
                Button(text("Consultar mi cuenta Apple")){model.inspectAccountDevices()}.disabled(model.busy)
            }
            if model.registrationState != .unknown {Button(text("Actualizar consulta")){approved=false;model.inspectAccountDevices()}.disabled(model.busy)}
            Text(text("La consulta no registra ni elimina dispositivos. Apple confirma la disponibilidad al instalar.")).font(.caption).foregroundStyle(.secondary)
        }.padding(18).frame(maxWidth:.infinity,alignment:.leading).background(.white.opacity(0.04),in:RoundedRectangle(cornerRadius:14))
    }
}


struct AppleVerificationView:View {
    @ObservedObject var model:SideloadModel
    let text:(String)->String
    @State private var code=""
    @FocusState private var focused:Bool
    private var valid:Bool {code.count==6 && code.utf8.allSatisfy {48...57 ~= $0}}
    private func confirm() {guard valid else {return};let submitted=code;code="";model.submitCode(submitted)}
    var body:some View {
        VStack(alignment:.leading,spacing:22) {
            HStack(alignment:.top,spacing:14) {
                Image(systemName:"lock.shield").font(.system(size:28,weight:.light)).foregroundStyle(EasyDesign.accent).frame(width:48,height:48).background(.white.opacity(0.04),in:RoundedRectangle(cornerRadius:12))
                VStack(alignment:.leading,spacing:6) {
                    Text(text("Verifica tu cuenta")).font(.title2.bold())
                    if !model.email.isEmpty {Text(model.email).font(.caption).foregroundStyle(.secondary)}
                    Text(text("Introduce los 6 dígitos que Apple muestra en tu dispositivo de confianza o envía por SMS.")).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                }
            }
            VStack(alignment:.leading,spacing:10) {
                Text(text("Código de verificación")).font(.callout.weight(.semibold))
                TextField("······",text:$code).textFieldStyle(.plain).font(.system(size:30,weight:.medium,design:.monospaced)).tracking(7)
                    .padding(.horizontal,18).padding(.vertical,15).frame(width:250)
                    .background(.black.opacity(0.18),in:RoundedRectangle(cornerRadius:11))
                    .overlay(RoundedRectangle(cornerRadius:11).strokeBorder(focused ? EasyDesign.accent.opacity(0.65) : .white.opacity(0.12)))
                    .focused($focused).accessibilityLabel(text("Código de verificación"))
                    .onChange(of:code){_,value in code=String(value.utf8.filter {48...57 ~= $0}.prefix(6).map {Character(UnicodeScalar($0))})}
                    .onSubmit {confirm()}
                Text(text("Puedes pegar el código completo.")).font(.caption).foregroundStyle(.secondary)
            }
            Button(action:confirm){Label(text("Verificar y continuar"),systemImage:"arrow.right")}.buttonStyle(EasyPrimaryStyle()).disabled(!valid)
            Divider().overlay(.white.opacity(0.06))
            DisclosureGroup(text("¿No recibiste el código?")) {
                VStack(alignment:.leading,spacing:12) {
                    Text(text("Elige dónde quieres recibir uno nuevo.")).font(.caption).foregroundStyle(.secondary)
                    Button {code="";model.sendToDevices()} label:{Label(text("Mostrar en mis dispositivos Apple"),systemImage:"ipad.and.iphone")}
                    ForEach(model.smsNumbers) {number in
                        Button {code="";model.sendSMS(number.id)} label:{Label(text("Enviar SMS al número terminado en")+" "+number.digits,systemImage:"message")}
                    }
                    Button(text("Solicitar otro código")){code="";model.resend()}.buttonStyle(EasyLinkStyle())
                }.padding(.top,12)
            }.font(.callout)
            HStack(alignment:.firstTextBaseline) {
                Text(text("El código se envía a Apple y no se guarda.")).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(text("Cancelar")){code="";model.cancel()}.buttonStyle(EasyLinkStyle())
            }
        }.padding(24).frame(maxWidth:.infinity,alignment:.leading)
            .background(.white.opacity(0.035),in:RoundedRectangle(cornerRadius:18))
            .overlay(RoundedRectangle(cornerRadius:18).strokeBorder(.white.opacity(0.06)))
            .onAppear {focused=true}
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
    private let accent=EasyDesign.accent
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
                            if !model.device.isEmpty {
                        Button(text("Comprobar USB y Wi-Fi")){model.checkConnections()}.disabled(model.busy)
                        if !model.connectionSummary.isEmpty {Text(model.connectionSummary).font(.callout.monospaced());Text(text("Esto verifica la conexión, no la firma ni la instalación. Para Wi-Fi, empareja por USB y activa la sincronización en Finder.")).font(.caption).foregroundStyle(.secondary)}
                    }
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
    @State private var expanded=false
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            if model.busy && !model.codeRequired {
                EasyCard {
                    VStack(alignment:.leading,spacing:14) {
                        HStack {Label(text(model.phase),systemImage:"arrow.triangle.2.circlepath").font(.headline);Spacer();Button(text("Cancelar")){model.cancel()}.buttonStyle(EasyLinkStyle())}
                        if let fraction=model.fraction {ProgressView(value:fraction).tint(EasyDesign.accent);Text(String(Int(fraction*100))+" %").font(.caption.monospacedDigit())}
                        else {ProgressView().progressViewStyle(.linear).tint(EasyDesign.accent);Text(text("Esta operación no informa un porcentaje. Puedes seguir el tiempo transcurrido y el registro.")).font(.caption).foregroundStyle(.secondary)}
                        TimelineView(.periodic(from:.now,by:1)){context in Text(text("Tiempo transcurrido")+" "+String(max(0,Int(context.date.timeIntervalSince(model.startedAt ?? context.date))))+" s").font(.caption.monospacedDigit()).foregroundStyle(.secondary)}
                    }
                }
            }
            if let memory=model.increasedMemoryLimit,model.completedInstallation {
                Text(text(memory ? "Memoria ampliada: confirmada en la firma." : "La firma no incluye memoria ampliada. Algunos juegos grandes pueden cerrarse por falta de memoria.")).font(.caption).foregroundStyle(memory ? Color.secondary : Color.orange)
            }
            if let error=model.error {
                EasyCard {VStack(alignment:.leading,spacing:8) {Label(text("Necesitamos revisar algo"),systemImage:"exclamationmark.triangle").font(.headline).foregroundStyle(.orange);Text(text(error)).font(.callout).textSelection(.enabled)}}
            }
            if let export=model.exportedSaves {Button(text("Mostrar ZIP de partidas")){NSWorkspace.shared.activateFileViewerSelecting([export])}}
            if !model.logs.isEmpty {
                DisclosureGroup(text("Actividad"),isExpanded:$expanded) {
                    VStack(alignment:.leading,spacing:12) {
                        HStack {Button(text("Copiar registro")){model.copyLogs(text:text)};if let url=model.logURL {Button(text("Mostrar registro guardado")){NSWorkspace.shared.activateFileViewerSelecting([url])}};Spacer()}
                        ScrollView {LazyVStack(alignment:.leading,spacing:7) {ForEach(model.logs) {entry in Text(entry.date.formatted(date:.omitted,time:.standard)+" · "+text(entry.message)+(entry.progress.map{" · "+String(Int($0*100))+" %"} ?? "")).font(.system(size:11,design:.monospaced)).textSelection(.enabled)}}.frame(maxWidth:.infinity,alignment:.leading)}.frame(height:180).defaultScrollAnchor(.bottom)
                    }.padding(.top,14)
                }.font(.callout).padding(18).background(EasyDesign.surface,in:RoundedRectangle(cornerRadius:14))
            }
        }
    }
}

// Shared across foreground and the optional launchd worker, without credentials.
enum InstallerLease {
    static func acquire(at location:URL?=nil)->Int32? {
        let root=location?.deletingLastPathComponent() ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/nxnative Easy")
        do {try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])}catch{return nil}
        let fd=Darwin.open((location ?? root.appendingPathComponent("refresh-jobs.json.lock")).path,O_CREAT|O_RDWR|O_NOFOLLOW|O_CLOEXEC,0o600)
        guard fd>=0 else{return nil}
        guard flock(fd,LOCK_EX|LOCK_NB)==0 else {Darwin.close(fd);return nil}
        return fd
    }
}

@MainActor enum BackgroundRenewal {
    static func run() {
        let identifier="com.nalancer08.nxnative.easy"
        let defaults=Bundle.main.bundleIdentifier==identifier ? UserDefaults.standard : (UserDefaults(suiteName:identifier) ?? .standard)
        guard let executable=Bundle.main.executableURL else{return}
        let helper=executable.deletingLastPathComponent().appendingPathComponent("nxnative-sideload")
        let model=SideloadModel(defaults:defaults,helperURL:helper)
        if CommandLine.arguments.contains("--dry-run") {
            print("Background renewal: \(model.jobs.filter {$0.enabled}.count) enabled jobs; no account/device operation performed")
            return
        }
        if NSRunningApplication.runningApplications(withBundleIdentifier:"com.nalancer08.nxnative.easy").contains(where:{$0.processIdentifier != ProcessInfo.processInfo.processIdentifier && $0.executableURL?.lastPathComponent=="NxNativeEasy"}) {return}
        model.checkRefresh()
        let deadline=Date().addingTimeInterval(240)
        while model.busy && Date()<deadline && !model.codeRequired {RunLoop.current.run(until:Date().addingTimeInterval(0.2))}
        if model.busy {model.cancel()}
    }
}
