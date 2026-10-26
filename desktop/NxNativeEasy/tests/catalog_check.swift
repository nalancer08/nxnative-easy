import Foundation

@main struct CatalogCheck {
    static func main() throws {
        let base=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {try? FileManager.default.removeItem(at:base)}
        let games=base.appendingPathComponent("dm/games")
        try FileManager.default.createDirectory(at:games,withIntermediateDirectories:true)
        func profile(_ id:String,_ text:String) throws {
            let folder=games.appendingPathComponent(id)
            try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
            try text.write(to:folder.appendingPathComponent("game.tsv"),atomically:true,encoding:.utf8)
        }
        try profile("0100000000000001","# name\tignored\nname\tPokémon Example\nbuild\tv0\t1.0\n")
        try profile("0100000000000002","name\tZelda Example\nbuild\tv0\t1.9.0\nbuild\tv1\t1.9.0\n")
        try profile("not-a-title","name\tNot a game\n")
        var entries=try GameCatalog.load(repo:base)
        assert(entries.count==2)
        assert(entries[0].name=="Pokémon Example")
        assert(entries[1].versions==["1.9.0"])
        assert(GameCatalog.search(entries,query:" POKEMON ").count==1)
        assert(GameCatalog.search(entries,query:"zelda 1.9").count==1)
        assert(GameCatalog.search(entries,query:"0100000000000002").first?.name=="Zelda Example")
        assert(GameCatalog.search(entries,query:"no-match").isEmpty)
        assert(GameCatalog.search(entries,query:"   ").count==2)
        assert(entries[0].notesURL.path.hasSuffix("0100000000000001/README.md"))
        try profile("0100000000000003","name\tAnother game\nbuild\tv1\t2.0\n")
        entries=try GameCatalog.load(repo:base)
        assert(entries.count==3 && entries.first?.name=="Another game")
        let repo=URL(fileURLWithPath:CommandLine.arguments[1])
        let actual=try GameCatalog.load(repo:repo)
        let children=try FileManager.default.contentsOfDirectory(at:repo.appendingPathComponent("dm/games"),includingPropertiesForKeys:nil)
        let expected=children.filter {$0.lastPathComponent.range(of:"^[0-9A-Fa-f]{16}$",options:.regularExpression) != nil && FileManager.default.fileExists(atPath:$0.appendingPathComponent("game.tsv").path)}
        assert(!actual.isEmpty && actual.count==expected.count)
        assert(Set(actual.map {$0.id}).count==actual.count)
        assert(actual.contains {$0.name=="Metroid Dread" && $0.versions.contains("2.1.0")})
        print("Catalog PASS: \(actual.count) repository profiles, live discovery, sorting, versions, accent-insensitive search and no-results state")
    }
}
