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
