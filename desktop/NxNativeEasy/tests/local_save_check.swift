import Foundation
private enum Failure:Error {case check(String)}
private func require(_ value:Bool,_ message:String)throws {if !value {throw Failure.check(message)}}
@MainActor private func until(_ condition:()->Bool)async throws {
    for _ in 0..<200 {if condition(){return};try await Task.sleep(nanoseconds:10_000_000)}
    throw Failure.check("watch did not receive a change")
}
@main private struct Check {
    @MainActor static func main()async {
        do {try await run();print("local saves: empty game, first save, metadata changes, committed roots, scope, cancellation and original bytes preserved")}
        catch {fputs("local save check failed: \(error)\n",stderr);exit(1)}
    }
    @MainActor private static func run()async throws {
        let fm=FileManager.default,root=fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer{try? fm.removeItem(at:root)}
        let title="010093801237C000",other="010015100B514000",game=root.appendingPathComponent(title),slot=game.appendingPathComponent("save/slot.bin")
        let model=LocalSaveMonitor(rootForTitle:{root.appendingPathComponent($0)})
        await model.refresh(titles:[title,"../outside"])
        try require(model.games[title]?.state == .empty && model.games.count==1,"a game can exist before its first save; reject invalid scope")
        try require(!fm.fileExists(atPath:root.path),"a read must never create save directories")
        try fm.createDirectory(at:game.appendingPathComponent("save.work"),withIntermediateDirectories:true)
        try Data("uncommitted".utf8).write(to:game.appendingPathComponent("save.work/progress"))
        await model.refresh(titles:[title]);try require(model.games[title]?.state == .empty,"working transactions are not saves")
        let watching=Task {await model.watch(titles:[title],interval:20_000_000)}
        try fm.createDirectory(at:slot.deletingLastPathComponent(),withIntermediateDirectories:true)
        let original=Data("synthetic committed progress".utf8);try original.write(to:slot)
        try await until{model.games[title]?.state == .present}
        try require(model.games[title]?.files==1 && model.games[title]?.modified != nil,"first committed save appears without cloud setup")
        let newDate=Date().addingTimeInterval(20);try fm.setAttributes([.modificationDate:newDate],ofItemAtPath:slot.path)
        try await until{abs((model.games[title]?.modified?.timeIntervalSince1970 ?? 0)-newDate.timeIntervalSince1970)<1}
        try fm.createDirectory(at:game.appendingPathComponent("save_device"),withIntermediateDirectories:true)
        try Data("shared progress".utf8).write(to:game.appendingPathComponent("save_device/state"))
        try await until{model.games[title]?.files==2}
        watching.cancel();await watching.value
        try require(try Data(contentsOf:slot)==original,"monitor must not change progress bytes")
        try fm.createSymbolicLink(at:game.appendingPathComponent("save/alias"),withDestinationURL:game.appendingPathComponent("save.work"))
        await model.refresh(titles:[title]);try require(model.games[title]?.state == .unavailable,"symlinks must not become trusted save evidence")
        try fm.removeItem(at:game.appendingPathComponent("save/alias"))
        await model.refresh(titles:[other]);try require(model.games[title]==nil && model.games[other]?.state == .empty,"a changed library scope removes stale metadata")
        let cancelled=Task {await model.refresh(titles:[title])};cancelled.cancel();await cancelled.value
        try require(model.games[title]==nil,"cancelled view must not publish an old title")
        let alias=root.appendingPathComponent("alias");try fm.createSymbolicLink(at:alias,withDestinationURL:game)
        try require(LocalSavePresence.inspect(root:alias).state == .unavailable,"title roots cannot follow another location")
        try require(try Data(contentsOf:slot)==original,"original progress survives all reads")
    }
}
