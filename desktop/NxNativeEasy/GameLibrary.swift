import Foundation
import Combine

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
}
struct OwnedGameOutput:Identifiable {
    let item:OwnedGame
    var id:String {item.id}
    var folder:URL {URL(fileURLWithPath:item.folder)}
    var titleID:String?
    var macApp:URL?
    var iosIPA:URL?
    var romfs:URL?
    var version:String?
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
