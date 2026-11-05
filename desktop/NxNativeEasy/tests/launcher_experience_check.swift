import Foundation
import AppKit
private enum Failure:Error {case check(String)}
private func require(_ ok:Bool,_ message:String)throws {if !ok {throw Failure.check(message)}}
@main struct Check {
    @MainActor static func main()async {
        do {try await run();print("Launcher experience PASS: published update channel, current-build comparison, automatic throttle and invalid release guard")}
        catch {fputs("Launcher experience failed: \(error)\n",stderr);exit(1)}
    }
    @MainActor static func run()async throws {
        _=NSApplication.shared
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer{try? FileManager.default.removeItem(at:root)}
        let sourceRepo=root.appendingPathComponent("catalog"),desktop=sourceRepo.appendingPathComponent("desktop")
        try FileManager.default.createDirectory(at:desktop,withIntermediateDirectories:true)
        let currentEngine=String(repeating:"c",count:40),older=String(repeating:"b",count:40)
        var catalog:[String:Any] = ["schema":2,"number":8,"version":"1.0.1","versions":["7":"1.0.0","8":"1.0.1"],"revision":currentEngine,"upstream":currentEngine,"entries":[],"sources":[older:7,currentEngine:8]]
        let catalogFile=desktop.appendingPathComponent("engine-history.json")
        try JSONSerialization.data(withJSONObject:catalog).write(to:catalogFile)
        let history=EngineHistory.load(repo:sourceRepo)
        try require(history?.number==8 && history?.buildNumber(for:older)==7 && history?.buildNumber(for:currentEngine)==8,"offline engine numbers must resolve old builds")
        try require(history?.buildVersion(for:older)=="1.0.0" && history?.buildVersion(for:currentEngine)=="1.0.1","show dotted engine versions, separate from Easy builds")
        try require(history?.buildNumber(for:String(repeating:"d",count:40))==nil,"unknown hashes have no invented order")
        let frontendSource=String(repeating:"d",count:40)
        try (frontendSource+"\n").write(to:sourceRepo.appendingPathComponent("SOURCE_REVISION"),atomically:true,encoding:.utf8)
        try require(EngineHistory.load(repo:sourceRepo)?.buildVersion(for:frontendSource)=="1.0.1","a packaged frontend-only release keeps its engine version")
        catalog["sources"]=[older:9];try JSONSerialization.data(withJSONObject:catalog).write(to:catalogFile)
        try require(EngineHistory.load(repo:sourceRepo)==nil,"catalog cannot claim source builds newer than its current number")
        try require(MacProfile(name:"Alex Rivera").initials=="AR" && MacProfile(name:"   ").initials.isEmpty,"local profile initials never use the signing email")
        let sha=String(repeating:"a",count:40)
        var requests:[String]=[]
        func fetch(_ url:String)async throws->Data {
            requests.append(url)
            let value:Any
            if url.hasSuffix("releases/latest") {value=["tag_name":"v1.31.0","draft":false,"prerelease":false,"assets":[["name":"SHA256SUMS","state":"uploaded"],["name":"nxnative-Easy-macOS-arm64.zip","state":"uploaded"]]] as [String:Any]}
            else if url.contains("git/ref/tags/") {value=["object":["type":"commit","sha":sha]]}
            else if url.hasSuffix("desktop/release.json") {value=["version":"1.31.0","build":51,"minimumMacOSMajor":26] as [String:Any]}
            else {throw Failure.check("Unexpected update endpoint")}
            return try JSONSerialization.data(withJSONObject:value)
        }
        let updater=AppUpdater(failureURL:root.appendingPathComponent("no-error"),fetcher:fetch,currentBuild:50)
        await updater.check()
        try require(updater.available?.build==51 && updater.checkedAt != nil && updater.error==nil,"old installation must find the published release")
        try require(requests.count==3 && !requests.contains(where:{$0.contains("heads/main")}),"unpublished main cannot block the last published update")
        await updater.check();try require(requests.count==3,"automatic foreground checks are throttled")
        let current=AppUpdater(failureURL:root.appendingPathComponent("no-error"),fetcher:fetch,currentBuild:51)
        await current.check(manual:true);try require(current.available==nil && current.showNotice && current.error==nil,"current build is explicitly confirmed")
        let invalid=AppUpdater(failureURL:root.appendingPathComponent("no-error"),fetcher:{_ in Data("{}".utf8)},currentBuild:50)
        await invalid.check(manual:true);try require(invalid.error != nil && invalid.available==nil,"malformed release must not invent an update")
    }
}
