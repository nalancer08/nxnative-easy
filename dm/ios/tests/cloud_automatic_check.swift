import Foundation

@_silgen_name("nxe_test_reset") private func reset(_ json: UnsafePointer<CChar>)
@_silgen_name("nxe_test_reply") private func reply(_ json: UnsafePointer<CChar>)
@_silgen_name("nxe_test_calls") private func calls() -> Int32
@_silgen_name("nxe_test_last") private func last() -> UnsafeMutablePointer<CChar>

private enum Failure: Error { case check(String) }
private func require(_ ok: Bool, _ message: String) throws { if !ok { throw Failure.check(message) } }
private func json(_ status: String, blocked: Bool = false, source: String = "") -> String {
    """
    {"status":"\(status)","message":"synthetic","choices":[],"blocksPlay":\(blocked),"restoredFrom":"\(source)"}
    """
}
@MainActor private func model() -> CloudSaveModel {
    let m = CloudSaveModel(); m.ready = true; m.blocked = false
    m.folder = URL(fileURLWithPath: "/synthetic-no-folder-access")
    return m
}
@MainActor private func waitUntil(_ predicate: () -> Bool) async throws {
    for _ in 0..<200 {
        if predicate() { return }
        try await Task.sleep(nanoseconds: 10_000_000)
    }
    throw Failure.check("async fixture timed out")
}

@main private struct Check {
    @MainActor static func main() async {
        do {
            let suite="nxnative.quick-play.tests."+UUID().uuidString,defaults=UserDefaults(suiteName:suite)!
            let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).resolvingSymlinksInPath()
            let selected=root.appendingPathComponent("selected"),other=root.appendingPathComponent("other")
            try FileManager.default.createDirectory(at:selected,withIntermediateDirectories:true)
            try FileManager.default.createDirectory(at:other,withIntermediateDirectories:true)
            let originalEnvironment=ProcessInfo.processInfo.environment["NXE_CLOUD_FOLDER"]
            defer {
                defaults.removePersistentDomain(forName:suite);try? FileManager.default.removeItem(at:root)
                if let originalEnvironment {setenv("NXE_CLOUD_FOLDER",originalEnvironment,1)}else{unsetenv("NXE_CLOUD_FOLDER")}
            }
            setenv("NXE_CLOUD_FOLDER",selected.path,1);reset(json("available"))
            let first=CloudSaveModel(defaults:defaults);await first.load()
            try require(first.folder?.path==selected.path && first.canQuickPlay,"new Mac game must adopt the explicit Easy folder before quick play")
            let originalBookmark=defaults.data(forKey:"saveContinuity.folder.v1")
            try require(originalBookmark != nil,"remember the selected folder")
            setenv("NXE_CLOUD_FOLDER",other.path,1);reset(json("local"))
            let mismatch=CloudSaveModel(defaults:defaults);await mismatch.load()
            try require(mismatch.permissionError != nil && !mismatch.canQuickPlay,"different pre-existing folder must stop quick play")
            try require(defaults.data(forKey:"saveContinuity.folder.v1")==originalBookmark,"never replace a previous game's folder without choosing")
            let gate=model();gate.status="conflict";try require(!gate.canQuickPlay,"conflict must keep the game on review")
            gate.status="waiting";try require(!gate.canQuickPlay,"pending delivery must not start automatically")
            gate.status="available";gate.blocked=true;try require(!gate.canQuickPlay,"blocked restore must stop automatic play")
            unsetenv("NXE_CLOUD_FOLDER")
            for (status, delay) in [("waiting", UInt64(3_000_000_000)), ("error", UInt64(15_000_000_000))] {
                reset(json(status)); let m = model(); var sleeps = 0
                await m.followCloud { nanos in
                    try require(nanos == delay, "wrong retry policy")
                    sleeps += 1; reply(json("available", source: "Test iPhone"))
                }
                try require(calls() == 2 && sleeps == 1, "delivery must retry and then stop")
                try require(m.status == "available" && m.restoredFrom == "Test iPhone", "confirmed restore notice")
                try require(!m.started, "checking must never start play")
                reply(json("available")); await m.check()
                try require(m.restoredFrom == "Test iPhone", "keep confirmation until play")
                reply(json("conflict")); await m.check()
                try require(m.restoredFrom == nil, "a late conflict must clear the ready receipt")
            }
            for status in ["available", "empty", "conflict"] {
                reset(json(status)); let m = model(); var sleeps = 0
                await m.followCloud { _ in sleeps += 1 }
                try require(calls() == 1 && sleeps == 0, "no polling or resolution for \(status)")
                let p = last(); defer { free(p) }
                try require(String(cString: p) == "check", "no automatic branch selection")
            }
            reset(json("error", blocked: true)); let blocked = model()
            await blocked.followCloud { _ in throw Failure.check("unsafe automatic recovery loop") }
            try require(calls() == 1 && blocked.blocked, "blocked recovery preserved")
            reset(json("waiting")); let permission = model(); permission.permissionError = "synthetic denied access"
            await permission.followCloud { _ in throw Failure.check("permission retry loop") }
            try require(calls() == 1, "permission requires folder reselection")
            reset(json("waiting")); let off = model(); off.folder = nil
            await off.followCloud { _ in throw Failure.check("sync off must stay off") }
            try require(calls() == 0, "disabled sync must not check provider")

            reset(json("waiting")); let cancelled = model()
            let task = Task { await cancelled.followCloud() }
            try await waitUntil { calls() == 1 && !cancelled.busy }
            task.cancel(); await task.value
            try require(calls() == 1, "inactive panel must cancel retry")

            reset(json("conflict")); let changed = model(); var played = false
            changed.status = "available"; changed.start { played = true }
            try await waitUntil { !changed.busy }
            try require(!played && !changed.started && changed.status == "conflict", "late conflict must stop play")

            reset(json("available")); let playing = model(); playing.start { played = true }
            try await waitUntil { !playing.busy }
            try require(played && playing.started, "explicit play starts once")
            let before = calls(); reply(json("available", source: "Late remote"))
            await playing.followCloud(); await playing.check(); playing.start { played = false }
            try require(calls() == before && played, "never check/restore or start twice during play")
            print("automatic continuity: delivery, offline retry, conflict, permission, cancellation and play guards passed")
        } catch {
            fputs("automatic continuity failed: \(error)\n", stderr); exit(1)
        }
    }
}
