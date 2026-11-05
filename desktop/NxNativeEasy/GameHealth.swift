import Foundation

// A newer launcher alone is never evidence that a game needs recompiling.
enum GameCareState:String {case expired,expiring,contentUpdate,rebuild,unknown,current,notInstalled}
struct GameCareEvidence {
    var installed=false
    var installedVersion:String?
    var preparedVersion:String?
    var expires:Date?
    var rebuild:Bool?
    var preparedRevision:String?
    var installedRevision:String?
    func state(now:Date=Date())->GameCareState {
        guard installed else {return .notInstalled}
        if let expires,expires<=now {return .expired}
        if let expires,expires.timeIntervalSince(now)<=48*3600 {return .expiring}
        if let a=installedVersion,!a.isEmpty,let b=preparedVersion,!b.isEmpty,a != b {return .contentUpdate}
        if rebuild==true {return .rebuild}
        if rebuild==nil,let a=installedRevision,let b=preparedRevision,a != b {return .unknown}
        return rebuild==false ? .current : .unknown
    }
}
struct EasyBuildStamp:Codable,Equatable {
    let version:String
    let build:Int
    let revision:String?
    static var current:Self? {
        guard let version=Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String,
              let build=Int(Bundle.main.object(forInfoDictionaryKey:"CFBundleVersion") as? String ?? "") else {return nil}
        return Self(version:version,build:build,revision:Bundle.main.object(forInfoDictionaryKey:"NxNativeSourceRevision") as? String)
    }
    static func prepared(folder:URL,target:String,ipa:URL?=nil)->Self? {
        guard let handle=try? FileHandle(forReadingFrom:folder.appendingPathComponent("nxnative-"+target+".json")) else {return nil}
        defer {try? handle.close()}
        guard let data=try? handle.read(upToCount:1048577),data.count<=1048576,
              let record=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],
              let version=record["easy_version"] as? String,let build=record["easy_build"] as? Int else {return nil}
        if let ipa {
            let paths=[record["full_ipa"] as? String,record["light_ipa"] as? String].compactMap{$0}
            guard paths.contains(ipa.path) else {return nil}
        }
        return Self(version:version,build:build,revision:record["source_revision"] as? String)
    }
}

// One decision supplies both the primary label and its action. Expiring signing
// takes priority over optional upgrades, so a renewal never starts a rebuild.
enum GamePrimaryIntent:Equatable {
    case play,renew,installSync,prepareSync,reviewUpdate,prepareMac,install,choose
    static func resolve(macReady:Bool,hasDevice:Bool,needsSync:Bool,syncReady:Bool,hasIPA:Bool,state:GameCareState?)->Self {
        if macReady {return .play}
        if hasDevice {
            if state == .expired || state == .expiring {return .renew}
            if needsSync {return syncReady ? .installSync : .prepareSync}
            if state == .rebuild || state == .contentUpdate {return .reviewUpdate}
            return .prepareMac
        }
        return hasIPA ? .install : .choose
    }
    var title:String {
        switch self {case .play:return "Jugar";case .renew:return "Renovar firma";case .installSync,.reviewUpdate:return "Actualizar en iPhone / iPad";case .prepareSync:return "Actualizar para sincronizar partidas";case .prepareMac:return "Preparar en Mac";case .install:return "Instalar en iPhone / iPad";case .choose:return "Añadir para jugar"}
    }
    var symbol:String {self == .play ? "play.fill" : self == .renew ? "arrow.clockwise" : "arrow.down.to.line"}
    var needsInstaller:Bool {[Self.renew,.installSync,.reviewUpdate,.install].contains(self)}
}
