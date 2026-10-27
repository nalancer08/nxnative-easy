import Foundation
@main struct WorkflowCheck {
    @MainActor static func main() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer {try? FileManager.default.removeItem(at:root)}
        let suite="nxnative.workflow."+UUID().uuidString
        let defaults=UserDefaults(suiteName:suite)!
        defer {defaults.removePersistentDomain(forName:suite)}
        let repo=root.appendingPathComponent("repo"),game=root.appendingPathComponent("game"),other=root.appendingPathComponent("other")
        for folder in [repo,game,other] {try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)}
        let file=game.appendingPathComponent("base.xci"),update=game.appendingPathComponent("update.nsp"),key=game.appendingPathComponent("prod.keys")
        for url in [file,update,key,repo.appendingPathComponent("inside.nsp"),other.appendingPathComponent("other.nsp")] {try Data("synthetic original".utf8).write(to:url)}
        let model=BuildModel(defaults:defaults,sourceRepo:repo)
        model.acceptDrop([file,update]);assert(model.folder?.path==game.path && model.preparationStep==0)
        model.target="ios";model.acceptDrop([file,update]);assert(model.preparationStep==1)
        assert(model.detectedFiles.count==2 && model.detectedFiles.allSatisfy {$0.readable})
        assert(model.detectedFiles.reduce(0){$0+$1.size}==36)
        let empty=other.appendingPathComponent("prod.keys");try Data().write(to:empty)
        assert(!model.acceptKeysFile(empty))
        assert(!model.acceptKeysFile(repo.appendingPathComponent("inside.nsp")))
        let keyAlias=root.appendingPathComponent("prod.keys");try FileManager.default.createSymbolicLink(at:keyAlias,withDestinationURL:repo.appendingPathComponent("inside.nsp"))
        assert(!model.acceptKeysFile(keyAlias))
        model.acceptDrop([key]);assert(model.keysFolder?.path==game.path && model.preparationStep==2)
        assert(model.readableKeys)
        model.acceptDrop([file,other.appendingPathComponent("other.nsp")]);assert(model.failed && model.folder?.path==game.path)
        assert(!model.acceptFolder(repo))
        let alias=root.appendingPathComponent("repo-alias");try FileManager.default.createSymbolicLink(at:alias,withDestinationURL:repo);assert(!model.acceptFolder(alias))
        model.running=true;model.acceptDrop([other]);assert(model.folder?.path==game.path);model.running=false
        for url in [file,update,key] {let bytes=try Data(contentsOf:url);assert(bytes==Data("synthetic original".utf8))}
        assert(!FileManager.default.fileExists(atPath:repo.appendingPathComponent("prod.keys").path))
        // Fake metadata worker: exercises automatic read, stale result rejection and cancellation only.
        let scripts=repo.appendingPathComponent("scripts"),desktop=repo.appendingPathComponent("desktop/NxNativeEasy")
        try FileManager.default.createDirectory(at:scripts,withIntermediateDirectories:true)
        try FileManager.default.createDirectory(at:desktop,withIntermediateDirectories:true)
        try """
        import os,sys
        if os.getpgrp()!=os.getpid():os.setsid()
        os.execv(sys.executable,[sys.executable]+sys.argv[1:])
        """.write(to:desktop.appendingPathComponent("build_session.py"),atomically:true,encoding:.utf8)
        try """
        import sys,json,time,os
        time.sleep(0.15)
        print(json.dumps({'schema':1,'status':'ready','name':os.path.basename(sys.argv[1]),'title_id':'010093801237C000','version':0,'updates':[],'dlc':[]}))
        """.write(to:scripts.appendingPathComponent("inspect_game.py"),atomically:true,encoding:.utf8)
        assert(model.acceptFolder(game));assert(model.inspecting)
        assert(model.acceptFolder(other));assert(model.inspecting)
        for _ in 0..<100 {if !model.inspecting {break};try await Task.sleep(nanoseconds:20_000_000)}
        assert(model.inspection?.ready==true && model.inspection?.name=="other")
        model.identifyGame();assert(model.inspecting);model.cancelInspection()
        try await Task.sleep(nanoseconds:250_000_000)
        assert(!model.inspecting && model.inspection==nil)
        print("Workflow PASS: shared chooser/drop validation, target-first flow, one-folder ambiguity, repository/symlink rejection, busy guard and unchanged source/key bytes")
    }
}
