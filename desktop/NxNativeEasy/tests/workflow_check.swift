import Foundation
@main struct WorkflowCheck {
    @MainActor static func main() throws {
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
        model.target="ios";model.acceptDrop([file,update]);assert(model.preparationStep==2)
        model.acceptDrop([key]);assert(model.keysFolder?.path==game.path && model.preparationStep==2)
        model.acceptDrop([file,other.appendingPathComponent("other.nsp")]);assert(model.failed && model.folder?.path==game.path)
        assert(!model.acceptFolder(repo))
        let alias=root.appendingPathComponent("repo-alias");try FileManager.default.createSymbolicLink(at:alias,withDestinationURL:repo);assert(!model.acceptFolder(alias))
        model.running=true;model.acceptDrop([other]);assert(model.folder?.path==game.path);model.running=false
        for url in [file,update,key] {let bytes=try Data(contentsOf:url);assert(bytes==Data("synthetic original".utf8))}
        assert(!FileManager.default.fileExists(atPath:repo.appendingPathComponent("prod.keys").path))
        print("Workflow PASS: shared chooser/drop validation, target-first flow, one-folder ambiguity, repository/symlink rejection, busy guard and unchanged source/key bytes")
    }
}
