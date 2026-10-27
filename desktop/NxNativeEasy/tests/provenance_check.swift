import Foundation
@main struct ProvenanceCheck {
    @MainActor static func main() throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer {try? FileManager.default.removeItem(at:root)}
        func git(_ args:[String])throws {
            let process=Process();process.executableURL=URL(fileURLWithPath:"/usr/bin/git");process.arguments=["-C",root.path]+args;process.standardOutput=FileHandle.nullDevice;process.standardError=FileHandle.nullDevice;try process.run();process.waitUntilExit();assert(process.terminationStatus==0)
        }
        func file(_ name:String,_ data:String)throws {
            let url=root.appendingPathComponent(name);try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true);try data.write(to:url,atomically:true,encoding:.utf8)
        }
        try git(["init","-b","main"]);try file("dm/host/example.c","one");try git(["add","."]);try git(["-c","user.name=Synthetic Test","-c","user.email=test@example.invalid","commit","-m","fixture"])
        let sha=BuildProvenance.head(root)!,title="010093801237C000"
        assert(BuildProvenance.recommendation(repo:root,revision:sha,titleID:title)==false)
        try file("docs/readme.md","notes");try file("dm/games/OTHER/game.tsv","other");try git(["add","."])
        assert(BuildProvenance.recommendation(repo:root,revision:sha,titleID:title)==false)
        try file("dm/games/"+title+"/game.tsv","updated profile");try git(["add","."])
        assert(BuildProvenance.recommendation(repo:root,revision:sha,titleID:title)==true)
        assert(BuildProvenance.recommendation(repo:root,revision:nil,titleID:title)==nil)
        assert(BuildProvenance.recommendation(repo:root,revision:String(repeating:"0",count:40),titleID:title)==nil)
        assert(!BuildProvenance.affects("desktop/NxNativeEasy/main.swift",titleID:title))
        assert(!BuildProvenance.affects("dm/host/tests/example.c",titleID:title))
        assert(BuildProvenance.affects("dm/gfx/nvn/dmsh_chain.h",titleID:title))
        let privateLog="header_key = 0123456789abcdef0123456789abcdef\nAuthorization: Bearer synthetic-token\nuser@test.invalid\n"+NSHomeDirectory()+"/Game/prod.keys"
        let diagnostic=BuildDiagnostics.report(version:"test",system:"test",revision:sha,target:"ios",stage:"Shaders",log:privateLog)
        assert(!diagnostic.contains("0123456789abcdef") && !diagnostic.contains("synthetic-token") && !diagnostic.contains("user@test.invalid") && !diagnostic.contains(NSHomeDirectory()+"/"))
        assert(diagnostic.contains("[redacted]") && diagnostic.contains("Shaders"))
        let libraryFolder=root.appendingPathComponent("Owned")
        try FileManager.default.createDirectory(at:libraryFolder,withIntermediateDirectories:true);try Data("original input".utf8).write(to:libraryFolder.appendingPathComponent("game.nsp"))
        let index=root.appendingPathComponent("state/library.json"),library=GameLibrary(file:index)
        try library.add(libraryFolder);library.recordBuild(folder:libraryFolder,target:"ios",revision:sha)
        let restored=GameLibrary(file:index)
        assert(restored.games[0].iosRevision==sha && restored.games[0].macRevision==nil)
        let retained=try Data(contentsOf:libraryFolder.appendingPathComponent("game.nsp"));assert(retained==Data("original input".utf8))
        print("Provenance/diagnostics PASS: actual Git comparisons, unknown history, per-platform persistence, original-byte preservation and secret redaction")
    }
}
