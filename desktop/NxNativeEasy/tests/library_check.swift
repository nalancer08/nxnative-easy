import Foundation
@main struct LibraryCheck {
    @MainActor static func main() throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer {try? FileManager.default.removeItem(at:root)}
        let folder=root.appendingPathComponent("Dread"),storage=root.appendingPathComponent("private/library.json")
        try FileManager.default.createDirectory(at:folder.appendingPathComponent("010093801237C000_build"),withIntermediateDirectories:true)
        try Data("synthetic input".utf8).write(to:folder.appendingPathComponent("owned.nsp"))
        let original=try Data(contentsOf:folder.appendingPathComponent("owned.nsp"))
        let library=GameLibrary(file:storage)
        let id=try library.add(folder)
        let alias=root.appendingPathComponent("alias");try FileManager.default.createSymbolicLink(at:alias,withDestinationURL:folder)
        let duplicate=try library.add(alias);assert(duplicate==id)
        assert(library.games.count==1 && library.games[0].titleID=="010093801237C000" && !library.games[0].ready)
        let ipa=folder.appendingPathComponent("game.ipa");try Data("synthetic archive".utf8).write(to:ipa)
        try JSONSerialization.data(withJSONObject:["schema":1,"packaging":"full","full_ipa":ipa.path,"bundle_id":"org.synthetic.dread"]).write(to:folder.appendingPathComponent("nxnative-ios.json"))
        library.refresh();assert(library.games[0].iosIPA==ipa && library.games[0].romfs==nil)
        let app=folder.appendingPathComponent("Dread.app")
        try FileManager.default.createDirectory(at:app.appendingPathComponent("Contents/MacOS"),withIntermediateDirectories:true)
        try Data().write(to:app.appendingPathComponent("Contents/MacOS/dmhost"))
        try FileManager.default.createDirectory(at:app.appendingPathComponent("Contents/Resources/romfs"),withIntermediateDirectories:true)
        try PropertyListSerialization.data(fromPropertyList:["CFBundleIdentifier":"org.synthetic.dread","DMTitleID":"010093801237C000"],format:.xml,options:0).write(to:app.appendingPathComponent("Contents/Info.plist"))
        try JSONSerialization.data(withJSONObject:["schema":1,"app_path":app.path,"bundle_id":"org.synthetic.dread"]).write(to:folder.appendingPathComponent("nxnative-mac.json"))
        let restored=GameLibrary(file:storage)
        assert(restored.games.count==1 && restored.games[0].macApp?.path==app.path && restored.games[0].iosIPA==ipa)
        try FileManager.default.removeItem(at:ipa);restored.refresh();assert(restored.games[0].iosIPA==nil && restored.games[0].macApp?.path==app.path)
        let moved=root.appendingPathComponent("moved");try FileManager.default.moveItem(at:folder,to:moved)
        restored.refresh();assert(restored.games.count==1 && restored.games[0].missing)
        restored.remove(id);assert(restored.games.isEmpty)
        let retained=try Data(contentsOf:moved.appendingPathComponent("owned.nsp"));assert(retained==original)
        assert(FileManager.default.fileExists(atPath:moved.appendingPathComponent("Dread.app").path))
        let permissions=try FileManager.default.attributesOfItem(atPath:storage.path)[.posixPermissions] as! NSNumber
        assert(permissions.intValue==0o600)
        try Data("broken private metadata".utf8).write(to:storage)
        let broken=GameLibrary(file:storage);assert(broken.error != nil)
        do {_=try broken.add(moved);assertionFailure("must preserve malformed library")}catch{}
        let preserved=try String(contentsOf:storage,encoding:.utf8);assert(preserved=="broken private metadata")
        print("Library PASS: canonical folder deduplication, persisted Mac+iOS outputs, missing-file refresh, unavailable-folder retention, metadata-only removal and malformed-file preservation")
    }
}
