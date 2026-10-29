import Foundation
import Combine
import CryptoKit

private func boundedLibraryData(_ url:URL)throws->Data {
    let stream=try FileHandle(forReadingFrom:url)
    defer {try? stream.close()}
    let data=try stream.read(upToCount:1048577) ?? Data()
    guard data.count<=1048576 else {throw CocoaError(.fileReadCorruptFile)}
    return data
}

struct OwnedGame:Codable,Identifiable,Equatable {
    var id:String
    var folder:String
    var added:Date
    var macRevision:String?
    var iosRevision:String?
}
struct OwnedGameOutput:Identifiable {
    let item:OwnedGame
    var id:String {item.id}
    var folder:URL {URL(fileURLWithPath:item.folder)}
    var originalBundleID:String?
    var titleID:String?
    var macApp:URL?
    var iosIPA:URL?
    var romfs:URL?
    var version:String?
    var macRevision:String?
    var iosRevision:String?
    var missing=false
    var ready:Bool {macApp != nil || iosIPA != nil}
    static func read(_ item:OwnedGame)->OwnedGameOutput {
        var output=OwnedGameOutput(item:item)
        let fm=FileManager.default
        var directory:ObjCBool=false
        guard fm.fileExists(atPath:item.folder,isDirectory:&directory),directory.boolValue else {output.missing=true;return output}
        func record(_ name:String)->[String:Any] {
            guard let data=try? boundedLibraryData(output.folder.appendingPathComponent(name)),data.count<=1048576,
                  let value=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],(value["schema"] as? Int ?? 1)==1 else {return [:]}
            return value
        }
        let mac=record("nxnative-mac.json"),ios=record("nxnative-ios.json")
        output.macRevision=item.macRevision ?? mac["source_revision"] as? String
        output.iosRevision=item.iosRevision ?? ios["source_revision"] as? String
        output.originalBundleID=ios["bundle_id"] as? String
        if let path=mac["app_path"] as? String {
            let bundle=URL(fileURLWithPath:path)
            if let data=try? boundedLibraryData(bundle.appendingPathComponent("Contents/Info.plist")),
               let info=(try? PropertyListSerialization.propertyList(from:data,format:nil)) as? [String:Any],
               let identifier=info["CFBundleIdentifier"] as? String,!identifier.isEmpty,
               (mac["bundle_id"] as? String).map({$0==identifier}) ?? true,
               fm.fileExists(atPath:bundle.appendingPathComponent("Contents/MacOS/dmhost").path),
               (try? bundle.appendingPathComponent("Contents/Resources/romfs").resourceValues(forKeys:[.isDirectoryKey]).isDirectory)==true {
                output.macApp=bundle;output.titleID=info["DMTitleID"] as? String ?? mac["title_id"] as? String
                output.version=info["CFBundleShortVersionString"] as? String ?? mac["version"] as? String
            }
        }
        if let id=output.titleID,id.range(of:"^[0-9A-Fa-f]{16}$",options:.regularExpression)==nil {output.titleID=nil}
        if output.titleID==nil {
            let ids=((try? fm.contentsOfDirectory(at:output.folder,includingPropertiesForKeys:nil)) ?? []).compactMap {url->String? in
                url.lastPathComponent.range(of:"^[0-9A-Fa-f]{16}_build$",options:.regularExpression) != nil ? String(url.lastPathComponent.prefix(16)).uppercased() : nil
            }
            if ids.count==1 {output.titleID=ids[0]}
        }
        output.titleID=output.titleID?.uppercased()
        let split=(ios["packaging"] as? String) != "full"
        if let identifier=ios["bundle_id"] as? String,!identifier.isEmpty,
           let prepared=IOSPackageOutput.load(record:ios,split:split),
           prepared.romfs.map({fm.fileExists(atPath:$0.path)}) ?? true {
            output.iosIPA=prepared.ipa;output.romfs=prepared.romfs
            if output.version==nil {output.version=ios["version"] as? String}
        }
        return output
    }
}

@MainActor final class GameLibrary:ObservableObject {
    private struct Document:Codable {let schema:Int;let games:[OwnedGame]}
    @Published private(set) var games:[OwnedGameOutput]=[]
    @Published var error:String?
    private var items:[OwnedGame]=[]
    private var writable=true
    private let file:URL
    init(file:URL?=nil) {
        self.file=file ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/nxnative Easy/library.json")
        if FileManager.default.fileExists(atPath:self.file.path) {
            do {
                let data=try boundedLibraryData(self.file)
                guard data.count<=1048576 else {throw CocoaError(.fileReadCorruptFile)}
                let document=try JSONDecoder().decode(Document.self,from:data)
                guard document.schema==1,Set(document.games.map(\.id)).count==document.games.count,document.games.allSatisfy({!$0.id.isEmpty && $0.folder.hasPrefix("/") && !$0.folder.contains("\0")}) else {throw CocoaError(.fileReadCorruptFile)}
                items=document.games
            }catch{writable=false;self.error="No pudimos leer tu biblioteca. Conservamos el archivo original sin sobrescribirlo."}
        }
        refresh()
    }
    func refresh() {games=items.map(OwnedGameOutput.read)}
    @discardableResult func add(_ folder:URL)throws->String {
        guard writable else {throw CocoaError(.fileReadCorruptFile)}
        let path=folder.resolvingSymlinksInPath().standardizedFileURL.path
        if let known=items.first(where:{$0.folder==path}) {refresh();return known.id}
        let url=URL(fileURLWithPath:path)
        let files=try FileManager.default.contentsOfDirectory(at:url,includingPropertiesForKeys:nil)
        guard files.contains(where:{["nsp","xci","nsz","xcz"].contains($0.pathExtension.lowercased()) || ["nxnative-mac.json","nxnative-ios.json"].contains($0.lastPathComponent)}) else {throw CocoaError(.fileReadUnknown)}
        let item=OwnedGame(id:UUID().uuidString,folder:path,added:Date())
        try persist(items+[item]);return item.id
    }
    func recordBuild(folder:URL,target:String,revision:String) {
        let path=folder.resolvingSymlinksInPath().standardizedFileURL.path
        guard let index=items.firstIndex(where:{$0.folder==path}),revision.range(of:"^[0-9a-fA-F]{40}$",options:.regularExpression) != nil else {return}
        var changed=items
        if target=="mac" {changed[index].macRevision=revision}else if target=="ios" {changed[index].iosRevision=revision}else{return}
        do {try persist(changed)}catch{self.error="No pudimos guardar la biblioteca. Tus archivos no se modificaron."}
    }
    func remove(_ id:String) {do{try persist(items.filter{$0.id != id})}catch{self.error="No pudimos guardar la biblioteca. Tus archivos no se modificaron."}}
    private func persist(_ proposed:[OwnedGame])throws {
        guard writable else {throw CocoaError(.fileReadCorruptFile)}
        let parent=file.deletingLastPathComponent()
        try FileManager.default.createDirectory(at:parent,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
        try FileManager.default.setAttributes([.posixPermissions:0o700],ofItemAtPath:parent.path)
        try JSONEncoder().encode(Document(schema:1,games:proposed)).write(to:file,options:.atomic)
        try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:file.path)
        items=proposed;error=nil;refresh()
    }
}

// These services read repository metadata, never game payloads or save folders.
enum BuildProvenance {
    static func affects(_ path:String,titleID:String)->Bool {
        if path.hasSuffix(".md") || path.contains("/tests/") {return false}
        return path.hasPrefix("dm/games/"+titleID.uppercased()+"/") || ["dm/host/","dm/gfx/","dm/tools/","dm/ios/","dm/mac/","dm/third_party/","dm/games/game.py","dm/games/profile_guess.py","dm/games/settings.","scripts/build_ipa_from_nsp.py","scripts/build_ios.py","scripts/build_mac.py"].contains(where:path.hasPrefix)
    }
    static func git(_ repo:URL,_ args:[String])->String? {
        guard FileManager.default.fileExists(atPath:repo.appendingPathComponent(".git").path) else{return nil}
        let task=Process(),pipe=Pipe();task.executableURL=URL(fileURLWithPath:"/usr/bin/git");task.arguments=["-C",repo.path]+args;task.standardOutput=pipe;task.standardError=FileHandle.nullDevice;task.standardInput=FileHandle.nullDevice
        do {try task.run();let data=pipe.fileHandleForReading.readDataToEndOfFile();task.waitUntilExit();return task.terminationStatus==0 ? String(decoding:data,as:UTF8.self).trimmingCharacters(in:.whitespacesAndNewlines) : nil}catch{return nil}
    }
    static func sourceIndex(_ repo:URL)->[String:String]? {
        guard let data=try? Data(contentsOf:repo.appendingPathComponent("SOURCE_INDEX.json")),data.count<2*1024*1024,let index=try? JSONDecoder().decode([String:String].self,from:data),index.count<20000,index.keys.allSatisfy({!$0.hasPrefix("/") && !$0.split(separator:"/").contains("..")}) else{return nil}
        return index
    }
    static func head(_ repo:URL)->String? {
        if let value=git(repo,["rev-parse","HEAD"]) {return value}
        guard sourceIndex(repo) != nil,let value=try? String(contentsOf:repo.appendingPathComponent("SOURCE_REVISION"),encoding:.utf8).trimmingCharacters(in:.whitespacesAndNewlines),value.range(of:"^[0-9a-f]{40}$",options:.regularExpression) != nil else{return nil}
        return value
    }
    static func recommendation(repo:URL,revision:String?,titleID:String)->Bool? {
        guard let revision,revision.range(of:"^[0-9a-fA-F]{40}$",options:.regularExpression) != nil else{return nil}
        if let paths=git(repo,["diff","--name-only","--no-renames",revision,"--"]) {return paths.split(separator:"\n").contains {affects(String($0),titleID:titleID)}}
        guard let current=sourceIndex(repo),let previous=sourceIndex(repo.deletingLastPathComponent().appendingPathComponent(revision)) else{return nil}
        for path in Set(current.keys).union(previous.keys) where affects(path,titleID:titleID) {
            let file=repo.appendingPathComponent(path)
            guard file.resolvingSymlinksInPath().path.hasPrefix(repo.resolvingSymlinksInPath().path+"/"),let expected=previous[path],current[path] != nil,let data=try? Data(contentsOf:file) else{return true}
            if SHA256.hash(data:data).map({String(format:"%02x",$0)}).joined() != expected {return true}
        }
        return false
    }
}

enum BuildDiagnostics {
    // Deliberately omit Apple account/device identifiers, environment and raw install logs.
    static func redact(_ value:String,home:String=NSHomeDirectory())->String {
        var out=value.replacingOccurrences(of:home+"/",with:"~/")
        let rules:[(String,String)]=[
            (#"(?i)([A-Za-z0-9_.-]+\s*=\s*)(?:0x)?[0-9a-f]{16,}"#,"$1[redacted]"),
            (#"(?i)(?:[^\s]*)(?:password|passwd|token|authorization|cookie|secret|anisette|apple.?id|udid)[^\n]*"#,"[private authentication/device detail removed]"),
            (#"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#,"[email removed]")]
        for (pattern,replacement) in rules {out=out.replacingOccurrences(of:pattern,with:replacement,options:.regularExpression)}
        return out
    }
    static func report(version:String,system:String,revision:String?,target:String,stage:String,log:String)->String {
        let tail=log.split(separator:"\n",omittingEmptySubsequences:false).suffix(50).joined(separator:"\n")
        return redact("nxnative Easy diagnostics\nApp: \(version)\nSystem: \(system)\nSource: \(revision ?? "unknown")\nTarget: \(target)\nStage: \(stage)\n\nLast build output (up to 50 lines):\n"+tail)
    }
}
