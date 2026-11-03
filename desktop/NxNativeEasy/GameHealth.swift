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
