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
        try profile("0100000000000004","name\tNested program\nprogram_of\t0100000000000003\nbuild\tv1\t2.0\n")
        let withProgram=try GameCatalog.load(repo:base)
        assert(withProgram.count==3,"A nested program is packed in its parent, not a separate game")
        try profile("0400000000000001","name\tFuture Kart\nbuild\tv0\tv0\n")
        let consoles=try GameCatalog.load(repo:base)
        assert(GameCatalog.search(consoles,query:"",console:.switch1).count==3)
        assert(GameCatalog.search(consoles,query:"",console:.switch2).map { $0.name }==["Future Kart"])
        assert(GameCatalog.search(consoles,query:"Switch 2").map { $0.name }==["Future Kart"],"A Switch 1 version containing 2 must not match the console query")
        assert(GameCatalog.search(consoles,query:"Nintendo Switch 1").count==3)
        assert(GameCatalog.search(consoles,query:"future",console:.switch1).isEmpty)
        assert(GameCatalog.search(consoles,query:"ns2 future",console:.switch2).count==1)
        let repo=URL(fileURLWithPath:CommandLine.arguments[1])
        let actual=try GameCatalog.load(repo:repo)
        let children=try FileManager.default.contentsOfDirectory(at:repo.appendingPathComponent("dm/games"),includingPropertiesForKeys:nil)
        let expected=children.filter {$0.lastPathComponent.range(of:"^[0-9A-Fa-f]{16}$",options:.regularExpression) != nil && FileManager.default.fileExists(atPath:$0.appendingPathComponent("game.tsv").path)}
        let applications=try expected.filter {child in
            !(try String(contentsOf:child.appendingPathComponent("game.tsv"),encoding:.utf8)).components(separatedBy:.newlines).contains{$0.hasPrefix("program_of\t")}
        }
        assert(!actual.isEmpty && actual.count==applications.count)
        assert(Set(actual.map {$0.id}).count==actual.count)
        assert(actual.contains {$0.name=="Metroid Dread" && $0.versions.contains("2.1.0")})
        let manifestData=try Data(contentsOf:repo.appendingPathComponent("desktop/NxNativeEasy/game-catalog.json"))
        let manifest=try JSONSerialization.jsonObject(with:manifestData) as! [String:Any]
        let rows=manifest["games"] as! [[String:Any]]
        assert(Set(rows.map {$0["id"] as! String})==Set(actual.map {$0.id}))
        for game in actual {
            let row=rows.first {$0["id"] as? String == game.id}!
            assert(row["console"] as? String == (game.isSwitch2 ? "switch2" : "switch1"))
            assert(row["name"] as? String == game.name)
            assert(row["versions"] as? [String] == game.versions)
            let artworkPath = (row["artwork"] as? String).map { repo.appendingPathComponent($0).path }
            assert(artworkPath == game.artworkURL?.path)
        }
        print("Catalog PASS: \(actual.count) repository profiles, live discovery, sorting, versions, accent-insensitive search and no-results state")
    }
}
