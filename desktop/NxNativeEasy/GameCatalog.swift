import Foundation

struct CatalogGame: Identifiable, Equatable {
    let id: String
    let name: String
    let versions: [String]

    func matches(_ query: String) -> Bool {
        let normalize: (String) -> String = {
            $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier:"en_US_POSIX"))
        }
        let haystack=normalize(([name,id]+versions).joined(separator:" "))
        return normalize(query).split(whereSeparator: {$0.isWhitespace}).allSatisfy {haystack.contains($0)}
    }
    var notesURL: URL {
        URL(string:"https://github.com/nalancer08/nxnative-easy/blob/main/dm/games/\(id)/README.md")!
    }
}

struct GameCatalog {
    // Read the installed checkout, not a manually maintained compatibility list.
    static func load(repo: URL) throws -> [CatalogGame] {
        let directory=repo.appendingPathComponent("dm/games",isDirectory:true)
        let children=try FileManager.default.contentsOfDirectory(at:directory,includingPropertiesForKeys:nil)
        var games: [CatalogGame]=[]
        for child in children {
            let id=child.lastPathComponent
            guard id.range(of:"^[0-9A-Fa-f]{16}$",options:.regularExpression) != nil else {continue}
            let profile=child.appendingPathComponent("game.tsv")
            guard FileManager.default.fileExists(atPath:profile.path) else {continue}
            let source=try String(contentsOf:profile,encoding:.utf8)
            var name: String?;var versions: [String]=[]
            for line in source.components(separatedBy:.newlines) {
                guard !line.trimmingCharacters(in:.whitespaces).hasPrefix("#") else {continue}
                let fields=line.components(separatedBy:"\t")
                if fields.count>1 && fields[0]=="name" {name=fields[1].trimmingCharacters(in:.whitespaces)}
                if fields.count>2 && fields[0]=="build" {
                    let version=fields[2].trimmingCharacters(in:.whitespaces)
                    if !version.isEmpty && !versions.contains(version) {versions.append(version)}
                }
            }
            games.append(CatalogGame(id:id,name:name?.isEmpty == false ? name! : id,versions:versions))
        }
        return games.sorted {
            let comparison=$0.name.localizedStandardCompare($1.name)
            return comparison == .orderedSame ? $0.id < $1.id : comparison == .orderedAscending
        }
    }
    static func search(_ games: [CatalogGame], query: String) -> [CatalogGame] {
        games.filter {$0.matches(query)}
    }
}
